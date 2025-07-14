pragma solidity ^0.8.21;
pragma experimental ABIEncoderV2;

import {BigMathMinified} from "../libraries/bigMathMinified.sol";
import {LiquidityCalcs} from "../libraries/liquidityCalcs.sol";
import {LiquiditySlotsLink} from "../libraries/liquiditySlotsLink.sol";

import {DexSlotsLink} from "../libraries/dexSlotsLink.sol";

import {IGovernorBravo} from "./interfaces/IGovernorBravo.sol";
import {ITimelock} from "./interfaces/ITimelock.sol";

import {IFluidLiquidityAdmin, AdminModuleStructs as FluidLiquidityAdminStructs} from "./interfaces/IFluidLiquidity.sol";
import {IFluidReserveContract} from "./interfaces/IFluidReserveContract.sol";

import {IFluidVaultFactory} from "./interfaces/IFluidVaultFactory.sol";
import {IFluidDexFactory} from "./interfaces/IFluidDexFactory.sol";
import { IFluidLendingFactory } from "./interfaces/IFluidLendingFactory.sol";


import {IFluidDex, IFluidAdminDex} from "./interfaces/IFluidDex.sol";
import {IFluidDexResolver} from "./interfaces/IFluidDex.sol";

import {IFluidVault} from "./interfaces/IFluidVault.sol";
import {IFluidVaultT1} from "./interfaces/IFluidVault.sol";

import {IFTokenAdmin} from "./interfaces/IFToken.sol";
import {ILendingRewards} from "./interfaces/IFToken.sol";

import {ISmartLendingAdmin} from "./interfaces/ISmartLending.sol";

import {IDSAV2} from "./interfaces/IDSA.sol";

import {PayloadIGPConstants} from "./constants.sol";

contract PayloadIGPHelpers is PayloadIGPConstants {
    /**
     * |
     * |     Proposal Payload Helpers      |
     * |__________________________________
     */
    function getVaultAddress(uint256 vaultId_) public view returns (address) {
        return VAULT_FACTORY.getVaultAddress(vaultId_);
    }

    function getDexAddress(uint256 dexId_) public view returns (address) {
        return DEX_FACTORY.getDexAddress(dexId_);
    }

    function getFTokenAddress(address token) public view returns (address) {
        if (token == WETH_ADDRESS) {
            return LENDING_FACTORY.computeToken(token, "NativeUnderlying");
        }
        return LENDING_FACTORY.computeToken(token, "fToken");
    }

    function getCurrentBaseWithdrawalLimit(address token_, address user_) internal view returns (uint256) {
        bytes32 _LIQUDITY_PROTOCOL_SUPPLY_SLOT = LiquiditySlotsLink.calculateDoubleMappingStorageSlot(
            LiquiditySlotsLink.LIQUIDITY_USER_SUPPLY_DOUBLE_MAPPING_SLOT,
            user_,
            token_
        );

        uint256 userSupplyData_ = LIQUIDITY.readFromStorage(_LIQUDITY_PROTOCOL_SUPPLY_SLOT);
        
        return BigMathMinified.fromBigNumber(
            (userSupplyData_ >> LiquiditySlotsLink.BITS_USER_SUPPLY_BASE_WITHDRAWAL_LIMIT) & X18,
            DEFAULT_EXPONENT_SIZE,
            DEFAULT_EXPONENT_MASK
        );
    }

    function setProtocolSupplyExpansion(
        address protocol,
        address token,
        uint256 expandPercent,
        uint256 expandDuration
    ) internal {
        FluidLiquidityAdminStructs.UserSupplyConfig[] memory configs_ = new FluidLiquidityAdminStructs.UserSupplyConfig[](1);
        configs_[0] = FluidLiquidityAdminStructs.UserSupplyConfig({
            user: protocol,
            token: token, 
            mode: 1,
            expandPercent: expandPercent,
            expandDuration: expandDuration,
            baseWithdrawalLimit: getCurrentBaseWithdrawalLimit(token, protocol) // Keep existing limit
        });
        LIQUIDITY.updateUserSupplyConfigs(configs_);
    }

    /// @dev gets a smart lending address based on the underlying dexId
    function getSmartLendingAddress(
        uint256 dexId_
    ) public view returns (address) {
        return SMART_LENDING_FACTORY.getSmartLendingAddress(dexId_);
    }

    struct SupplyProtocolConfig {
        address protocol;
        address supplyToken;
        uint256 expandPercent;
        uint256 expandDuration;
        uint256 baseWithdrawalLimitInUSD;
    }

    struct BorrowProtocolConfig {
        address protocol;
        address borrowToken;
        uint256 expandPercent;
        uint256 expandDuration;
        uint256 baseBorrowLimitInUSD;
        uint256 maxBorrowLimitInUSD;
    }

    function setSupplyProtocolLimits(
        SupplyProtocolConfig memory protocolConfig_
    ) internal {
        {
            // Supply Limits
            FluidLiquidityAdminStructs.UserSupplyConfig[]
                memory configs_ = new FluidLiquidityAdminStructs.UserSupplyConfig[](
                    1
                );

            configs_[0] = FluidLiquidityAdminStructs.UserSupplyConfig({
                user: address(protocolConfig_.protocol),
                token: protocolConfig_.supplyToken,
                mode: 1,
                expandPercent: protocolConfig_.expandPercent,
                expandDuration: protocolConfig_.expandDuration,
                baseWithdrawalLimit: getRawAmount(
                    protocolConfig_.supplyToken,
                    0,
                    protocolConfig_.baseWithdrawalLimitInUSD,
                    true
                )
            });

            LIQUIDITY.updateUserSupplyConfigs(configs_);
        }
    }

    function setBorrowProtocolLimits(
        BorrowProtocolConfig memory protocolConfig_
    ) internal {
        {
            // Borrow Limits
            FluidLiquidityAdminStructs.UserBorrowConfig[]
                memory configs_ = new FluidLiquidityAdminStructs.UserBorrowConfig[](
                    1
                );

            configs_[0] = FluidLiquidityAdminStructs.UserBorrowConfig({
                user: address(protocolConfig_.protocol),
                token: protocolConfig_.borrowToken,
                mode: 1,
                expandPercent: protocolConfig_.expandPercent,
                expandDuration: protocolConfig_.expandDuration,
                baseDebtCeiling: getRawAmount(
                    protocolConfig_.borrowToken,
                    0,
                    protocolConfig_.baseBorrowLimitInUSD,
                    false
                ),
                maxDebtCeiling: getRawAmount(
                    protocolConfig_.borrowToken,
                    0,
                    protocolConfig_.maxBorrowLimitInUSD,
                    false
                )
            });

            LIQUIDITY.updateUserBorrowConfigs(configs_);
        }
    }

    function setSupplyProtocolLimitsPaused(
        address protocol_,
        address token_
    ) internal {
        {
            // Supply Limits
            FluidLiquidityAdminStructs.UserSupplyConfig[]
                memory configs_ = new FluidLiquidityAdminStructs.UserSupplyConfig[](
                    1
                );

            configs_[0] = FluidLiquidityAdminStructs.UserSupplyConfig({
                user: protocol_,
                token: token_,
                mode: 1,
                expandPercent: 1, // 0.01%
                expandDuration: 16777215, // max time
                baseWithdrawalLimit: 10
            });

            LIQUIDITY.updateUserSupplyConfigs(configs_);
        }
    }

    function setBorrowProtocolLimitsPaused(
        address protocol_,
        address token_
    ) internal {
        {
            // Borrow Limits
            FluidLiquidityAdminStructs.UserBorrowConfig[]
                memory configs_ = new FluidLiquidityAdminStructs.UserBorrowConfig[](
                    1
                );

            configs_[0] = FluidLiquidityAdminStructs.UserBorrowConfig({
                user: protocol_,
                token: token_,
                mode: 1,
                expandPercent: 1, // 0.01%
                expandDuration: 16777215, // max time
                baseDebtCeiling: 10,
                maxDebtCeiling: 20
            });

            LIQUIDITY.updateUserBorrowConfigs(configs_);
        }
    }

    struct DexBorrowProtocolConfigInShares {
        address dex;
        address protocol;
        uint256 expandPercent;
        uint256 expandDuration;
        uint256 baseBorrowLimit;
        uint256 maxBorrowLimit;
    }

    function setDexBorrowProtocolLimitsInShares(
        DexBorrowProtocolConfigInShares memory protocolConfig_
    ) internal {
        IFluidAdminDex.UserBorrowConfig[]
            memory config_ = new IFluidAdminDex.UserBorrowConfig[](1);
        config_[0] = IFluidAdminDex.UserBorrowConfig({
            user: protocolConfig_.protocol,
            expandPercent: protocolConfig_.expandPercent,
            expandDuration: protocolConfig_.expandDuration,
            baseDebtCeiling: protocolConfig_.baseBorrowLimit,
            maxDebtCeiling: protocolConfig_.maxBorrowLimit
        });

        IFluidDex(protocolConfig_.dex).updateUserBorrowConfigs(config_);
    }

    function getRawAmount(
        address token,
        uint256 amount,
        uint256 amountInUSD,
        bool isSupply
    ) public view virtual returns (uint256) {
        return 0;
    }

    struct DexConfig {
        address dex;
        address tokenA;
        address tokenB;
        bool smartCollateral;
        bool smartDebt;
        uint256 baseWithdrawalLimitInUSD;
        uint256 baseBorrowLimitInUSD;
        uint256 maxBorrowLimitInUSD;
    }

    enum VAULT_TYPE {
        TYPE_1,
        TYPE_2,
        TYPE_3,
        TYPE_4
    }

    struct VaultConfig {
        address vault;
        VAULT_TYPE vaultType;
        address supplyToken;
        address borrowToken;
        uint256 baseWithdrawalLimitInUSD;
        uint256 baseBorrowLimitInUSD;
        uint256 maxBorrowLimitInUSD;
    }

    function setDexLimits(DexConfig memory dex_) internal {
        // Smart Collateral
        if (dex_.smartCollateral) {
            SupplyProtocolConfig memory protocolConfigTokenA_ = SupplyProtocolConfig({
                protocol: dex_.dex,
                supplyToken: dex_.tokenA,
                expandPercent: 50 * 1e2, // 50%
                expandDuration: 1 hours, // 1 hour
                baseWithdrawalLimitInUSD: dex_.baseWithdrawalLimitInUSD
            });

            setSupplyProtocolLimits(protocolConfigTokenA_);

            SupplyProtocolConfig memory protocolConfigTokenB_ = SupplyProtocolConfig({
                protocol: dex_.dex,
                supplyToken: dex_.tokenB,
                expandPercent: 50 * 1e2, // 50%
                expandDuration: 1 hours, // 1 hour
                baseWithdrawalLimitInUSD: dex_.baseWithdrawalLimitInUSD
            });

            setSupplyProtocolLimits(protocolConfigTokenB_);
        }

        // Smart Debt
        if (dex_.smartDebt) {
            BorrowProtocolConfig memory protocolConfigTokenA_ = BorrowProtocolConfig({
                protocol: dex_.dex,
                borrowToken: dex_.tokenA,
                expandPercent: 50 * 1e2, // 50%
                expandDuration: 1 hours, // 1 hour
                baseBorrowLimitInUSD: dex_.baseBorrowLimitInUSD,
                maxBorrowLimitInUSD: dex_.maxBorrowLimitInUSD
            });

            setBorrowProtocolLimits(protocolConfigTokenA_);

            BorrowProtocolConfig memory protocolConfigTokenB_ = BorrowProtocolConfig({
                protocol: dex_.dex,
                borrowToken: dex_.tokenB,
                expandPercent: 50 * 1e2, // 50%
                expandDuration: 1 hours, // 1 hour
                baseBorrowLimitInUSD: dex_.baseBorrowLimitInUSD,
                maxBorrowLimitInUSD: dex_.maxBorrowLimitInUSD
            });

            setBorrowProtocolLimits(protocolConfigTokenB_);
        }
    }

    function setVaultLimits(VaultConfig memory vault_) internal {
        if (vault_.vaultType == VAULT_TYPE.TYPE_1) {
            SupplyProtocolConfig memory protocolConfig_ = SupplyProtocolConfig({
                protocol: vault_.vault,
                supplyToken: vault_.supplyToken,
                expandPercent: 50 * 1e2, // 50%
                expandDuration: 6 hours, // 6 hours
                baseWithdrawalLimitInUSD: vault_.baseWithdrawalLimitInUSD
            });

            setSupplyProtocolLimits(protocolConfig_);
        }

        if (vault_.vaultType == VAULT_TYPE.TYPE_1) {
            BorrowProtocolConfig memory protocolConfig_ = BorrowProtocolConfig({
                protocol: vault_.vault,
                borrowToken: vault_.borrowToken,
                expandPercent: 50 * 1e2, // 50%
                expandDuration: 6 hours, // 6 hours
                baseBorrowLimitInUSD: vault_.baseBorrowLimitInUSD,
                maxBorrowLimitInUSD: vault_.maxBorrowLimitInUSD
            });

            setBorrowProtocolLimits(protocolConfig_);
        }

        if (vault_.vaultType == VAULT_TYPE.TYPE_2) {
            BorrowProtocolConfig memory protocolConfig_ = BorrowProtocolConfig({
                protocol: vault_.vault,
                borrowToken: vault_.borrowToken,
                expandPercent: 30 * 1e2, // 30%
                expandDuration: 6 hours, // 6 hours
                baseBorrowLimitInUSD: vault_.baseBorrowLimitInUSD,
                maxBorrowLimitInUSD: vault_.maxBorrowLimitInUSD
            });

            setBorrowProtocolLimits(protocolConfig_);
        }

        if (vault_.vaultType == VAULT_TYPE.TYPE_3) {
            SupplyProtocolConfig memory protocolConfig_ = SupplyProtocolConfig({
                protocol: vault_.vault,
                supplyToken: vault_.supplyToken,
                expandPercent: 35 * 1e2, // 35%
                expandDuration: 6 hours, // 6 hours
                baseWithdrawalLimitInUSD: vault_.baseWithdrawalLimitInUSD
            });

            setSupplyProtocolLimits(protocolConfig_);
        }
    }

    function updateDexBaseLimits(
        uint256 dexId,
        uint256 maxSupplySharesInUSD,
        uint256 maxBorrowSharesInUSD
    ) internal {
        address dexAddress = getDexAddress(dexId);
        if (dexAddress == address(0)) return;

        (address AddressTokenA, address AddressTokenB) = getDexTokens(
            dexAddress
        );

        uint256 baseWithdrawalInUSD = (maxSupplySharesInUSD * 45) / 100; // 45% of supply cap
        uint256 baseBorrowInUSD = (maxBorrowSharesInUSD * 60) / 100; // 60% of max borrow cap
        uint256 maxBorrowInUSD = (maxBorrowSharesInUSD * 125) / 100; // 25% increase

        DexConfig memory dex_ = DexConfig({
            dex: dexAddress,
            tokenA: AddressTokenA,
            tokenB: AddressTokenB,
            smartCollateral: maxSupplySharesInUSD > 0,
            smartDebt: maxBorrowSharesInUSD > 0,
            baseWithdrawalLimitInUSD: baseWithdrawalInUSD,
            baseBorrowLimitInUSD: baseBorrowInUSD,
            maxBorrowLimitInUSD: maxBorrowInUSD
        });
        setDexLimits(dex_);
    }

    function getDexTokens(
        address dexAddress_
    ) internal view returns (address, address) {
        IFluidDex.ConstantViews memory constantViews_ = IFluidDex(dexAddress_)
            .constantsView();

        return (constantViews_.token0, constantViews_.token1);
    }

    function updateDexRevenueCut(uint256 dexId, uint256 revenueCut) internal {
        address dexAddress = getDexAddress(dexId);
        uint256 dexVariables2_ = IFluidDex(dexAddress).readFromStorage(
            bytes32(DexSlotsLink.DEX_VARIABLES2_SLOT)
        );
        uint256 fee_ = (dexVariables2_ >> 2) & X17;

        IFluidDex(dexAddress).updateFeeAndRevenueCut(
            fee_, // fee stays the same
            revenueCut
        );
    }
}
