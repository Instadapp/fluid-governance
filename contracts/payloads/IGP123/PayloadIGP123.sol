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
import {IDexV2} from "../common/interfaces/IDexV2.sol";

/// @notice IGP123: Launch limits for REUSD protocols, all actions from IGP-117 (with updated DEX V2), rollback module on LL, and DexFactory cleanup
contract PayloadIGP123 is PayloadIGPMain {
    uint256 public constant PROPOSAL_ID = 123;

    function execute() public virtual override {
        super.execute();

        // Action 1: Launch limits for REUSD vaults (160-164) + remove Team MS auth
        action1();

        // Action 2: Launch limits for REUSD-USDT DEX (44) + remove Team MS auth
        action2();

        // Action 3: Restrict limits and pause wstUSR-USDT DEX and remove MS auth (from IGP117)
        action3();

        // Action 4: Restrict limits and pause vaults 142, 113, 135 (from IGP117)
        action4();

        // Action 5: Remove MS auth from deprecated dexes 5, 6, 7, 8, 10, 34 (from IGP117)
        action5();

        // Action 6: Update range percents for syrupUSDC-USDC and syrupUSDT-USDT DEXes (from IGP117)
        action6();

        // Action 7: DEX V2 soft launch - re-send limits, auth, and updated admin implementations
        action7();

        // Action 8: Roll out rollbackModule on Liquidity Layer
        action8();

        // Action 9: Cleanup - disable old DexDeploymentLogic on DexFactory
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

    /// @notice Action 1: Launch limits for REUSD T1 vaults (160, 161, 162), T3 vault (163), T2 vault (164) + remove Team MS auth
    function action1() internal isActionSkippable(1) {
        // Vault 160: REUSD / USDC (TYPE_1)
        {
            address REUSD_USDC_VAULT = getVaultAddress(160);
            VaultConfig memory VAULT_REUSD_USDC = VaultConfig({
                vault: REUSD_USDC_VAULT,
                vaultType: VAULT_TYPE.TYPE_1,
                supplyToken: REUSD_ADDRESS,
                borrowToken: USDC_ADDRESS,
                baseWithdrawalLimitInUSD: 8_000_000, // $8M
                baseBorrowLimitInUSD: 8_000_000, // $8M
                maxBorrowLimitInUSD: 20_000_000 // $20M
            });
            setVaultLimits(VAULT_REUSD_USDC);
            VAULT_FACTORY.setVaultAuth(REUSD_USDC_VAULT, TEAM_MULTISIG, false);
        }

        // Vault 161: REUSD / USDT (TYPE_1)
        {
            address REUSD_USDT_VAULT = getVaultAddress(161);
            VaultConfig memory VAULT_REUSD_USDT = VaultConfig({
                vault: REUSD_USDT_VAULT,
                vaultType: VAULT_TYPE.TYPE_1,
                supplyToken: REUSD_ADDRESS,
                borrowToken: USDT_ADDRESS,
                baseWithdrawalLimitInUSD: 8_000_000, // $8M
                baseBorrowLimitInUSD: 8_000_000, // $8M
                maxBorrowLimitInUSD: 20_000_000 // $20M
            });
            setVaultLimits(VAULT_REUSD_USDT);
            VAULT_FACTORY.setVaultAuth(REUSD_USDT_VAULT, TEAM_MULTISIG, false);
        }

        // Vault 162: REUSD / GHO (TYPE_1)
        {
            address REUSD_GHO_VAULT = getVaultAddress(162);
            VaultConfig memory VAULT_REUSD_GHO = VaultConfig({
                vault: REUSD_GHO_VAULT,
                vaultType: VAULT_TYPE.TYPE_1,
                supplyToken: REUSD_ADDRESS,
                borrowToken: GHO_ADDRESS,
                baseWithdrawalLimitInUSD: 8_000_000, // $8M
                baseBorrowLimitInUSD: 8_000_000, // $8M
                maxBorrowLimitInUSD: 20_000_000 // $20M
            });
            setVaultLimits(VAULT_REUSD_GHO);
            VAULT_FACTORY.setVaultAuth(REUSD_GHO_VAULT, TEAM_MULTISIG, false);
        }

        // Vault 163: REUSD / USDC-USDT (TYPE_3) - borrow limits at USDC-USDT DEX
        {
            address REUSD_USDC_USDT_VAULT = getVaultAddress(163);
            address USDC_USDT_DEX = getDexAddress(2);

            VaultConfig memory VAULT_REUSD_USDC_USDT = VaultConfig({
                vault: REUSD_USDC_USDT_VAULT,
                vaultType: VAULT_TYPE.TYPE_3,
                supplyToken: REUSD_ADDRESS,
                borrowToken: address(0),
                baseWithdrawalLimitInUSD: 8_000_000, // $8M
                baseBorrowLimitInUSD: 0,
                maxBorrowLimitInUSD: 0
            });
            setVaultLimits(VAULT_REUSD_USDC_USDT);
            VAULT_FACTORY.setVaultAuth(
                REUSD_USDC_USDT_VAULT,
                TEAM_MULTISIG,
                false
            );

            DexBorrowProtocolConfigInShares
                memory config_ = DexBorrowProtocolConfigInShares({
                    dex: USDC_USDT_DEX,
                    protocol: REUSD_USDC_USDT_VAULT,
                    expandPercent: 30 * 1e2, // 30%
                    expandDuration: 6 hours,
                    baseBorrowLimit: 4_000_000 * 1e18, // ~4M shares (~$8M)
                    maxBorrowLimit: 10_000_000 * 1e18 // ~10M shares (~$20M)
                });
            setDexBorrowProtocolLimitsInShares(config_);
        }

        // Vault 164: REUSD-USDT / USDT (TYPE_2) - USDT debt limits
        {
            address REUSD_USDT__USDT_VAULT = getVaultAddress(164);
            VaultConfig memory VAULT_REUSD_USDT__USDT = VaultConfig({
                vault: REUSD_USDT__USDT_VAULT,
                vaultType: VAULT_TYPE.TYPE_2,
                supplyToken: address(0),
                borrowToken: USDT_ADDRESS,
                baseWithdrawalLimitInUSD: 0,
                baseBorrowLimitInUSD: 5_000_000, // $5M
                maxBorrowLimitInUSD: 10_000_000 // $10M
            });
            setVaultLimits(VAULT_REUSD_USDT__USDT);
            VAULT_FACTORY.setVaultAuth(
                REUSD_USDT__USDT_VAULT,
                TEAM_MULTISIG,
                false
            );
        }
    }

    /// @notice Action 2: Launch limits for REUSD-USDT DEX (Pool 44) + remove Team MS auth
    function action2() internal isActionSkippable(2) {
        address REUSD_USDT_DEX = getDexAddress(44);

        DexConfig memory DEX_REUSD_USDT = DexConfig({
            dex: REUSD_USDT_DEX,
            tokenA: REUSD_ADDRESS,
            tokenB: USDT_ADDRESS,
            smartCollateral: true,
            smartDebt: false,
            baseWithdrawalLimitInUSD: 5_000_000, // $5M per token
            baseBorrowLimitInUSD: 0,
            maxBorrowLimitInUSD: 0
        });
        setDexLimits(DEX_REUSD_USDT);

        DEX_FACTORY.setDexAuth(REUSD_USDT_DEX, TEAM_MULTISIG, false);
    }

    /// @notice Action 3: Restrict limits and pause wstUSR-USDT DEX (Pool 29) and remove MS auth (from IGP117)
    function action3() internal isActionSkippable(3) {
        address wstUSR_USDT_DEX = getDexAddress(29);

        IFluidDex(wstUSR_USDT_DEX).updateMaxSupplyShares(10);

        setSupplyProtocolLimitsPaused(wstUSR_USDT_DEX, wstUSR_ADDRESS);
        setSupplyProtocolLimitsPaused(wstUSR_USDT_DEX, USDT_ADDRESS);

        IFluidDex(wstUSR_USDT_DEX).pauseSwapAndArbitrage();

        address[] memory supplyTokens = new address[](2);
        supplyTokens[0] = wstUSR_ADDRESS;
        supplyTokens[1] = USDT_ADDRESS;

        address[] memory borrowTokens = new address[](0);

        LIQUIDITY.pauseUser(wstUSR_USDT_DEX, supplyTokens, borrowTokens);

        DEX_FACTORY.setDexAuth(wstUSR_USDT_DEX, TEAM_MULTISIG, false);
    }

    /// @notice Action 4: Restrict limits and pause vaults 142, 113, 135 (from IGP117)
    function action4() internal isActionSkippable(4) {
        {
            // Vault 142: wstUSR/USDTb (TYPE 1)
            address wstUSR_USDTb_VAULT = getVaultAddress(142);

            setSupplyProtocolLimitsPaused(wstUSR_USDTb_VAULT, wstUSR_ADDRESS);
            setBorrowProtocolLimitsPaused(wstUSR_USDTb_VAULT, USDTb_ADDRESS);

            address[] memory supplyTokens = new address[](1);
            supplyTokens[0] = wstUSR_ADDRESS;

            address[] memory borrowTokens = new address[](1);
            borrowTokens[0] = USDTb_ADDRESS;

            LIQUIDITY.pauseUser(wstUSR_USDTb_VAULT, supplyTokens, borrowTokens);
        }

        {
            // Vault 113: wstUSR-USDT<>USDT (TYPE 2)
            address wstUSR_USDT__USDT_VAULT = getVaultAddress(113);
            address wstUSR_USDT_DEX = getDexAddress(29);

            setSupplyProtocolLimitsPausedDex(
                wstUSR_USDT_DEX,
                wstUSR_USDT__USDT_VAULT
            );

            IFluidDex(wstUSR_USDT_DEX).pauseUser(
                wstUSR_USDT__USDT_VAULT,
                true,
                false
            );

            setBorrowProtocolLimitsPaused(
                wstUSR_USDT__USDT_VAULT,
                USDT_ADDRESS
            );

            address[] memory supplyTokens = new address[](0);

            address[] memory borrowTokens = new address[](1);
            borrowTokens[0] = USDT_ADDRESS;

            LIQUIDITY.pauseUser(
                wstUSR_USDT__USDT_VAULT,
                supplyTokens,
                borrowTokens
            );

            VAULT_FACTORY.setVaultAuth(
                wstUSR_USDT__USDT_VAULT,
                TEAM_MULTISIG,
                false
            );
        }

        {
            // Vault 135: wstUSR-USDC<>USDC-USDT concentrated (TYPE 3)
            address wstUSR_USDC__USDC_USDT_CONCENTRATED_VAULT = getVaultAddress(
                135
            );
            address wstUSR_USDC_DEX = getDexAddress(27);
            address USDC_USDT_CONCENTRATED_DEX = getDexAddress(34);

            setSupplyProtocolLimitsPausedDex(
                wstUSR_USDC_DEX,
                wstUSR_USDC__USDC_USDT_CONCENTRATED_VAULT
            );

            IFluidDex(wstUSR_USDC_DEX).pauseUser(
                wstUSR_USDC__USDC_USDT_CONCENTRATED_VAULT,
                true,
                false
            );

            setBorrowProtocolLimitsPausedDex(
                USDC_USDT_CONCENTRATED_DEX,
                wstUSR_USDC__USDC_USDT_CONCENTRATED_VAULT
            );

            IFluidDex(USDC_USDT_CONCENTRATED_DEX).pauseUser(
                wstUSR_USDC__USDC_USDT_CONCENTRATED_VAULT,
                false,
                true
            );
        }
    }

    /// @notice Action 5: Remove MS auth from deprecated dexes 5, 6, 7, 8, 10, 34 (from IGP117)
    function action5() internal isActionSkippable(5) {
        DEX_FACTORY.setDexAuth(getDexAddress(5), TEAM_MULTISIG, false);
        DEX_FACTORY.setDexAuth(getDexAddress(6), TEAM_MULTISIG, false);
        DEX_FACTORY.setDexAuth(getDexAddress(7), TEAM_MULTISIG, false);
        DEX_FACTORY.setDexAuth(getDexAddress(8), TEAM_MULTISIG, false);
        DEX_FACTORY.setDexAuth(getDexAddress(10), TEAM_MULTISIG, false);
        DEX_FACTORY.setDexAuth(getDexAddress(34), TEAM_MULTISIG, false);
    }

    /// @notice Action 6: Update range percents for syrupUSDC-USDC and syrupUSDT-USDT DEXes (from IGP117)
    function action6() internal isActionSkippable(6) {
        {
            address syrupUSDC_USDC_DEX = getDexAddress(39);
            IFluidDex(syrupUSDC_USDC_DEX).updateRangePercents(
                0.0001 * 1e4, // upper range: 0.0001%
                0.4 * 1e4, // lower range: 0.4%
                4 days
            );
        }

        {
            address syrupUSDT_USDT_DEX = getDexAddress(40);
            IFluidDex(syrupUSDT_USDT_DEX).updateRangePercents(
                0.0001 * 1e4, // upper range: 0.0001%
                0.4 * 1e4, // lower range: 0.4%
                4 days
            );
        }
    }

    /// @notice Action 7: DEX V2 soft launch - re-send limits ($50k MM, $75k DEX), auth, and updated admin implementations
    function action7() internal isActionSkippable(7) {
        address[5] memory tokens = [
            ETH_ADDRESS,
            USDC_ADDRESS,
            USDT_ADDRESS,
            cbBTC_ADDRESS,
            WBTC_ADDRESS
        ];

        {
            for (uint256 i = 0; i < tokens.length; i++) {
                BorrowProtocolConfig
                    memory borrowConfig = BorrowProtocolConfig({
                        protocol: MONEY_MARKET_PROXY,
                        borrowToken: tokens[i],
                        expandPercent: 50 * 1e2, // 50%
                        expandDuration: 6 hours,
                        baseBorrowLimitInUSD: 50_000, // $50k
                        maxBorrowLimitInUSD: 50_000 // $50k
                    });
                setBorrowProtocolLimits(borrowConfig);

                SupplyProtocolConfig
                    memory supplyConfig = SupplyProtocolConfig({
                        protocol: MONEY_MARKET_PROXY,
                        supplyToken: tokens[i],
                        expandPercent: 50 * 1e2, // 50%
                        expandDuration: 6 hours,
                        baseWithdrawalLimitInUSD: 50_000 // $50k
                    });
                setSupplyProtocolLimits(supplyConfig);
            }
        }

        {
            for (uint256 i = 0; i < tokens.length; i++) {
                BorrowProtocolConfig
                    memory borrowConfig = BorrowProtocolConfig({
                        protocol: DEX_V2_PROXY,
                        borrowToken: tokens[i],
                        expandPercent: 50 * 1e2, // 50%
                        expandDuration: 6 hours,
                        baseBorrowLimitInUSD: 75_000, // $75k
                        maxBorrowLimitInUSD: 75_000 // $75k
                    });
                setBorrowProtocolLimits(borrowConfig);

                SupplyProtocolConfig
                    memory supplyConfig = SupplyProtocolConfig({
                        protocol: DEX_V2_PROXY,
                        supplyToken: tokens[i],
                        expandPercent: 50 * 1e2, // 50%
                        expandDuration: 6 hours,
                        baseWithdrawalLimitInUSD: 75_000 // $75k
                    });
                setSupplyProtocolLimits(supplyConfig);
            }
        }

        {
            IDexV2(DEX_V2_PROXY).updateAuth(TEAM_MULTISIG, true);
            IDexV2(MONEY_MARKET_PROXY).updateAuth(TEAM_MULTISIG, true);
        }

        {
            address D3_ADMIN_IMPLEMENTATION = 0x48956a66F1d7Df6356b2C9364ef786fD7aCACCd9;
            address D4_ADMIN_IMPLEMENTATION = 0x944E4C51fCE91587f89352098Fe3C9E341fE1E65;

            IDexV2(DEX_V2_PROXY).updateDexTypeToAdminImplementation(
                3,
                1,
                D3_ADMIN_IMPLEMENTATION
            );

            IDexV2(DEX_V2_PROXY).updateDexTypeToAdminImplementation(
                4,
                1,
                D4_ADMIN_IMPLEMENTATION
            );
        }
    }

    /// @notice Action 8: Roll out rollbackModule on Liquidity Layer (audited by Statemind)
    function action8() internal isActionSkippable(8) {
        address ROLLBACK_MODULE = 0x463874c5A102ceEa919D63f748a433304D1bd1c0;

        bytes4[] memory sigs_ = new bytes4[](9);
        sigs_[0] = 0x3ff8b31d; // registerRollbackImplementation(address,address)
        sigs_[1] = 0x47e870e6; // rollbackDummyImplementation()
        sigs_[2] = 0x4cc44703; // cleanupExpiredRollbackImplementation(address)
        sigs_[3] = 0x52d3667c; // getRollbackForImplementation(address)
        sigs_[4] = 0x553fea25; // ROLLBACK_PERIOD()
        sigs_[5] = 0x981c829f; // registerRollbackDummyImplementation()
        sigs_[6] = 0xb788f3a1; // TEAM_MULTISIG()
        sigs_[7] = 0xde465d79; // rollbackImplementation(address,address)
        sigs_[8] = 0xe7934bb5; // getRollbackDummyImplementation()

        IInfiniteProxy(address(LIQUIDITY)).addImplementation(
            ROLLBACK_MODULE,
            sigs_
        );
    }

    /// @notice Action 9: Cleanup - disable old DexT1DeploymentLogic on DexFactory
    function action9() internal isActionSkippable(9) {
        DEX_FACTORY.setDexDeploymentLogic(
            0x7db5101f12555bD7Ef11B89e4928061B7C567D27,
            false
        );
    }

    /**
     * |
     * |     Payload Actions End Here      |
     * |__________________________________
     */

    // Token Prices Constants
    uint256 public constant ETH_USD_PRICE = 2_000 * 1e2;
    uint256 public constant wstETH_USD_PRICE = 3_575 * 1e2;
    uint256 public constant weETH_USD_PRICE = 3_050 * 1e2;
    uint256 public constant rsETH_USD_PRICE = 2_980 * 1e2;
    uint256 public constant weETHs_USD_PRICE = 2_920 * 1e2;
    uint256 public constant mETH_USD_PRICE = 3_040 * 1e2;
    uint256 public constant ezETH_USD_PRICE = 3_000 * 1e2;
    uint256 public constant OSETH_USD_PRICE = 3_060 * 1e2;

    uint256 public constant BTC_USD_PRICE = 69_000 * 1e2;

    uint256 public constant STABLE_USD_PRICE = 1 * 1e2;
    uint256 public constant sUSDe_USD_PRICE = 1.20 * 1e2;
    uint256 public constant sUSDs_USD_PRICE = 1.08 * 1e2;
    uint256 public constant syrupUSDT_USD_PRICE = 1.10 * 1e2;
    uint256 public constant syrupUSDC_USD_PRICE = 1.14 * 1e2;
    uint256 public constant REUSD_USD_PRICE = 1.06 * 1e2; // $1.06
    uint256 public constant csUSDL_USD_PRICE = 1.03 * 1e2; // $1.03

    uint256 public constant FLUID_USD_PRICE = 2.19 * 1e2;

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
        } else if (token == REUSD_ADDRESS) {
            usdPrice = REUSD_USD_PRICE;
            decimals = 18;
        } else if (token == csUSDL_ADDRESS) {
            usdPrice = csUSDL_USD_PRICE;
            decimals = 18;
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
