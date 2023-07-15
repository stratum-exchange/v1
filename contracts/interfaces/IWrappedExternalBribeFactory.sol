// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

interface IWrappedExternalBribeFactory {
  function oldBribeToNew(address) external view returns (address);

  function createBribe(address existing_bribe) external returns (address);
}
