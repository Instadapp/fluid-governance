pragma solidity ^0.8.21;

interface IFluidLendingFactory {
    /// @notice Computes the address of a token based on the asset and fToken type.
    /// @param asset_ The address of the underlying asset.
    /// @param fTokenType_ The type of fToken (e.g., "fToken" or "NativeUnderlying").
    /// @return The computed address of the token.
    function computeToken(address asset_, string calldata fTokenType_) external view returns (address);

    /// @notice Sets an address as a factory-level authorization or not.
    /// @param auth The address to be set as factory authorization.
    /// @param allowed A boolean indicating whether the specified address is allowed as factory auth.
    function setFactoryAuth(address auth, bool allowed) external;

    /// @notice Sets an address as a deployer or not.
    /// @param deployer_ The address to be set as deployer.
    /// @param allowed_ A boolean indicating whether the specified address is allowed as deployer.
    function setDeployer(address deployer_, bool allowed_) external;
}