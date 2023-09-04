// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import "contracts/libraries/Math.sol";
import "contracts/interfaces/IERC20.sol";
import "contracts/Constants.sol";
import "contracts/interfaces/IMetaBribe.sol";
import "contracts/interfaces/IVotingEscrow.sol";
import "contracts/interfaces/IVoter.sol";
import "contracts/interfaces/IWrappedExternalBribeFactory.sol";
import "contracts/interfaces/IWrappedExternalBribe.sol";

/*

@title Curve Fee Distribution modified for ve(3,3) emissions
@author Curve Finance, andrecronje, stratum exchange
@license MIT

*/

contract MetaBribe is IMetaBribe, Constants {
  event CheckpointToken(uint time, uint tokens);

  event Claimed(uint tokenId, uint amount, uint claim_epoch, uint max_epoch);

  uint constant WEEK = SECONDS_PER_EPOCH;

  uint public start_time; // epoch/week
  uint public time_cursor;
  mapping(uint => uint) public time_cursor_of; // tokenId => epoch/week
  mapping(uint => uint) public user_epoch_of;

  uint public last_token_time;
  uint[1000000000000000] public tokens_per_week;

  address public voting_escrow;
  address public token; // STRAT
  uint public token_last_balance;

  uint[1000000000000000] public ve_supply;

  address public depositor;
  address public governor;

  address[] public partners;
  mapping(address => uint[]) public partnerToTokenIds;
  mapping(uint => mapping(uint => uint)) public partnerTokenVotesPerEpoch; // epoch => tokenId => votes
  mapping(uint => uint) public totalPartnerVotesPerEpoch; // epoch => total partner votes

  IVoter public immutable voter;
  IWrappedExternalBribeFactory public immutable wxBribeFactory;

  constructor(address _voting_escrow, address _voter, address _wxBribeFactory) {
    uint _t = (block.timestamp / WEEK) * WEEK;
    start_time = _t;
    last_token_time = _t;
    time_cursor = _t;
    address _token = IVotingEscrow(_voting_escrow).token();
    token = _token;
    voting_escrow = _voting_escrow;
    voter = IVoter(_voter);
    wxBribeFactory = IWrappedExternalBribeFactory(_wxBribeFactory);
    depositor = msg.sender;
    governor = msg.sender;
    require(IERC20(_token).approve(_voting_escrow, type(uint).max));
  }

  function setGovernor(address _governor) public {
    require(msg.sender == governor);
    require(_governor != address(0));
    governor = _governor;
  }

  function addPartners(
    address[] memory _partners,
    uint[] memory _tokenIds
  ) external {
    require(_partners.length == _tokenIds.length, "array size differs");
    require(msg.sender == governor);

    for (
      uint newPartnerIdx = 0;
      newPartnerIdx < _partners.length;
      newPartnerIdx++
    ) {
      // only accept tokens with voting power (plausibility check)
      require(
        IVotingEscrow(voting_escrow).balanceOfNFT(_tokenIds[newPartnerIdx]) > 0,
        "zero voting power"
      );

      // prevent duplicate entries
      for (
        uint existingPartnerIdx = 0;
        existingPartnerIdx < partners.length;
        existingPartnerIdx++
      ) {
        for (
          uint veTokenIdx = 0;
          veTokenIdx < partnerToTokenIds[partners[existingPartnerIdx]].length;
          veTokenIdx++
        ) {
          if (
            partnerToTokenIds[partners[existingPartnerIdx]][veTokenIdx] ==
            _tokenIds[newPartnerIdx]
          ) {
            revert("already partner token");
          }
        }
      }

      // add new partner and tokenId
      if (!isPartner(_partners[newPartnerIdx])) {
        partners.push(_partners[newPartnerIdx]);
      }
      partnerToTokenIds[_partners[newPartnerIdx]].push(
        _tokenIds[newPartnerIdx]
      );
    }
  }

  function removePartner(address _partner) external {
    require(msg.sender == governor);
    uint partnerIndex = 0;
    bool partnerFound = false;
    for (uint i = 0; i < partners.length; i++) {
      if (partners[i] == _partner) {
        partnerIndex = i;
        partnerFound = true;
        break;
      }
    }
    require(partnerFound, "address no partner");
    delete partners[partnerIndex];
    delete partnerToTokenIds[_partner];
  }

  function removePartnerToken(address _partner, uint _tokenId) external {
    require(msg.sender == governor);
    for (uint i = 0; i < partnerToTokenIds[_partner].length; i++) {
      if (partnerToTokenIds[_partner][i] == _tokenId) {
        partnerToTokenIds[_partner][i] = 0;
        return;
      }
    }
    revert("not found");
  }

  function partnersLength() external view returns (uint) {
    return partners.length;
  }

  function isPartner(address _partner) public view returns (bool) {
    for (uint i = 0; i < partners.length; i++) {
      if (partners[i] == _partner) {
        return true;
      }
    }
    return false;
  }

  function isEligibleTokenId(uint _tokenId) public view returns (bool) {
    for (uint i = 0; i < partners.length; i++) {
      uint[] memory tokenIds = partnerToTokenIds[partners[i]];
      for (uint j = 0; j < tokenIds.length; j++) {
        if (tokenIds[j] == _tokenId) {
          return true;
        }
      }
    }
    return false;
  }

  function timestamp() public view returns (uint) {
    return (block.timestamp / WEEK) * WEEK;
  }

  /// @dev updates to_distribute
  function _checkpoint_token() internal {
    uint token_balance = IERC20(token).balanceOf(address(this));
    uint to_distribute = token_balance - token_last_balance;
    token_last_balance = token_balance;

    uint t = last_token_time;
    uint since_last = block.timestamp - t;
    last_token_time = block.timestamp;
    uint this_week = (t / WEEK) * WEEK;
    uint next_week = 0;

    for (uint i = 0; i < 20; i++) {
      next_week = this_week + WEEK;
      if (block.timestamp < next_week) {
        if (since_last == 0 && block.timestamp == t) {
          tokens_per_week[this_week] += to_distribute;
        } else {
          tokens_per_week[this_week] +=
            (to_distribute * (block.timestamp - t)) /
            since_last;
        }
        break;
      } else {
        if (since_last == 0 && next_week == t) {
          tokens_per_week[this_week] += to_distribute;
        } else {
          tokens_per_week[this_week] +=
            (to_distribute * (next_week - t)) /
            since_last;
        }
      }
      t = next_week;
      this_week = next_week;
    }
    emit CheckpointToken(block.timestamp, to_distribute);
  }

  function checkpoint_token() external {
    assert(msg.sender == depositor);
    _snapshot_partner_votes();
    _checkpoint_token();
  }

  function _snapshot_partner_votes() internal {
    uint past_epoch = timestamp() - WEEK;
    for (uint i = 0; i < partners.length; i++) {
      if (partners[i] == address(0)) {
        continue;
      }
      for (uint j = 0; j < partnerToTokenIds[partners[i]].length; j++) {
        uint _tokenId = partnerToTokenIds[partners[i]][j];
        uint used_votes = 0;
        for (uint k = 0; k < voter.length(); k++) {
          used_votes += voter.votesByNFTAndPool(_tokenId, voter.poolByIndex(k));
        }
        partnerTokenVotesPerEpoch[past_epoch][_tokenId] = used_votes;
        totalPartnerVotesPerEpoch[past_epoch] += used_votes;
      }
    }
  }

  function _find_timestamp_epoch(
    address ve,
    uint _timestamp
  ) internal view returns (uint) {
    uint _min = 0;
    uint _max = IVotingEscrow(ve).epoch();
    for (uint i = 0; i < 128; i++) {
      if (_min >= _max) break;
      uint _mid = (_min + _max + 2) / 2;
      IVotingEscrow.Point memory pt = IVotingEscrow(ve).point_history(_mid);
      if (pt.ts <= _timestamp) {
        _min = _mid;
      } else {
        _max = _mid - 1;
      }
    }
    return _min;
  }

  function _find_timestamp_user_epoch(
    address ve,
    uint tokenId,
    uint _timestamp,
    uint max_user_epoch
  ) internal view returns (uint) {
    uint _min = 0;
    uint _max = max_user_epoch;
    for (uint i = 0; i < 128; i++) {
      if (_min >= _max) break;
      uint _mid = (_min + _max + 2) / 2;
      IVotingEscrow.Point memory pt = IVotingEscrow(ve).user_point_history(
        tokenId,
        _mid
      );
      if (pt.ts <= _timestamp) {
        _min = _mid;
      } else {
        _max = _mid - 1;
      }
    }
    return _min;
  }

  function getWrappedExternalBribeByPool(
    uint _poolIndex
  ) public view returns (address) {
    address pool = voter.poolByIndex(_poolIndex);
    address gauge = voter.gauges(pool);
    address xBribe = voter.external_bribes(gauge);
    return wxBribeFactory.oldBribeToNew(xBribe);
  }

  function ve_for_at(
    uint _tokenId,
    uint _timestamp
  ) public view returns (uint) {
    address ve = voting_escrow;
    uint max_user_epoch = IVotingEscrow(ve).user_point_epoch(_tokenId);
    uint epoch = _find_timestamp_user_epoch(
      ve,
      _tokenId,
      _timestamp,
      max_user_epoch
    );
    IVotingEscrow.Point memory pt = IVotingEscrow(ve).user_point_history(
      _tokenId,
      epoch
    );
    int256 vp = int256(pt.bias - pt.slope * (int128(int256(_timestamp - pt.ts))));
    return vp > 0 ? uint(vp) : 0;
  }

  function _checkpoint_total_supply() internal {
    address ve = voting_escrow;
    uint t = time_cursor;
    uint rounded_timestamp = (block.timestamp / WEEK) * WEEK;
    IVotingEscrow(ve).checkpoint();

    for (uint i = 0; i < 20; i++) {
      if (t > rounded_timestamp) {
        break;
      } else {
        uint epoch = _find_timestamp_epoch(ve, t);
        IVotingEscrow.Point memory pt = IVotingEscrow(ve).point_history(epoch);
        int128 dt = 0;
        if (t > pt.ts) {
          dt = int128(int256(t - pt.ts));
        }
        ve_supply[t] = pt.bias > pt.slope * dt
          ? uint(int256(pt.bias - pt.slope * dt))
          : 0;
      }
      t += WEEK;
    }
    time_cursor = t;
  }

  function checkpoint_total_supply() external {
    _checkpoint_total_supply();
  }

  /// @notice sums up values of bribes associated with partner tokenId in epoch _ts
  function check_user_bribes_value(
    uint tokenId,
    uint _ts
  ) public view returns (uint) {
    uint bribes_value = 0;
    uint pools_len = voter.length();
    for (uint i = 0; i < pools_len; i++) {
      address _wxBribe = getWrappedExternalBribeByPool(i);
      if (_wxBribe != address(0)) {
        bribes_value += IWrappedExternalBribe(_wxBribe).getPartnerBribesValue(_ts, tokenId);
      }
    }
    return bribes_value;
  }

  /// @notice sums up values of all bribes
  function check_total_bribes_value(uint _ts) public view returns (uint) {
    uint bribes_value = 0;
    uint pools_len = voter.length();
    for (uint i = 0; i < pools_len; i++) {
      address _wxBribe = getWrappedExternalBribeByPool(i);
      if (_wxBribe != address(0)) {
        bribes_value += IWrappedExternalBribe(_wxBribe).getTotalPartnersBribesValue(_ts);
      }
    }
    return bribes_value;
  }

  /// @notice sum of voting power of all partner veSTRAT
  function total_partner_voting_power(uint _ts) public view returns (uint) {
    uint partnerBalance = 0;
    for (uint i = 0; i < partners.length; i++) {
      for (uint j = 0; j < partnerToTokenIds[partners[i]].length; j++) {
        uint tokenId = partnerToTokenIds[partners[i]][j];
        uint balance = ve_for_at(tokenId, _ts);
        partnerBalance += balance;
      }
    }
    return partnerBalance;
  }

  function get_metabribe_weight(
    uint _tokenId,
    uint week_cursor
  ) public view returns (uint) {
    uint total_bribes_value = check_total_bribes_value(week_cursor);
    uint user_bribes_value = check_user_bribes_value(_tokenId, week_cursor);
    uint token_voting_power = ve_for_at(_tokenId, week_cursor);
    uint total_voting_power = total_partner_voting_power(week_cursor);
    if (user_bribes_value > 0) {
      return
        (2 * user_bribes_value * 1000) / total_bribes_value +
        (token_voting_power * 1000) / total_voting_power;
    }
    return 0;
  }

  function get_metabribe_total_weight(
    uint week_cursor
  ) public view returns (uint) {
    uint totalWeight = 0;
    for (uint partnerIdx = 0; partnerIdx < partners.length; partnerIdx++) {
      for (
        uint partnerTokenIdx = 0;
        partnerTokenIdx < partnerToTokenIds[partners[partnerIdx]].length;
        partnerTokenIdx++
      ) {
        uint nftID = partnerToTokenIds[partners[partnerIdx]][partnerTokenIdx];
        totalWeight += get_metabribe_weight(nftID, week_cursor);
      }
    }
    return totalWeight;
  }

  function _claim(
    uint _tokenId,
    address ve,
    uint _last_token_time
  ) internal returns (uint) {
    require(IVotingEscrow(voting_escrow).isApprovedOrOwner(msg.sender, _tokenId), "not approved");

    uint user_epoch = 0;
    uint rebase = 0;

    uint max_user_epoch = IVotingEscrow(ve).user_point_epoch(_tokenId);
    uint _start_time = start_time;

    if (max_user_epoch == 0) return 0;

    uint week_cursor = time_cursor_of[_tokenId];
    if (week_cursor == 0) {
      user_epoch = _find_timestamp_user_epoch(
        ve,
        _tokenId,
        _start_time,
        max_user_epoch
      );
    } else {
      user_epoch = user_epoch_of[_tokenId];
    }

    if (user_epoch == 0) user_epoch = 1;

    IVotingEscrow.Point memory user_point = IVotingEscrow(ve)
      .user_point_history(_tokenId, user_epoch);

    if (week_cursor == 0)
      week_cursor = ((user_point.ts + WEEK - 1) / WEEK) * WEEK;
    if (week_cursor >= last_token_time) return 0;
    if (week_cursor < _start_time) week_cursor = _start_time;

    IVotingEscrow.Point memory old_user_point;

    for (uint i = 0; i < 50; i++) {
      if (week_cursor >= _last_token_time) break;

      if (week_cursor >= user_point.ts && user_epoch <= max_user_epoch) {
        user_epoch += 1;
        old_user_point = user_point;
        if (user_epoch > max_user_epoch) {
          user_point = IVotingEscrow.Point(0, 0, 0, 0);
        } else {
          user_point = IVotingEscrow(ve).user_point_history(
            _tokenId,
            user_epoch
          );
        }
      } else {
        // metabribe logic
        uint weight = get_metabribe_weight(_tokenId, week_cursor);
        uint totalWeight = get_metabribe_total_weight(week_cursor);

        if (totalWeight == 0) {
          rebase = 0;
        } else {
          rebase +=
            (((weight * 1000) / totalWeight) * tokens_per_week[week_cursor]) /
            1000;
        }

        week_cursor += WEEK;
      }
    }

    user_epoch = Math.min(max_user_epoch, user_epoch - 1);
    user_epoch_of[_tokenId] = user_epoch;
    time_cursor_of[_tokenId] = week_cursor;

    // emit Claimed(_tokenId, to_distribute, user_epoch, max_user_epoch);

    return rebase;
  }

  function _claimable(
    uint _tokenId,
    address ve,
    uint _last_token_time
  ) internal view returns (uint) {
    uint user_epoch = 0;
    // uint to_distribute = 0;
    uint rebase = 0;

    uint max_user_epoch = IVotingEscrow(ve).user_point_epoch(_tokenId);
    uint _start_time = start_time;

    if (max_user_epoch == 0) return 0;

    uint week_cursor = time_cursor_of[_tokenId];
    if (week_cursor == 0) {
      user_epoch = _find_timestamp_user_epoch(
        ve,
        _tokenId,
        _start_time,
        max_user_epoch
      );
    } else {
      user_epoch = user_epoch_of[_tokenId];
    }

    if (user_epoch == 0) user_epoch = 1;

    IVotingEscrow.Point memory user_point = IVotingEscrow(ve)
      .user_point_history(_tokenId, user_epoch);

    if (week_cursor == 0)
      week_cursor = ((user_point.ts + WEEK - 1) / WEEK) * WEEK;
    if (week_cursor >= last_token_time) return 0;
    if (week_cursor < _start_time) week_cursor = _start_time;

    IVotingEscrow.Point memory old_user_point;

    for (uint i = 0; i < 50; i++) {
      if (week_cursor >= _last_token_time) break;

      if (week_cursor >= user_point.ts && user_epoch <= max_user_epoch) {
        user_epoch += 1;
        old_user_point = user_point;
        if (user_epoch > max_user_epoch) {
          user_point = IVotingEscrow.Point(0, 0, 0, 0);
        } else {
          user_point = IVotingEscrow(ve).user_point_history(
            _tokenId,
            user_epoch
          );
        }
      } else {
        // metabribe logic
        uint weight = get_metabribe_weight(_tokenId, week_cursor);
        uint totalWeight = get_metabribe_total_weight(week_cursor);

        if (totalWeight == 0) {
          rebase = 0;
        } else {
          rebase +=
            (((weight * 1000) / totalWeight) * tokens_per_week[week_cursor]) /
            1000;
        }
        week_cursor += WEEK;
      }
    }
    return rebase;
  }

  function claimable(
    uint _tokenId
  ) external view returns (uint) {
    uint _last_token_time = (last_token_time / WEEK) * WEEK;
    return _claimable(_tokenId, voting_escrow, _last_token_time);
  }

  function claim(uint _tokenId) external returns (uint) {
    require(isPartner(msg.sender) == true, "not a partner");
    if (block.timestamp >= time_cursor) _checkpoint_total_supply();
    uint _last_token_time = last_token_time;
    _last_token_time = (_last_token_time / WEEK) * WEEK;
    uint amount = _claim(_tokenId, voting_escrow, _last_token_time);
    if (amount != 0) {
      IVotingEscrow(voting_escrow).deposit_for(_tokenId, amount);
      token_last_balance -= amount;
    }
    return amount;
  }

  function claim_many(
    uint[] memory _tokenIds
  ) external returns (bool) {
    if (block.timestamp >= time_cursor) _checkpoint_total_supply();
    uint _last_token_time = last_token_time;
    _last_token_time = (_last_token_time / WEEK) * WEEK;
    address _voting_escrow = voting_escrow;
    uint total = 0;

    for (uint i = 0; i < _tokenIds.length; i++) {
      uint _tokenId = _tokenIds[i];
      if (_tokenId == 0) break;
      uint amount = _claim(_tokenId, _voting_escrow, _last_token_time);
      if (amount != 0) {
        IVotingEscrow(_voting_escrow).deposit_for(_tokenId, amount);
        total += amount;
      }
    }
    if (total != 0) {
      token_last_balance -= total;
    }

    return true;
  }

  // Once off event on contract initialize
  function setDepositor(address _depositor) external {
    require(msg.sender == depositor);
    require(_depositor != address(0));
    depositor = _depositor;
  }
}
