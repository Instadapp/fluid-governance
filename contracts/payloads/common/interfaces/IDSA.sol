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
}
