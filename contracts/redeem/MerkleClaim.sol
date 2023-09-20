// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.13;

/// ============ Imports ============

import { IStratum } from "contracts/interfaces/IStratum.sol";
import { IVotingEscrow } from "contracts/interfaces/IVotingEscrow.sol";
import { MerkleProof } from "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol"; // OZ: MerkleProof

/// @title MerkleClaim
/// @notice Claims STRAT for members of a merkle tree
/// @author Modified from Merkle Airdrop Starter (https://github.com/Anish-Agnihotri/merkle-airdrop-starter/blob/master/contracts/src/MerkleClaimERC20.sol)
contract MerkleClaim {
  /// ============ Immutable storage ============

  /// @notice STRAT token to claim
  IStratum public immutable STRAT;
  /// @notice ERC20-claimee inclusion root
  bytes32 public immutable merkleRoot;
  /// @notice for lockdrop using create_lock_for()
  address public immutable votingEscrow;

  /// ============ Mutable storage ============

  /// @notice Mapping of addresses who have claimed tokens
  mapping(address => bool) public hasClaimed;

  /// ============ Constructor ============

  /// @notice Creates a new MerkleClaim contract
  /// @param _strat address
  /// @param _merkleRoot of claimees
  constructor(address _strat, bytes32 _merkleRoot, address _votingEscrow) {
    STRAT = IStratum(_strat);
    merkleRoot = _merkleRoot;
    votingEscrow = _votingEscrow;
    STRAT.approve(votingEscrow, type(uint256).max);
  }

  /// ============ Events ============

  /// @notice Emitted after a successful token claim
  /// @param to recipient of claim
  /// @param amount of tokens claimed
  event Claim(address indexed to, uint256 amount, uint256 tokenId);

  /// ============ Functions ============

  /// @notice Allows claiming tokens if address is part of merkle tree
  /// @param amount of tokens owed to claimee
  /// @param proof merkle proof to prove address and amount are in tree
  function claim(uint256 amount, bytes32[] calldata proof) external returns (uint256) {
    // Throw if address has already claimed tokens
    require(!hasClaimed[msg.sender], "ALREADY_CLAIMED");

    // Verify merkle proof, or revert if not in tree
    bytes32 leaf = keccak256(
      bytes.concat(keccak256(abi.encode(msg.sender, amount)))
    );
    bool isValidLeaf = MerkleProof.verify(proof, merkleRoot, leaf);
    require(isValidLeaf, "NOT_IN_MERKLE");

    // Set address to claimed
    hasClaimed[msg.sender] = true;

    // Claim tokens for address
    require(STRAT.claim(address(this), amount), "CLAIM_FAILED");
    uint256 tokenId = IVotingEscrow(votingEscrow).create_lock_for(amount, 52 weeks, msg.sender);

    // Emit claim event
    emit Claim(msg.sender, amount, tokenId);

    return tokenId;
  }
}
