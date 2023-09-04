// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import { WrappedExternalBribe } from "contracts/WrappedExternalBribe.sol";

contract WrappedExternalBribeFactory {
  address public immutable voter;
  mapping(address => address) public oldBribeToNew;
  address public last_bribe;
  address public router;
  address public governor;
  address public currency;

  constructor(address _voter, address _router, address _currency) {
    voter = _voter;
    router = _router;
    governor = msg.sender;
    currency = _currency;
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

  function setCurrency(address _newCurrency) public {
    require(msg.sender == governor);
    require(_newCurrency != address(0));
    currency = _newCurrency;
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
        currency,
        governor
      )
    );
    oldBribeToNew[existing_bribe] = last_bribe;
    return last_bribe;
  }
}
