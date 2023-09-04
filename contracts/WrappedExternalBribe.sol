// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import "contracts/libraries/Math.sol";
import "contracts/ExternalBribe.sol";
import "contracts/interfaces/IERC20.sol";
import "contracts/interfaces/IGauge.sol";
import "contracts/interfaces/IPair.sol";
import "contracts/interfaces/IRouter.sol";
import "contracts/interfaces/IVoter.sol";
import "contracts/interfaces/IVotingEscrow.sol";
import "contracts/interfaces/IWrappedExternalBribe.sol";
import "contracts/interfaces/IWrappedExternalBribeFactory.sol";
import "contracts/interfaces/IMetaBribe.sol";
import "contracts/Constants.sol";

// Bribes pay out rewards for a given pool based on the votes that were received from the user (goes hand in hand with Voter.vote())
contract WrappedExternalBribe is IWrappedExternalBribe, Constants {

  struct MetaBribeInfo {
    address bribedToken;
    uint amount;
    uint value;
    bool partner;
    address gauge;
  }

  struct MetaBribeEpoch {
    uint totalValue;
    uint totalValueFromPartners;
    mapping(uint => MetaBribeInfo[]) bribes; // tokenId => MetaBribeInfo[]
  }

  address public immutable voter;
  address public immutable _ve;
  address public router;
  address public governor;
  IWrappedExternalBribeFactory public wxbFactory;
  ExternalBribe public underlying_bribe;

  uint internal constant DURATION = SECONDS_PER_EPOCH; // rewards are released over the voting period
  uint internal constant MAX_REWARD_TOKENS = 16;

  uint internal constant PRECISION = 10 ** 18;

  mapping(address => mapping(uint => uint)) public tokenRewardsPerEpoch;
  mapping(address => uint) public periodFinish;
  mapping(address => mapping(uint => uint)) public lastEarn;

  address[] public rewards;
  mapping(address => bool) public isReward;

  // Make sure MetaBribe weights are final at the end of epoch: Memorizing prevents changes in formula
  // weights, when updating MetaBribe partner/token whitelists with tokenIds that have already
  // bribed in the past.
  mapping(uint => MetaBribeEpoch) public metaBribeEpoch; // epoch => MetaBribeEpoch

  /// @notice A checkpoint for marking balance
  struct RewardCheckpoint {
    uint timestamp;
    uint balance;
  }

  event NotifyReward(
    address indexed from,
    address indexed reward,
    uint epoch,
    uint amount
  );
  event NotifyRewardMetaBribe(
    address indexed from,
    address indexed reward,
    uint epoch,
    uint amount,
    uint value,
    bool partner,
    address gauge,
    uint tokenId
  );
  event ClaimRewards(address indexed from, address indexed reward, uint amount);

  constructor(
    address _voter,
    address _old_bribe,
    address _router,
    address _governor
  ) {
    voter = _voter;
    router = _router;
    governor = _governor;
    _ve = IVoter(_voter)._ve();
    wxbFactory = IWrappedExternalBribeFactory(msg.sender);
    underlying_bribe = ExternalBribe(_old_bribe);

    for (uint i; i < underlying_bribe.rewardsListLength(); i++) {
      address underlying_reward = underlying_bribe.rewards(i);
      if (underlying_reward != address(0)) {
        isReward[underlying_reward] = true;
        rewards.push(underlying_reward);
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

  function setRouter(address _newRouter) public {
    require(msg.sender == governor);
    require(_newRouter != address(0));
    router = _newRouter;
  }

  function setGovernor(address _governor) public {
    require(msg.sender == governor);
    require(_governor != address(0));
    governor = _governor;
  }

  function _bribeStart(uint timestamp) internal pure returns (uint) {
    return timestamp - (timestamp % SECONDS_PER_EPOCH);
  }

  function getEpochStart(uint timestamp) public pure returns (uint) {
    uint bribeStart = _bribeStart(timestamp);
    uint bribeEnd = bribeStart + DURATION;
    return timestamp < bribeEnd ? bribeStart : bribeStart + SECONDS_PER_EPOCH;
  }

  function rewardsListLength() external view returns (uint) {
    return rewards.length;
  }

  function getRewardByIndex(uint _i) external view returns (address) {
    return rewards[_i];
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
      lastEarn[tokens[i]][tokenId] = block.timestamp;
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
      lastEarn[tokens[i]][tokenId] = block.timestamp;
      if (_reward > 0) _safeTransfer(tokens[i], _owner, _reward);

      emit ClaimRewards(_owner, tokens[i], _reward);
    }
  }

  function earned(address token, uint tokenId) public view returns (uint) {
    if (underlying_bribe.numCheckpoints(tokenId) == 0) {
      return 0;
    }

    uint reward = 0;
    uint _ts = 0;
    uint _bal = 0;
    uint _supply = 1;
    uint _index = 0;
    uint _currTs = _bribeStart(lastEarn[token][tokenId]); // take epoch last claimed in as starting point

    _index = underlying_bribe.getPriorBalanceIndex(tokenId, _currTs);
    (_ts, _bal) = underlying_bribe.checkpoints(tokenId, _index);
    // accounts for case where lastEarn is before first checkpoint
    _currTs = Math.max(_currTs, _bribeStart(_ts));

    // get epochs between current epoch and first checkpoint in same epoch as last claim
    uint numEpochs = (_bribeStart(block.timestamp) - _currTs) / DURATION;

    if (numEpochs > 0) {
      for (uint256 i = 0; i < numEpochs; i++) {
        // get index of last checkpoint in this epoch
        _index = underlying_bribe.getPriorBalanceIndex(
          tokenId,
          _currTs + DURATION - 1
        );
        // get checkpoint in this epoch
        (_ts, _bal) = underlying_bribe.checkpoints(tokenId, _index);
        // get supply of last checkpoint in this epoch
        (, _supply) = underlying_bribe.supplyCheckpoints(
          underlying_bribe.getPriorSupplyIndex(_currTs + DURATION - 1)
        );
        reward += (_bal * tokenRewardsPerEpoch[token][_currTs]) / _supply;
        _currTs += DURATION;
      }
    }

    return reward;
  }

  function left(address token) external view returns (uint) {
    uint adjustedTstamp = getEpochStart(block.timestamp);
    return tokenRewardsPerEpoch[token][adjustedTstamp];
  }

  // only for tests, debugging and insights, not used in contracts anymore
  function getMetaBribe(
    uint tokenId,
    uint ts
  )
    external
    view
    returns (
      address[] memory,
      uint[] memory,
      uint[] memory,
      bool[] memory,
      address[] memory
    )
  {
    MetaBribeInfo[] storage mb = metaBribeEpoch[ts].bribes[tokenId];
    uint n = mb.length;
    address[] memory bribedTokens = new address[](n);
    uint[] memory amounts = new uint[](n);
    uint[] memory values = new uint[](n);
    bool[] memory partner = new bool[](n);
    address[] memory gauges = new address[](n);
    for (uint i = 0; i < n; i++) {
      bribedTokens[i] = mb[i].bribedToken;
      amounts[i] = mb[i].amount;
      values[i] = mb[i].value;
      partner[i] = mb[i].partner;
      gauges[i] = mb[i].gauge;
    }
    return (bribedTokens, amounts, values, partner, gauges);
  }

  // emits a bribe by a user
  function notifyRewardAmount(
    address token,
    uint amount,
    address gauge,
    uint tokenId
  ) external lock {
    require(amount > 0);
    if (!isReward[token]) {
      require(
        IVoter(voter).isWhitelisted(token),
        "bribe tokens must be whitelisted"
      );
      require(rewards.length < MAX_REWARD_TOKENS, "too many rewards tokens");
    }
    // bribes kick in at the start of next bribe period
    uint adjustedTstamp = getEpochStart(block.timestamp);
    uint epochRewards = tokenRewardsPerEpoch[token][adjustedTstamp];

    _safeTransferFrom(token, msg.sender, address(this), amount);
    tokenRewardsPerEpoch[token][adjustedTstamp] = epochRewards + amount;

    periodFinish[token] = adjustedTstamp + DURATION;

    if (!isReward[token]) {
      isReward[token] = true;
      rewards.push(token);
    }

    IMetaBribe _metaBribe = IMetaBribe(wxbFactory.metaBribe());
    uint value = _metaBribe.estimateValue(token, amount, _metaBribe.currency());

    bool isPartner = isPartnerToken(tokenId);

    metaBribeEpoch[adjustedTstamp].bribes[tokenId].push(MetaBribeInfo({
      bribedToken : token,
      amount : amount,
      value : value,
      partner : isPartner,
      gauge : gauge
    }));

    metaBribeEpoch[adjustedTstamp].totalValue += value;
    if (isPartner) {
      metaBribeEpoch[adjustedTstamp].totalValueFromPartners += value;
    }

    emit NotifyRewardMetaBribe(
      msg.sender,
      token,
      adjustedTstamp,
      amount,
      value,
      isPartner,
      gauge,
      tokenId
    );
  }

  /// @inheritdoc IWrappedExternalBribe
  function getTotalBribesValue(uint ts) external view returns (uint) {
    return metaBribeEpoch[getEpochStart(ts)].totalValue;
  }

  /// @inheritdoc IWrappedExternalBribe
  function getTotalPartnersBribesValue(uint ts) external view returns (uint) {
    return metaBribeEpoch[getEpochStart(ts)].totalValueFromPartners;
  }

  /// @inheritdoc IWrappedExternalBribe
  function getPartnerBribesValue(uint ts, uint tokenId) external view returns (uint) {
    ts = getEpochStart(ts);
    uint sum = 0;
    MetaBribeInfo[] storage mb = metaBribeEpoch[ts].bribes[tokenId];
    for (uint i = 0; i < mb.length; i++) {
      if (mb[i].partner) {
        sum += mb[i].value;
      }
    }
    return sum;
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

  /// @return true if tokenId is a whitelisted MetaBribe partner token
  function isPartnerToken(uint tokenId) public view returns (bool) {
    address metaBribe = wxbFactory.metaBribe();
    return IMetaBribe(metaBribe).isEligibleTokenId(tokenId);
  }
}
