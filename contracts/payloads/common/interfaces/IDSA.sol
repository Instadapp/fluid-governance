pragma solidity ^0.8.21;

interface IDSAV2 {
    function cast(
        string[] memory _targetNames,
        bytes[] memory _datas,
        address _origin
    )
    external
    payable 
    returns (bytes32);

    function isAuth(address user) external view returns (bool);
}

interface IDSAConnectorsV2 {
    function toggleChief(address _chiefAddress) external;

    function chief(address _chiefAddress) external view returns (bool);
}

/// @notice Legacy v1 InstaConnectors registry (InstaIndex connectors(1)).
interface IDSAConnectorsV1 {
    function disableChief(address _userAddress) external;

    function chief(address _userAddress) external view returns (bool);
}

interface IDSAInstaIndex {
    function master() external view returns (address);
}
