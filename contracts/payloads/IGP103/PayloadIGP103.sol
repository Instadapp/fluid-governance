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

import {ILite} from "../common/interfaces/ILite.sol";

contract PayloadIGP103 is PayloadIGPMain {
    uint256 public constant PROPOSAL_ID = 103;

    function execute() public virtual override {
        super.execute();

        // Action 1: Set Fee Handler for weETH-ETH DEX
        action1();

        // Action 2: Withdraw $FLUID for Rewards
        action2();

        // Action 3: Update the Max Supply Shares for USDE-USDTb DEX
        action3();

        // Action 4: Update Dex Fee Auths
        action4();

        // Action 5: Update Token Auths
        action5();

        // Action 6: Update Vault Fee Rewards Auths
        action6();

        // Action 7: Update USDe-USDT Dex Fee auth
        action7();

        // Action 8: Add sUSDe-USDT Dex Fee auth
        action8();
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

    // @notice Action 1: Set Fee Handler for weETH-ETH DEX
    function action1() internal isActionSkippable(1) {
        address weETH_ETH_DEX = getDexAddress(9);

        // Fee Handler Addresses
        address FeeHandler = 0x8eaE5474C3DFE2c5F07E7423019E443258A73100;

        // Add new handler as auth
        DEX_FACTORY.setDexAuth(weETH_ETH_DEX, FeeHandler, true);
    }

    // @notice Action 2: Withdraw $FLUID for Rewards
    function action2() internal isActionSkippable(2) {
        string[] memory targets = new string[](1);
        bytes[] memory encodedSpells = new bytes[](1);

        string
            memory withdrawSignature = "withdraw(address,uint256,address,uint256,uint256)";

        // Spell 1: Transfer FLUID to Team Multisig
        {
            uint256 FLUID_AMOUNT = 125_000 * 1e18;
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

    // @notice Action 3: Update the Max Supply Shares for USDE-USDTb DEX
    function action3() internal isActionSkippable(3) {
        {
            {
                // Set max supply shares
                IFluidDex(USDE_USDTb_DEX).updateMaxSupplyShares(
                    15_000_000 * 1e18 // $30M
                );
            }
        }
    }

    // @notice Action 4: Update Dex Fee Auths
    function action4() internal isActionSkippable(4) {
        {
            // Dex Fee Auths
            address oldDexFeeAuth = 0x7BD48D505A195d2d3B90263b7E4DB78909b817D3;
            address newDexFeeAuth = 0x13c8d980dAb87b003D46C03e661672D167c824b9;

            // Remove old dex fee auth
            DEX_FACTORY.setGlobalAuth(oldDexFeeAuth, false);

            // Add new dex fee auth
            DEX_FACTORY.setGlobalAuth(newDexFeeAuth, true);
        }
    }

    // @notice Action 5: Update Token Auths
    function action5() internal isActionSkippable(5) {
       {
            // Token Auths
            address oldTokenAuth = 0xb2875c793CE2277dE813953D7306506E87842b76;
            address newTokenAuth = 0x3C27B24E9d7f3F5B9B4914A430C34ac8f8B27006;

            FluidLiquidityAdminStructs.AddressBool[]
                memory addrBools_ = new FluidLiquidityAdminStructs.AddressBool[](2);

            // update token auth
            addrBools_[0] = FluidLiquidityAdminStructs.AddressBool({
                addr: oldTokenAuth,
                value: false
            });

            addrBools_[1] = FluidLiquidityAdminStructs.AddressBool({
                addr: newTokenAuth,
                value: true
            });

            LIQUIDITY.updateAuths(addrBools_);
        }
    }

    // @notice Action 6: Update Vault Fee Rewards Auths
    function action6() internal isActionSkippable(6) {
        {
            // Vault Fee Rewards Auths
            address newVaultFeeRewardsAuth = 0xEf363bA369Bd2140C5371C973dA9542c08bA9f9F;

            // add new vault fee rewards auth
            VAULT_FACTORY.setGlobalAuth(newVaultFeeRewardsAuth, true);
        }
    }

    // @notice Action 7: Update USDe-USDT Dex Fee auth
    function action7() internal isActionSkippable(7) {
        address USDe_USDT_DEX = getDexAddress(18);

        // Fee Handler Addresses
        address oldFeeHandler = 0x855BaEf2EEBf4238e6e509c85a5277a3c5A38f9D;
        address newFeeHandler = 0x49EF1B3230a8d2AC7205E808dF5859f1b94D61Df;

        // Remove old fee handler
        DEX_FACTORY.setDexAuth(USDe_USDT_DEX, oldFeeHandler, false);

        // Add new fee handler as auth
        DEX_FACTORY.setDexAuth(USDe_USDT_DEX, newFeeHandler, true);
    }

    // @notice Action 8: Add sUSDe-USDT Dex Fee auth
    function action8() internal isActionSkippable(8) {
        address sUSDe_USDT_DEX = getDexAddress(15);

        // Fee Handler Addresses
        address FeeHandler = 0xc5ba4D4142Ae5cf9ec802B298963A08390658f05;

        // Add new handler as auth
        DEX_FACTORY.setDexAuth(sUSDe_USDT_DEX, FeeHandler, true);
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
