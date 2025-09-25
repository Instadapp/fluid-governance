pragma solidity ^0.8.21;

interface ILite {
    function setAdmin(address newAdmin) external;

    function getAdmin() external view returns (address);

    function removeImplementation(address implementation_) external;

    function addImplementation(
        address implementation_,
        bytes4[] calldata sigs_
    ) external;

    function setDummyImplementation(address newDummyImplementation_) external;

    function updateMaxRiskRatio(
        uint8[] memory protocolId_,
        uint256[] memory newRiskRatio_
    ) external;

    function updateAggrMaxVaultRatio(uint256 newAggrMaxVaultRatio_) external;

    function addDSAAuth(address auth_) external;
    
    // Collect stETH revenue to the treasury address set in Lite
    // amount_ is specified in stETH wei (1e18 per stETH)
    function collectRevenue(uint256 amount_) external;
        
    function getImplementationSigs(address implementation_) external view returns (bytes4[] memory);
    function updateSecondaryAuth(address secondaryAuth_) external;
    function updateRebalancer(address rebalancer_, bool isRebalancer_) external;
}