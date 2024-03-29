// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import "contracts/interfaces/IPairFactory.sol";
import "contracts/Pair.sol";

contract PairFactory is IPairFactory {
  bool public isPaused;
  address public pauser;
  address public pendingPauser;

  uint256 public stableFee;
  uint256 public volatileFee;
  uint256 public constant MAX_FEE = 300; // 3%
  // Override to indicate there is custom 0% fee - as a 0 value in the customFee mapping indicates
  // that no custom fee rate has been set
  uint256 public constant ZERO_FEE_INDICATOR = 420;

  address public feeManager;
  address public pendingFeeManager;

  mapping(address => mapping(address => mapping(bool => address)))
    public getPair;
  address[] public allPairs;
  mapping(address => bool) public is3pool;
  mapping(address => bool) public isPair; // simplified check if its a pair, given that `stable` flag might not be available in peripherals
  mapping(address => uint256) public customFee; // override for custom fees

  address internal _temp0;
  address internal _temp1;
  bool internal _temp;

  event PairCreated(
    address indexed token0,
    address indexed token1,
    bool stable,
    address pair,
    uint
  );

  constructor() {
    pauser = msg.sender;
    isPaused = false;
    feeManager = msg.sender;
    stableFee = 4; // 0.04%
    volatileFee = 30;
  }

  function allPairsLength() external view returns (uint) {
    return allPairs.length;
  }

  function getPairByIndex(uint idx) external view returns (address) {
    return allPairs[idx];
  }

  /// normal pools + 3pools

  function setPauser(address _pauser) external {
    require(msg.sender == pauser);
    pendingPauser = _pauser;
  }

  function acceptPauser() external {
    require(msg.sender == pendingPauser);
    pauser = pendingPauser;
  }

  function setPause(bool _state) external {
    require(msg.sender == pauser);
    isPaused = _state;
  }

  function setFeeManager(address _feeManager) external {
    require(msg.sender == feeManager, "not fee manager");
    pendingFeeManager = _feeManager;
  }

  function acceptFeeManager() external {
    require(msg.sender == pendingFeeManager, "not pending fee manager");
    feeManager = pendingFeeManager;
  }

  function setFee(bool _stable, uint256 _fee) external {
    require(msg.sender == feeManager, "not fee manager");
    require(_fee <= MAX_FEE, "fee too high");
    require(_fee != 0, "fee must be nonzero");
    if (_stable) {
      stableFee = _fee;
    } else {
      volatileFee = _fee;
    }
  }

  function setCustomFee(address pool, uint256 fee) external {
    require(msg.sender == feeManager, "not fee manager");
    if (fee > MAX_FEE && fee != ZERO_FEE_INDICATOR) revert();
    require(isPair[pool], "invalid pool");

    customFee[pool] = fee;
  }

  function getFee(address pool, bool _stable) public view returns (uint256) {
    uint fee = customFee[pool];
    return
      fee == ZERO_FEE_INDICATOR ? 0 : fee != 0 ? fee : _stable
        ? stableFee
        : volatileFee;
  }
  
  function getFee(address pool) external view returns (uint256) {
    return getFee(pool, is3pool[pool] || Pair(pool).stable());
  }

  function pairCodeHash() external pure returns (bytes32) {
    return keccak256(type(Pair).creationCode);
  }

  function getInitializable() external view returns (address, address, bool) {
    return (_temp0, _temp1, _temp);
  }

  function create3Pool(address _3pool) external {
    require(msg.sender == pauser);
    allPairs.push(_3pool);
    isPair[_3pool] = true;
    is3pool[_3pool] = true;
  }

  function createPair(
    address tokenA,
    address tokenB,
    bool stable
  ) external returns (address pair) {
    require(tokenA != tokenB, "IA"); // Pair: IDENTICAL_ADDRESSES
    (address token0, address token1) = tokenA < tokenB
      ? (tokenA, tokenB)
      : (tokenB, tokenA);
    require(token0 != address(0), "ZA"); // Pair: ZERO_ADDRESS
    require(getPair[token0][token1][stable] == address(0), "PE"); // Pair: PAIR_EXISTS - single check is sufficient
    bytes32 salt = keccak256(abi.encodePacked(token0, token1, stable)); // notice salt includes stable as well, 3 parameters
    (_temp0, _temp1, _temp) = (token0, token1, stable);
    pair = address(new Pair{ salt: salt }());
    getPair[token0][token1][stable] = pair;
    getPair[token1][token0][stable] = pair; // populate mapping in the reverse direction
    allPairs.push(pair);
    isPair[pair] = true;
    is3pool[pair] = false;
    emit PairCreated(token0, token1, stable, pair, allPairs.length);
  }
}
