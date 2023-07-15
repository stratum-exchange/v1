// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

interface IGauge {
  function notifyRewardAmount(
    address token,
    uint amount,
    bool is3pool
  ) external;

  function getReward(address account, address[] memory tokens) external;

  function claimFees() external returns (uint claimed0, uint claimed1);

  function claimFeesFor3Pool(
    address _swapAddress
  ) external returns (uint claimed0, uint claimed1, uint claimed2);

  function left(address token) external view returns (uint);

  function isForPair() external view returns (bool);
}
