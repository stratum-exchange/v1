// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;
//import "forge-std/console2.sol";
import "contracts/libraries/Math.sol";
import "contracts/interfaces/IBribe.sol";
import "contracts/interfaces/IERC20.sol";
import "contracts/interfaces/IMinter.sol";
import "contracts/interfaces/IVoter.sol";
import "contracts/interfaces/IVotingEscrow.sol";
import "contracts/Constants.sol";

// Bribes pay out rewards for a given pool based on the votes that were received from the user (goes hand in hand with Voter.vote())
contract InternalBribe is IBribe, Constants {
  address public immutable voter; // only voter can modify balances (since it only happens on vote())
  address public immutable _ve; // 天使のたまご
  address public immutable minter;

  uint internal constant DURATION = SECONDS_PER_EPOCH; // rewards are released over the voting period
  uint internal constant MAX_REWARD_TOKENS = 16;

  uint internal constant PRECISION = 10 ** 18;

  mapping(address => mapping(uint256 => IBribe.Reward)) private _rewardData; // token -> startTimestamp -> Reward
  mapping(uint256 => uint256) public _totalSupply;
  uint256 public firstBribeTimestamp;
  mapping(uint => uint) public balanceOf;
  mapping(address => mapping(uint => uint)) public tokenRewardsPerEpoch;
  mapping(address => uint) public periodFinish;
  mapping(uint256 => mapping(address => uint256)) public userTimestamp;

  address[] public rewards;
  mapping(address => bool) public isReward;

  /// @notice A checkpoint for marking balance
  struct Checkpoint {
    uint timestamp;
    uint balanceOf;
  }

  /// @notice A checkpoint for marking supply
  struct SupplyCheckpoint {
    uint timestamp;
    uint supply;
  }

  /// @notice A record of balance checkpoints for each account, by index
  mapping(uint => mapping(uint => Checkpoint)) public checkpoints;
  /// @notice The number of checkpoints for each account
  mapping(uint => uint) public numCheckpoints;
  /// @notice A record of balance checkpoints for each token, by index
  mapping(uint => SupplyCheckpoint) public supplyCheckpoints;
  /// @notice The number of checkpoints
  uint public supplyNumCheckpoints;
  mapping(uint256 => mapping(uint256 => uint256)) private _balances;

  event Deposit(address indexed from, uint tokenId, uint amount);
  event Withdraw(address indexed from, uint tokenId, uint amount);
  event NotifyReward(
    address indexed from,
    address indexed reward,
    uint epoch,
    uint amount
  );
  event ClaimRewards(address indexed from, address indexed reward, uint amount);

  constructor(address _voter, address[] memory _allowedRewardTokens) {
    voter = _voter;
    _ve = IVoter(_voter)._ve();
    minter = IVoter(_voter).minter();
    firstBribeTimestamp = 0;

    for (uint i; i < _allowedRewardTokens.length; i++) {
      if (_allowedRewardTokens[i] != address(0)) {
        isReward[_allowedRewardTokens[i]] = true;
        rewards.push(_allowedRewardTokens[i]);
      }
    }
  }

  // simple re-entrancy check
  uint internal _unlocked = 1;
  modifier lock() {
    require(_unlocked == 1);
    _unlocked = 2;
    _;
    _unlocked = 1;
  }

  function getEpochStart() public view returns (uint256) {
    return IMinter(minter).active_period();
  }

  function getNextEpochStart() public view returns (uint256) {
    return getEpochStart() + DURATION;
  }

  function rewardsListLength() external view returns (uint) {
    return rewards.length;
  }

  // returns the last time the reward was modified or periodFinish if the reward has ended
  function lastTimeRewardApplicable(address token) public view returns (uint) {
    return Math.min(block.timestamp, periodFinish[token]);
  }

  // allows a user to claim rewards for a given token
  function getReward(uint tokenId, address[] memory tokens) external lock {
    require(IVotingEscrow(_ve).isApprovedOrOwner(msg.sender, tokenId));
    for (uint i = 0; i < tokens.length; i++) {
      uint _reward = earned(tokens[i], tokenId);
      userTimestamp[tokenId][tokens[i]] = getNextEpochStart();
      if (_reward > 0) _safeTransfer(tokens[i], msg.sender, _reward);

      emit ClaimRewards(msg.sender, tokens[i], _reward);
    }
  }

  // used by Voter to allow batched reward claims
  function getRewardForOwner(
    uint tokenId,
    address[] memory tokens
  ) external lock {
    require(msg.sender == voter);
    address _owner = IVotingEscrow(_ve).ownerOf(tokenId);
    for (uint i = 0; i < tokens.length; i++) {
      uint _reward = earned(tokens[i], tokenId);
      userTimestamp[tokenId][tokens[i]] = getNextEpochStart();
      if (_reward > 0) _safeTransfer(tokens[i], _owner, _reward);

      emit ClaimRewards(_owner, tokens[i], _reward);
    }
  }

  function balanceOfAt(
    uint256 tokenId,
    uint256 _timestamp
  ) public view returns (uint256) {
    return _balances[tokenId][_timestamp];
  }

  function earned(address token, uint tokenId) public view returns (uint) {
    uint256 k = 0;
    uint256 reward = 0;
    uint256 _endTimestamp = getNextEpochStart();
    uint256 _userLastTime = userTimestamp[tokenId][token];

    if (_endTimestamp == _userLastTime) {
      return 0;
    }

    // if user first time then set it to first bribe - week to avoid any timestamp problem
    if (_userLastTime < firstBribeTimestamp) {
      _userLastTime = firstBribeTimestamp - DURATION;
    }

    for (k; k < 50; k++) {
      if (_userLastTime == _endTimestamp) {
        // if we reach the current epoch, exit
        break;
      }
      reward += _earned(tokenId, token, _userLastTime);
      _userLastTime += DURATION;
    }

    return reward;
  }

  function _earned(
    uint256 tokenId,
    address _rewardToken,
    uint256 _timestamp
  ) internal view returns (uint256) {
    uint256 _balance = balanceOfAt(tokenId, _timestamp);
    if (_balance == 0) {
      return 0;
    } else {
      uint256 _rewardPerToken = rewardPerToken(_rewardToken, _timestamp);
      uint256 _rewards = (_rewardPerToken * _balance) / 1e18;
      return _rewards;
    }
  }

  function rewardPerToken(
    address _rewardsToken,
    uint256 _timestamp
  ) public view returns (uint256) {
    if (_totalSupply[_timestamp] == 0) {
      return _rewardData[_rewardsToken][_timestamp].rewardsPerEpoch;
    }
    return
      (_rewardData[_rewardsToken][_timestamp].rewardsPerEpoch * 1e18) /
      _totalSupply[_timestamp];
  }

  // This is an external function, but internal notation is used since it can only be called "internally" from Gauges
  function _deposit(uint amount, uint tokenId) external lock {
    require(amount > 0, "Cannot stake 0");
    require(msg.sender == voter);
    uint256 _startTimestamp = getNextEpochStart();
    uint256 _oldSupply = _totalSupply[_startTimestamp];
    _totalSupply[_startTimestamp] = _oldSupply + amount;
    _balances[tokenId][_startTimestamp] =
      _balances[tokenId][_startTimestamp] +
      amount;
    emit Deposit(msg.sender, tokenId, amount);
  }

  function _withdraw(uint amount, uint tokenId) external lock {
    require(amount > 0, "Cannot withdraw 0");
    require(msg.sender == voter);
    uint256 _startTimestamp = getNextEpochStart();

    if (amount <= _balances[tokenId][_startTimestamp]) {
      uint256 _oldSupply = _totalSupply[_startTimestamp];
      uint256 _oldBalance = _balances[tokenId][_startTimestamp];
      _totalSupply[_startTimestamp] = _oldSupply - amount;
      _balances[tokenId][_startTimestamp] = _oldBalance - amount;
      emit Withdraw(msg.sender, tokenId, amount);
    }
  }

  function left(address token) external view returns (uint) {
    uint adjustedTstamp = getEpochStart();
    return _rewardData[token][adjustedTstamp].rewardsPerEpoch;
  }

  function notifyRewardAmount(address token, uint amount) external lock {
    require(isReward[token], "reward token not verified");
    _safeTransferFrom(token, msg.sender, address(this), amount);

    uint256 _startTimestamp = getNextEpochStart();
    if (firstBribeTimestamp == 0) {
      firstBribeTimestamp = _startTimestamp;
    }

    uint256 _lastReward = _rewardData[token][_startTimestamp].rewardsPerEpoch;

    _rewardData[token][_startTimestamp].rewardsPerEpoch = _lastReward + amount;
    _rewardData[token][_startTimestamp].lastUpdateTime = block.timestamp;
    _rewardData[token][_startTimestamp].periodFinish =
      _startTimestamp +
      DURATION;

    emit NotifyReward(msg.sender, token, _startTimestamp, amount);
  }

  function swapOutRewardToken(
    uint i,
    address oldToken,
    address newToken
  ) external {
    require(msg.sender == IVotingEscrow(_ve).team(), "only team");
    require(rewards[i] == oldToken);
    require(
      IVoter(voter).isWhitelisted(newToken),
      "newToken must be whitelisted"
    );
    isReward[oldToken] = false;
    isReward[newToken] = true;
    rewards[i] = newToken;
  }

  function _safeTransfer(address token, address to, uint256 value) internal {
    require(token.code.length > 0);
    (bool success, bytes memory data) = token.call(
      abi.encodeWithSelector(IERC20.transfer.selector, to, value)
    );
    require(success && (data.length == 0 || abi.decode(data, (bool))));
  }

  function _safeTransferFrom(
    address token,
    address from,
    address to,
    uint256 value
  ) internal {
    require(token.code.length > 0);
    (bool success, bytes memory data) = token.call(
      abi.encodeWithSelector(IERC20.transferFrom.selector, from, to, value)
    );
    require(success && (data.length == 0 || abi.decode(data, (bool))));
  }
}
