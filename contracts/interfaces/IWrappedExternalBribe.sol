// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

interface IWrappedExternalBribe {
  struct MetaBribes {
    address[] bribedTokens;
    uint[] amounts;
    uint[] values;
    address[] gauges;
    uint tokenId;
  }

  function getRewardByIndex(uint _i) external view returns (address);

  function rewardsListLength() external view returns (uint);

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
}
