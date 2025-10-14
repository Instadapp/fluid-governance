pragma solidity ^0.8.21;

interface IFluidAdminDex {
    /// @param upperThresholdPercent_ in 4 decimals, 10000 = 1%
    /// @param lowerThresholdPercent_ in 4 decimals, 10000 = 1%
    /// @param thresholdShiftTime_ in secs, in how much time the threshold percent should take to shift the ranges
    /// @param shiftTime_ in secs, in how much time the upper config changes should be fully done.
    function updateThresholdPercent(
        uint upperThresholdPercent_,
        uint lowerThresholdPercent_,
        uint thresholdShiftTime_,
        uint shiftTime_
    ) external;

    function updateCenterPriceLimits(
        uint maxCenterPrice_,
        uint minCenterPrice_
    ) external;

    function updateCenterPriceAddress(
        uint centerPriceAddress_,
        uint percent_,
        uint time_
    ) external;

    function readFromStorage(
        bytes32 slot_
    ) external view returns (uint256 result_);

    function updateMaxSupplyShares(uint maxSupplyShares_) external;

    function updateMaxBorrowShares(uint maxBorrowShares_) external;

    /// @notice struct to set user supply & withdrawal config
    struct UserSupplyConfig {
        ///
        /// @param user address
        address user;
        ///
        /// @param expandPercent withdrawal limit expand percent. in 1e2: 100% = 10_000; 1% = 100
        /// Also used to calculate rate at which withdrawal limit should decrease (instant).
        uint256 expandPercent;
        ///
        /// @param expandDuration withdrawal limit expand duration in seconds.
        /// used to calculate rate together with expandPercent
        uint256 expandDuration;
        ///
        /// @param baseWithdrawalLimit base limit, below this, user can withdraw the entire amount.
        /// amount in raw (to be multiplied with exchange price) or normal depends on configured mode in user config for the token:
        /// with interest -> raw, without interest -> normal
        uint256 baseWithdrawalLimit;
    }

    /// @notice struct to set user borrow & payback config
    struct UserBorrowConfig {
        ///
        /// @param user address
        address user;
        ///
        /// @param expandPercent debt limit expand percent. in 1e2: 100% = 10_000; 1% = 100
        /// Also used to calculate rate at which debt limit should decrease (instant).
        uint256 expandPercent;
        ///
        /// @param expandDuration debt limit expand duration in seconds.
        /// used to calculate rate together with expandPercent
        uint256 expandDuration;
        ///
        /// @param baseDebtCeiling base borrow limit. until here, borrow limit remains as baseDebtCeiling
        /// (user can borrow until this point at once without stepped expansion). Above this, automated limit comes in place.
        /// amount in raw (to be multiplied with exchange price) or normal depends on configured mode in user config for the token:
        /// with interest -> raw, without interest -> normal
        uint256 baseDebtCeiling;
        ///
        /// @param maxDebtCeiling max borrow ceiling, maximum amount the user can borrow.
        /// amount in raw (to be multiplied with exchange price) or normal depends on configured mode in user config for the token:
        /// with interest -> raw, without interest -> normal
        uint256 maxDebtCeiling;
    }

    function updateUserBorrowConfigs(
        UserBorrowConfig[] memory userBorrowConfigs_
    ) external;

    function updateUserSupplyConfigs(
        UserSupplyConfig[] memory userSupplyConfigs_
    ) external;

    struct InitializeVariables {
        bool smartCol;
        uint token0ColAmt;
        bool smartDebt;
        uint token0DebtAmt;
        uint centerPrice;
        uint fee;
        uint revenueCut;
        uint upperPercent;
        uint lowerPercent;
        uint upperShiftThreshold;
        uint lowerShiftThreshold;
        uint thresholdShiftTime;
        uint centerPriceAddress;
        uint hookAddress;
        uint maxCenterPrice;
        uint minCenterPrice;
    }

    function initialize(InitializeVariables memory initializeVariables_) external payable;

    function updateRangePercents(
        uint upperPercent_,
        uint lowerPercent_,
        uint shiftTime_
    ) external; 

    /// @param fee_ in 4 decimals, 10000 = 1%
    /// @param revenueCut_ in 4 decimals, 100000 = 10%, 10% cut on fee_, so if fee is 1% and cut is 10% then cut in swap amount will be 10% of 1% = 0.1%
    function updateFeeAndRevenueCut(uint fee_, uint revenueCut_) external;

    /// @notice pause user operations at DEX level
    /// @param user_ address of user to pause operations for
    /// @param pauseSupply_ whether to pause supply operations
    /// @param pauseBorrow_ whether to pause borrow operations
    function pauseUser(address user_, bool pauseSupply_, bool pauseBorrow_) external;

    function pauseSwapAndArbitrage() external;
}

interface IFluidUserDex {


    struct Implementations {
        address shift;
        address admin;
        address colOperations;
        address debtOperations;
        address perfectOperationsAndOracle;
    }

    struct ConstantViews {
        uint256 dexId;
        address liquidity;
        address factory;
        Implementations implementations;
        address deployerContract;
        address token0;
        address token1;
        bytes32 supplyToken0Slot;
        bytes32 borrowToken0Slot;
        bytes32 supplyToken1Slot;
        bytes32 borrowToken1Slot;
        bytes32 exchangePriceToken0Slot;
        bytes32 exchangePriceToken1Slot;
        uint256 oracleMapping;
    }


    function constantsView() external view returns (ConstantViews memory constantsView_);

}

interface IFluidDex is IFluidAdminDex, IFluidUserDex {
}

interface IFluidDexResolver {
    struct Configs {
        bool isSmartCollateralEnabled;
        bool isSmartDebtEnabled;
        uint256 fee;
        uint256 revenueCut;
        uint256 upperRange;
        uint256 lowerRange;
        uint256 upperShiftThreshold;
        uint256 lowerShiftThreshold;
        uint256 shiftingTime;
        address centerPriceAddress;
        address hookAddress;
        uint256 maxCenterPrice;
        uint256 minCenterPrice;
        uint256 utilizationLimitToken0;
        uint256 utilizationLimitToken1;
        uint256 maxSupplyShares;
        uint256 maxBorrowShares;
    }

    function getDexConfigs(
        address dex_
    ) external view returns (Configs memory configs_);
}