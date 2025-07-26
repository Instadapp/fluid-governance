pragma solidity ^0.8.21;

interface IFluidSmartLendingFactory {
    /// @notice Updates the authorization status of an address for a SmartLending contract. Only callable by owner.
    /// @param smartLending_ The address of the SmartLending contract.
    /// @param auth_ The address to be updated.
    /// @param allowed_ The new authorization status.
    function updateSmartLendingAuth(
        address smartLending_,
        address auth_,
        bool allowed_
    ) external;

    /// @notice Sets the creation code for new SmartLending contracts. Only callable by owner.
    /// @param creationCode_ New SmartLending contract creation code.
    function setSmartLendingCreationCode(bytes calldata creationCode_) external;

    /// @notice Computes the address of a SmartLending contract based on a given DEX ID.
    /// @param dexId_ The ID of the DEX for which the SmartLending contract address is being computed.
    /// @return The computed SmartLending contract address.
    function getSmartLendingAddress(
        uint256 dexId_
    ) external view returns (address);

    /// @notice Sets an address as a factory-level authorization or not.
    /// @param auth The address to be set as factory authorization.
    /// @param allowed A boolean indicating whether the specified address is allowed as factory auth.
    function setFactoryAuth(address auth, bool allowed) external;

    /// @notice Sets an address as a deployer or not.
    /// @param deployer_ The address to be set as deployer.
    /// @param allowed_ A boolean indicating whether the specified address is allowed as deployer.
    function updateDeployer(address deployer_, bool allowed_) external;
}
