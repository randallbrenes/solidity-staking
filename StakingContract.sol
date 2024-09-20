// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/security/Pausable.sol";

contract StakingContract is Ownable, ReentrancyGuard, Pausable {

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

    constructor(IERC20 _stakingToken, uint256 _rewardRate) Ownable(msg.sender) {
        stakingToken = _stakingToken;
        rewardRate = _rewardRate;
    }

    function stake(uint256 amount) public payable whenNotPaused nonReentrant { // protect from re-entrant
        require(amount > 0, "Cannot stake 0 tokens");
        require(amount <= stakingToken.balanceOf(msg.sender), "Insufficient balance");

        // Update existing rewards before changing the stake
        _updateRewards(msg.sender);

        // Transfer staking tokens from the user to the contract
        bool success = stakingToken.transferFrom(msg.sender, address(this), amount);
        require(success, "Failed to transfer tokens");

        // Update the user's stake
        Stake storage stakeData = stakes[msg.sender];
        stakeData.amount += amount;
        stakeData.timestamp = block.number; // Use block number instead of timestamp

        emit Staked(msg.sender, amount);
    }

    function withdraw(uint256 amount) external payable whenNotPaused nonReentrant { // protect from re-entrant
        Stake storage stakeData = stakes[msg.sender];
        require(stakeData.amount >= amount, "Insufficient balance to withdraw");

        // Update existing rewards before changing the stake
        _updateRewards(msg.sender);

        // Update the user's stake
        stakeData.amount -= amount;

        // Transfer staking tokens from the contract to the user
        bool success = stakingToken.transfer(msg.sender, amount);
        require(success, "Failed to transfer tokens");

        emit Withdrawn(msg.sender, amount);
    }

    function claimRewards() external payable whenNotPaused nonReentrant { // protect from re-entrant
        _updateRewards(msg.sender);
        
        Stake storage stakeData = stakes[msg.sender];
        uint256 rewardsToClaim = stakeData.rewardsEarned;

        require(rewardsToClaim > 0, "No rewards to claim");

        // Reset the rewards earned to zero
        stakeData.rewardsEarned = 0;

        // Transfer reward tokens to the user
        bool success = stakingToken.transfer(msg.sender, rewardsToClaim);
        require(success, "Failed to transfer tokens");

        emit RewardClaimed(msg.sender, rewardsToClaim);
    }

    function _updateRewards(address user) private { // private to avoid calls from anyone
        Stake storage stakeData = stakes[user];

        // Calculate rewards based on time since last update
        uint256 elapsedTime = block.number - stakeData.timestamp;
        uint256 newRewards = (stakeData.amount * rewardRate * elapsedTime/1000); // unrealistic approach to reward per second 1 token
        
        // Update rewards and timestamp
        stakeData.rewardsEarned += newRewards;
        stakeData.timestamp = block.number;
    }

    function getStake() external view returns (uint256 amount, uint256 rewardsEarned) {
        Stake storage stakeData = stakes[msg.sender];
        return (stakeData.amount, stakeData.rewardsEarned);
    }
    
    function pause() public onlyOwner { // safeguard function to pause contract in case of worries
    _pause();
    }
    
    function unpause() public onlyOwner { // safeguard function to unpause contract
    _unpause();
    }
}