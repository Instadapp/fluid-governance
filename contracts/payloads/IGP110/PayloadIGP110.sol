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

contract PayloadIGP110 is PayloadIGPMain {
    uint256 public constant PROPOSAL_ID = 110;

    function execute() public virtual override {
        super.execute();

        // Action 1: Cleanup allowances from Reserve contract
        action1();

        // Action 2: Set dust limits for syrupUSDT DEX and vaults
        action2();
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

    /// @notice Action 1: Cleanup allowances from Reserve contract
    function action1() internal isActionSkippable(1) {
        address[] memory protocols_ = new address[](44);
        protocols_[0] = 0x6A29A46E21C730DcA1d8b23d637c101cec605C5B;
        protocols_[1] = 0xBFADEA65591235f38809076e14803Ac84AcF3F97;
        protocols_[2] = 0x4045720a33193b4Fe66c94DFbc8D37B0b4D9B469;
        protocols_[3] = 0x3996464c0fCCa8183e13ea5E5e74375e2c8744Dd;
        protocols_[4] = 0xBc345229C1b52e4c30530C614BB487323BA38Da5;
        protocols_[5] = 0x1c2bB46f36561bc4F05A94BD50916496aa501078;
        protocols_[6] = 0x51197586F6A9e2571868b6ffaef308f3bdfEd3aE;
        protocols_[7] = 0xA0F83Fc5885cEBc0420ce7C7b139Adc80c4F4D91;
        protocols_[8] = 0xf55B8e9F0c51Ace009f4b41d03321675d4C643b3;
        protocols_[9] = 0xdF16AdaF80584b2723F3BA1Eb7a601338Ba18c4e;
        protocols_[10] = 0x2411802D8BEA09be0aF8fD8D08314a63e706b29C;
        protocols_[11] = 0x40D9b8417E6E1DcD358f04E3328bCEd061018A82;
        protocols_[12] = 0x40D9b8417E6E1DcD358f04E3328bCEd061018A82;
        protocols_[13] = 0xb4F3bf2d96139563777C0231899cE06EE95Cc946;
        protocols_[14] = 0x1982CC7b1570C2503282d0A0B41F69b3B28fdcc3;
        protocols_[15] = 0x92643E964CA4b2c165a95CA919b0A819acA6D5F1;
        protocols_[16] = 0xF2c8F54447cbd591C396b0Dd7ac15FAF552d0FA4;
        protocols_[17] = 0xeAEf563015634a9d0EE6CF1357A3b205C35e028D;
        protocols_[18] = 0xeAEf563015634a9d0EE6CF1357A3b205C35e028D;
        protocols_[19] = 0x82B27fA821419F5689381b565a8B0786aA2548De;
        protocols_[20] = 0x5C20B550819128074FD538Edf79791733ccEdd18;
        protocols_[21] = 0x9Fb7b4477576Fe5B32be4C1843aFB1e55F251B33;
        protocols_[22] = 0xE6b5D1CdC4935295c84772C4700932b4BFC93274;
        protocols_[23] = 0x3A0b7c8840D74D39552EF53F586dD8c3d1234C40;
        protocols_[24] = 0x6F72895Cf6904489Bcd862c941c3D02a3eE4f03e;
        protocols_[25] = 0x01c7c1c41dea58b043e700eFb23Dc077F12a125e;
        protocols_[26] = 0x1c2bB46f36561bc4F05A94BD50916496aa501078;
        protocols_[27] = 0x51197586F6A9e2571868b6ffaef308f3bdfEd3aE;
        protocols_[28] = 0xbEC491FeF7B4f666b270F9D5E5C3f443cBf20991;
        protocols_[29] = 0xeAbBfca72F8a8bf14C4ac59e69ECB2eB69F0811C;
        protocols_[30] = 0xf55B8e9F0c51Ace009f4b41d03321675d4C643b3;
        protocols_[31] = 0xdF16AdaF80584b2723F3BA1Eb7a601338Ba18c4e;
        protocols_[32] = 0xBFADEA65591235f38809076e14803Ac84AcF3F97;
        protocols_[33] = 0x4045720a33193b4Fe66c94DFbc8D37B0b4D9B469;
        protocols_[34] = 0xb4F3bf2d96139563777C0231899cE06EE95Cc946;
        protocols_[35] = 0x0C8C77B7FF4c2aF7F6CEBbe67350A490E3DD6cB3;
        protocols_[36] = 0xE16A6f5359ABB1f61cE71e25dD0932e3E00B00eB;
        protocols_[37] = 0x1982CC7b1570C2503282d0A0B41F69b3B28fdcc3;
        protocols_[38] = 0x92643E964CA4b2c165a95CA919b0A819acA6D5F1;
        protocols_[39] = 0xF2c8F54447cbd591C396b0Dd7ac15FAF552d0FA4;
        protocols_[40] = 0x3996464c0fCCa8183e13ea5E5e74375e2c8744Dd;
        protocols_[41] = 0xBc345229C1b52e4c30530C614BB487323BA38Da5;
        protocols_[42] = 0x3A0b7c8840D74D39552EF53F586dD8c3d1234C40;
        protocols_[43] = 0x6F72895Cf6904489Bcd862c941c3D02a3eE4f03e;

        address[] memory tokens_ = new address[](44);
        tokens_[0] = 0x40D16FC0246aD3160Ccc09B8D0D3A2cD28aE6C2f; // GHO
        tokens_[1] = 0x9D39A5DE30e57443BfF2A8307A4256c8797A3497; // sUSDe
        tokens_[2] = 0x9D39A5DE30e57443BfF2A8307A4256c8797A3497; // sUSDe
        tokens_[3] = 0x9D39A5DE30e57443BfF2A8307A4256c8797A3497; // sUSDe
        tokens_[4] = 0x9D39A5DE30e57443BfF2A8307A4256c8797A3497; // sUSDe
        tokens_[5] = 0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0; // wstETH
        tokens_[6] = 0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0; // wstETH
        tokens_[7] = 0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0; // wstETH
        tokens_[8] = 0xCd5fE23C85820F7B72D0926FC9b05b43E359b7ee; // weETH
        tokens_[9] = 0xCd5fE23C85820F7B72D0926FC9b05b43E359b7ee; // weETH
        tokens_[10] = 0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0; // wstETH
        tokens_[11] = 0xCd5fE23C85820F7B72D0926FC9b05b43E359b7ee; // weETH
        tokens_[12] = 0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0; // wstETH
        tokens_[13] = 0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0; // wstETH
        tokens_[14] = 0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0; // wstETH
        tokens_[15] = 0xCd5fE23C85820F7B72D0926FC9b05b43E359b7ee; // weETH
        tokens_[16] = 0xCd5fE23C85820F7B72D0926FC9b05b43E359b7ee; // weETH
        tokens_[17] = 0xCd5fE23C85820F7B72D0926FC9b05b43E359b7ee; // weETH
        tokens_[18] = 0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0; // wstETH
        tokens_[19] = 0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0; // wstETH
        tokens_[20] = 0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0; // wstETH
        tokens_[21] = 0xdAC17F958D2ee523a2206206994597C13D831ec7; // USDT
        tokens_[22] = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48; // USDC
        tokens_[23] = 0xdAC17F958D2ee523a2206206994597C13D831ec7; // USDT
        tokens_[24] = 0xdAC17F958D2ee523a2206206994597C13D831ec7; // USDT
        tokens_[25] = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48; // USDC
        tokens_[26] = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48; // USDC
        tokens_[27] = 0xdAC17F958D2ee523a2206206994597C13D831ec7; // USDT
        tokens_[28] = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48; // USDC
        tokens_[29] = 0xdAC17F958D2ee523a2206206994597C13D831ec7; // USDT
        tokens_[30] = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48; // USDC
        tokens_[31] = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48; // USDC
        tokens_[32] = 0xdAC17F958D2ee523a2206206994597C13D831ec7; // USDT
        tokens_[33] = 0xdAC17F958D2ee523a2206206994597C13D831ec7; // USDT
        tokens_[34] = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48; // USDC
        tokens_[35] = 0xdAC17F958D2ee523a2206206994597C13D831ec7; // USDT
        tokens_[36] = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48; // USDC
        tokens_[37] = 0xdAC17F958D2ee523a2206206994597C13D831ec7; // USDT
        tokens_[38] = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48; // USDC
        tokens_[39] = 0xdAC17F958D2ee523a2206206994597C13D831ec7; // USDT
        tokens_[40] = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48; // USDC
        tokens_[41] = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48; // USDC
        tokens_[42] = 0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599; // WBTC
        tokens_[43] = 0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599; // WBTC

        // Call revoke() on ReserveContractProxy to cleanup allowances
        IFluidReserveContract(RESERVE_CONTRACT_PROXY).revoke(protocols_, tokens_);
    }

    /// @notice Action 2: Set dust limits for syrupUSDT DEX and vaults
    function action2() internal isActionSkippable(2) {
        {
            // dust limits for SYRUPUSDT-USDT DEX (DEX ID 40)
            address syrupUSDT_USDT_DEX = getDexAddress(40);
            // SYRUPUSDT-USDT DEX - Dust limits
            DexConfig memory DEX_syrupUSDT_USDT = DexConfig({
                dex: syrupUSDT_USDT_DEX,
                tokenA: syrupUSDT_ADDRESS,
                tokenB: USDT_ADDRESS,
                smartCollateral: true,
                smartDebt: false,
                baseWithdrawalLimitInUSD: 10_000, // $10k
                baseBorrowLimitInUSD: 0, // $0
                maxBorrowLimitInUSD: 0 // $0
            });
            setDexLimits(DEX_syrupUSDT_USDT); // Smart Collateral

            DEX_FACTORY.setDexAuth(syrupUSDT_USDT_DEX, TEAM_MULTISIG, true);
        }
        {
            // dust limits for SYRUPUSDT-USDT/USDT vault (Vault ID 149)
            address syrupUSDT_USDT__USDT_VAULT = getVaultAddress(149);
            // [TYPE 2] SYRUPUSDT-USDT<>USDT | smart collateral & debt, all dust
            VaultConfig memory VAULT_syrupUSDT_USDT__USDT = VaultConfig({
                vault: syrupUSDT_USDT__USDT_VAULT,
                vaultType: VAULT_TYPE.TYPE_2,
                supplyToken: address(0),
                borrowToken: USDT_ADDRESS,
                baseWithdrawalLimitInUSD: 0,   // $7k
                baseBorrowLimitInUSD: 7_000,       // $7k
                maxBorrowLimitInUSD: 9_000         // $9k
            });

            setVaultLimits(VAULT_syrupUSDT_USDT__USDT); // TYPE_2 => 149
            VAULT_FACTORY.setVaultAuth(
                syrupUSDT_USDT__USDT_VAULT,
                TEAM_MULTISIG,
                true
            );
        }
        {
            // dust limits for SYRUPUSDT/USDC vault (Vault ID 150)
            address syrupUSDT__USDC_VAULT = getVaultAddress(150);
            // [TYPE 1] SYRUPUSDT/USDC vault - Dust limits
            VaultConfig memory VAULT_syrupUSDT__USDC = VaultConfig({
                vault: syrupUSDT__USDC_VAULT,
                vaultType: VAULT_TYPE.TYPE_1,
                supplyToken: syrupUSDT_ADDRESS,
                borrowToken: USDC_ADDRESS,
                baseWithdrawalLimitInUSD: 7_000, // $7k
                baseBorrowLimitInUSD: 7_000, // $7k
                maxBorrowLimitInUSD: 9_000 // $9k
            });

            setVaultLimits(VAULT_syrupUSDT__USDC);
            VAULT_FACTORY.setVaultAuth(
                syrupUSDT__USDC_VAULT,
                TEAM_MULTISIG,
                true
            );
        }
        {
            // dust limits for SYRUPUSDT/USDT vault (Vault ID 151)
            address syrupUSDT__USDT_VAULT = getVaultAddress(151);
            // [TYPE 1] SYRUPUSDT/USDT vault - Dust limits
            VaultConfig memory VAULT_syrupUSDT__USDT = VaultConfig({
                vault: syrupUSDT__USDT_VAULT,
                vaultType: VAULT_TYPE.TYPE_1,
                supplyToken: syrupUSDT_ADDRESS,
                borrowToken: USDT_ADDRESS,
                baseWithdrawalLimitInUSD: 7_000, // $7k
                baseBorrowLimitInUSD: 7_000, // $7k
                maxBorrowLimitInUSD: 9_000 // $9k
            });

            setVaultLimits(VAULT_syrupUSDT__USDT);
            VAULT_FACTORY.setVaultAuth(
                syrupUSDT__USDT_VAULT,
                TEAM_MULTISIG,
                true
            );
        }
        {
            // dust limits for SYRUPUSDT/GHO vault (Vault ID 152)
            address syrupUSDT__GHO_VAULT = getVaultAddress(152);
            // [TYPE 1] SYRUPUSDT/GHO vault - Dust limits
            VaultConfig memory VAULT_syrupUSDT__GHO = VaultConfig({
                vault: syrupUSDT__GHO_VAULT,
                vaultType: VAULT_TYPE.TYPE_1,
                supplyToken: syrupUSDT_ADDRESS,
                borrowToken: GHO_ADDRESS,
                baseWithdrawalLimitInUSD: 7_000, // $7k
                baseBorrowLimitInUSD: 7_000, // $7k
                maxBorrowLimitInUSD: 9_000 // $9k
            });

            setVaultLimits(VAULT_syrupUSDT__GHO);
            VAULT_FACTORY.setVaultAuth(
                syrupUSDT__GHO_VAULT,
                TEAM_MULTISIG,
                true
            );
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

    uint256 public constant FLUID_USD_PRICE = 4.2 * 1e2;

    uint256 public constant RLP_USD_PRICE = 1.18 * 1e2;
    uint256 public constant wstUSR_USD_PRICE = 1.07 * 1e2;
    uint256 public constant XAUT_USD_PRICE = 3_240 * 1e2;
    uint256 public constant PAXG_USD_PRICE = 3_240 * 1e2;

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
        } else if (token == syrupUSDT_ADDRESS) {
            usdPrice = syrupUSDT_USD_PRICE;
            decimals = 6;
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
