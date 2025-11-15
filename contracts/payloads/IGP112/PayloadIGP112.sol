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

        // Action 4: Update Lite treasury to Reserve contract
        action4();

        // Action 5: Update liquidation penalty on all USDT debt vaults
        action5();
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
        IFluidReserveContract(RESERVE_CONTRACT_PROXY).revoke(protocols_, tokens_);
    }

    /// @notice Action 2: Clean up very old v1 vaults (1-10)
    function action2() internal isActionSkippable(2) {
        pauseVault(1);
        pauseVault(2);
        pauseVault(3);
        pauseVault(4);
        pauseVault(5);
        pauseVault(6);
        pauseVault(7);
        pauseVault(8);
        pauseVault(9);
        pauseVault(10);
    }

    /// @notice Helper function to pause old v1 vault completely
    function pauseVault(uint256 vaultId) internal {
        address vault_ = getVaultAddress(vaultId);
        IFluidVaultT1.ConstantViews memory constants_ = IFluidVaultT1(vault_).constantsView();

        // TYPE_1 vault - pause both supply and borrow
        // Pause supply limits
        setSupplyProtocolLimitsPaused(vault_, constants_.supplyToken);

        // Pause borrow limits
        setBorrowProtocolLimitsPaused(vault_, constants_.borrowToken);

        // Pause user operations
        address[] memory supplyTokens = new address[](1);
        supplyTokens[0] = constants_.supplyToken;

        address[] memory borrowTokens = new address[](1);
        borrowTokens[0] = constants_.borrowToken;

        LIQUIDITY.pauseUser(vault_, supplyTokens, borrowTokens);
    }

    /// @notice Action 3: Max restrict deUSD-USDC DEX
    function action3() internal isActionSkippable(3) {
        address deUSD_USDC_DEX = getDexAddress(19);

        // Max restrict supply limits for both tokens
        setSupplyProtocolLimitsPaused(deUSD_USDC_DEX, deUSD_ADDRESS);
        setSupplyProtocolLimitsPaused(deUSD_USDC_DEX, USDC_ADDRESS);

        // Pause user operations
        address[] memory supplyTokens = new address[](2);
        supplyTokens[0] = deUSD_ADDRESS;
        supplyTokens[1] = USDC_ADDRESS;

        LIQUIDITY.pauseUser(deUSD_USDC_DEX, supplyTokens, new address[](0));

        // Set max supply shares to 0 and pause swap and arbitrage
        IFluidDex(deUSD_USDC_DEX).updateMaxSupplyShares(0);
        IFluidDex(deUSD_USDC_DEX).pauseSwapAndArbitrage();
    }

    /// @notice Action 4: Update Lite treasury to Reserve contract
    function action4() internal isActionSkippable(4) {
        // Lite DSA address
        IDSAV2 IETH_V2_DSA = IDSAV2(0x9600A48ed0f931d0c422D574e3275a90D8b22745);

        // Add Governance Timelock as an authorized auth on iETH v2 DSA to allow the timelock to cast spells on Lite DSA
        IETHV2.addDSAAuth(address(this));

        // Update Lite treasury from main treasury to Reserve Contract
        string[] memory targets = new string[](1);
        bytes[] memory encodedSpells = new bytes[](1);

        string memory updateTreasurySignature = "updateTreasury(address)";

        targets[0] = "BASIC-A";
        encodedSpells[0] = abi.encodeWithSignature(
            updateTreasurySignature,
            address(FLUID_RESERVE)
        );

        IETH_V2_DSA.cast(targets, encodedSpells, address(this));
    }

    /// @notice Action 5: Update liquidation penalty on all USDT debt vaults
    function action5() internal isActionSkippable(5) {
        // List of all USDT debt vaults with their new liquidation penalties
        VaultLiquidationPenalty[] memory vaults = new VaultLiquidationPenalty[](8);
        
        // ETH/USDT: 2% -> 1%
        vaults[0] = VaultLiquidationPenalty({vaultId: 12, liquidationPenalty: 1 * 1e2});
        
        // wstETH/USDT: 3% -> 2.5%
        vaults[1] = VaultLiquidationPenalty({vaultId: 15, liquidationPenalty: 250}); // 2.5% = 250 in 1e2 format
        
        // weETH/USDT: 4% -> 3%
        vaults[2] = VaultLiquidationPenalty({vaultId: 20, liquidationPenalty: 3 * 1e2});
        
        // WBTC/USDT: 4% -> 3%
        vaults[3] = VaultLiquidationPenalty({vaultId: 22, liquidationPenalty: 3 * 1e2});
        
        // cbBTC/USDT: 4% -> 3%
        vaults[4] = VaultLiquidationPenalty({vaultId: 30, liquidationPenalty: 3 * 1e2});
        
        // tBTC/USDT: 4% -> 3%
        vaults[5] = VaultLiquidationPenalty({vaultId: 89, liquidationPenalty: 3 * 1e2});
        
        // lBTC/USDT: 5% -> 4%
        vaults[6] = VaultLiquidationPenalty({vaultId: 108, liquidationPenalty: 4 * 1e2});
        
        // USDe-USDtb/USDT (TYPE_2): 3% -> 2.5%
        vaults[7] = VaultLiquidationPenalty({vaultId: 137, liquidationPenalty: 250}); // 2.5% = 250 in 1e2 format

        // Update liquidation penalty for each vault
        for (uint256 i = 0; i < vaults.length; i++) {
            address vaultAddress = getVaultAddress(vaults[i].vaultId);
            IFluidVaultT1(vaultAddress).updateLiquidationPenalty(vaults[i].liquidationPenalty);
        }
    }
    /**
     * |
     * |     Payload Actions End Here      |
     * |__________________________________
     */

    // Token Prices Constants (same as other IGP files)
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
    uint256 public constant syrupUSDT_USD_PRICE = 1.10 * 1e2;
    uint256 public constant syrupUSDC_USD_PRICE = 1.13 * 1e2;

    uint256 public constant FLUID_USD_PRICE = 4.2 * 1e2;

    uint256 public constant RLP_USD_PRICE = 1.18 * 1e2;
    uint256 public constant wstUSR_USD_PRICE = 1.07 * 1e2;
    uint256 public constant XAUT_USD_PRICE = 3_240 * 1e2;
    uint256 public constant PAXG_USD_PRICE = 3_240 * 1e2;
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

