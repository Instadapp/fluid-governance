pragma solidity ^0.8.21;
pragma experimental ABIEncoderV2;

import {BigMathMinified} from "../libraries/bigMathMinified.sol";
import {LiquidityCalcs} from "../libraries/liquidityCalcs.sol";
import {LiquiditySlotsLink} from "../libraries/liquiditySlotsLink.sol";

import {IGovernorBravo} from "../common/interfaces/IGovernorBravo.sol";
import {ITimelock} from "../common/interfaces/ITimelock.sol";

import {IFluidLiquidityAdmin, AdminModuleStructs as FluidLiquidityAdminStructs} from "../common/interfaces/IFluidLiquidity.sol";
import {IFluidReserveContract} from "../common/interfaces/IFluidReserveContract.sol";

import {IFluidVaultFactory} from "../common/interfaces/IFluidVaultFactory.sol";
import {IFluidDexFactory} from "../common/interfaces/IFluidDexFactory.sol";

import {IFluidDex, IFluidAdminDex, IFluidDexResolver} from "../common/interfaces/IFluidDex.sol";

import {IFluidVault, IFluidVaultT1} from "../common/interfaces/IFluidVault.sol";

import {IFTokenAdmin, ILendingRewards} from "../common/interfaces/IFToken.sol";

import {ISmartLendingAdmin} from "../common/interfaces/ISmartLending.sol";
import {IFluidSmartLendingFactory} from "../common/interfaces/IFluidSmartLendingFactory.sol";
import {IFluidLendingFactory} from "../common/interfaces/IFluidLendingFactory.sol";

import {ICodeReader} from "../common/interfaces/ICodeReader.sol";

import {IDSAV2} from "../common/interfaces/IDSA.sol";
import {IERC20} from "../common/interfaces/IERC20.sol";
import {IProxy} from "../common/interfaces/IProxy.sol";
import {PayloadIGPConstants} from "../common/constants.sol";
import {PayloadIGPHelpers} from "../common/helpers.sol";
import {PayloadIGPMain} from "../common/main.sol";

import {ILite} from "../common/interfaces/ILite.sol";

contract PayloadIGP105 is PayloadIGPMain {
    uint256 public constant PROPOSAL_ID = 105;

    function execute() public virtual override {
        super.execute();

        // Action 1: Clean up the default rate curves on unutilized assets
        action1();

        // Action 2: Update ETH interest rate curve
        action2();

        // Action 3: Make Team Multisig 2 as deployer on all factories
        action3();

        // Action 4: Set wstUSR launch limits and dust limits
        action4();

        // Action 5: Withdraw additional $FLUID for Rewards
        action5();

        // Action 6: Update LBTC oracle and center price
        action6();

        // Action 7: Update USDe T1 vaults parameters
        action7();

        // Action 8: Provide Credit to Team Multisig for Fluid DEX Lite
        action8();

        // Action 9: Refunding Lite Users
        action9();
    }

    function verifyProposal() public view override {}

    function _PROPOSAL_ID() internal view override returns (uint256) {
        return PROPOSAL_ID;
    }

    /**
     * |
     * |     Proposal Payload Actions      |
     * |__________________________________
     */

    // @notice Action 1: Clean up the default rate curves on unutilized assets
    function action1() internal isActionSkippable(1) {
        address[15] memory tokens_ = [
            lBTC_ADDRESS, // lBTC
            rsETH_ADDRESS, // rsETH
            ezETH_ADDRESS, // ezETH
            wstUSR_ADDRESS, // wstUSR
            eBTC_ADDRESS, // eBTC
            USD0_ADDRESS, // USD0
            iUSD_ADDRESS, // iUSD
            fxUSD_ADDRESS, // fxUSD
            RLP_ADDRESS, // RLP
            XAUT_ADDRESS, // XAUT
            PAXG_ADDRESS, // PAXG
            USR_ADDRESS, // USR
            tBTC_ADDRESS, // tBTC
            csUSDL_ADDRESS, // csUSDL
            deUSD_ADDRESS // deUSD
        ];

        for (uint256 i = 0; i < tokens_.length; i++) {
            FluidLiquidityAdminStructs.RateDataV2Params[]
                memory params_ = new FluidLiquidityAdminStructs.RateDataV2Params[](
                    1
                );
            params_[0] = FluidLiquidityAdminStructs.RateDataV2Params({
                token: tokens_[i],
                kink1: 50 * 1e2, // 50%
                kink2: 80 * 1e2, // 80%
                rateAtUtilizationZero: 0, // 0%
                rateAtUtilizationKink1: 20 * 1e2, // 20%
                rateAtUtilizationKink2: 40 * 1e2, // 40%
                rateAtUtilizationMax: 100 * 1e2 // 100%
            });
            LIQUIDITY.updateRateDataV2s(params_);
        }
    }

    // @notice Action 2: Update ETH interest rate curve
    function action2() internal isActionSkippable(2) {
        {
            FluidLiquidityAdminStructs.RateDataV2Params[]
                memory params_ = new FluidLiquidityAdminStructs.RateDataV2Params[](
                    1
                );

            params_[0] = FluidLiquidityAdminStructs.RateDataV2Params({
                token: ETH_ADDRESS, // ETH
                kink1: 88 * 1e2, // 88%
                kink2: 93 * 1e2, // 93%
                rateAtUtilizationZero: 0, // 0%
                rateAtUtilizationKink1: 2.75 * 1e2, // 2.75%
                rateAtUtilizationKink2: 4 * 1e2, // 4%
                rateAtUtilizationMax: 100 * 1e2 // 100%
            });

            LIQUIDITY.updateRateDataV2s(params_);
        }
    }

    // @notice Action 3: Make Team Multisig 2 as deployer on all factories
    function action3() internal isActionSkippable(3) {
        // Set TEAM_MULTISIG_2 as deployer on all factories

        // Vault Factory
        IFluidVaultFactory(VAULT_FACTORY).setDeployer(TEAM_MULTISIG_2, true);

        // Dex Factory
        IFluidDexFactory(DEX_FACTORY).setDeployer(TEAM_MULTISIG_2, true);

        // Lending Factory
        IFluidLendingFactory(LENDING_FACTORY).setDeployer(
            TEAM_MULTISIG_2,
            true
        );

        // Smart Lending Factory
        IFluidSmartLendingFactory(SMART_LENDING_FACTORY).updateDeployer(
            TEAM_MULTISIG_2,
            true
        );
    }

    // @notice Action 4: Set wstUSR launch limits and dust limits
    function action4() internal isActionSkippable(4) {
        // Set launch limits for existing WSTUSR/STABLE vaults (T1 vaults)
        {
            address wstUSR_USDC_VAULT = getVaultAddress(110);

            // [TYPE 1] WSTUSR/USDC vault - Launch limits
            VaultConfig memory VAULT_wstUSR_USDC = VaultConfig({
                vault: wstUSR_USDC_VAULT,
                vaultType: VAULT_TYPE.TYPE_1,
                supplyToken: wstUSR_ADDRESS,
                borrowToken: USDC_ADDRESS,
                baseWithdrawalLimitInUSD: 8_000_000, // $8M
                baseBorrowLimitInUSD: 6_000_000, // $6M
                maxBorrowLimitInUSD: 20_000_000 // $20M
            });

            setVaultLimits(VAULT_wstUSR_USDC);
            VAULT_FACTORY.setVaultAuth(wstUSR_USDC_VAULT, TEAM_MULTISIG, false);
        }

        {
            address wstUSR_USDT_VAULT = getVaultAddress(111);

            // [TYPE 1] WSTUSR/USDT vault - Launch limits
            VaultConfig memory VAULT_wstUSR_USDT = VaultConfig({
                vault: wstUSR_USDT_VAULT,
                vaultType: VAULT_TYPE.TYPE_1,
                supplyToken: wstUSR_ADDRESS,
                borrowToken: USDT_ADDRESS,
                baseWithdrawalLimitInUSD: 8_000_000, // $8M
                baseBorrowLimitInUSD: 6_000_000, // $6M
                maxBorrowLimitInUSD: 20_000_000 // $20M
            });

            setVaultLimits(VAULT_wstUSR_USDT);
            VAULT_FACTORY.setVaultAuth(wstUSR_USDT_VAULT, TEAM_MULTISIG, false);
        }

        {
            address wstUSR_GHO_VAULT = getVaultAddress(112);

            // [TYPE 1] WSTUSR/GHO vault - Launch limits
            VaultConfig memory VAULT_wstUSR_GHO = VaultConfig({
                vault: wstUSR_GHO_VAULT,
                vaultType: VAULT_TYPE.TYPE_1,
                supplyToken: wstUSR_ADDRESS,
                borrowToken: GHO_ADDRESS,
                baseWithdrawalLimitInUSD: 8_000_000, // $8M
                baseBorrowLimitInUSD: 6_000_000, // $6M
                maxBorrowLimitInUSD: 20_000_000 // $20M
            });

            setVaultLimits(VAULT_wstUSR_GHO);
            VAULT_FACTORY.setVaultAuth(wstUSR_GHO_VAULT, TEAM_MULTISIG, false);
        }

        // Set Dust Limit for wstUSR vaults

        {
            // dust limits for wstUSR/USDTb vault
            address wstUSR_USDTb_VAULT = getVaultAddress(142);

            // [TYPE 1] WSTUSR/USDTbvault - Dust limits
            VaultConfig memory VAULT_wstUSR_USDTb = VaultConfig({
                vault: wstUSR_USDTb_VAULT,
                vaultType: VAULT_TYPE.TYPE_1,
                supplyToken: wstUSR_ADDRESS,
                borrowToken: USDTb_ADDRESS,
                baseWithdrawalLimitInUSD: 7_000, // $7k
                baseBorrowLimitInUSD: 7_000, // $7k
                maxBorrowLimitInUSD: 9_000 // $9k
            });

            setVaultLimits(VAULT_wstUSR_USDTb);
            VAULT_FACTORY.setVaultAuth(wstUSR_USDTb_VAULT, TEAM_MULTISIG, true);
        }

        {
            // dust limits for wstUSR/USDC-USDT vault
            address wstUSR_USDC_USDT_VAULT = getVaultAddress(143);
            address USDC_USDT_DEX = getDexAddress(2);

            {
                // [TYPE 3] WSTUSR<>USDC-USDT vault - Dust limits
                VaultConfig memory VAULT_wstUSR_USDC_USDT = VaultConfig({
                    vault: wstUSR_USDC_USDT_VAULT,
                    vaultType: VAULT_TYPE.TYPE_3,
                    supplyToken: wstUSR_ADDRESS, // Set at vault level
                    borrowToken: address(0), // Set at DEX level
                    baseWithdrawalLimitInUSD: 7_000,
                    baseBorrowLimitInUSD: 0,
                    maxBorrowLimitInUSD: 0
                });

                setVaultLimits(VAULT_wstUSR_USDC_USDT);
                VAULT_FACTORY.setVaultAuth(
                    wstUSR_USDC_USDT_VAULT,
                    TEAM_MULTISIG,
                    true
                );
            }

            {
                DexBorrowProtocolConfigInShares
                    memory config_ = DexBorrowProtocolConfigInShares({
                        dex: USDC_USDT_DEX,
                        protocol: wstUSR_USDC_USDT_VAULT,
                        expandPercent: 30 * 1e2, // 20%
                        expandDuration: 6 hours, // 6 hours
                        baseBorrowLimit: 3500 * 1e18, // 3500 shares or $7k
                        maxBorrowLimit: 4500 * 1e18 // 4500 shares or $9k
                    });

                setDexBorrowProtocolLimitsInShares(config_);
            }
        }

        {
            // dust limits for wstUSR/USDC-USDT concentrated vault
            address wstUSR_USDC_USDT_CONCENTRATED_VAULT = getVaultAddress(144);
            address USDC_USDT_CONCENTRATED_DEX = getDexAddress(34);

            {
                // [TYPE 3] WSTUSR<>USDC-USDT concentrated vault - Dust limits
                VaultConfig
                    memory VAULT_wstUSR_USDC_USDT_CONCENTRATED = VaultConfig({
                        vault: wstUSR_USDC_USDT_CONCENTRATED_VAULT,
                        vaultType: VAULT_TYPE.TYPE_3,
                        supplyToken: wstUSR_ADDRESS, // Set at vault level
                        borrowToken: address(0), // Set at DEX level
                        baseWithdrawalLimitInUSD: 7_000,
                        baseBorrowLimitInUSD: 0,
                        maxBorrowLimitInUSD: 0
                    });

                setVaultLimits(VAULT_wstUSR_USDC_USDT_CONCENTRATED);
                VAULT_FACTORY.setVaultAuth(
                    wstUSR_USDC_USDT_CONCENTRATED_VAULT,
                    TEAM_MULTISIG,
                    true
                );
            }

            {
                DexBorrowProtocolConfigInShares
                    memory vaultConfig_ = DexBorrowProtocolConfigInShares({
                        dex: USDC_USDT_CONCENTRATED_DEX,
                        protocol: wstUSR_USDC_USDT_CONCENTRATED_VAULT,
                        expandPercent: 30 * 1e2, // 20%
                        expandDuration: 6 hours, // 6 hours
                        baseBorrowLimit: 3500 * 1e18, // 3500 shares or $7k
                        maxBorrowLimit: 4500 * 1e18 // 4500 shares or $9k
                    });

                setDexBorrowProtocolLimitsInShares(vaultConfig_);
            }
        }
    }

    // @notice Action 5: Withdraw additional $FLUID for Rewards
    function action5() internal isActionSkippable(5) {
        string[] memory targets = new string[](1);
        bytes[] memory encodedSpells = new bytes[](1);

        string
            memory withdrawSignature = "withdraw(address,uint256,address,uint256,uint256)";

        // Spell 1: Transfer FLUID to Team Multisig
        {
            uint256 FLUID_AMOUNT = 11_500 * 1e18;
            targets[0] = "BASIC-A";
            encodedSpells[0] = abi.encodeWithSignature(
                withdrawSignature,
                FLUID_ADDRESS,
                FLUID_AMOUNT,
                TEAM_MULTISIG,
                0,
                0
            );
        }

        IDSAV2(TREASURY).cast(targets, encodedSpells, address(this));
    }

    // @notice Action 6: Update LBTC oracle and center price
    function action6() internal isActionSkippable(6) {
        {
            address lBTC_cbBTC_DEX = getDexAddress(17);
            IFluidDex(lBTC_cbBTC_DEX).updateCenterPriceAddress(
                170,
                1e4,
                2 days
            );
        }
        {
            address LBTC_WBTC_DEX_ADDRESS = getDexAddress(30);
            IFluidDex(LBTC_WBTC_DEX_ADDRESS).updateCenterPriceAddress(
                171,
                1e4,
                2 days
            );
        }
        {
            address LBTC_cbBTC__cbBTC_VAULT = getVaultAddress(114);
            IFluidVault(LBTC_cbBTC__cbBTC_VAULT).updateOracle(173); // https://etherscan.io/address/0x784801D99D55D7220BcC91Cd60bb13b92A20b0F4
        }
        {
            address LBTC_cbBTC__wBTC_VAULT = getVaultAddress(97);
            IFluidVault(LBTC_cbBTC__wBTC_VAULT).updateOracle(174); // https://etherscan.io/address/0x19bd1022114A8c45e9D6a332aE9e31Af53bF98cb
        }
        {
            address WBTC_LBTC__WBTC_VAULT = getVaultAddress(115);
            IFluidVault(WBTC_LBTC__WBTC_VAULT).updateOracle(175); // https://etherscan.io/address/0xb6ccC6b170b0c9B93Fa4b6400ebdD7dBec2C224D
        }
    }

    // @notice Action 7: Update USDE T1 vaults parameters
    function action7() internal isActionSkippable(7) {
        uint256 LML = 96 * 1e2;
        uint256 LT = 95 * 1e2;
        uint256 CF = 94 * 1e2;
        uint256 LP = 0.5 * 1e2;
        {
            address USDe_USDC_VAULT = getVaultAddress(66);

            // [TYPE 1] USDe/USDC vault - Launch limits
            VaultConfig memory VAULT_USDe_USDC = VaultConfig({
                vault: USDe_USDC_VAULT,
                vaultType: VAULT_TYPE.TYPE_1,
                supplyToken: USDe_ADDRESS,
                borrowToken: USDC_ADDRESS,
                baseWithdrawalLimitInUSD: 8_000_000, // $8M
                baseBorrowLimitInUSD: 8_000_000, // $8M
                maxBorrowLimitInUSD: 50_000_000 // $50M
            });

            setVaultLimits(VAULT_USDe_USDC);

            IFluidVaultT1(USDe_USDC_VAULT).updateLiquidationMaxLimit(LML);
            IFluidVaultT1(USDe_USDC_VAULT).updateLiquidationThreshold(LT);
            IFluidVaultT1(USDe_USDC_VAULT).updateCollateralFactor(CF);
            IFluidVaultT1(USDe_USDC_VAULT).updateLiquidationPenalty(LP);
        }
        {
            address USDe_USDT_VAULT = getVaultAddress(67);

            // [TYPE 1] USDe/USDT vault - Launch limits
            VaultConfig memory VAULT_USDe_USDT = VaultConfig({
                vault: USDe_USDT_VAULT,
                vaultType: VAULT_TYPE.TYPE_1,
                supplyToken: USDe_ADDRESS,
                borrowToken: USDT_ADDRESS,
                baseWithdrawalLimitInUSD: 8_000_000, // $8M
                baseBorrowLimitInUSD: 8_000_000, // $8M
                maxBorrowLimitInUSD: 50_000_000 // $50M
            });

            setVaultLimits(VAULT_USDe_USDT);

            IFluidVaultT1(USDe_USDT_VAULT).updateLiquidationMaxLimit(LML);
            IFluidVaultT1(USDe_USDT_VAULT).updateLiquidationThreshold(LT);
            IFluidVaultT1(USDe_USDT_VAULT).updateCollateralFactor(CF);
            IFluidVaultT1(USDe_USDT_VAULT).updateLiquidationPenalty(LP);
        }
        {
            address USDe_GHO_VAULT = getVaultAddress(68);

            // [TYPE 1] USDe/GHO vault - Launch limits
            VaultConfig memory VAULT_USDe_GHO = VaultConfig({
                vault: USDe_GHO_VAULT,
                vaultType: VAULT_TYPE.TYPE_1,
                supplyToken: USDe_ADDRESS,
                borrowToken: GHO_ADDRESS,
                baseWithdrawalLimitInUSD: 8_000_000, // $8M
                baseBorrowLimitInUSD: 8_000_000, // $8M
                maxBorrowLimitInUSD: 20_000_000 // $20M
            });

            setVaultLimits(VAULT_USDe_GHO);

            IFluidVaultT1(USDe_GHO_VAULT).updateLiquidationMaxLimit(LML);
            IFluidVaultT1(USDe_GHO_VAULT).updateLiquidationThreshold(LT);
            IFluidVaultT1(USDe_GHO_VAULT).updateCollateralFactor(CF);
            IFluidVaultT1(USDe_GHO_VAULT).updateLiquidationPenalty(LP);
        }
    }

    // @notice Action 8: Provide Credit to Team Multisig for Fluid DEX Lite
    function action8() internal isActionSkippable(8) {
        // Give Team Multisig 2.5M USDC credit
        {
            FluidLiquidityAdminStructs.UserBorrowConfig[]
                memory configs_ = new FluidLiquidityAdminStructs.UserBorrowConfig[](
                    1
                );

            configs_[0] = FluidLiquidityAdminStructs.UserBorrowConfig({
                user: TEAM_MULTISIG,
                token: USDC_ADDRESS,
                mode: 1,
                expandPercent: 1 * 1e2, // 1%
                expandDuration: 16777215, // max time
                baseDebtCeiling: getRawAmount(
                    USDC_ADDRESS,
                    0,
                    2_500_000, // $2.5M
                    false
                ),
                maxDebtCeiling: getRawAmount(
                    USDC_ADDRESS,
                    0,
                    2_500_000, // $2.5M
                    false
                )
            });

            LIQUIDITY.updateUserBorrowConfigs(configs_);
        }

        // Give Team Multisig 2.5M USDT credit
        {
            FluidLiquidityAdminStructs.UserBorrowConfig[]
                memory configs_ = new FluidLiquidityAdminStructs.UserBorrowConfig[](
                    1
                );

            configs_[0] = FluidLiquidityAdminStructs.UserBorrowConfig({
                user: TEAM_MULTISIG,
                token: USDT_ADDRESS,
                mode: 1,
                expandPercent: 1 * 1e2, // 1%
                expandDuration: 16777215, // max time
                baseDebtCeiling: getRawAmount(
                    USDT_ADDRESS,
                    0,
                    2_500_000, // $2.5M
                    false
                ),
                maxDebtCeiling: getRawAmount(
                    USDT_ADDRESS,
                    0,
                    2_500_000, // $2.5M
                    false
                )
            });

            LIQUIDITY.updateUserBorrowConfigs(configs_);
        }
    }

    // @notice Action 9: Refunding Lite Users
    function action9() internal isActionSkippable(9) {
        // Step 1: Withdraw 55 stETH from Lite vault to Treasury
        {
            string[] memory targets = new string[](1);
            bytes[] memory encodedSpells = new bytes[](1);

            // Spell 1: Withdraw 55 stETH from Lite vault and send back to iETH v2 vault as normal deposit
            {
                uint256 STETH_AMOUNT = 55 * 1e18; // 55 stETH
                string memory withdrawSignature = "withdraw(address,uint256,address,uint256,uint256)";
                
                targets[0] = "BASIC-D-V2";
                encodedSpells[0] = abi.encodeWithSignature(
                    withdrawSignature,
                    IETHV2,
                    STETH_AMOUNT,
                    address(IETHV2),
                    0,
                    0
                );
            }

            IDSAV2(TREASURY).cast(targets, encodedSpells, address(this));
        }
    }

    /**
     * |
     * |     Payload Actions End Here      |
     * |__________________________________
     */

    // Token Prices Constants
    uint256 public constant ETH_USD_PRICE = 3_700 * 1e2;
    uint256 public constant wstETH_USD_PRICE = 3_700 * 1e2;
    uint256 public constant weETH_USD_PRICE = 3_700 * 1e2;
    uint256 public constant rsETH_USD_PRICE = 3_700 * 1e2;
    uint256 public constant weETHs_USD_PRICE = 3_700 * 1e2;
    uint256 public constant mETH_USD_PRICE = 3_700 * 1e2;
    uint256 public constant ezETH_USD_PRICE = 3_700 * 1e2;

    uint256 public constant BTC_USD_PRICE = 113_000 * 1e2;

    uint256 public constant STABLE_USD_PRICE = 1 * 1e2;
    uint256 public constant sUSDe_USD_PRICE = 1.19 * 1e2;
    uint256 public constant sUSDs_USD_PRICE = 1.06 * 1e2;

    uint256 public constant FLUID_USD_PRICE = 6 * 1e2;

    uint256 public constant RLP_USD_PRICE = 1.22 * 1e2;
    uint256 public constant wstUSR_USD_PRICE = 1.09 * 1e2;
    uint256 public constant XAUT_USD_PRICE = 3_340 * 1e2;
    uint256 public constant PAXG_USD_PRICE = 3_340 * 1e2;

    uint256 public constant csUSDL_USD_PRICE = 1.03 * 1e2;

    function getRawAmount(
        address token,
        uint256 amount,
        uint256 amountInUSD,
        bool isSupply
    ) public view override returns (uint256) {
        if (amount > 0 && amountInUSD > 0) {
            revert("both usd and amount are not zero");
        }
        uint256 exchangePriceAndConfig_ = LIQUIDITY.readFromStorage(
            LiquiditySlotsLink.calculateMappingStorageSlot(
                LiquiditySlotsLink.LIQUIDITY_EXCHANGE_PRICES_MAPPING_SLOT,
                token
            )
        );

        (
            uint256 supplyExchangePrice,
            uint256 borrowExchangePrice
        ) = LiquidityCalcs.calcExchangePrices(exchangePriceAndConfig_);

        uint256 usdPrice = 0;
        uint256 decimals = 18;
        if (token == ETH_ADDRESS) {
            usdPrice = ETH_USD_PRICE;
            decimals = 18;
        } else if (token == wstETH_ADDRESS) {
            usdPrice = wstETH_USD_PRICE;
            decimals = 18;
        } else if (token == weETH_ADDRESS) {
            usdPrice = weETH_USD_PRICE;
            decimals = 18;
        } else if (token == rsETH_ADDRESS) {
            usdPrice = rsETH_USD_PRICE;
            decimals = 18;
        } else if (token == weETHs_ADDRESS) {
            usdPrice = weETHs_USD_PRICE;
            decimals = 18;
        } else if (token == mETH_ADDRESS) {
            usdPrice = mETH_USD_PRICE;
            decimals = 18;
        } else if (token == ezETH_ADDRESS) {
            usdPrice = ezETH_USD_PRICE;
            decimals = 18;
        } else if (
            token == cbBTC_ADDRESS ||
            token == WBTC_ADDRESS ||
            token == eBTC_ADDRESS ||
            token == lBTC_ADDRESS
        ) {
            usdPrice = BTC_USD_PRICE;
            decimals = 8;
        } else if (token == tBTC_ADDRESS) {
            usdPrice = BTC_USD_PRICE;
            decimals = 18;
        } else if (token == USDC_ADDRESS || token == USDT_ADDRESS) {
            usdPrice = STABLE_USD_PRICE;
            decimals = 6;
        } else if (token == sUSDe_ADDRESS) {
            usdPrice = sUSDe_USD_PRICE;
            decimals = 18;
        } else if (token == sUSDs_ADDRESS) {
            usdPrice = sUSDs_USD_PRICE;
            decimals = 18;
        } else if (token == csUSDL_ADDRESS) {
            usdPrice = csUSDL_USD_PRICE;
            decimals = 18;
        } else if (
            token == GHO_ADDRESS ||
            token == USDe_ADDRESS ||
            token == deUSD_ADDRESS ||
            token == USR_ADDRESS ||
            token == USD0_ADDRESS ||
            token == fxUSD_ADDRESS ||
            token == BOLD_ADDRESS ||
            token == iUSD_ADDRESS ||
            token == USDTb_ADDRESS
        ) {
            usdPrice = STABLE_USD_PRICE;
            decimals = 18;
        } else if (token == INST_ADDRESS) {
            usdPrice = FLUID_USD_PRICE;
            decimals = 18;
        } else if (token == wstUSR_ADDRESS) {
            usdPrice = wstUSR_USD_PRICE;
            decimals = 18;
        } else if (token == RLP_ADDRESS) {
            usdPrice = RLP_USD_PRICE;
            decimals = 18;
        } else if (token == XAUT_ADDRESS) {
            usdPrice = XAUT_USD_PRICE;
            decimals = 6;
        } else if (token == PAXG_ADDRESS) {
            usdPrice = PAXG_USD_PRICE;
            decimals = 18;
        } else {
            revert("not-found");
        }

        uint256 exchangePrice = isSupply
            ? supplyExchangePrice
            : borrowExchangePrice;

        if (amount > 0) {
            return (amount * 1e12) / exchangePrice;
        } else {
            return
                (amountInUSD * 1e12 * (10 ** decimals)) /
                ((usdPrice * exchangePrice) / 1e2);
        }
    }
}
