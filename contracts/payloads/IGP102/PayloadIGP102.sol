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

import {IStETH} from "../common/interfaces/IStETH.sol";
import {IWstETH} from "../common/interfaces/IWstETH.sol";

contract PayloadIGP102 is PayloadIGPMain {
    uint256 public constant PROPOSAL_ID = 102;

    function execute() public virtual override {
        super.execute();

        // Action 1: Set Launch Limits for USDe-USDTb / GHO T2 Vault
        action1();

        // Action 2: Set Launch Limits for GHO-USDe / GHO T2 Vault
        action2();

        // Action 3: Remove MS as auth for csUSDL-USDC dex and set rebalancer for csUSDL-USDC smart lending
        action3();

        // Action 4: Collect stETH, wstETH revenue and deposit from reserve contract to Lite Vault
        action4();

        // Action 5: Update wstUSR-USDC Supply Caps
        action5();

        // Action 6: Update Dex Fee Auths
        action6();

        // Action 7: Update Rates Auths
        action7();

        // Action 8: Update Dex Range Auths
        action8();

        // Action 9: Update Limits Auths
        action9();

        // Action 10: Update Dex Limits Auths
        action10();

        // Action 11: Add USDe-USDT Dex Fee auth
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

    // @notice Action 1: Set Launch Limits for USDe-USDTb / GHO T2 Vault
    function action1() internal isActionSkippable(1) {
        {
            // launch limits
            address USDE_USDTb__GHO_VAULT = getVaultAddress(140);

            // USDE-USDTb / GHO T2 vault
            VaultConfig memory VAULT_USDE_USDTb_GHO = VaultConfig({
                vault: USDE_USDTb__GHO_VAULT,
                vaultType: VAULT_TYPE.TYPE_2,
                supplyToken: address(0), // supply token
                borrowToken: GHO_ADDRESS,
                baseWithdrawalLimitInUSD: 0,
                baseBorrowLimitInUSD: 5_000_000, // $5M
                maxBorrowLimitInUSD: 20_000_000 // $20M
            });

            setVaultLimits(VAULT_USDE_USDTb_GHO);

            VAULT_FACTORY.setVaultAuth(
                USDE_USDTb__GHO_VAULT,
                TEAM_MULTISIG,
                false
            );
        }
        {
            // remove auth
            address USDE_USDTb_DEX = getDexAddress(36);
            DEX_FACTORY.setDexAuth(USDE_USDTb_DEX, TEAM_MULTISIG, false);
        }
    }

    // @notice Action 2: Set Launch Limits for GHO-USDe / GHO T2 Vault
    function action2() internal isActionSkippable(2) {
        {
            // launch limits
            address GHO_USDe__GHO_VAULT = getVaultAddress(141);

            // GHO-USDe / GHO T2 vault
            VaultConfig memory VAULT_GHO_USDe_GHO = VaultConfig({
                vault: GHO_USDe__GHO_VAULT,
                vaultType: VAULT_TYPE.TYPE_2,
                supplyToken: address(0), // supply token
                borrowToken: GHO_ADDRESS,
                baseWithdrawalLimitInUSD: 0,
                baseBorrowLimitInUSD: 5_000_000, // $5M
                maxBorrowLimitInUSD: 10_000_000 // $10M
            });

            setVaultLimits(VAULT_GHO_USDe_GHO);

            VAULT_FACTORY.setVaultAuth(
                GHO_USDe__GHO_VAULT,
                TEAM_MULTISIG,
                false
            );
        }
        {
            //remove auth
            address GHO_USDe_DEX = getDexAddress(37);
            DEX_FACTORY.setDexAuth(GHO_USDe_DEX, TEAM_MULTISIG, false);
        }
    }

    // @notice Action 3: Remove MS as auth for csUSDL-USDC dex and set rebalancer for csUSDL-USDC smart lending
    function action3() internal isActionSkippable(3) {
        address csUSDL_USDC_DEX = getDexAddress(38);
        {
            // csUSDL-USDC DEX
            DEX_FACTORY.setDexAuth(csUSDL_USDC_DEX, TEAM_MULTISIG, false);
        }
        {
            address fSL38_csUSDL_USDC = getSmartLendingAddress(38);

            // set rebalancer at fSL38 to reserve contract proxy
            ISmartLendingAdmin(fSL38_csUSDL_USDC).setRebalancer(
                address(FLUID_RESERVE)
            );
        }
    }

    // @notice Action 4: Collect stETH, wstETH revenue and deposit from reserve contract to Lite Vault
    function action4() internal isActionSkippable(4) {
        {
            address[] memory tokens = new address[](2);

            tokens[0] = ETH_ADDRESS;
            tokens[1] = wstETH_ADDRESS;

            LIQUIDITY.collectRevenue(tokens);
        
            uint256[] memory amounts = new uint256[](2);

            amounts[0] = address(FLUID_RESERVE).balance - 0.1 ether;
            amounts[1] =
                IERC20(wstETH_ADDRESS).balanceOf(address(FLUID_RESERVE)) -
                0.1 ether;

            FLUID_RESERVE.withdrawFunds(tokens, amounts, address(TREASURY)); // Withdraw to Treasury
        }
        {
            address[] memory tokens = new address[](1);
            uint256[] memory amounts = new uint256[](1);

            tokens[0] = stETH_ADDRESS;
            amounts[0] = IERC20(stETH_ADDRESS).balanceOf(
                address(FLUID_RESERVE)
            );

            FLUID_RESERVE.withdrawFunds(tokens, amounts, address(TREASURY)); // Withdraw to Treasury
        }
        {
            // stake ETH and unwrap wstETH
            {
                // Stake ETH
                string[] memory targets = new string[](2);
                bytes[] memory encodedSpells = new bytes[](2);

                string
                    memory depositSignature = "deposit(uint256,uint256,uint256)";
                string
                    memory withdrawSignature = "withdraw(uint256,uint256,uint256)";

                // Spell 1: Stake ETH
                {
                    uint256 ETH_AMOUNT = address(TREASURY).balance;
                    targets[0] = "LIDO-STETH-A";
                    encodedSpells[0] = abi.encodeWithSignature(
                        depositSignature,
                        ETH_AMOUNT,
                        0,
                        0
                    );
                }

                // Spell 2: Unwrap WSTETH
                {
                    uint256 WSTETH_AMOUNT = IERC20(wstETH_ADDRESS).balanceOf(
                        address(TREASURY)
                    );
                    targets[1] = "WSTETH-A";
                    encodedSpells[1] = abi.encodeWithSignature(
                        withdrawSignature,
                        WSTETH_AMOUNT,
                        0,
                        0
                    );
                }

                IDSAV2(TREASURY).cast(targets, encodedSpells, address(this));
            }
        }
        {
            // Deposit stETH into Lite Vault
            string[] memory targets = new string[](1);
            bytes[] memory encodedSpells = new bytes[](1);

            string
                memory depositSignature = "deposit(address,uint256,uint256,uint256)";

            // Spell 1: Deposit stETH into Lite
            {
                uint256 STETH_AMOUNT = IERC20(stETH_ADDRESS).balanceOf(
                    address(TREASURY)
                );
                targets[0] = "BASIC-D-V2";
                encodedSpells[0] = abi.encodeWithSignature(
                    depositSignature,
                    IETHV2,
                    STETH_AMOUNT,
                    0,
                    0
                );
            }

            IDSAV2(TREASURY).cast(targets, encodedSpells, address(this));
        }
    }

    // @notice Action 5: Update wstUSR-USDC Supply Caps
    function action5() internal isActionSkippable(5) {
        {
            // update wstUSR-USDC max supply shares
            {
                address wstUSR_USDC_DEX = getDexAddress(27);

                IFluidDex(wstUSR_USDC_DEX).updateMaxSupplyShares(
                    10_000_000 * 1e18
                ); // $20M
            }
        }
    }

    // @notice Action 6: Update Dex Fee Auths
    function action6() internal isActionSkippable(6) {
        {
            // Dex Fee Auths
            address oldDexFeeAuth = 0xE3e18c563d11ced9B0c9cb8dD0284CF4442bC06a;
            address newDexFeeAuth = 0x7BD48D505A195d2d3B90263b7E4DB78909b817D3;

            // Remove old dex fee auth
            DEX_FACTORY.setGlobalAuth(oldDexFeeAuth, false);

            // Add new dex fee auth
            DEX_FACTORY.setGlobalAuth(newDexFeeAuth, true);
        }
    }

    // @notice Action 7: Update Rates Auths
    function action7() internal isActionSkippable(7) {
        {
            // Rates Auths
            address oldRatesAuth = 0x3eca30f7dB5AeAbD8757cE5Baf850dA8acA086Db;
            address newRatesAuth = 0x1e6B029284dc2779F8FfBD83a3a5aA00EdCE6ba4;

            FluidLiquidityAdminStructs.AddressBool[]
                memory addrBools_ = new FluidLiquidityAdminStructs.AddressBool[](2);

            // update rates auth
            addrBools_[0] = FluidLiquidityAdminStructs.AddressBool({
                addr: oldRatesAuth,
                value: false
            });

            addrBools_[1] = FluidLiquidityAdminStructs.AddressBool({
                addr: newRatesAuth,
                value: true
            });

            LIQUIDITY.updateAuths(addrBools_);
        }
    }

    // @notice Action 8: Update Dex Range Auths
    function action8() internal isActionSkippable(8) {
        {
            // Range Auth Dex
            address newRangeAuthDex = 0x827089c01E9f761ff1A6D7041a9388bDdae74cc4;

            // Add new range auth dex
            DEX_FACTORY.setGlobalAuth(newRangeAuthDex, true);
        }
    }

    // @notice Action 9: Update Limits Auths
    function action9() internal isActionSkippable(9) {
        {
            // Limits Auth
            address newLimitsAuth = 0x38f099E69F76978E195712727A1858C6c63335aa;

            FluidLiquidityAdminStructs.AddressBool[]
                memory addrBools_ = new FluidLiquidityAdminStructs.AddressBool[](1);

            // set limits auth
            addrBools_[0] = FluidLiquidityAdminStructs.AddressBool({
                addr: newLimitsAuth,
                value: true
            });

            LIQUIDITY.updateAuths(addrBools_);
        }
    }

    // @notice Action 10: Update Dex Limits Auths
    function action10() internal isActionSkippable(10) {
        {
            // Limits Auth Dex
            address newLimitsAuthDex = 0x5A09B07DFCc0852ADA327Dc81A9cb676B6c676f2;

            // Add new limits auth dex
            DEX_FACTORY.setGlobalAuth(newLimitsAuthDex, true);
        }
    }

    // @notice Action 11: Add USDe-USDT Dex Fee auth
    function action11() internal isActionSkippable(11) {
        address USDe_USDT_DEX = getDexAddress(18);

        // Fee Handler Addresses
        address FeeHandler = 0x855BaEf2EEBf4238e6e509c85a5277a3c5A38f9D;

        // Add new handler as auth
        DEX_FACTORY.setDexAuth(USDe_USDT_DEX, FeeHandler, true);
    }

    /**
     * |
     * |     Payload Actions End Here      |
     * |__________________________________
     */

    // Token Prices Constants
    uint256 public constant ETH_USD_PRICE = 2_500 * 1e2;
    uint256 public constant wstETH_USD_PRICE = 3_050 * 1e2;
    uint256 public constant weETH_USD_PRICE = 2_700 * 1e2;
    uint256 public constant rsETH_USD_PRICE = 2_650 * 1e2;
    uint256 public constant weETHs_USD_PRICE = 2_600 * 1e2;
    uint256 public constant mETH_USD_PRICE = 2_690 * 1e2;
    uint256 public constant ezETH_USD_PRICE = 2_650 * 1e2;

    uint256 public constant BTC_USD_PRICE = 103_000 * 1e2;

    uint256 public constant STABLE_USD_PRICE = 1 * 1e2;
    uint256 public constant sUSDe_USD_PRICE = 1.17 * 1e2;
    uint256 public constant sUSDs_USD_PRICE = 1.05 * 1e2;

    uint256 public constant FLUID_USD_PRICE = 4.2 * 1e2;

    uint256 public constant RLP_USD_PRICE = 1.18 * 1e2;
    uint256 public constant wstUSR_USD_PRICE = 1.07 * 1e2;
    uint256 public constant XAUT_USD_PRICE = 3_240 * 1e2;
    uint256 public constant PAXG_USD_PRICE = 3_240 * 1e2;

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
