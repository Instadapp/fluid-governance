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

import {IFluidVault, IFluidVaultT1} from "../common/interfaces/IFluidVault.sol";

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

contract PayloadIGP113 is PayloadIGPMain {
    uint256 public constant PROPOSAL_ID = 113;

    function execute() public virtual override {
        super.execute();

        // Action 1: Update WEETH fee handler on DexFactory
        action1();

        // Action 2: LL upgrades (AdminModule updates)
        action2();

        // Action 3: Set dust limits for OSETH protocols
        action3();

        // Action 4: Set dexV2 dust limits (to be configured)
        action4();

        // Action 5: Increase borrow caps on LBTC-CBBTC / WBTC
        action5();
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

    /// @notice Action 1: Update WEETH fee handler on DexFactory
    function action1() internal isActionSkippable(1) {
        address WEETH_DEX = getDexAddress(9);

        // Old fee handler address
        address oldFeeHandler = 0x8eaE5474C3DFE2c5F07E7423019E443258A73100;

        // New fee handler address
        address newFeeHandler = 0xD43d85f4F4eEDdA3ed3BbE2Ca7351eE32b8bB44a;

        // Remove old fee handler as auth
        DEX_FACTORY.setDexAuth(WEETH_DEX, oldFeeHandler, false);

        // Add new fee handler as auth
        DEX_FACTORY.setDexAuth(WEETH_DEX, newFeeHandler, true);
    }

    /// @notice Action 2: Upgrade LL AdminModule and UserModule on Liquidity infiniteProxy
    /// Adding decay limits and other upgrades, same as already rolled out on Polygon, Base, Arbitrum
    function action2() internal isActionSkippable(2) {
        // Update UserModule
        {
            address oldImplementation_ = 0x6967e68F7f9b3921181f27E66Aa9c3ac7e13dBc0;
            address newImplementation_ = 0xF1167F851509CA5Ef56f8521fB1EE07e4e5C92C8;

            bytes4[] memory sigs_ = IInfiniteProxy(address(LIQUIDITY))
                .getImplementationSigs(oldImplementation_);

            IInfiniteProxy(address(LIQUIDITY)).removeImplementation(
                oldImplementation_
            );

            IInfiniteProxy(address(LIQUIDITY)).addImplementation(
                newImplementation_,
                sigs_
            );
        }

        // Update AdminModule
        {
            address oldImplementation_ = 0xC3800E7527145837e525cfA6AD96B6B5DaE01586;
            address newImplementation_ = 0x53EFFA0e612d88f39Ab32eb5274F2fae478d261C;

            bytes4[] memory sigs_ = IInfiniteProxy(address(LIQUIDITY))
                .getImplementationSigs(oldImplementation_);

            IInfiniteProxy(address(LIQUIDITY)).removeImplementation(
                oldImplementation_
            );

            IInfiniteProxy(address(LIQUIDITY)).addImplementation(
                newImplementation_,
                sigs_
            );
        }
    }

    /// @notice Action 3: Set dust limits for OSETH protocols
    /// OSETH / USDC, OSETH / USDT, OSETH / GHO, OSETH / USDC-USDT, OSETH / USDC-USDT concentrated
    /// oseth-eth <> wsteth-eth (OSETH-ETH dex id 43)
    /// Protocols yet to be deployed, starting with vault id 153
    function action3() internal isActionSkippable(3) {
        // OSETH-ETH DEX (id 43) - Dust limits
        address OSETH_ETH_DEX = getDexAddress(43);
        {
            DexConfig memory DEX_OSETH_ETH = DexConfig({
                dex: OSETH_ETH_DEX,
                tokenA: OSETH_ADDRESS,
                tokenB: ETH_ADDRESS,
                smartCollateral: true,
                smartDebt: false,
                baseWithdrawalLimitInUSD: 10_000, // $10k
                baseBorrowLimitInUSD: 0,
                maxBorrowLimitInUSD: 0
            });
            setDexLimits(DEX_OSETH_ETH);
            DEX_FACTORY.setDexAuth(OSETH_ETH_DEX, TEAM_MULTISIG, true);
        }

        // Vault ID 153: OSETH / USDC (TYPE_1) - Dust limits
        {
            address OSETH_USDC_VAULT = getVaultAddress(153);
            VaultConfig memory VAULT_OSETH_USDC = VaultConfig({
                vault: OSETH_USDC_VAULT,
                vaultType: VAULT_TYPE.TYPE_1,
                supplyToken: OSETH_ADDRESS,
                borrowToken: USDC_ADDRESS,
                baseWithdrawalLimitInUSD: 7_000, // $7k
                baseBorrowLimitInUSD: 7_000, // $7k
                maxBorrowLimitInUSD: 9_000 // $9k
            });
            setVaultLimits(VAULT_OSETH_USDC);
            VAULT_FACTORY.setVaultAuth(OSETH_USDC_VAULT, TEAM_MULTISIG, true);
        }

        // Vault ID 154: OSETH / USDT (TYPE_1) - Dust limits
        {
            address OSETH_USDT_VAULT = getVaultAddress(154);
            VaultConfig memory VAULT_OSETH_USDT = VaultConfig({
                vault: OSETH_USDT_VAULT,
                vaultType: VAULT_TYPE.TYPE_1,
                supplyToken: OSETH_ADDRESS,
                borrowToken: USDT_ADDRESS,
                baseWithdrawalLimitInUSD: 7_000, // $7k
                baseBorrowLimitInUSD: 7_000, // $7k
                maxBorrowLimitInUSD: 9_000 // $9k
            });
            setVaultLimits(VAULT_OSETH_USDT);
            VAULT_FACTORY.setVaultAuth(OSETH_USDT_VAULT, TEAM_MULTISIG, true);
        }

        // Vault ID 155: OSETH / GHO (TYPE_1) - Dust limits
        {
            address OSETH_GHO_VAULT = getVaultAddress(155);
            VaultConfig memory VAULT_OSETH_GHO = VaultConfig({
                vault: OSETH_GHO_VAULT,
                vaultType: VAULT_TYPE.TYPE_1,
                supplyToken: OSETH_ADDRESS,
                borrowToken: GHO_ADDRESS,
                baseWithdrawalLimitInUSD: 7_000, // $7k
                baseBorrowLimitInUSD: 7_000, // $7k
                maxBorrowLimitInUSD: 9_000 // $9k
            });
            setVaultLimits(VAULT_OSETH_GHO);
            VAULT_FACTORY.setVaultAuth(OSETH_GHO_VAULT, TEAM_MULTISIG, true);
        }

        // Vault ID 156: OSETH / USDC-USDT (TYPE_3) - Dust limits
        {
            address OSETH_USDC_USDT_VAULT = getVaultAddress(156);
            address USDC_USDT_DEX = getDexAddress(2);

            {
                VaultConfig memory VAULT_OSETH_USDC_USDT = VaultConfig({
                    vault: OSETH_USDC_USDT_VAULT,
                    vaultType: VAULT_TYPE.TYPE_3,
                    supplyToken: OSETH_ADDRESS,
                    borrowToken: address(0), // Set at DEX level
                    baseWithdrawalLimitInUSD: 7_000, // $7k
                    baseBorrowLimitInUSD: 0,
                    maxBorrowLimitInUSD: 0
                });
                setVaultLimits(VAULT_OSETH_USDC_USDT);
                VAULT_FACTORY.setVaultAuth(
                    OSETH_USDC_USDT_VAULT,
                    TEAM_MULTISIG,
                    true
                );
            }

            {
                // Set borrow limits at DEX level for TYPE_3 vault
                DexBorrowProtocolConfigInShares
                    memory config_ = DexBorrowProtocolConfigInShares({
                        dex: USDC_USDT_DEX,
                        protocol: OSETH_USDC_USDT_VAULT,
                        expandPercent: 30 * 1e2, // 30%
                        expandDuration: 6 hours, // 6 hours
                        baseBorrowLimit: 3500 * 1e18, // 3500 shares or $7k
                        maxBorrowLimit: 4500 * 1e18 // 4500 shares or $9k
                    });
                setDexBorrowProtocolLimitsInShares(config_);
            }
        }

        // Vault ID 157: OSETH / USDC-USDT concentrated (TYPE_3) - Dust limits
        {
            address OSETH_USDC_USDT_CONC_VAULT = getVaultAddress(157);
            address USDC_USDT_DEX = getDexAddress(34);

            {
                VaultConfig memory VAULT_OSETH_USDC_USDT_CONC = VaultConfig({
                    vault: OSETH_USDC_USDT_CONC_VAULT,
                    vaultType: VAULT_TYPE.TYPE_3,
                    supplyToken: OSETH_ADDRESS,
                    borrowToken: address(0), // Set at DEX level
                    baseWithdrawalLimitInUSD: 7_000, // $7k
                    baseBorrowLimitInUSD: 0,
                    maxBorrowLimitInUSD: 0
                });
                setVaultLimits(VAULT_OSETH_USDC_USDT_CONC);
                VAULT_FACTORY.setVaultAuth(
                    OSETH_USDC_USDT_CONC_VAULT,
                    TEAM_MULTISIG,
                    true
                );
            }

            {
                // Set borrow limits at DEX level for TYPE_3 vault
                DexBorrowProtocolConfigInShares
                    memory config_ = DexBorrowProtocolConfigInShares({
                        dex: USDC_USDT_DEX,
                        protocol: OSETH_USDC_USDT_CONC_VAULT,
                        expandPercent: 30 * 1e2, // 30%
                        expandDuration: 6 hours, // 6 hours
                        baseBorrowLimit: 3500 * 1e18, // 3500 shares or $7k
                        maxBorrowLimit: 4500 * 1e18 // 4500 shares or $9k
                    });
                setDexBorrowProtocolLimitsInShares(config_);
            }
        }

        // Vault ID 158: oseth-eth <> wsteth-eth (TYPE_4) - Set borrow dust limits for WSTETH-ETH DEX (id 1)
        {
            address OSETH_ETH__wstETH_ETH_VAULT = getVaultAddress(158);
            address WSTETH_ETH_DEX = getDexAddress(1);

            // For TYPE_4, borrow limits set via DexBorrowProtocolConfigInShares
            DexBorrowProtocolConfigInShares
                memory config_ = DexBorrowProtocolConfigInShares({
                    dex: WSTETH_ETH_DEX,
                    protocol: OSETH_ETH__wstETH_ETH_VAULT,
                    expandPercent: 30 * 1e2, // 30%
                    expandDuration: 6 hours, // 6 hours
                    baseBorrowLimit: 1 * 1e18, // 1 share or $6k
                    maxBorrowLimit: 1.5 * 1e18 // 1.5 shares or $9k
                });
            setDexBorrowProtocolLimitsInShares(config_);
        }
    }

    /// @notice Action 4: Set dexV2 dust limits for DEX v2 and Money Market proxies
    function action4() internal isActionSkippable(4) {
        // ---------------------------------------------------------------------
        // Borrow (debt) limits: ETH, USDC, USDT -> $5k base, $10k max
        // ---------------------------------------------------------------------
        {
            address[3] memory debtTokens = [
                ETH_ADDRESS,
                USDC_ADDRESS,
                USDT_ADDRESS
            ];

            // Configure for both proxies
            address[2] memory debtProtocols = [
                DEX_V2_PROXY,
                MONEY_MARKET_PROXY
            ];

            for (uint256 i = 0; i < debtProtocols.length; i++) {
                for (uint256 j = 0; j < debtTokens.length; j++) {
                    BorrowProtocolConfig
                        memory borrowConfig = BorrowProtocolConfig({
                            protocol: debtProtocols[i],
                            borrowToken: debtTokens[j],
                            expandPercent: 30 * 1e2, // 30%
                            expandDuration: 6 hours, // 6 hours
                            baseBorrowLimitInUSD: 5_000, // $5k
                            maxBorrowLimitInUSD: 10_000 // $10k
                        });

                    setBorrowProtocolLimits(borrowConfig);
                }
            }
        }

        // ---------------------------------------------------------------------
        // Supply (collateral) limits: ETH, USDC, USDT, cbBTC, WBTC -> $10k base
        // ---------------------------------------------------------------------
        {
            address[5] memory collateralTokens = [
                ETH_ADDRESS,
                USDC_ADDRESS,
                USDT_ADDRESS,
                cbBTC_ADDRESS,
                WBTC_ADDRESS
            ];

            // Configure for both proxies
            address[2] memory collateralProtocols = [
                DEX_V2_PROXY,
                MONEY_MARKET_PROXY
            ];

            for (uint256 i = 0; i < collateralProtocols.length; i++) {
                for (uint256 j = 0; j < collateralTokens.length; j++) {
                    SupplyProtocolConfig
                        memory supplyConfig = SupplyProtocolConfig({
                            protocol: collateralProtocols[i],
                            supplyToken: collateralTokens[j],
                            expandPercent: 50 * 1e2, // 50%
                            expandDuration: 6 hours, // 6 hours
                            baseWithdrawalLimitInUSD: 10_000 // $10k
                        });

                    setSupplyProtocolLimits(supplyConfig);
                }
            }
        }
    }

    /// @notice Action 5: Increase borrow caps on LBTC-CBBTC / WBTC
    function action5() internal isActionSkippable(5) {
        // LBTC-CBBTC / WBTC vault (vault id 97)
        address LBTC_cbBTC__WBTC_VAULT = getVaultAddress(97);

        // Increase borrow limits
        VaultConfig memory VAULT_LBTC_cbBTC__WBTC = VaultConfig({
            vault: LBTC_cbBTC__WBTC_VAULT,
            vaultType: VAULT_TYPE.TYPE_2,
            supplyToken: address(0), // TYPE_2 vault
            borrowToken: WBTC_ADDRESS,
            baseWithdrawalLimitInUSD: 0, // Set at DEX level
            baseBorrowLimitInUSD: 5_000_000,
            maxBorrowLimitInUSD: 5_000_000
        });

        setVaultLimits(VAULT_LBTC_cbBTC__WBTC);
    }

    /**
     * |
     * |     Payload Actions End Here      |
     * |__________________________________
     */

    // Token Prices Constants (same as other IGP files)
    uint256 public constant ETH_USD_PRICE = 2_780 * 1e2;
    uint256 public constant wstETH_USD_PRICE = 3_440 * 1e2;
    uint256 public constant weETH_USD_PRICE = 3_050 * 1e2;
    uint256 public constant rsETH_USD_PRICE = 2_980 * 1e2;
    uint256 public constant weETHs_USD_PRICE = 2_920 * 1e2;
    uint256 public constant mETH_USD_PRICE = 3_040 * 1e2;
    uint256 public constant ezETH_USD_PRICE = 3_000 * 1e2;
    uint256 public constant OSETH_USD_PRICE = 2_980 * 1e2;

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
