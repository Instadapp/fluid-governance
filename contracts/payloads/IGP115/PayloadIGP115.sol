// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.21;
pragma experimental ABIEncoderV2;

import {BigMathMinified} from "../libraries/bigMathMinified.sol";
import {LiquidityCalcs} from "../libraries/liquidityCalcs.sol";
import {LiquiditySlotsLink} from "../libraries/liquiditySlotsLink.sol";

import {IGovernorBravo} from "../common/interfaces/IGovernorBravo.sol";
import {ITimelock} from "../common/interfaces/ITimelock.sol";

import {
    IFluidLiquidityAdmin,
    AdminModuleStructs as FluidLiquidityAdminStructs
} from "../common/interfaces/IFluidLiquidity.sol";
import {
    IFluidReserveContract,
    IFluidReserveContractV2
} from "../common/interfaces/IFluidReserveContract.sol";

import {IFluidVaultFactory} from "../common/interfaces/IFluidVaultFactory.sol";
import {IFluidDexFactory} from "../common/interfaces/IFluidDexFactory.sol";

import {
    IFluidDex,
    IFluidAdminDex,
    IFluidDexResolver
} from "../common/interfaces/IFluidDex.sol";

import {
    IFluidVault,
    IFluidVaultT1,
    IFluidVaultT2
} from "../common/interfaces/IFluidVault.sol";

import {IFTokenAdmin, ILendingRewards} from "../common/interfaces/IFToken.sol";

import {ISmartLendingAdmin} from "../common/interfaces/ISmartLending.sol";
import {
    ISmartLendingFactory
} from "../common/interfaces/ISmartLendingFactory.sol";
import {
    IFluidLendingFactory
} from "../common/interfaces/IFluidLendingFactory.sol";

import {ICodeReader} from "../common/interfaces/ICodeReader.sol";
import {IDSAV2} from "../common/interfaces/IDSA.sol";
import {IERC20} from "../common/interfaces/IERC20.sol";
import {IInfiniteProxy} from "../common/interfaces/IInfiniteProxy.sol";
import {PayloadIGPConstants} from "../common/constants.sol";
import {PayloadIGPHelpers} from "../common/helpers.sol";
import {PayloadIGPMain} from "../common/main.sol";
import {ILite} from "../common/interfaces/ILite.sol";

/// @notice IGP115: Configure OSETH T2 vault, OSETH vaults launch limits
contract PayloadIGP115 is PayloadIGPMain {
    uint256 public constant PROPOSAL_ID = 115;

    function execute() public virtual override {
        super.execute();

        // Action 1: Set launch limits for OSETH related protocols. Same as in IGP114 without The T4 OSETH vault related logic
        action1();

        // Action 2: Configure OSETH T2 vault (Vault ID 159) and related DEX settings + launch limits
        action2();

        // Action 3: Deprecate T4 vault (OSETH-ETH <> wstETH-ETH, VAULT ID 158)
        action3();
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

    /// @notice Action 1: Set launch limits for OSETH related protocols. Same as in IGP114 without The T4 OSETH vault related logic
    function action1() internal isActionSkippable(1) {
        // OSETH-ETH DEX (id 43) - Launch limits
        address OSETH_ETH_DEX = getDexAddress(43);
        {
            DexConfig memory DEX_OSETH_ETH = DexConfig({
                dex: OSETH_ETH_DEX,
                tokenA: OSETH_ADDRESS,
                tokenB: ETH_ADDRESS,
                smartCollateral: true,
                smartDebt: false,
                baseWithdrawalLimitInUSD: 14 * ONE_MILLION, // $14M base withdraw, for ~30M max supply shares
                baseBorrowLimitInUSD: 0,
                maxBorrowLimitInUSD: 0
            });
            setDexLimits(DEX_OSETH_ETH);

            DEX_FACTORY.setDexAuth(OSETH_ETH_DEX, TEAM_MULTISIG, false);
        }

        // Vault ID 153: OSETH / USDC (TYPE_1) - Launch limits
        {
            address OSETH_USDC_VAULT = getVaultAddress(153);
            VaultConfig memory VAULT_OSETH_USDC = VaultConfig({
                vault: OSETH_USDC_VAULT,
                vaultType: VAULT_TYPE.TYPE_1,
                supplyToken: OSETH_ADDRESS,
                borrowToken: USDC_ADDRESS,
                baseWithdrawalLimitInUSD: 8 * ONE_MILLION, // $8M
                baseBorrowLimitInUSD: 5 * ONE_MILLION, // $5M
                maxBorrowLimitInUSD: 10 * ONE_MILLION // $10M
            });
            setVaultLimits(VAULT_OSETH_USDC);

            VAULT_FACTORY.setVaultAuth(OSETH_USDC_VAULT, TEAM_MULTISIG, false);
        }

        // Vault ID 154: OSETH / USDT (TYPE_1) - Launch limits
        {
            address OSETH_USDT_VAULT = getVaultAddress(154);
            VaultConfig memory VAULT_OSETH_USDT = VaultConfig({
                vault: OSETH_USDT_VAULT,
                vaultType: VAULT_TYPE.TYPE_1,
                supplyToken: OSETH_ADDRESS,
                borrowToken: USDT_ADDRESS,
                baseWithdrawalLimitInUSD: 8 * ONE_MILLION, // $8M
                baseBorrowLimitInUSD: 5 * ONE_MILLION, // $5M
                maxBorrowLimitInUSD: 10 * ONE_MILLION // $10M
            });
            setVaultLimits(VAULT_OSETH_USDT);

            VAULT_FACTORY.setVaultAuth(OSETH_USDT_VAULT, TEAM_MULTISIG, false);
        }

        // Vault ID 155: OSETH / GHO (TYPE_1) - Launch limits
        {
            address OSETH_GHO_VAULT = getVaultAddress(155);
            VaultConfig memory VAULT_OSETH_GHO = VaultConfig({
                vault: OSETH_GHO_VAULT,
                vaultType: VAULT_TYPE.TYPE_1,
                supplyToken: OSETH_ADDRESS,
                borrowToken: GHO_ADDRESS,
                baseWithdrawalLimitInUSD: 8 * ONE_MILLION, // $8M
                baseBorrowLimitInUSD: 5 * ONE_MILLION, // $5M
                maxBorrowLimitInUSD: 10 * ONE_MILLION // $10M
            });
            setVaultLimits(VAULT_OSETH_GHO);

            VAULT_FACTORY.setVaultAuth(OSETH_GHO_VAULT, TEAM_MULTISIG, false);
        }

        // Vault ID 156: OSETH / USDC-USDT (TYPE_3) - Launch limits
        {
            address OSETH_USDC_USDT_VAULT = getVaultAddress(156);
            address USDC_USDT_DEX = getDexAddress(2);

            {
                VaultConfig memory VAULT_OSETH_USDC_USDT = VaultConfig({
                    vault: OSETH_USDC_USDT_VAULT,
                    vaultType: VAULT_TYPE.TYPE_3,
                    supplyToken: OSETH_ADDRESS,
                    borrowToken: address(0), // Set at DEX level
                    baseWithdrawalLimitInUSD: 8 * ONE_MILLION, // $8M
                    baseBorrowLimitInUSD: 0,
                    maxBorrowLimitInUSD: 0
                });
                setVaultLimits(VAULT_OSETH_USDC_USDT);

                VAULT_FACTORY.setVaultAuth(
                    OSETH_USDC_USDT_VAULT,
                    TEAM_MULTISIG,
                    false
                );
            }

            {
                // Set borrow limits at DEX level for TYPE_3 vault (launch limits)
                DexBorrowProtocolConfigInShares
                    memory config_ = DexBorrowProtocolConfigInShares({
                        dex: USDC_USDT_DEX,
                        protocol: OSETH_USDC_USDT_VAULT,
                        expandPercent: 30 * 1e2, // 30%
                        expandDuration: 6 hours, // 6 hours
                        baseBorrowLimit: 2_500_000 * 1e18, // ~2.5M shares (~$5M)
                        maxBorrowLimit: 5 * ONE_MILLION * 1e18 // ~5M shares (~$10M)
                    });
                setDexBorrowProtocolLimitsInShares(config_);
            }
        }

        // Vault ID 157: OSETH / USDC-USDT concentrated (TYPE_3) - Launch limits
        {
            address OSETH_USDC_USDT_CONC_VAULT = getVaultAddress(157);
            address USDC_USDT_DEX = getDexAddress(34);

            {
                VaultConfig memory VAULT_OSETH_USDC_USDT_CONC = VaultConfig({
                    vault: OSETH_USDC_USDT_CONC_VAULT,
                    vaultType: VAULT_TYPE.TYPE_3,
                    supplyToken: OSETH_ADDRESS,
                    borrowToken: address(0), // Set at DEX level
                    baseWithdrawalLimitInUSD: 8 * ONE_MILLION, // $8M
                    baseBorrowLimitInUSD: 0,
                    maxBorrowLimitInUSD: 0
                });
                setVaultLimits(VAULT_OSETH_USDC_USDT_CONC);

                VAULT_FACTORY.setVaultAuth(
                    OSETH_USDC_USDT_CONC_VAULT,
                    TEAM_MULTISIG,
                    false
                );
            }

            {
                // Set borrow limits at DEX level for TYPE_3 vault (launch limits)
                DexBorrowProtocolConfigInShares
                    memory config_ = DexBorrowProtocolConfigInShares({
                        dex: USDC_USDT_DEX,
                        protocol: OSETH_USDC_USDT_CONC_VAULT,
                        expandPercent: 30 * 1e2, // 30%
                        expandDuration: 6 hours, // 6 hours
                        baseBorrowLimit: 2_500_000 * 1e18, // ~2.5M shares (~$5M)
                        maxBorrowLimit: 5 * ONE_MILLION * 1e18 // ~5M shares (~$10M)
                    });
                setDexBorrowProtocolLimitsInShares(config_);
            }
        }
    }

    /// @notice Action 2: Configure OSETH T2 vault (Vault ID 159) and related DEX settings
    function action2() internal isActionSkippable(2) {
        // ---------------------------------------------------------------------
        // 1) Configure OSETH T2 vault (oseth-eth <> wsteth, vault id 159)
        // ---------------------------------------------------------------------
        address OSETH_ETH__wstETH_VAULT = getVaultAddress(159);

        {
            // 1.a) Set rebalancer to Reserve contract proxy
            IFluidVaultT1(OSETH_ETH__wstETH_VAULT).updateRebalancer(
                address(FLUID_RESERVE)
            );

            // 1.b) Set oracle (nonce 207)
            IFluidVault(OSETH_ETH__wstETH_VAULT).updateOracle(207);

            // 1.c) Update core risk params
            IFluidVaultT2(OSETH_ETH__wstETH_VAULT).updateCoreSettings(
                0, // supplyRate_ (0%)
                100 * 1e2, // borrowRateMagnifier_ (100%)
                94 * 1e2, // collateralFactor_ (94%)
                96 * 1e2, // liquidationThreshold_ (96%)
                97 * 1e2, // liquidationMaxLimit_ (97%)
                5 * 1e2, // withdrawGap_ (5%)
                2 * 1e2, // liquidationPenalty_ (2%)
                0 // borrowFee_ (0%)
            );
        }

        // ---------------------------------------------------------------------
        // 2) ETH-OSETH DEX (id 43) – supply caps and LL supply limits
        // ---------------------------------------------------------------------
        address ETH_OSETH_DEX = getDexAddress(43);

        // 2.a) Max supply shares: 5.7k (~$33M)
        IFluidDex(ETH_OSETH_DEX).updateMaxSupplyShares(5_700 * 1e18);

        // // 2.b) Token LL supply limits via Dex smart collateral:
        // // Base withdrawal: $14M each (OSETH and ETH)
        // {
        //     DexConfig memory DEX_OSETH_ETH = DexConfig({
        //         dex: ETH_OSETH_DEX,
        //         tokenA: OSETH_ADDRESS,
        //         tokenB: ETH_ADDRESS,
        //         smartCollateral: true,
        //         smartDebt: false,
        //         baseWithdrawalLimitInUSD: 14 * ONE_MILLION,
        //         baseBorrowLimitInUSD: 0,
        //         maxBorrowLimitInUSD: 0
        //     });
        //     setDexLimits(DEX_OSETH_ETH);
        // }

        // 2.c) Set DEX-level supply config for T2 vault
        {
            IFluidAdminDex.UserSupplyConfig[]
                memory configs_ = new IFluidAdminDex.UserSupplyConfig[](1);

            // Base withdraw: $8M for OSETH T2 vault on ETH-OSETH DEX
            configs_[0] = IFluidAdminDex.UserSupplyConfig({
                user: OSETH_ETH__wstETH_VAULT,
                expandPercent: 35 * 1e2, // 35%
                expandDuration: 6 hours, // 6 hours
                baseWithdrawalLimit: 1_400 * 1e18 // 1200 shares = ~8M USD
            });

            IFluidDex(ETH_OSETH_DEX).updateUserSupplyConfigs(configs_);
        }

        // 2.d) Set LL borrow config for T2 vault
        {
            VaultConfig memory VAULT_OSETH_USDC = VaultConfig({
                vault: OSETH_ETH__wstETH_VAULT,
                vaultType: VAULT_TYPE.TYPE_2,
                supplyToken: address(0), // Set at DEX level
                borrowToken: wstETH_ADDRESS,
                baseWithdrawalLimitInUSD: 0,
                baseBorrowLimitInUSD: 8 * ONE_MILLION, // $8M
                maxBorrowLimitInUSD: 30 * ONE_MILLION // $30M
            });
            setVaultLimits(VAULT_OSETH_USDC);
        }
    }

    /// @notice Action 3: Deprecate T4 vault (OSETH-ETH <> wstETH-ETH, VAULT ID 158)
    function action3() internal isActionSkippable(3) {
        // VAULT ID 158: OSETH-ETH <> wstETH-ETH (TYPE_4)
        address OSETH_ETH__wstETH_ETH_VAULT = getVaultAddress(158);

        // pause supply side
        {
            address ETH_OSETH_DEX = getDexAddress(43);

            // max restrict limits
            setSupplyProtocolLimitsPausedDex(
                ETH_OSETH_DEX,
                OSETH_ETH__wstETH_ETH_VAULT
            );

            // Pause vault operations at DEX level
            IFluidDex(ETH_OSETH_DEX).pauseUser(
                OSETH_ETH__wstETH_ETH_VAULT,
                true, // pause supply side
                false // can't pause supply, never given allowance
            );
        }

        // pause borrow side
        {
            address WSTETH_ETH_DEX = getDexAddress(1);

            // max restrict limits
            setBorrowProtocolLimitsPausedDex(
                WSTETH_ETH_DEX,
                OSETH_ETH__wstETH_ETH_VAULT
            );

            // Pause vault operations at DEX level
            IFluidDex(WSTETH_ETH_DEX).pauseUser(
                OSETH_ETH__wstETH_ETH_VAULT,
                false, // can't pause supply, never given allowance
                true // pause borrow side
            );
        }
    }

    /**
     * |
     * |     Payload Actions End Here      |
     * |__________________________________
     */

    // Token Prices Constants (same as other IGP files)
    uint256 public constant ETH_USD_PRICE = 2_900 * 1e2;
    uint256 public constant wstETH_USD_PRICE = 3_575 * 1e2;
    uint256 public constant weETH_USD_PRICE = 3_050 * 1e2;
    uint256 public constant rsETH_USD_PRICE = 2_980 * 1e2;
    uint256 public constant weETHs_USD_PRICE = 2_920 * 1e2;
    uint256 public constant mETH_USD_PRICE = 3_040 * 1e2;
    uint256 public constant ezETH_USD_PRICE = 3_000 * 1e2;
    uint256 public constant OSETH_USD_PRICE = 3_060 * 1e2;

    uint256 public constant BTC_USD_PRICE = 86_000 * 1e2;

    uint256 public constant STABLE_USD_PRICE = 1 * 1e2;
    uint256 public constant sUSDe_USD_PRICE = 1.20 * 1e2;
    uint256 public constant sUSDs_USD_PRICE = 1.08 * 1e2;
    uint256 public constant syrupUSDT_USD_PRICE = 1.10 * 1e2;
    uint256 public constant syrupUSDC_USD_PRICE = 1.14 * 1e2;

    uint256 public constant FLUID_USD_PRICE = 3.32 * 1e2;

    uint256 public constant RLP_USD_PRICE = 1.26 * 1e2;
    uint256 public constant wstUSR_USD_PRICE = 1.12 * 1e2;
    uint256 public constant XAUT_USD_PRICE = 4_040 * 1e2;
    uint256 public constant PAXG_USD_PRICE = 4_050 * 1e2;
    uint256 public constant JRUSDE_USD_PRICE = 1.00 * 1e2;
    uint256 public constant SRUSDE_USD_PRICE = 1.00 * 1e2;

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
        } else if (token == OSETH_ADDRESS) {
            usdPrice = OSETH_USD_PRICE;
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
        } else if (token == syrupUSDT_ADDRESS) {
            usdPrice = syrupUSDT_USD_PRICE;
            decimals = 6;
        } else if (token == syrupUSDC_ADDRESS) {
            usdPrice = syrupUSDC_USD_PRICE;
            decimals = 6;
        } else if (token == JRUSDE_ADDRESS) {
            usdPrice = JRUSDE_USD_PRICE;
            decimals = 18;
        } else if (token == SRUSDE_ADDRESS) {
            usdPrice = SRUSDE_USD_PRICE;
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
