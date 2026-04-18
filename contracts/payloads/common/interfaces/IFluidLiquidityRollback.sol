pragma solidity ^0.8.21;

interface IFluidLiquidityRollback {
    function registerRollbackImplementation(
        address oldImplementation_,
        address newImplementation_
    ) external;

    function registerRollbackDummyImplementation() external;
}
