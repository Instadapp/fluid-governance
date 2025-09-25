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
import {ILiteSigs} from "../common/interfaces/ILiteSigs.sol";

contract PayloadIGP108 is PayloadIGPMain {
    uint256 public constant PROPOSAL_ID = 108;

    /**
     * |
     * |     Admin Actions      |
     * |__________________________________
     */

    function execute() public virtual override {
        super.execute();

        // Action 1:  Collect Revenue to Team Multisig for the First Buyback
        action1();

        // Action 2: Set launch limits for syrupUSDC DEX and its vaults
        action2();

        // Action 3: Enable New DSA Connector Multisig as Chief on DSAv2 Connector
        action3();

        // Action 4: Reduce the Limits on Less Utilized Vaults
        action4();

        // Action 5: Absorb Dust Debt for wstETH-WBTC
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

    // @notice Action 1: Collect Revenue to Team Multisig for the First Buyback
    function action1() internal isActionSkippable(1) {
        {
            address[] memory tokens = new address[](9);

            tokens[0] = USDT_ADDRESS;
            tokens[1] = wstETH_ADDRESS;
            tokens[2] = ETH_ADDRESS;
            tokens[3] = USDC_ADDRESS;
            tokens[4] = sUSDe_ADDRESS;
            tokens[5] = cbBTC_ADDRESS;
            tokens[6] = WBTC_ADDRESS;
            tokens[7] = GHO_ADDRESS;
            tokens[8] = USDe_ADDRESS;

            LIQUIDITY.collectRevenue(tokens);
        }
        {
            address[] memory tokens = new address[](9);
            uint256[] memory amounts = new uint256[](9);

            tokens[0] = USDT_ADDRESS;
            amounts[0] =
                IERC20(USDT_ADDRESS).balanceOf(address(FLUID_RESERVE)) -
                10;

            tokens[1] = wstETH_ADDRESS;
            amounts[1] =
                IERC20(wstETH_ADDRESS).balanceOf(address(FLUID_RESERVE)) -
                0.1 ether;

            tokens[2] = ETH_ADDRESS;
            amounts[2] = address(FLUID_RESERVE).balance - 0.1 ether; // 0.1 ETH

            tokens[3] = USDC_ADDRESS;
            amounts[3] =
                IERC20(USDC_ADDRESS).balanceOf(address(FLUID_RESERVE)) -
                10;

            tokens[4] = sUSDe_ADDRESS;
            amounts[4] =
                IERC20(sUSDe_ADDRESS).balanceOf(address(FLUID_RESERVE)) -
                0.1 ether;

            tokens[5] = cbBTC_ADDRESS;
            amounts[5] =
                IERC20(cbBTC_ADDRESS).balanceOf(address(FLUID_RESERVE)) -
                10;

            tokens[6] = WBTC_ADDRESS;
            amounts[6] =
                IERC20(WBTC_ADDRESS).balanceOf(address(FLUID_RESERVE)) -
                10;

            tokens[7] = GHO_ADDRESS;
            amounts[7] =
                IERC20(GHO_ADDRESS).balanceOf(address(FLUID_RESERVE)) -
                10;

            tokens[8] = USDe_ADDRESS;
            amounts[8] =
                IERC20(USDe_ADDRESS).balanceOf(address(FLUID_RESERVE)) -
                10;

            FLUID_RESERVE.withdrawFunds(tokens, amounts, TEAM_MULTISIG);
        }
    }

    // @notice Action 2: Set launch limits for syrupUSDC DEX and its vaults
    function action2() internal isActionSkippable(2) {
        {
            address syrupUSDC_USDC_DEX = getDexAddress(39);
            // syrupUSDC-USDC DEX
            DexConfig memory DEX_syrupUSDC_USDC = DexConfig({
                dex: syrupUSDC_USDC_DEX,
                tokenA: syrupUSDC_ADDRESS,
                tokenB: USDC_ADDRESS,
                smartCollateral: true,
                smartDebt: false,
                baseWithdrawalLimitInUSD: 7_000_000, // $7M
                baseBorrowLimitInUSD: 0, // $0
                maxBorrowLimitInUSD: 0 // $0
            });
            setDexLimits(DEX_syrupUSDC_USDC); // Smart Collateral

            DEX_FACTORY.setDexAuth(syrupUSDC_USDC_DEX, TEAM_MULTISIG, false);
        }
        {
            address syrupUSDC_USDC__USDC_VAULT = getVaultAddress(145);
            // [TYPE 2] syrupUSDC-USDC<>USDC | smart collateral & debt
            VaultConfig memory VAULT_syrupUSDC_USDC__USDC = VaultConfig({
                vault: syrupUSDC_USDC__USDC_VAULT,
                vaultType: VAULT_TYPE.TYPE_2,
                supplyToken: address(0),
                borrowToken: USDC_ADDRESS,
                baseWithdrawalLimitInUSD: 0,
                baseBorrowLimitInUSD: 5_000_000, // $5M
                maxBorrowLimitInUSD: 20_000_000 // $20M
            });

            setVaultLimits(VAULT_syrupUSDC_USDC__USDC); // TYPE_2 => 145
            VAULT_FACTORY.setVaultAuth(
                syrupUSDC_USDC__USDC_VAULT,
                TEAM_MULTISIG,
                false
            );
        }
        {
            // launch limits for syrupUSDC/USDC vault
            address syrupUSDC__USDC_VAULT = getVaultAddress(146);
            // [TYPE 1] syrupUSDC/USDC vault - Launch limits
            VaultConfig memory VAULT_syrupUSDC__USDC = VaultConfig({
                vault: syrupUSDC__USDC_VAULT,
                vaultType: VAULT_TYPE.TYPE_1,
                supplyToken: syrupUSDC_ADDRESS,
                borrowToken: USDC_ADDRESS,
                baseWithdrawalLimitInUSD: 7_000_000, // $7M
                baseBorrowLimitInUSD: 5_000_000, // $5M
                maxBorrowLimitInUSD: 20_000_000 // $20M
            });

            setVaultLimits(VAULT_syrupUSDC__USDC);
            VAULT_FACTORY.setVaultAuth(
                syrupUSDC__USDC_VAULT,
                TEAM_MULTISIG,
                false
            );
        }
        {
            // launch limits for syrupUSDC/USDT vault
            address syrupUSDC__USDT_VAULT = getVaultAddress(147);
            // [TYPE 1] syrupUSDC/USDT vault - Launch limits
            VaultConfig memory VAULT_syrupUSDC__USDT = VaultConfig({
                vault: syrupUSDC__USDT_VAULT,
                vaultType: VAULT_TYPE.TYPE_1,
                supplyToken: syrupUSDC_ADDRESS,
                borrowToken: USDT_ADDRESS,
                baseWithdrawalLimitInUSD: 7_000_000, // $7M
                baseBorrowLimitInUSD: 5_000_000, // $5M
                maxBorrowLimitInUSD: 20_000_000 // $20M
            });

            setVaultLimits(VAULT_syrupUSDC__USDT);
            VAULT_FACTORY.setVaultAuth(
                syrupUSDC__USDT_VAULT,
                TEAM_MULTISIG,
                false
            );
        }
        {
            // launch limits for syrupUSDC/GHO vault
            address syrupUSDC__GHO_VAULT = getVaultAddress(148);
            // [TYPE 1] syrupUSDC/GHO vault - Launch limits
            VaultConfig memory VAULT_syrupUSDC__GHO = VaultConfig({
                vault: syrupUSDC__GHO_VAULT,
                vaultType: VAULT_TYPE.TYPE_1,
                supplyToken: syrupUSDC_ADDRESS,
                borrowToken: GHO_ADDRESS,
                baseWithdrawalLimitInUSD: 7_000_000, // $7M
                baseBorrowLimitInUSD: 5_000_000, // $5M
                maxBorrowLimitInUSD: 20_000_000 // $20M
            });

            setVaultLimits(VAULT_syrupUSDC__GHO);
            VAULT_FACTORY.setVaultAuth(
                syrupUSDC__GHO_VAULT,
                TEAM_MULTISIG,
                false
            );
        }
    }

    // @notice Action 3: Enable New DSA Connector Multisig as Chief on DSAv2 Connector
    function action3() internal isActionSkippable(3) {
        DSA_CONNECTORS_V2.toggleChief(
            0xCe40798c731Ce4F90EB239E4894D9c643eB1ddE7
        ); // New Connector Multisig
    }

    // @notice Action 4: Reduce the Limits on Less Utilized Vaults
    function action4() internal isActionSkippable(4) {
        {
            // Vault IDs 24,25,26: ETH/WBTC, wstETH/WBTC, weETH/WBTC - Max Borrow to $40M
            {
                address ETH_WBTC_VAULT = getVaultAddress(24);

                BorrowProtocolConfig
                    memory protocolConfig_ = BorrowProtocolConfig({
                        protocol: ETH_WBTC_VAULT,
                        borrowToken: WBTC_ADDRESS,
                        expandPercent: 50 * 1e2, // 50%
                        expandDuration: 6 hours, // 6 hours
                        baseBorrowLimitInUSD: 15_000_000, // $15M base limit
                        maxBorrowLimitInUSD: 40_000_000 // $40M max limit
                    });

                setBorrowProtocolLimits(protocolConfig_);
            }
            {
                address wstETH_WBTC_VAULT = getVaultAddress(25);

                BorrowProtocolConfig
                    memory protocolConfig_ = BorrowProtocolConfig({
                        protocol: wstETH_WBTC_VAULT,
                        borrowToken: WBTC_ADDRESS,
                        expandPercent: 50 * 1e2, // 50%
                        expandDuration: 6 hours, // 6 hours
                        baseBorrowLimitInUSD: 15_000_000, // $15M base limit
                        maxBorrowLimitInUSD: 40_000_000 // $40M max limit
                    });

                setBorrowProtocolLimits(protocolConfig_);
            }
            {
                address weETH_WBTC_VAULT = getVaultAddress(26);

                BorrowProtocolConfig
                    memory protocolConfig_ = BorrowProtocolConfig({
                        protocol: weETH_WBTC_VAULT,
                        borrowToken: WBTC_ADDRESS,
                        expandPercent: 50 * 1e2, // 50%
                        expandDuration: 6 hours, // 6 hours
                        baseBorrowLimitInUSD: 15_000_000, // $15M base limit
                        maxBorrowLimitInUSD: 40_000_000 // $40M max limit
                    });

                setBorrowProtocolLimits(protocolConfig_);
            }
        }
        {
            // Vault ID 13: Wsteth/eth - Max Borrow to $500M
            address wstETH_ETH_VAULT = getVaultAddress(13);

            BorrowProtocolConfig memory protocolConfig_ = BorrowProtocolConfig({
                protocol: wstETH_ETH_VAULT,
                borrowToken: ETH_ADDRESS,
                expandPercent: 50 * 1e2, // 50%
                expandDuration: 6 hours, // 6 hours
                baseBorrowLimitInUSD: 45_000_000, // $45M base limit
                maxBorrowLimitInUSD: 500_000_000 // $500M max limit
            });

            setBorrowProtocolLimits(protocolConfig_);
        }
        {
            // Vault IDs 14,15: Wsteth/stables - Max Borrow to $70M

            {
                address wstETH_USDC_VAULT = getVaultAddress(14);

                BorrowProtocolConfig
                    memory protocolConfig_ = BorrowProtocolConfig({
                        protocol: wstETH_USDC_VAULT,
                        borrowToken: USDC_ADDRESS,
                        expandPercent: 50 * 1e2, // 50%
                        expandDuration: 6 hours, // 6 hours
                        baseBorrowLimitInUSD: 8_500_000, // $8.5M base limit
                        maxBorrowLimitInUSD: 70_000_000 // $70M max limit
                    });

                setBorrowProtocolLimits(protocolConfig_);
            }
            {
                address wstETH_USDT_VAULT = getVaultAddress(15);

                BorrowProtocolConfig
                    memory protocolConfig_ = BorrowProtocolConfig({
                        protocol: wstETH_USDT_VAULT,
                        borrowToken: USDT_ADDRESS,
                        expandPercent: 50 * 1e2, // 50%
                        expandDuration: 6 hours, // 6 hours
                        baseBorrowLimitInUSD: 8_500_000, // $8.5M base limit
                        maxBorrowLimitInUSD: 70_000_000 // $70M max limit
                    });

                setBorrowProtocolLimits(protocolConfig_);
            }
        }
        {
            // Vault ID 16: Weeth/Wsteth - Max Borrow to $300M
            address weETH_wstETH_VAULT = getVaultAddress(16);

            BorrowProtocolConfig memory protocolConfig_ = BorrowProtocolConfig({
                protocol: weETH_wstETH_VAULT,
                borrowToken: wstETH_ADDRESS,
                expandPercent: 50 * 1e2, // 50%
                expandDuration: 6 hours, // 6 hours
                baseBorrowLimitInUSD: 20_000_000, // $20M base limit
                maxBorrowLimitInUSD: 300_000_000 // $300M max limit
            });

            setBorrowProtocolLimits(protocolConfig_);
        }
        {
            // Vault IDs 31,32,33: ETH/cbBTC Vaults - Max Borrow to $70M
            {
                address ETH_cbBTC_VAULT_31 = getVaultAddress(31);

                BorrowProtocolConfig
                    memory protocolConfig_ = BorrowProtocolConfig({
                        protocol: ETH_cbBTC_VAULT_31,
                        borrowToken: cbBTC_ADDRESS,
                        expandPercent: 50 * 1e2, // 50%
                        expandDuration: 6 hours, // 6 hours
                        baseBorrowLimitInUSD: 15_000_000, // $15M base limit
                        maxBorrowLimitInUSD: 70_000_000 // $70M max limit
                    });

                setBorrowProtocolLimits(protocolConfig_);
            }
            {
                address ETH_cbBTC_VAULT_32 = getVaultAddress(32);

                BorrowProtocolConfig
                    memory protocolConfig_ = BorrowProtocolConfig({
                        protocol: ETH_cbBTC_VAULT_32,
                        borrowToken: cbBTC_ADDRESS,
                        expandPercent: 50 * 1e2, // 50%
                        expandDuration: 6 hours, // 6 hours
                        baseBorrowLimitInUSD: 15_000_000, // $15M base limit
                        maxBorrowLimitInUSD: 70_000_000 // $70M max limit
                    });

                setBorrowProtocolLimits(protocolConfig_);
            }
            {
                address ETH_cbBTC_VAULT_33 = getVaultAddress(33);

                BorrowProtocolConfig
                    memory protocolConfig_ = BorrowProtocolConfig({
                        protocol: ETH_cbBTC_VAULT_33,
                        borrowToken: cbBTC_ADDRESS,
                        expandPercent: 50 * 1e2, // 50%
                        expandDuration: 6 hours, // 6 hours
                        baseBorrowLimitInUSD: 15_000_000, // $15M base limit
                        maxBorrowLimitInUSD: 70_000_000 // $70M max limit
                    });

                setBorrowProtocolLimits(protocolConfig_);
            }
        }
    }

    // // @notice Action 5: Absorb Dust Debt for wstETH-WBTC
    // function action5() internal isActionSkippable(5) {
    //     address wstETH_WBTC_VAULT = getVaultAddress(25);

    //     // Create array with all NFT IDs from 1 to 18 (total 18 positions)
    //     uint[] memory nftIds = new uint[](18);
    //     for (uint i = 0; i < 18; i++) {
    //         nftIds[i] = i + 1;
    //     }
        
    //     IFluidVaultT1(wstETH_WBTC_VAULT).absorbDustDebt(nftIds);
    // }

    /**
     * |
     * |     Payload Actions End Here      |
     * |__________________________________
     */
    // Token Prices Constants
    uint256 public constant ETH_USD_PRICE = 4_500 * 1e2;
    uint256 public constant wstETH_USD_PRICE = 5_400 * 1e2;
    uint256 public constant weETH_USD_PRICE = 5_400 * 1e2;
    uint256 public constant rsETH_USD_PRICE = 5_400 * 1e2;
    uint256 public constant weETHs_USD_PRICE = 5_400 * 1e2;
    uint256 public constant mETH_USD_PRICE = 5_400 * 1e2;
    uint256 public constant ezETH_USD_PRICE = 5_400 * 1e2;
    uint256 public constant stETH_USD_PRICE = 4_500 * 1e2;

    uint256 public constant BTC_USD_PRICE = 111_000 * 1e2;

    uint256 public constant STABLE_USD_PRICE = 1 * 1e2;
    uint256 public constant sUSDe_USD_PRICE = 1.19 * 1e2;
    uint256 public constant sUSDs_USD_PRICE = 1.06 * 1e2;

    uint256 public constant FLUID_USD_PRICE = 6 * 1e2;

    uint256 public constant RLP_USD_PRICE = 1.22 * 1e2;
    uint256 public constant wstUSR_USD_PRICE = 1.10 * 1e2;
    uint256 public constant XAUT_USD_PRICE = 3_340 * 1e2;
    uint256 public constant PAXG_USD_PRICE = 3_340 * 1e2;

    uint256 public constant csUSDL_USD_PRICE = 1.03 * 1e2;
    uint256 public constant syrupUSDC_USD_PRICE = 1.12 * 1e2;

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
        } else if (token == syrupUSDC_ADDRESS) {
            usdPrice = syrupUSDC_USD_PRICE;
            decimals = 6;
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
