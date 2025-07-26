// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

interface ISmartLendingFactory {
    function setSmartLendingCreationCode(bytes memory creationCode) external;
    /// @notice Sets an address as a factory-level authorization or not.
    /// @param auth The address to be set as factory authorization.
    /// @param allowed A boolean indicating whether the specified address is allowed as factory auth.
    function setFactoryAuth(address auth, bool allowed) external;

    /// @notice Sets an address as a deployer or not.
    /// @param deployer_ The address to be set as deployer.
    /// @param allowed_ A boolean indicating whether the specified address is allowed as deployer.
    function updateDeployer(address deployer_, bool allowed_) external;
} 