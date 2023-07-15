// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.13;

import "contracts/libraries/Math.sol";
import "contracts/Constants.sol";
import "contracts/interfaces/IMinter.sol";
import "contracts/interfaces/IRewardsDistributor.sol";
import "contracts/interfaces/IMetaBribe.sol";
import "contracts/interfaces/IStratum.sol";
import "contracts/interfaces/IVoter.sol";
import "contracts/interfaces/IVotingEscrow.sol";

// codifies the minting rules as per ve(3,3), abstracted from the token to support any token that allows minting

contract Minter is IMinter, Constants {

  uint internal constant WEEK = SECONDS_PER_EPOCH; // allows minting once per week (reset every Thursday 00:00 UTC)
  uint internal constant TAIL_EMISSION = 2; // 0.2%
  uint internal constant PRECISION = 1000;
  uint internal emission;
  uint internal numEpoch;
  IStratum public immutable _stratum;
  IVoter public immutable _voter;
  IVotingEscrow public immutable _ve;
  IRewardsDistributor public immutable _rewards_distributor;
  IMetaBribe public immutable _meta_bribe;
  uint public weekly = 750_000 * 1e18; // represents a starting weekly emission of 750k STRAT (STRAT has 18 decimals)
  uint public active_period;
  uint internal constant LOCK = SECONDS_PER_EPOCH * 52 * 1;

  address internal initializer;
  address public team;
  address public pendingTeam;
  uint public teamRate;
  uint public constant MAX_TEAM_RATE = 50; // 5%

  event Mint(
    address indexed sender,
    uint weekly,
    uint circulating_supply,
    uint circulating_emission
  );

  constructor(
    address __voter, // the voting & distribution system
    address __ve, // the ve(3,3) system that will be locked into
    address __rewards_distributor, // the distribution system that ensures users aren't diluted
    address __meta_bribe
  ) {
    initializer = msg.sender;
    team = msg.sender;
    teamRate = 20; // 2%
    emission = 990; // 99%, changes to 99.5% on epoch 20
    _stratum = IStratum(IVotingEscrow(__ve).token());
    _voter = IVoter(__voter);
    _ve = IVotingEscrow(__ve);
    _rewards_distributor = IRewardsDistributor(__rewards_distributor);
    _meta_bribe = IMetaBribe(__meta_bribe);
    active_period = ((block.timestamp + (2 * WEEK)) / WEEK) * WEEK;
  }

  function initialize(
    address[] memory claimants,
    uint[] memory amounts,
    uint max // sum amounts / max = % ownership of top protocols, so if initial 20m is distributed, and target is 25% protocol ownership, then max - 4 x 20m = 80m
  ) external {
    require(initializer == msg.sender);
    _stratum.mint(address(this), max);
    _stratum.approve(address(_ve), type(uint).max);
    for (uint i = 0; i < claimants.length; i++) {
      _ve.create_lock_for(amounts[i], LOCK, claimants[i]);
    }
    initializer = address(0);
    active_period = ((block.timestamp) / WEEK) * WEEK; // allow minter.update_period() to mint new emissions THIS Thursday
  }

  function setTeam(address _team) external {
    require(msg.sender == team, "not team");
    pendingTeam = _team;
  }

  function acceptTeam() external {
    require(msg.sender == pendingTeam, "not pending team");
    team = pendingTeam;
  }

  function setTeamRate(uint _teamRate) external {
    require(msg.sender == team, "not team");
    require(_teamRate <= MAX_TEAM_RATE, "rate too high");
    teamRate = _teamRate;
  }

  // calculate circulating supply as total token supply - locked supply
  function circulating_supply() public view returns (uint) {
    return _stratum.totalSupply() - _ve.totalSupply();
  }

  // emission calculation is 1% of available supply to mint adjusted by circulating / total supply
  function calculate_emission() public view returns (uint) {
    return (weekly * emission) / PRECISION;
  }

  // weekly emission takes the max of calculated (aka target) emission versus circulating tail end emission
  function weekly_emission() public view returns (uint) {
    return Math.max(calculate_emission(), circulating_emission());
  }

  // calculates tail end (infinity) emissions as 0.2% of total supply
  function circulating_emission() public view returns (uint) {
    return (circulating_supply() * TAIL_EMISSION) / PRECISION;
  }

  // calculate inflation and adjust ve balances accordingly
  function calculate_growth(uint _minted) public view returns (uint) {
    uint _veTotal = _ve.totalSupply();
    uint _stratumTotal = _stratum.totalSupply();
    return
      (((((_minted * _veTotal) / _stratumTotal) * _veTotal) / _stratumTotal) *
        _veTotal) /
      _stratumTotal /
      2;
  }

  // update period can only be called once per cycle (1 week)
  function update_period() external returns (uint) {
    uint _period = active_period;
    // if (block.timestamp >= _period + WEEK && initializer == address(0)) {
    if (initializer == address(0)) {
      // only trigger if new week
      _period = (block.timestamp / WEEK) * WEEK;
      active_period = _period;
      weekly = weekly_emission();

      // rebase
      uint _growth = calculate_growth(weekly);

      // metabribe
      uint _meta_bribes = (70 * (_growth + weekly)) / PRECISION;

      // team emissions
      uint _teamEmissions = (teamRate * (_growth + weekly)) / PRECISION;

      uint _required = _growth + _meta_bribes + weekly + _teamEmissions;
      uint _balanceOf = _stratum.balanceOf(address(this));
      if (_balanceOf < _required) {
        _stratum.mint(address(this), _required - _balanceOf);
      }

      unchecked {
        ++numEpoch;
      }
      if (numEpoch == 20) emission = 995;

      require(_stratum.transfer(team, _teamEmissions));

      // rebase (metabribe)
      require(_stratum.transfer(address(_meta_bribe), _meta_bribes));
      _meta_bribe.checkpoint_token(); // checkpoint token balance that was just minted in rewards distributor
      _meta_bribe.checkpoint_total_supply(); // checkpoint supply

      require(_stratum.transfer(address(_rewards_distributor), _growth));
      _rewards_distributor.checkpoint_token(); // checkpoint token balance that was just minted in rewards distributor
      _rewards_distributor.checkpoint_total_supply(); // checkpoint supply

      _stratum.approve(address(_voter), weekly);
      _voter.notifyRewardAmount(weekly);

      emit Mint(
        msg.sender,
        weekly,
        circulating_supply(),
        circulating_emission()
      );
    }
    return _period;
  }
}
