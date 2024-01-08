// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

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

    uint256 public constant period = 1 days;
    IERC20 public token;
    uint256 public totalStakedWeight;
    mapping(address => DepositInfo[9]) public deposits;
    mapping(uint256 => Duration) public durations;

    mapping(address => Weight[9]) public weights;

    event Deposit(address indexed depositor, uint256 amount, uint256 indexed duration, uint256 timestamp, uint256 nonce);
    event Withdraw(address indexed depositor, uint256 indexed duration, uint256 amount, uint256 nonce);
    event UpdateWeight(address indexed depositor, uint256 indexed unaffectedWeight, uint256 indexed depositorWeight, uint256 timestamp);

    function initialize(address _tokenAddress) external virtual initializer {
        token = IERC20(_tokenAddress);
        durations[1] = Duration({index: 1, coefficient: 1});
        durations[7] = Duration({index: 2, coefficient: 4});
        durations[30] = Duration({index: 3, coefficient: 16});
        durations[90] = Duration({index: 4, coefficient: 64});
        durations[180] = Duration({index: 5, coefficient: 128});
        durations[360] = Duration({index: 6, coefficient: 256});
        durations[720] = Duration({index: 7, coefficient: 512});
        durations[1440] = Duration({index: 8, coefficient: 1024});
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
        DepositInfo memory totalDepositInfo = deposits[msg.sender][0];
        Weight memory totalWeight = weights[msg.sender][0];
        DepositInfo memory depositInfo = deposits[msg.sender][durations[_duration].index];
        Weight memory weight = weights[msg.sender][durations[_duration].index];
        totalDepositInfo = DepositInfo({
            depositor: msg.sender,
            amount: _amount + totalDepositInfo.amount,
            duration: 0,
            timestamp: block.timestamp,
            nonce: totalDepositInfo.nonce + 1
        });
        totalWeight.accountWeight -= weight.accountWeight;
        totalStakedWeight -= totalWeight.accountWeight;
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
        totalStakedWeight += totalWeight.accountWeight;

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
        uint256 depositAmount = depositInfo.amount;
        uint256 depositNonce = depositInfo.nonce;

        delete deposits[msg.sender][durations[_duration].index];
        delete weights[msg.sender][durations[_duration].index];

        deposits[msg.sender][0].amount -= depositAmount;
        deposits[msg.sender][0].timestamp = block.timestamp;

        uint256 decreaseWeight = _calculateWeight(depositAmount, _duration);

        weights[msg.sender][0].accountWeight -= decreasedWeight;
        totalStakedWeight -= decreasedWeight;
        uint256 unaffectedWeight = calculateDepositorWeight(msg.sender);
        bool result = token.transfer(msg.sender, depositInfo.amount);
        require(result, 'ZKFStaking: ZKF transfer failed.');
        emit Withdraw(msg.sender, _duration, depositAmount, depositNonce);
        emit UpdateWeight(msg.sender, unaffectedWeight, weights[msg.sender][0].accountWeight, block.timestamp);
    }


}