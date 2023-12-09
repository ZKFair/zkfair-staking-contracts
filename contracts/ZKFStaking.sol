// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

contract StakingContract is OwnableUpgradeable {

    struct DepositInfo {
        address depositor;
        uint256 amount;
        uint256 duration; // Duration in days
        uint256 timestamp;
        uint256 nonce;
    }

    struct Weight {
        uint256 accountWeight;
        uint256 update_at;
    }

    struct Duration {
        uint8 index;
        uint256 coefficient;
    }

    uint256 public period = 1 days;

    mapping(address => DepositInfo[9]) public deposits;
    IERC20 public token;
    mapping(uint256 => Duration) public durations;

    mapping(address => Weight[9]) public weights;

    event Deposit(address indexed depositor, uint256 amount, uint256 indexed duration, uint256 timestamp, uint256 nonce);
    event Withdraw(address indexed depositor, uint256 indexed duration, uint256 amount, uint256 nonce);
    event UpdateWeight(address indexed depositor, uint256 indexed unaffectedWeight, uint256 indexed depositorWeight, uint256 timestamp);

    constructor(address _tokenAddress) {
        token = IERC20(_tokenAddress);
        durations[1] = Duration({index: 1, coefficient: 1});
        durations[7] = Duration({index: 2, coefficient: 4});
        durations[30] = Duration({index: 3, coefficient: 16});
        durations[90] = Duration({index: 4, coefficient: 64});
        durations[180] = Duration({index: 5, coefficient: 128});
        durations[360] = Duration({index: 6, coefficient: 256});
        durations[720] = Duration({index: 7, coefficient: 512});
        durations[1440] = Duration({index: 8, coefficient: 1024});
    }

    function initialize() external virtual initializer {
        // Initialize OZ contracts
        __Ownable_init_unchained();
    }

    function _calculateWeight(uint256 _amount, uint256 _duration) internal view returns (uint256) {
        return _amount * durations[_duration].coefficient;
    }

    function calculateDepositorWeight(address depositor) public view returns (uint256 unaffectedWeight) {
        uint256 today = block.timestamp - block.timestamp % period;

        for (uint8 i = 1; i < 9; i++) {
            Weight memory weight = weights[depositor][i];
            if (weight.update_at < today) {
                unaffectedWeight += weight.accountWeight;
            }
        }
        return unaffectedWeight;
    }


    function deposit(uint256 _duration, uint256 _amount) external {
        require(durations[_duration].index != 0, "Invalid duration");
        require(_amount > 0, "Amount must be greater than 0");

        bool result = token.transferFrom(msg.sender, address(this), _amount);
        require(result, 'ZKFStaking: ZKF transfer failed.');
        // Get current account info
        DepositInfo storage totalDepositInfo = deposits[msg.sender][0];
        Weight storage totalWeight = weights[msg.sender][0];
        DepositInfo storage depositInfo = deposits[msg.sender][durations[_duration].index];
        Weight storage weight = weights[msg.sender][durations[_duration].index];
        totalDepositInfo = DepositInfo({
            depositor: msg.sender,
            amount: _amount + totalDepositInfo.amount,
            duration: 0,
            timestamp: block.timestamp,
            nonce: totalDepositInfo.nonce + 1
        });
        totalWeight.accountWeight -= weight.accountWeight;
        depositInfo = DepositInfo({
            depositor: msg.sender,
            amount: _amount + depositInfo.amount,
            duration: _duration,
            timestamp: block.timestamp,
            nonce: depositInfo.nonce + 1
        });
        weight = Weight({
            accountWeight: _calculateWeight(depositInfo.amount, depositInfo.duration),
            update_at: block.timestamp
        });
        totalWeight.accountWeight += weight.accountWeight;
        totalWeight.update_at = block.timestamp;
        deposits[msg.sender][0] = totalDepositInfo;
        deposits[msg.sender][durations[_duration].index] = depositInfo;
        weights[msg.sender][0] = totalWeight;
        weights[msg.sender][durations[_duration].index] = weight;
        emit Deposit(msg.sender, depositInfo.amount, _duration, block.timestamp, depositInfo.nonce);
        uint256 unaffectedWeight = calculateDepositorWeight(msg.sender);
        emit UpdateWeight(msg.sender, unaffectedWeight, totalWeight.accountWeight, block.timestamp);
    }

    function withdraw(uint256 _duration) external {
        require(durations[_duration].index != 0, "Invalid duration");
        DepositInfo memory depositInfo = deposits[msg.sender][durations[_duration].index];
        require(depositInfo.depositor == msg.sender, "Unauthorized withdrawal");
        require(depositInfo.amount > 0, "empty amount");
        require(block.timestamp >= depositInfo.timestamp + (depositInfo.duration * period), "Deposit is not matured yet");

        deposits[msg.sender][0].amount -= depositInfo.amount;
        deposits[msg.sender][0].timestamp = block.timestamp;
        weights[msg.sender][0].accountWeight -= _calculateWeight(depositInfo.amount, depositInfo.duration);

        delete deposits[msg.sender][durations[_duration].index];
        delete weights[msg.sender][durations[_duration].index];
        uint256 unaffectedWeight = calculateDepositorWeight(msg.sender);
        bool result = token.transfer(msg.sender, depositInfo.amount);
        require(result, 'ZKFStaking: ZKF transfer failed.');
        emit Withdraw(depositInfo.depositor, _duration, depositInfo.amount, depositInfo.nonce);
        emit UpdateWeight(msg.sender, unaffectedWeight, weights[msg.sender][0].accountWeight, block.timestamp);
    }

}