pragma solidity ^0.8.21;

interface IFluidDexFactory {
    /// @notice                         Computes the address of a dex based on its given ID (`dexId_`).
    /// @param dexId_                   The ID of the dex.
    /// @return dex_                    Returns the computed address of the dex.
    function getDexAddress(uint256 dexId_) external view returns (address dex_);

    function setDexAuth(address dex_, address dexAuth_, bool allowed_) external;

    /// @notice                         Sets an address (`globalAuth_`) as a global authorization or not.
    ///                                 This function can only be called by the owner.
    /// @param globalAuth_              The address to be set as global authorization.
    /// @param allowed_                 A boolean indicating whether the specified address is allowed to update any dex config.
    function setGlobalAuth(address globalAuth_, bool allowed_) external;

    /// @notice Sets an address as a factory-level authorization or not.
    /// @param auth The address to be set as factory authorization.
    /// @param allowed A boolean indicating whether the specified address is allowed as factory auth.
    function setFactoryAuth(address auth, bool allowed) external;

    /// @notice Sets an address as a deployer or not.
    /// @param deployer_ The address to be set as deployer.
    /// @param allowed_ A boolean indicating whether the specified address is allowed as deployer.
    function setDeployer(address deployer_, bool allowed_) external;

    function owner() external view returns (address);

    function setDexDeploymentLogic(
        address deploymentLogic_,
        bool allowed_
    ) external;
}