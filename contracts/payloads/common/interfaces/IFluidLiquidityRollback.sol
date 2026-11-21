pragma solidity ^0.8.21;

interface IFluidLiquidityRollback {
    struct RollbackSigsSlot {
        uint40 rollbackRegisterTimestamp;
        address replacesImplementation;
        bytes4[] sigs;
    }

    function registerRollbackImplementation(
        address oldImplementation_,
        address newImplementation_
    ) external;

    function registerRollbackDummyImplementation() external;

    function cleanupExpiredRollbackImplementation(
        address implementation_
    ) external;

    function getRollbackForImplementation(
        address rollbackImplementation_
    ) external view returns (RollbackSigsSlot memory);
}
