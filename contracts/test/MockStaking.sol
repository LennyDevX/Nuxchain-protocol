// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "../interfaces/IStakingIntegration.sol";

/**
 * @title MockStaking
 * @dev Mock contract for EnhancedSmartStaking in tests
 */
contract MockStaking {
    mapping(address => uint256) public userDeposits;
    
    /// @dev Get total deposit for user
    function getTotalDeposit(address user) external view returns (uint256) {
        return userDeposits[user];
    }
    
    /// @dev Set user deposit (for testing)
    function setUserDeposit(address user, uint256 amount) external {
        userDeposits[user] = amount;
    }
    
    /// @dev Notify skill activation (no-op in mock)
    function notifySkillActivation(
        address user,
        uint256 skillId,
        IStakingIntegration.SkillType skillType,
        uint16 value
    ) external {}
    
    /// @dev Notify skill deactivation (no-op in mock)
    function notifySkillDeactivation(address user, uint256 skillId) external {}
}
