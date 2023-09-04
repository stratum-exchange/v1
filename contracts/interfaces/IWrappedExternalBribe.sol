// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

interface IWrappedExternalBribe {
  struct MetaBribes {
    address[] bribedTokens;
    uint[] amounts;
    uint[] values;
    bool[] partner;
    address[] gauges;
    uint tokenId;
  }

  function getRewardByIndex(uint _i) external view returns (address);

  function rewardsListLength() external view returns (uint);

  /// @param ts timestamp will be rounded down to epoch
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
      address[] memory,
      uint
    );

  /// @param ts timestamp will be rounded down to epoch
  /// @return summed bribe values of the epoch
  function getTotalBribesValue(uint ts) external view returns(uint);

  /// @param ts timestamp will be rounded down to epoch
  /// @return summed bribe values of the epoch, but only from MetaBribe partners
  function getTotalPartnersBribesValue(uint ts) external view returns(uint);

  /// @param ts timestamp will be rounded down to epoch
  /// @return summed bribe values of the epoch from given tokenId, only if it was
  ///         a partner tokenId a time of bribe emission
  function getPartnerBribesValue(uint ts, uint tokenId) external view returns(uint);
}
