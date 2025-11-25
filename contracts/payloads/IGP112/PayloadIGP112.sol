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
import {IProxy} from "../common/interfaces/IProxy.sol";
import {PayloadIGPConstants} from "../common/constants.sol";
import {PayloadIGPHelpers} from "../common/helpers.sol";
import {PayloadIGPMain} from "../common/main.sol";
import {ILite} from "../common/interfaces/ILite.sol";

contract PayloadIGP112 is PayloadIGPMain {
    uint256 public constant PROPOSAL_ID = 112;

    function execute() public virtual override {
        super.execute();

        // Action 1: Cleanup leftover allowances from Reserve contract
        action1();

        // Action 2: Clean up very old v1 vaults (1-10)
        action2();

        // Action 3: Max restrict deUSD-USDC DEX
        action3();

        // Action 4: Collect Lite vault revenue for buybacks
        action4();

        // Action 5: Update Lite treasury to Reserve contract
        action5();

        // Action 6: Update liquidation penalty on all USDT debt vaults
        action6();

        // Action 7: Launch USDe-JRUSDE and SRUSDE-USDe DEX limits
        action7();

        // Action 8: Upgrade Reserve Contract Implementation
        action8();

        // Action 9: Update syrupUSDC vault parameters
        action9();

        // Action 10: Collect liquidity layer revenue for buybacks
        action10();
    }

    function verifyProposal() public view override {}

    function _PROPOSAL_ID() internal view override returns (uint256) {
        return PROPOSAL_ID;
    }

    // Struct to hold vault ID and new liquidation penalty
    struct VaultLiquidationPenalty {
        uint256 vaultId;
        uint256 liquidationPenalty; // in 1e2 format (1% = 100)
    }

    struct VaultWithdrawalLimit {
        uint256 vaultId;
        uint256 baseWithdrawalLimitInUSD;
    }

    /**
     * |
     * |     Proposal Payload Actions      |
     * |__________________________________
     */

    /// @notice Action 1: Cleanup leftover allowances from Reserve contract
    function action1() internal isActionSkippable(1) {
        address[] memory protocols_ = new address[](17);
        protocols_[0] = 0x5C20B550819128074FD538Edf79791733ccEdd18;
        protocols_[1] = 0x9Fb7b4477576Fe5B32be4C1843aFB1e55F251B33;
        protocols_[2] = 0xE6b5D1CdC4935295c84772C4700932b4BFC93274;
        protocols_[3] = 0x6F72895Cf6904489Bcd862c941c3D02a3eE4f03e;
        protocols_[4] = 0xeAbBfca72F8a8bf14C4ac59e69ECB2eB69F0811C;
        protocols_[5] = 0xbEC491FeF7B4f666b270F9D5E5C3f443cBf20991;
        protocols_[6] = 0x51197586F6A9e2571868b6ffaef308f3bdfEd3aE;
        protocols_[7] = 0x1c2bB46f36561bc4F05A94BD50916496aa501078;
        protocols_[8] = 0x4045720a33193b4Fe66c94DFbc8D37B0b4D9B469;
        protocols_[9] = 0xdF16AdaF80584b2723F3BA1Eb7a601338Ba18c4e;
        protocols_[10] = 0x0C8C77B7FF4c2aF7F6CEBbe67350A490E3DD6cB3;
        protocols_[11] = 0xE16A6f5359ABB1f61cE71e25dD0932e3E00B00eB;
        protocols_[12] = 0x1982CC7b1570C2503282d0A0B41F69b3B28fdcc3;
        protocols_[13] = 0xb4F3bf2d96139563777C0231899cE06EE95Cc946;
        protocols_[14] = 0xBc345229C1b52e4c30530C614BB487323BA38Da5;
        protocols_[15] = 0xF2c8F54447cbd591C396b0Dd7ac15FAF552d0FA4;
        protocols_[16] = 0x92643E964CA4b2c165a95CA919b0A819acA6D5F1;

        address[] memory tokens_ = new address[](17);
        tokens_[0] = 0xdAC17F958D2ee523a2206206994597C13D831ec7; // USDT
        tokens_[1] = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48; // USDC
        tokens_[2] = 0xdAC17F958D2ee523a2206206994597C13D831ec7; // USDT
        tokens_[3] = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48; // USDC
        tokens_[4] = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48; // USDC
        tokens_[5] = 0xdAC17F958D2ee523a2206206994597C13D831ec7; // USDT
        tokens_[6] = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48; // USDC
        tokens_[7] = 0xdAC17F958D2ee523a2206206994597C13D831ec7; // USDT
        tokens_[8] = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48; // USDC
        tokens_[9] = 0xdAC17F958D2ee523a2206206994597C13D831ec7; // USDT
        tokens_[10] = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48; // USDC
        tokens_[11] = 0xdAC17F958D2ee523a2206206994597C13D831ec7; // USDT
        tokens_[12] = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48; // USDC
        tokens_[13] = 0xdAC17F958D2ee523a2206206994597C13D831ec7; // USDT
        tokens_[14] = 0xdAC17F958D2ee523a2206206994597C13D831ec7; // USDT
        tokens_[15] = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48; // USDC
        tokens_[16] = 0xdAC17F958D2ee523a2206206994597C13D831ec7; // USDT

        // Call revoke() on ReserveContractProxy to cleanup leftover allowances from IGP110
        IFluidReserveContract(RESERVE_CONTRACT_PROXY).revoke(
            protocols_,
            tokens_
        );
    }

    /// @notice Action 2: Reduce limits on very old v1 vaults (1-10)
    function action2() internal isActionSkippable(2) {
        VaultWithdrawalLimit[]
            memory supplyLimits_ = new VaultWithdrawalLimit[](10);
        supplyLimits_[0] = VaultWithdrawalLimit({
            vaultId: 1,
            baseWithdrawalLimitInUSD: 4_000
        }); // ETH/USDC
        supplyLimits_[1] = VaultWithdrawalLimit({
            vaultId: 2,
            baseWithdrawalLimitInUSD: 6_000
        }); // ETH/USDT
        supplyLimits_[2] = VaultWithdrawalLimit({
            vaultId: 3,
            baseWithdrawalLimitInUSD: 5_000
        }); // wstETH/ETH
        supplyLimits_[3] = VaultWithdrawalLimit({
            vaultId: 4,
            baseWithdrawalLimitInUSD: 4_000
        }); // wstETH/USDC
        supplyLimits_[4] = VaultWithdrawalLimit({
            vaultId: 5,
            baseWithdrawalLimitInUSD: 4_000
        }); // wstETH/USDT
        supplyLimits_[5] = VaultWithdrawalLimit({
            vaultId: 6,
            baseWithdrawalLimitInUSD: 8_000_000
        }); // weETH/wstETH
        supplyLimits_[6] = VaultWithdrawalLimit({
            vaultId: 7,
            baseWithdrawalLimitInUSD: 5_000
        }); // sUSDe/USDC
        supplyLimits_[7] = VaultWithdrawalLimit({
            vaultId: 8,
            baseWithdrawalLimitInUSD: 1_000
        }); // sUSDe/USDT
        supplyLimits_[8] = VaultWithdrawalLimit({
            vaultId: 9,
            baseWithdrawalLimitInUSD: 5_800_000
        }); // weETH/USDC
        supplyLimits_[9] = VaultWithdrawalLimit({
            vaultId: 10,
            baseWithdrawalLimitInUSD: 2_800_000
        }); // weETH/USDT

        for (uint256 i = 0; i < supplyLimits_.length; i++) {
            address vault_ = getVaultAddress(supplyLimits_[i].vaultId);
            IFluidVaultT1.ConstantViews memory constants_ = IFluidVaultT1(
                vault_
            ).constantsView();

            SupplyProtocolConfig memory supplyConfig_ = SupplyProtocolConfig({
                protocol: vault_,
                supplyToken: constants_.supplyToken,
                expandPercent: 25 * 1e2, // 25%
                expandDuration: 12 hours, // 12 hours
                baseWithdrawalLimitInUSD: supplyLimits_[i]
                    .baseWithdrawalLimitInUSD
            });
            setSupplyProtocolLimits(supplyConfig_);
        }

        // Apply "paused" borrow limits to all vaults 1-10 using the helper
        for (uint256 vaultId = 1; vaultId <= 10; vaultId++) {
            address vault_ = getVaultAddress(vaultId);
            IFluidVaultT1.ConstantViews memory constants_ = IFluidVaultT1(
                vault_
            ).constantsView();
            setBorrowProtocolLimitsPaused(vault_, constants_.borrowToken);
        }
    }

    /// @notice Action 3: Max restrict deUSD-USDC DEX
    function action3() internal isActionSkippable(3) {
        address deUSD_USDC_DEX = getDexAddress(19);

        // Set max supply shares to 10 (minimal limit to allow withdrawals)
        IFluidDex(deUSD_USDC_DEX).updateMaxSupplyShares(10);
    }

    /// @notice Action 4: Collect Lite vault revenue for buybacks
    function action4() internal isActionSkippable(4) {
        uint256 STETH_AMOUNT = 85 * 1e18; // 85 stETH
        ILite(IETHV2).collectRevenue(STETH_AMOUNT);

        // Spell: Transfer 85 stETH from iETHv2 to Team Multisig
        string[] memory targets = new string[](1);
        bytes[] memory encodedSpells = new bytes[](1);

        string
            memory withdrawSignature = "withdraw(address,uint256,address,uint256,uint256)";
        targets[0] = "BASIC-A";
        encodedSpells[0] = abi.encodeWithSignature(
            withdrawSignature,
            stETH_ADDRESS,
            STETH_AMOUNT,
            address(TEAM_MULTISIG),
            0,
            0
        );

        IDSAV2(TREASURY).cast(targets, encodedSpells, address(this));
    }

    /// @notice Action 5: Update Lite treasury to Reserve contract
    function action5() internal isActionSkippable(5) {
        // Call updateTreasury directly on Lite contract
        IETHV2.updateTreasury(address(FLUID_RESERVE));
    }

    /// @notice Action 6: Update liquidation penalty on all USDT debt vaults
    function action6() internal isActionSkippable(6) {
        // List of all USDT debt vaults with their new liquidation penalties
        VaultLiquidationPenalty[] memory vaults = new VaultLiquidationPenalty[](
            8
        );

        // ETH/USDT: 2% -> 1%
        vaults[0] = VaultLiquidationPenalty({
            vaultId: 12,
            liquidationPenalty: 1 * 1e2
        });

        // wstETH/USDT: 3% -> 2.5%
        vaults[1] = VaultLiquidationPenalty({
            vaultId: 15,
            liquidationPenalty: 250
        }); // 2.5% = 250 in 1e2 format

        // weETH/USDT: 4% -> 3%
        vaults[2] = VaultLiquidationPenalty({
            vaultId: 20,
            liquidationPenalty: 3 * 1e2
        });

        // WBTC/USDT: 4% -> 3%
        vaults[3] = VaultLiquidationPenalty({
            vaultId: 22,
            liquidationPenalty: 3 * 1e2
        });

        // cbBTC/USDT: 4% -> 3%
        vaults[4] = VaultLiquidationPenalty({
            vaultId: 30,
            liquidationPenalty: 3 * 1e2
        });

        // tBTC/USDT: 4% -> 3%
        vaults[5] = VaultLiquidationPenalty({
            vaultId: 89,
            liquidationPenalty: 3 * 1e2
        });

        // lBTC/USDT: 5% -> 4%
        vaults[6] = VaultLiquidationPenalty({
            vaultId: 108,
            liquidationPenalty: 4 * 1e2
        });

        // USDe-USDtb/USDT (TYPE_2): 3% -> 2.5%
        vaults[7] = VaultLiquidationPenalty({
            vaultId: 137,
            liquidationPenalty: 250
        }); // 2.5% = 250 in 1e2 format

        // Update liquidation penalty for each vault
        for (uint256 i = 0; i < vaults.length; i++) {
            address vaultAddress = getVaultAddress(vaults[i].vaultId);
            IFluidVaultT1(vaultAddress).updateLiquidationPenalty(
                vaults[i].liquidationPenalty
            );
        }
    }

    /// @notice Action 7: Launch USDe-JRUSDE and SRUSDE-USDe DEX limits and configure smart lending
    function action7() internal isActionSkippable(7) {
        // DEX ID 41: USDe-JRUSDE
        address USDE_JRUSDE_DEX = getDexAddress(41);
        DexConfig memory dexConfigUSDe_ = DexConfig({
            dex: USDE_JRUSDE_DEX,
            tokenA: USDe_ADDRESS,
            tokenB: JRUSDE_ADDRESS,
            smartCollateral: true,
            smartDebt: false,
            baseWithdrawalLimitInUSD: 5_500_000, // $5.5M per token
            baseBorrowLimitInUSD: 0,
            maxBorrowLimitInUSD: 0
        });
        setDexLimits(dexConfigUSDe_);

        // DEX ID 42: SRUSDE-USDe
        address SRUSDE_USDE_DEX = getDexAddress(42);
        DexConfig memory dexConfigSRUs_ = DexConfig({
            dex: SRUSDE_USDE_DEX,
            tokenA: SRUSDE_ADDRESS,
            tokenB: USDe_ADDRESS,
            smartCollateral: true,
            smartDebt: false,
            baseWithdrawalLimitInUSD: 5_500_000, // $5.5M per token
            baseBorrowLimitInUSD: 0,
            maxBorrowLimitInUSD: 0
        });
        setDexLimits(dexConfigSRUs_);

        // Launch supply shares cap
        uint256 launchSupplyShares_ = 6_000_000 * 1e18; // $12M equivalent shares
        IFluidDex(USDE_JRUSDE_DEX).updateMaxSupplyShares(launchSupplyShares_);
        IFluidDex(SRUSDE_USDE_DEX).updateMaxSupplyShares(launchSupplyShares_);

        // Configure smart lending rebalancers to Reserve contract
        address fSL_USDE_JRUSDE = getSmartLendingAddress(41);
        if (fSL_USDE_JRUSDE != address(0)) {
            ISmartLendingAdmin(fSL_USDE_JRUSDE).setRebalancer(
                address(FLUID_RESERVE)
            );
        }

        address fSL_SRUSDE_USDE = getSmartLendingAddress(42);
        if (fSL_SRUSDE_USDE != address(0)) {
            ISmartLendingAdmin(fSL_SRUSDE_USDE).setRebalancer(
                address(FLUID_RESERVE)
            );
        }

        // Remove Team Multisig authorization on the DEXes post launch
        DEX_FACTORY.setDexAuth(USDE_JRUSDE_DEX, TEAM_MULTISIG, false);
        DEX_FACTORY.setDexAuth(SRUSDE_USDE_DEX, TEAM_MULTISIG, false);
    }

    /// @notice Action 8: Upgrade Reserve Contract Implementation
    function action8() internal isActionSkippable(8) {
        IProxy(address(FLUID_RESERVE)).upgradeToAndCall(
            address(0xFb3102759F2d57F547b9C519db49Ce1fFDE15dB2),
            abi.encode()
        );
    }

    /// @notice Action 9: Update CF/LT on syrupUSDC vaults
    function action9() internal isActionSkippable(9) {
        uint256 collateralFactor = 90 * 1e2; // 90%
        uint256 liquidationThreshold = 92 * 1e2; // 92%

        for (uint256 i = 145; i <= 152; i++) {
            address vault = getVaultAddress(i);
            IFluidVaultT1(vault).updateLiquidationThreshold(
                liquidationThreshold
            );
            IFluidVaultT1(vault).updateCollateralFactor(collateralFactor);
        }
    }

    /// @notice Action 10: Collect liquidity layer revenue for buybacks
    function action10() internal isActionSkippable(10) {
        {
            // liquidity layer revenue
            address[] memory tokens = new address[](8);
            tokens[0] = USDT_ADDRESS;
            tokens[1] = wstETH_ADDRESS;
            tokens[2] = ETH_ADDRESS;
            tokens[3] = USDC_ADDRESS;
            tokens[4] = sUSDe_ADDRESS;
            tokens[5] = cbBTC_ADDRESS;
            tokens[6] = WBTC_ADDRESS;
            tokens[7] = GHO_ADDRESS;
            LIQUIDITY.collectRevenue(tokens);
        }
        {
            address[] memory tokens = new address[](8);
            uint256[] memory amounts = new uint256[](8);
            tokens[0] = USDT_ADDRESS;
            amounts[0] =
                IERC20(USDT_ADDRESS).balanceOf(address(FLUID_RESERVE)) -
                10;
            tokens[1] = wstETH_ADDRESS;
            amounts[1] =
                IERC20(wstETH_ADDRESS).balanceOf(address(FLUID_RESERVE)) -
                0.1 ether;
            tokens[2] = ETH_ADDRESS;
            amounts[2] = address(FLUID_RESERVE).balance - 0.1 ether;
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
            IFluidReserveContractV2(address(FLUID_RESERVE)).withdrawFunds(
                tokens,
                amounts,
                TEAM_MULTISIG,
                "revenue for buybacks"
            );
        }
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
