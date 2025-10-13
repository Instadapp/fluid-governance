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
import {ISmartLendingFactory} from "../common/interfaces/ISmartLendingFactory.sol";
import {IFluidLendingFactory} from "../common/interfaces/IFluidLendingFactory.sol";

import {ICodeReader} from "../common/interfaces/ICodeReader.sol";

import {IDSAV2} from "../common/interfaces/IDSA.sol";
import {IERC20} from "../common/interfaces/IERC20.sol";
import {IProxy} from "../common/interfaces/IProxy.sol";
import {PayloadIGPConstants} from "../common/constants.sol";
import {PayloadIGPHelpers} from "../common/helpers.sol";
import {PayloadIGPMain} from "../common/main.sol";

contract PayloadIGP93 is PayloadIGPMain {
    uint256 public constant PROPOSAL_ID = 93;

    function execute() public virtual override {
        super.execute();

        // Action 1: Collect ETH Revenue and Transfer to Multisig
        action1();

        // Action 2: Update Borrow Rate Magnifier on LBTC-CBBTC / WBTC Vault
        action2();

        // Action 3: Adjust Rate curves of WBTC & cbBTC
        action3();

        // Action 4: Adjust CF, LT, LML for GHO Vaults
        action4();

        // Action5: Update expand percentage and duration for fTokens
        action5();

        // Action 6: Reduce limits on unused USDE debt vaults
        action6();

        // Action 7: Readjust the Max Borrow Limit for LBTC-cbBTC<>cbBTC vault
        action7();

        // Action 8: Set dust limits for Gold based vaults and DEX
        action8();

        // Action 9: Transfer $FLUID to Team Multisig for Rewards
        action9();

        // Action 10: Update borrow caps for cbBTC-wBTC Dex pool and USDC-USDT pool
        action10();

        // Action 11: Update lower range of weETHs-ETH & lower range and fees of rsETH-ETH
        action11();
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

    // @notice Action 1: Collect ETH Revenue and Transfer to Multisig
    function action1() internal isActionSkippable(1) {
        address[] memory tokens = new address[](1);

        tokens[0] = ETH_ADDRESS;

        LIQUIDITY.collectRevenue(tokens);

        uint256[] memory amounts = new uint256[](1);

        amounts[0] = address(FLUID_RESERVE).balance - 1;

        FLUID_RESERVE.withdrawFunds(tokens, amounts, TEAM_MULTISIG);
    }

    // @notice Action 2: Update Borrow Rate Magnifier on LBTC-CBBTC / WBTC Vault
    function action2() internal isActionSkippable(2) {
        address lBTC_cbBTC__WBTC_VAULT = getVaultAddress(97);

        IFluidVaultT1(lBTC_cbBTC__WBTC_VAULT).updateBorrowRateMagnifier(
            150 * 1e2
        ); // 1.5x borrowRateMagnifier
    }

    // @notice Action 3: Adjust Rate curves of WBTC & cbBTC
    function action3() internal isActionSkippable(3) {
        {
            // Update WBTC & cbBTC rate
            FluidLiquidityAdminStructs.RateDataV2Params[]
                memory params_ = new FluidLiquidityAdminStructs.RateDataV2Params[](
                    2
                );

            params_[0] = FluidLiquidityAdminStructs.RateDataV2Params({
                token: WBTC_ADDRESS, // WBTC
                kink1: 80 * 1e2, // 80%
                kink2: 90 * 1e2, // 90%
                rateAtUtilizationZero: 0, // 0%
                rateAtUtilizationKink1: 2 * 1e2, // 2%
                rateAtUtilizationKink2: 10 * 1e2, // 10%
                rateAtUtilizationMax: 100 * 1e2 // 100%
            });

            params_[1] = FluidLiquidityAdminStructs.RateDataV2Params({
                token: cbBTC_ADDRESS, // cbBTC
                kink1: 80 * 1e2, // 80%
                kink2: 90 * 1e2, // 90%
                rateAtUtilizationZero: 0, // 0%
                rateAtUtilizationKink1: 2 * 1e2, // 2%
                rateAtUtilizationKink2: 10 * 1e2, // 10%
                rateAtUtilizationMax: 100 * 1e2 // 100%
            });

            LIQUIDITY.updateRateDataV2s(params_);
        }
    }

    // @notice Action 4: Adjust CF, LT, LML for GHO Vaults
    function action4() internal isActionSkippable(4) {
        {
            address GHO_USDC__GHO_USDC = getVaultAddress(61);
            address sUSDe_GHO = getVaultAddress(56);

            uint256 CF = 90 * 1e2;
            uint256 LT = 92 * 1e2;
            uint256 LML = 95 * 1e2;

            IFluidVaultT1(GHO_USDC__GHO_USDC).updateCollateralFactor(CF);
            IFluidVaultT1(GHO_USDC__GHO_USDC).updateLiquidationThreshold(LT);
            IFluidVaultT1(GHO_USDC__GHO_USDC).updateLiquidationMaxLimit(LML);

            IFluidVaultT1(sUSDe_GHO).updateLiquidationMaxLimit(LML);
            IFluidVaultT1(sUSDe_GHO).updateLiquidationThreshold(LT);
            IFluidVaultT1(sUSDe_GHO).updateCollateralFactor(CF);
        }

        {
            address ETH_GHO = getVaultAddress(54);

            uint256 CF = 87 * 1e2;
            uint256 LT = 92 * 1e2;
            uint256 LML = 94 * 1e2;

            IFluidVaultT1(ETH_GHO).updateLiquidationMaxLimit(LML);
            IFluidVaultT1(ETH_GHO).updateLiquidationThreshold(LT);
            IFluidVaultT1(ETH_GHO).updateCollateralFactor(CF);
        }
    }

    // @notice Action 5: Update expand percentage and duration for fTokens
    function action5() internal isActionSkippable(5) {
        uint256 EXPAND_PERCENT = 35 * 1e2; // 35%
        uint256 EXPAND_DURATION = 6 hours;
        // Update fUSDC
        setProtocolSupplyExpansion(
            getFTokenAddress(USDC_ADDRESS),
            USDC_ADDRESS,
            EXPAND_PERCENT,
            EXPAND_DURATION
        );

        // Update fUSDT
        setProtocolSupplyExpansion(
            getFTokenAddress(USDT_ADDRESS),
            USDT_ADDRESS,
            EXPAND_PERCENT,
            EXPAND_DURATION
        );

        // Update fWETH
        setProtocolSupplyExpansion(
            getFTokenAddress(WETH_ADDRESS),
            ETH_ADDRESS,
            EXPAND_PERCENT,
            EXPAND_DURATION
        );

        // Update fwstETH
        setProtocolSupplyExpansion(
            getFTokenAddress(wstETH_ADDRESS),
            wstETH_ADDRESS,
            EXPAND_PERCENT,
            EXPAND_DURATION
        );

        // Update fGHO
        setProtocolSupplyExpansion(
            getFTokenAddress(GHO_ADDRESS),
            GHO_ADDRESS,
            EXPAND_PERCENT,
            EXPAND_DURATION
        );

        // Update fsUSDS
        setProtocolSupplyExpansion(
            getFTokenAddress(sUSDs_ADDRESS),
            sUSDs_ADDRESS,
            EXPAND_PERCENT,
            EXPAND_DURATION
        );
    }

    // @notice Action 6: Reduce limits on unused USDE debt vaults
    function action6() internal isActionSkippable(6) {
        {
            address vault_eth_usde = getVaultAddress(69);
            // Pause supply and borrow limits
            setSupplyProtocolLimitsPaused(vault_eth_usde, ETH_ADDRESS);
            setBorrowProtocolLimitsPaused(vault_eth_usde, USDe_ADDRESS);
        }

        {
            address vault_wsteth_usde = getVaultAddress(70);
            // Pause supply and borrow limits
            setSupplyProtocolLimitsPaused(vault_wsteth_usde, wstETH_ADDRESS);
            setBorrowProtocolLimitsPaused(vault_wsteth_usde, USDe_ADDRESS);
        }

        {
            address vault_weeth_usde = getVaultAddress(71);
            // Pause supply and borrow limits
            setSupplyProtocolLimitsPaused(vault_weeth_usde, weETH_ADDRESS);
            setBorrowProtocolLimitsPaused(vault_weeth_usde, USDe_ADDRESS);
        }

        {
            address vault_wbtc_usde = getVaultAddress(72);
            // Pause supply and borrow limits
            setSupplyProtocolLimitsPaused(vault_wbtc_usde, WBTC_ADDRESS);
            setBorrowProtocolLimitsPaused(vault_wbtc_usde, USDe_ADDRESS);
        }

        {
            address vault_cbbtc_usde = getVaultAddress(73);
            // Pause supply and borrow limits
            setSupplyProtocolLimitsPaused(vault_cbbtc_usde, cbBTC_ADDRESS);
            setBorrowProtocolLimitsPaused(vault_cbbtc_usde, USDe_ADDRESS);
        }
    }

    // @notice Action 7: Readjust the Max Borrow Limit for LBTC-cbBTC<>cbBTC vault
    function action7() internal isActionSkippable(7) {
        address LBTC_cbBTC__cbBTC_VAULT = getVaultAddress(114);

        {
            // [TYPE 2] LBTC-cbBTC<>cbBTC vault
            VaultConfig memory VAULT_LBTC_cbBTC__cbBTC = VaultConfig({
                vault: LBTC_cbBTC__cbBTC_VAULT,
                vaultType: VAULT_TYPE.TYPE_2,
                supplyToken: address(0),
                borrowToken: cbBTC_ADDRESS,
                baseWithdrawalLimitInUSD: 0, // set at dex
                baseBorrowLimitInUSD: 12_000_000, // $12M
                maxBorrowLimitInUSD: 35_000_000 // $35M = ~380 cbBTC
            });
            setVaultLimits(VAULT_LBTC_cbBTC__cbBTC);
        }
    }

    // @notice Action 8: Set dust limits for Gold based vaults and DEX
    function action8() internal isActionSkippable(8) {
        {
            // PAXG-XAUT DEX
            address PAXG_XAUT_DEX = getDexAddress(32);
            {
                DexConfig memory DEX_PAXG_XAUT = DexConfig({
                    dex: PAXG_XAUT_DEX,
                    tokenA: PAXG_ADDRESS,
                    tokenB: XAUT_ADDRESS,
                    smartCollateral: true,
                    smartDebt: false,
                    baseWithdrawalLimitInUSD: 10_000, // $10k
                    baseBorrowLimitInUSD: 0, // $0
                    maxBorrowLimitInUSD: 0 // $0
                });
                setDexLimits(DEX_PAXG_XAUT); // Smart Collateral

                DEX_FACTORY.setDexAuth(PAXG_XAUT_DEX, TEAM_MULTISIG, true);
            }
        }

        {
            // [TYPE 1] XAUT / USDC VAULT
            address XAUT_USDC_VAULT = getVaultAddress(116);
            {
                VaultConfig memory VAULT_XAUT_USDC = VaultConfig({
                    vault: XAUT_USDC_VAULT,
                    vaultType: VAULT_TYPE.TYPE_1,
                    supplyToken: XAUT_ADDRESS,
                    borrowToken: USDC_ADDRESS,
                    baseWithdrawalLimitInUSD: 10_000, // $10k
                    baseBorrowLimitInUSD: 8_000, // $8k
                    maxBorrowLimitInUSD: 10_000 // $10k
                });

                setVaultLimits(VAULT_XAUT_USDC); // TYPE_1 => 116

                VAULT_FACTORY.setVaultAuth(
                    XAUT_USDC_VAULT,
                    TEAM_MULTISIG,
                    true
                );
            }
        }

        {
            // [TYPE 1] XAUT / USDT VAULT
            address XAUT_USDT_VAULT = getVaultAddress(117);
            {
                VaultConfig memory VAULT_XAUT_USDT = VaultConfig({
                    vault: XAUT_USDT_VAULT,
                    vaultType: VAULT_TYPE.TYPE_1,
                    supplyToken: XAUT_ADDRESS,
                    borrowToken: USDT_ADDRESS,
                    baseWithdrawalLimitInUSD: 10_000, // $10k
                    baseBorrowLimitInUSD: 8_000, // $8k
                    maxBorrowLimitInUSD: 10_000 // $10k
                });

                setVaultLimits(VAULT_XAUT_USDT); // TYPE_1 => 117

                VAULT_FACTORY.setVaultAuth(
                    XAUT_USDT_VAULT,
                    TEAM_MULTISIG,
                    true
                );
            }
        }

        {
            // [TYPE 1] XAUT / GHO VAULT
            address XAUT_GHO_VAULT = getVaultAddress(118);
            {
                VaultConfig memory VAULT_XAUT_GHO = VaultConfig({
                    vault: XAUT_GHO_VAULT,
                    vaultType: VAULT_TYPE.TYPE_1,
                    supplyToken: XAUT_ADDRESS,
                    borrowToken: GHO_ADDRESS,
                    baseWithdrawalLimitInUSD: 10_000, // $10k
                    baseBorrowLimitInUSD: 8_000, // $8k
                    maxBorrowLimitInUSD: 10_000 // $10k
                });

                setVaultLimits(VAULT_XAUT_GHO); // TYPE_1 => 118

                VAULT_FACTORY.setVaultAuth(XAUT_GHO_VAULT, TEAM_MULTISIG, true);
            }
        }

        {
            // [TYPE 1] PAXG / USDC VAULT
            address PAXG_USDC_VAULT = getVaultAddress(119);
            {
                VaultConfig memory VAULT_PAXG_USDC = VaultConfig({
                    vault: PAXG_USDC_VAULT,
                    vaultType: VAULT_TYPE.TYPE_1,
                    supplyToken: PAXG_ADDRESS,
                    borrowToken: USDC_ADDRESS,
                    baseWithdrawalLimitInUSD: 10_000, // $10k
                    baseBorrowLimitInUSD: 8_000, // $8k
                    maxBorrowLimitInUSD: 10_000 // $10k
                });

                setVaultLimits(VAULT_PAXG_USDC); // TYPE_1 => 119

                VAULT_FACTORY.setVaultAuth(
                    PAXG_USDC_VAULT,
                    TEAM_MULTISIG,
                    true
                );
            }
        }

        {
            // [TYPE 1] PAXG / USDT VAULT
            address PAXG_USDT_VAULT = getVaultAddress(120);
            {
                VaultConfig memory VAULT_PAXG_USDT = VaultConfig({
                    vault: PAXG_USDT_VAULT,
                    vaultType: VAULT_TYPE.TYPE_1,
                    supplyToken: PAXG_ADDRESS,
                    borrowToken: USDT_ADDRESS,
                    baseWithdrawalLimitInUSD: 10_000, // $10k
                    baseBorrowLimitInUSD: 8_000, // $8k
                    maxBorrowLimitInUSD: 10_000 // $10k
                });

                setVaultLimits(VAULT_PAXG_USDT); // TYPE_1 => 120

                VAULT_FACTORY.setVaultAuth(
                    PAXG_USDT_VAULT,
                    TEAM_MULTISIG,
                    true
                );
            }
        }

        {
            // [TYPE 1] PAXG / GHO VAULT
            address PAXG_GHO_VAULT = getVaultAddress(121);
            {
                VaultConfig memory VAULT_PAXG_GHO = VaultConfig({
                    vault: PAXG_GHO_VAULT,
                    vaultType: VAULT_TYPE.TYPE_1,
                    supplyToken: PAXG_ADDRESS,
                    borrowToken: GHO_ADDRESS,
                    baseWithdrawalLimitInUSD: 10_000, // $10k
                    baseBorrowLimitInUSD: 8_000, // $8k
                    maxBorrowLimitInUSD: 10_000 // $10k
                });

                setVaultLimits(VAULT_PAXG_GHO); // TYPE_1 => 121

                VAULT_FACTORY.setVaultAuth(PAXG_GHO_VAULT, TEAM_MULTISIG, true);
            }
        }

        {
            // [TYPE 2] PAXG-XAUT<>USDC | smart collateral & normal debt
            address PAXG_XAUT__USDC_VAULT = getVaultAddress(122);

            {
                VaultConfig memory VAULT_PAXG_XAUT__USDC = VaultConfig({
                    vault: PAXG_XAUT__USDC_VAULT,
                    vaultType: VAULT_TYPE.TYPE_2,
                    supplyToken: address(0),
                    borrowToken: USDC_ADDRESS,
                    baseWithdrawalLimitInUSD: 0,
                    baseBorrowLimitInUSD: 8_000, // $8k
                    maxBorrowLimitInUSD: 10_000 // $10k
                });

                setVaultLimits(VAULT_PAXG_XAUT__USDC); // TYPE_2 => 122

                VAULT_FACTORY.setVaultAuth(
                    PAXG_XAUT__USDC_VAULT,
                    TEAM_MULTISIG,
                    true
                );
            }
        }

        {
            // [TYPE 2] PAXG-XAUT<>USDT | smart collateral & normal debt
            address PAXG_XAUT__USDT_VAULT = getVaultAddress(123);

            {
                VaultConfig memory VAULT_PAXG_XAUT__USDT = VaultConfig({
                    vault: PAXG_XAUT__USDT_VAULT,
                    vaultType: VAULT_TYPE.TYPE_2,
                    supplyToken: address(0),
                    borrowToken: USDT_ADDRESS,
                    baseWithdrawalLimitInUSD: 0,
                    baseBorrowLimitInUSD: 8_000, // $8k
                    maxBorrowLimitInUSD: 10_000 // $10k
                });

                setVaultLimits(VAULT_PAXG_XAUT__USDT); // TYPE_2 => 123

                VAULT_FACTORY.setVaultAuth(
                    PAXG_XAUT__USDT_VAULT,
                    TEAM_MULTISIG,
                    true
                );
            }
        }

        {
            // [TYPE 2] PAXG-XAUT<>GHO | smart collateral & normal debt
            address PAXG_XAUT__GHO_VAULT = getVaultAddress(124);

            {
                VaultConfig memory VAULT_PAXG_XAUT__GHO = VaultConfig({
                    vault: PAXG_XAUT__GHO_VAULT,
                    vaultType: VAULT_TYPE.TYPE_2,
                    supplyToken: address(0),
                    borrowToken: GHO_ADDRESS,
                    baseWithdrawalLimitInUSD: 0,
                    baseBorrowLimitInUSD: 8_000, // $8k
                    maxBorrowLimitInUSD: 10_000 // $10k
                });

                setVaultLimits(VAULT_PAXG_XAUT__GHO); // TYPE_2 => 124

                VAULT_FACTORY.setVaultAuth(
                    PAXG_XAUT__GHO_VAULT,
                    TEAM_MULTISIG,
                    true
                );
            }
        }
    }

    // @notice Action 9: Transfer $FLUID to Team Multisig for Rewards
    function action9() internal isActionSkippable(9) {
        string[] memory targets = new string[](1);
        bytes[] memory encodedSpells = new bytes[](1);

        string
            memory withdrawSignature = "withdraw(address,uint256,address,uint256,uint256)";

        // Spell 1: Transfer FLUID to Team Multisig
        {
            uint256 FLUID_AMOUNT = 582_222 * 1e18;
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

    // @notice Action 10: Update borrow shares for cbBTC-wBTC Dex pool and USDC-USDT pool
    function action10() internal isActionSkippable(10) {
        {
            address CBBTC_WBTC_DEX_ADDRESS = getDexAddress(3);

            // Update max borrow shares on cbBTC-WBTC
            IFluidDex(CBBTC_WBTC_DEX_ADDRESS).updateMaxBorrowShares(
                150 * 1e18 // 150 shares
            );
        }

        {
            address USDC_USDT_DEX = getDexAddress(2);

            // Update max borrow shares on USDC-USDT
            IFluidDex(USDC_USDT_DEX).updateMaxBorrowShares(
                35_000_000 * 1e18 // 35M shares
            );
        }
    }

    // @notice Action 11: Update lower range of weETHs-ETH & lower range and fees of rsETH-ETH
    function action11() internal isActionSkippable(11) {
        {
            address weETHs_ETH_DEX_ADDRESS = getDexAddress(14);
            {
                // Update Lower Range
                IFluidDex(weETHs_ETH_DEX_ADDRESS).updateRangePercents(
                    0.0001 * 1e4, // +0.0001%
                    0.2 * 1e4, // -0.2%
                    10 days
                );
            }
        }

        {
            address rsETH_ETH_DEX_ADDRESS = getDexAddress(13);
            {
                // update Lower Range
                IFluidDex(rsETH_ETH_DEX_ADDRESS).updateRangePercents(
                    0.0001 * 1e4, // +0.0001%
                    0.2 * 1e4, // -0.2%
                    10 days
                );
            }

            {
                //Update Trading Fee
                IFluidDex(rsETH_ETH_DEX_ADDRESS).updateFeeAndRevenueCut(
                    0.02 * 1e4, // 0.02%
                    25 * 1e4 // 25%
                );
            }
        }
    }

    /**
     * |
     * |     Payload Actions End Here      |
     * |__________________________________
     */

    // Token Prices Constants
    uint256 public constant ETH_USD_PRICE = 1_750 * 1e2;
    uint256 public constant wstETH_USD_PRICE = 2_300 * 1e2;
    uint256 public constant weETH_USD_PRICE = 2_000 * 1e2;
    uint256 public constant rsETH_USD_PRICE = 1_975 * 1e2;
    uint256 public constant weETHs_USD_PRICE = 1_930 * 1e2;
    uint256 public constant mETH_USD_PRICE = 2_000 * 1e2;
    uint256 public constant ezETH_USD_PRICE = 1_975 * 1e2;

    uint256 public constant BTC_USD_PRICE = 94_500 * 1e2;

    uint256 public constant STABLE_USD_PRICE = 1 * 1e2;
    uint256 public constant sUSDe_USD_PRICE = 1.15 * 1e2;
    uint256 public constant sUSDs_USD_PRICE = 1.02 * 1e2;

    uint256 public constant FLUID_USD_PRICE = 5 * 1e2;

    uint256 public constant RLP_USD_PRICE = 1.16 * 1e2;
    uint256 public constant wstUSR_USD_PRICE = 1.07 * 1e2;

    uint256 public constant XAUT_USD_PRICE = 3_400 * 1e2;
    uint256 public constant PAXG_USD_PRICE = 3_400 * 1e2;

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
        } else if (
            token == GHO_ADDRESS ||
            token == USDe_ADDRESS ||
            token == deUSD_ADDRESS ||
            token == USR_ADDRESS ||
            token == USD0_ADDRESS ||
            token == fxUSD_ADDRESS ||
            token == BOLD_ADDRESS
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
