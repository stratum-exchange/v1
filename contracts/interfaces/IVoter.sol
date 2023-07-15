// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

interface IVoter {
  function _ve() external view returns (address);

  function length() external view returns (uint);

  function gauges(address pool) external view returns (address);

  function weights(address pool) external view returns (uint);

  function isGauge(address _gauge) external view returns (bool);

  function external_bribes(address gauge) external view returns (address);

  function poolByIndex(uint _index) external view returns (address);

  function is3poolGauge(address _gauge) external view returns (bool);

  function poolForGauge(address _gauge) external view returns (address);

  function votesByNFTAndPool(
    uint _tokenId,
    address _pool
  ) external view returns (uint);

  function governor() external view returns (address);

  function emergencyCouncil() external view returns (address);

  function attachTokenToGauge(uint _tokenId, address account) external;

  function detachTokenFromGauge(uint _tokenId, address account) external;

  function emitDeposit(uint _tokenId, address account, uint amount) external;

  function emitWithdraw(uint _tokenId, address account, uint amount) external;

  function isWhitelisted(address token) external view returns (bool);

  function notifyRewardAmount(uint amount) external;

  function distribute(address _gauge) external;
}
