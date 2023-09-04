// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import { WrappedExternalBribe } from "contracts/WrappedExternalBribe.sol";

contract WrappedExternalBribeFactory {
  address public immutable voter;
  mapping(address => address) public oldBribeToNew;
  address public last_bribe;
  address public router;
  address public metaBribe;
  address public governor;

  constructor(address _voter, address _router) {
    voter = _voter;
    router = _router;
    governor = msg.sender;
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

  function setMetaBribeAddress(address _metaBribe) public {
    require(msg.sender == governor);
    require(_metaBribe != address(0));
    metaBribe = _metaBribe;
  }

  function createBribe(address existing_bribe) external returns (address) {
    require(
      oldBribeToNew[existing_bribe] == address(0),
      "Wrapped bribe already created"
    );
    last_bribe = address(
      new WrappedExternalBribe(
        voter,
        existing_bribe,
        router,
        governor
      )
    );
    oldBribeToNew[existing_bribe] = last_bribe;
    return last_bribe;
  }
}
