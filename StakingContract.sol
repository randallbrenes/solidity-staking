// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract StakingContract is Ownable {
    IERC20 public stakingToken;
    uint256 public rewardRate; // Reward tokens per staked token per second

    struct Stake {
        uint256 amount;
        uint256 timestamp;
        uint256 rewardsEarned; // Track total rewards earned
    }

    mapping(address => Stake) public stakes;

    event Staked(address indexed user, uint256 amount);
    event Withdrawn(address indexed user, uint256 amount);
    event RewardClaimed(address indexed user, uint256 amount);

    constructor(IERC20 _stakingToken, uint256 _rewardRate)  Ownable( msg.sender )  {
        stakingToken = _stakingToken;
        rewardRate = _rewardRate;
    }

    function stake(uint256 amount) public payable {
        require(amount > 0, "Cannot stake 0 tokens");

        // Update existing rewards before changing the stake
        updateRewards(msg.sender);

        // Transfer staking tokens from the user to the contract
        stakingToken.transferFrom(msg.sender, address(this), amount);

        // Update the user's stake
        Stake storage stakeData = stakes[msg.sender];
        stakeData.amount += amount;
        stakeData.timestamp = block.timestamp;

        emit Staked(msg.sender, amount);
    }

    function withdraw(uint256 amount) external {
        Stake storage stakeData = stakes[msg.sender];
        require(stakeData.amount >= amount, "Insufficient balance to withdraw");

        // Update existing rewards before changing the stake
        updateRewards(msg.sender);

        // Update the user's stake
        stakeData.amount -= amount;

        // Transfer staking tokens from the contract to the user
        stakingToken.transfer(msg.sender, amount);

        emit Withdrawn(msg.sender, amount);
    }

    function claimRewards() external {
        updateRewards(msg.sender);
        
        Stake storage stakeData = stakes[msg.sender];
        uint256 rewardsToClaim = stakeData.rewardsEarned;

        require(rewardsToClaim > 0, "No rewards to claim");

        // Reset the rewards earned to zero
        stakeData.rewardsEarned = 0;

        // Transfer reward tokens to the user
        stakingToken.transfer(msg.sender, rewardsToClaim);

        emit RewardClaimed(msg.sender, rewardsToClaim);
    }

    function updateRewards(address user) internal {
        Stake storage stakeData = stakes[user];

        // Calculate rewards based on time since last update
        uint256 elapsedTime = block.timestamp - stakeData.timestamp;
        uint256 newRewards = (stakeData.amount * rewardRate * elapsedTime);
        
        // Update rewards and timestamp
        stakeData.rewardsEarned += newRewards;
        stakeData.timestamp = block.timestamp;
    }

    function getStake() external view returns (uint256 amount, uint256 rewardsEarned) {
        Stake storage stakeData = stakes[msg.sender];
        return (stakeData.amount, stakeData.rewardsEarned);
    }
}
