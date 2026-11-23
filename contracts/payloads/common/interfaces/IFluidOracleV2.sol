pragma solidity ^0.8.21;

interface IFluidOracleV2 {
    function setGuardian(address guardian_, bool allowed_) external;
}
