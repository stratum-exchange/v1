// contracts/GLDToken.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract ZZZ is ERC20 {
  constructor() ERC20("ZZZ", "ZZZ") {
    _mint(msg.sender, 5_000_000 * 1e18);
  }

  function mint(address to, uint amount) external {
    _mint(to, amount);
  }
}
