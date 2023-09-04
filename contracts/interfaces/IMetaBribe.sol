// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

interface IMetaBribe {
  function checkpoint_token() external;

  function checkpoint_total_supply() external;

  function isPartner(address _partner) external view returns (bool);

  function isEligibleTokenId(uint _tokenId) external view returns (bool);
}
