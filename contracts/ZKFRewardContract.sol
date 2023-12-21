// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {MerkleProof} from "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";

contract ZKFRewardContract is OwnableUpgradeable {
    event UpdateMerkleRoot(bytes32 indexed oldRoot, bytes32 indexed newRoot, uint256 indexed timestamp);
    event ClaimReward(address indexed recipient, uint256 indexed amount, uint256 indexed timestamp, uint256 totalClaimed);
    event UpdateBalance(uint256 indexed amount, uint256 balance, uint256 totalDistributed, uint256 indexed timestamp);

    struct ClaimInfo {
        uint256 amount;
        uint256 timestamp;
    }

    uint256 public constant period = 1 days;

    bytes32 private merkleRoot;
    bytes32 public pendingMerkleRoot;

    // admin address which can propose adding a new merkle root
    address public proposalAuthority;
    // admin address which approves or rejects a proposed merkle root
    address public reviewAuthority;

    uint256 public totalDistributed;
    uint256 public balanceUpdatedAt;
    uint256 public rootUpdatedAt;
    address public rewardSponsor;
    
    mapping(address => ClaimInfo) public claims;

    modifier onlyValidAddress(address addr) {
        require(addr != address(0), "Illegal address");
        _;
    }

    constructor() {
        _disableInitializers();
    }
    
    function initialize(address _proposalAuthority, address _reviewAuthority, address _rewardSponsor)  onlyValidAddress(_proposalAuthority) onlyValidAddress(_reviewAuthority) onlyValidAddress(_rewardSponsor)  external virtual initializer {
        proposalAuthority = _proposalAuthority;
        reviewAuthority = _reviewAuthority;
        rewardSponsor = _rewardSponsor;
        // Initialize OZ contracts
        __Ownable_init_unchained();
    }

    function setProposalAuthority(address _account) onlyValidAddress(_account) public {
        require(msg.sender == proposalAuthority);
        proposalAuthority = _account;
    }

    function setReviewAuthority(address _account) onlyValidAddress(_account) public {
        require(msg.sender == reviewAuthority);
        reviewAuthority = _account;
    }

    function setRewardSponsor(address _account) onlyValidAddress(_account) public {
        require(msg.sender == rewardSponsor);
        rewardSponsor = _account;
    }


    receive() external payable {
        require(msg.sender == rewardSponsor, "Thank you for your support, but you are not Sponsor");
        uint256 today = block.timestamp - block.timestamp % period;
        require(today > balanceUpdatedAt);
        totalDistributed += msg.value;
        emit UpdateBalance(msg.value, address(this).balance, totalDistributed, block.timestamp);
        balanceUpdatedAt = block.timestamp;
    }

    function _verify(address addr, uint256 amount, bytes32[] memory proof) view internal {
        bytes32 leaf = keccak256(abi.encodePacked(addr, amount));
        require(MerkleProof.verify(proof, merkleRoot, leaf), "Invalid proof");
    }

    function claimReward(uint256 amount, bytes32[] memory proof) external {
        uint256 today = block.timestamp - block.timestamp % period;
        require(rootUpdatedAt > today, 'Rewards are being calculated, please try again late');
        require(claims[msg.sender].timestamp < today, "You already claimed your reward, please try again tomorrow");
        _verify(msg.sender, amount, proof);
        uint256 contractBalance = address(this).balance;
        if (amount >= contractBalance) {
            amount = contractBalance;
        }
        claims[msg.sender].amount += amount;
        claims[msg.sender].timestamp = block.timestamp;
        payable(msg.sender).transfer(amount); // send reward
        emit ClaimReward(msg.sender, amount, block.timestamp, claims[msg.sender].amount);

    }

    function proposerMerkleRoot(bytes32 _merkleRoot) public {
        require(msg.sender == proposalAuthority);
        require(pendingMerkleRoot == 0x00);
        pendingMerkleRoot = _merkleRoot;
    }

    function reviewPendingMerkleRoot(bool _approved) public {
        require(msg.sender == reviewAuthority);
        require(pendingMerkleRoot != 0x00);
        if (_approved) {
            bytes32 oldRoot = merkleRoot;
            merkleRoot = pendingMerkleRoot;
            rootUpdatedAt = block.timestamp;
            emit UpdateMerkleRoot(oldRoot, merkleRoot, block.timestamp);
        }
        delete pendingMerkleRoot;
    }
}