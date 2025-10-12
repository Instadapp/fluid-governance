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

contract PayloadIGP109 is PayloadIGPMain {
    uint256 public constant PROPOSAL_ID = 109;

    function execute() public virtual override {
        super.execute();

        // Action 1: Update CF, LT, and LML for sUSDE Vaults on mainnet
        action1();

        // Action 2: Update CF, LT, LML, and LP for wstUSR Vaults
        action2();

        // Action 3: Transfer $FLUID to Team Multisig for Mainnet, Plasma, Arbitrum Rewards
        action3();

        // Action 4: Transfer $FLUID to Team Multisig for Solana Rewards
        action4();

        // Action 5: Pause limits for cbBTC-USDT DEX and its vaults
        action5();

        // Action 6: Pause limits for cbBTC-ETH DEX and its vault
        action6();

        // Action 7: Set limits for fSUSDs
        action7();

        // Action 8: Pause limits for sUSDS vaults
        action8();

        // Action 9: Pause limits for sUSDS DEX and Smart Lending
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

    /// @notice Action 1: Update CF, LT, and LML for sUSDE on mainnet
    function action1() internal isActionSkippable(1) {
        uint256 CF = 92 * 1e2; // 92% Collateral Factor
        uint256 LT = 94 * 1e2; // 94% Liquidation Threshold
        uint256 LML = 96 * 1e2; // 96% Liquidation Max Limit

        // Vault IDs to update: 17, 18, 50, 56, 92, 98, 125, 126
        uint256[] memory vaultIds = new uint256[](7);
        vaultIds[0] = 17;
        vaultIds[1] = 18;
        vaultIds[2] = 50;
        vaultIds[3] = 56;
        vaultIds[4] = 92;
        vaultIds[5] = 98;
        vaultIds[6] = 125;
        vaultIds[7] = 126;

        for (uint256 i = 0; i < vaultIds.length; i++) {
            address vaultAddress = getVaultAddress(vaultIds[i]);

            IFluidVaultT1(vaultAddress).updateLiquidationMaxLimit(LML);
            IFluidVaultT1(vaultAddress).updateLiquidationThreshold(LT);
            IFluidVaultT1(vaultAddress).updateCollateralFactor(CF);
        }
    }

    /// @notice Action 2: Update CF, LT, LML, and LP for wstUSR vaults
    function action2() internal isActionSkippable(2) {
        uint256 CF = 92 * 1e2; // 92% Collateral Factor
        uint256 LT = 94 * 1e2; // 94% Liquidation Threshold
        uint256 LML = 96 * 1e2; // 96% Liquidation Max Limit
        uint256 LP = 2 * 1e2; // 2% Liquidation Penalty

        // Vault IDs to update: 110, 111, 112, 133, 134, 135
        uint256[] memory vaultIds = new uint256[](6);
        vaultIds[0] = 110;
        vaultIds[1] = 111;
        vaultIds[2] = 112;
        vaultIds[3] = 133;
        vaultIds[4] = 134;
        vaultIds[5] = 135;
        vaultIds[6] = 142;
        vaultIds[7] = 143;
        vaultIds[8] = 144;

        for (uint256 i = 0; i < vaultIds.length; i++) {
            address vaultAddress = getVaultAddress(vaultIds[i]);

            // Update in safe order: LML first, then LT, then CF, then LP
            IFluidVaultT1(vaultAddress).updateLiquidationMaxLimit(LML);
            IFluidVaultT1(vaultAddress).updateLiquidationThreshold(LT);
            IFluidVaultT1(vaultAddress).updateCollateralFactor(CF);
            IFluidVaultT1(vaultAddress).updateLiquidationPenalty(LP);
        }
    }

    /// @notice Action 3: Transfer $FLUID to Team Multisig for for Mainnet, Plasma, Arbitrum Rewards
    function action3() internal isActionSkippable(3) {
        string[] memory targets = new string[](1);
        bytes[] memory encodedSpells = new bytes[](1);

        string
            memory withdrawSignature = "withdraw(address,uint256,address,uint256,uint256)";

        // Spell 1: Transfer FLUID to Team Multisig for Mainnet, Plasma, Arbitrum Rewards
        {
            uint256 FLUID_AMOUNT = 1_000_000 * 1e18; // 1M FLUID tokens
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

    /// @notice Action 4: Transfer $FLUID to Team Multisig for Solana Rewards
    function action4() internal isActionSkippable(4) {
        string[] memory targets = new string[](1);
        bytes[] memory encodedSpells = new bytes[](1);

        string
            memory withdrawSignature = "withdraw(address,uint256,address,uint256,uint256)";

        // Spell 1: Transfer FLUID to Team Multisig for Solana Rewards
        {
            uint256 FLUID_AMOUNT = 1_000_000 * 1e18; // 1M FLUID tokens
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

    /// @notice Action 5: Pause limits for cbBTC-USDT DEX and its vault
    function action5() internal isActionSkippable(5) {
        // Pause limits for cbBTC-USDT T4 Vault (Vault 105)
        {
            address cbBTC_USDT__cbBTC_USDT_VAULT_ADDRESS = getVaultAddress(105);
            address cbBTC_USDT_DEX_ADDRESS = getDexAddress(22);
            // Pause supply and borrow limits for cbBTC
            setSupplyProtocolLimitsPaused(
                cbBTC_USDT__cbBTC_USDT_VAULT_ADDRESS,
                cbBTC_ADDRESS
            );
            setSupplyProtocolLimitsPaused(
                cbBTC_USDT__cbBTC_USDT_VAULT_ADDRESS,
                USDT_ADDRESS
            );
            setBorrowProtocolLimitsPaused(
                cbBTC_USDT__cbBTC_USDT_VAULT_ADDRESS,
                cbBTC_ADDRESS
            );
            setSupplyProtocolLimitsPaused(
                cbBTC_USDT__cbBTC_USDT_VAULT_ADDRESS,
                USDT_ADDRESS
            );
            // Pause vault operations at DEX level
            IFluidDex(cbBTC_USDT_DEX_ADDRESS).pauseUser(
                cbBTC_USDT__cbBTC_USDT_VAULT_ADDRESS,
                true,
                true
            );
        }

        // Pause limits for cbBTC-USDT DEX (DEX 22)
        {
            address cbBTC_USDT_DEX_ADDRESS = getDexAddress(22);
            // Pause supply and borrow limits for both tokens
            setSupplyProtocolLimitsPaused(
                cbBTC_USDT_DEX_ADDRESS,
                cbBTC_ADDRESS
            );
            setSupplyProtocolLimitsPaused(cbBTC_USDT_DEX_ADDRESS, USDT_ADDRESS);
            setBorrowProtocolLimitsPaused(
                cbBTC_USDT_DEX_ADDRESS,
                cbBTC_ADDRESS
            );
            setBorrowProtocolLimitsPaused(cbBTC_USDT_DEX_ADDRESS, USDT_ADDRESS);

            // Pause user operations
            address[] memory supplyTokens = new address[](2);
            supplyTokens[0] = cbBTC_ADDRESS;
            supplyTokens[1] = USDT_ADDRESS;

            address[] memory borrowTokens = new address[](2);
            borrowTokens[0] = cbBTC_ADDRESS;
            borrowTokens[1] = USDT_ADDRESS;

            LIQUIDITY.pauseUser(
                cbBTC_USDT_DEX_ADDRESS,
                supplyTokens,
                borrowTokens
            );
        }
    }

    /// @notice Action 6: Pause limits for cbBTC-ETH DEX and its vault
    function action6() internal isActionSkippable(6) {
        // Pause limits for cbBTC-ETH T4 Vault (Vault 106)
        {
            address cbBTC_ETH__cbBTC_ETH_VAULT_ADDRESS = getVaultAddress(106);
            address cbBTC_ETH_DEX_ADDRESS = getDexAddress(26);
            // Pause supply and borrow limits for cbBTC
            setSupplyProtocolLimitsPaused(
                cbBTC_ETH__cbBTC_ETH_VAULT_ADDRESS,
                cbBTC_ADDRESS
            );
            setSupplyProtocolLimitsPaused(
                cbBTC_ETH__cbBTC_ETH_VAULT_ADDRESS,
                ETH_ADDRESS
            );
            setBorrowProtocolLimitsPaused(
                cbBTC_ETH__cbBTC_ETH_VAULT_ADDRESS,
                cbBTC_ADDRESS
            );
            setBorrowProtocolLimitsPaused(
                cbBTC_ETH__cbBTC_ETH_VAULT_ADDRESS,
                ETH_ADDRESS
            );

            // Pause vault operations at DEX level
            IFluidDex(cbBTC_ETH_DEX_ADDRESS).pauseUser(
                cbBTC_ETH__cbBTC_ETH_VAULT_ADDRESS,
                true,
                true
            );
        }

        // Pause limits for cbBTC-ETH DEX (DEX 26)
        {
            address cbBTC_ETH_DEX_ADDRESS = getDexAddress(26);
            // Pause supply and borrow limits for both tokens
            setSupplyProtocolLimitsPaused(cbBTC_ETH_DEX_ADDRESS, cbBTC_ADDRESS);
            setSupplyProtocolLimitsPaused(cbBTC_ETH_DEX_ADDRESS, ETH_ADDRESS);
            setBorrowProtocolLimitsPaused(cbBTC_ETH_DEX_ADDRESS, cbBTC_ADDRESS);
            setBorrowProtocolLimitsPaused(cbBTC_ETH_DEX_ADDRESS, ETH_ADDRESS);

            // Pause user operations
            address[] memory supplyTokens = new address[](2);
            supplyTokens[0] = cbBTC_ADDRESS;
            supplyTokens[1] = ETH_ADDRESS;

            address[] memory borrowTokens = new address[](2);
            borrowTokens[0] = cbBTC_ADDRESS;
            borrowTokens[1] = ETH_ADDRESS;

            LIQUIDITY.pauseUser(
                cbBTC_ETH_DEX_ADDRESS,
                supplyTokens,
                borrowTokens
            );
        }
    }

    /// @notice Action 7: Set limits for fSUSDs
    function action7() internal isActionSkippable(7) {
        IFTokenAdmin fSUSDs_ADDRESS = IFTokenAdmin(address(F_SUSDs_ADDRESS));

        SupplyProtocolConfig
            memory protocolConfigTokenB_ = SupplyProtocolConfig({
                protocol: address(fSUSDs_ADDRESS),
                supplyToken: sUSDs_ADDRESS,
                expandPercent: 25 * 1e2, // 25%
                expandDuration: 6 hours, // 6 hours
                baseWithdrawalLimitInUSD: 50_000 // $50K
            });

        setSupplyProtocolLimits(protocolConfigTokenB_);
    }

    /// @notice Action 8: Pause limits for sUSDS vaults
    function action8() internal isActionSkippable(8) {
        // Pause limits for ETH-sUSDS T1 Vault (Vault 84)
        {
            address ETH_sUSDS_VAULT_ADDRESS = getVaultAddress(84);
            // [TYPE 1] ETH<>sUSDs | collateral & debt
            Vault memory VAULT_ETH_sUSDs = Vault({
                vault: ETH_sUSDS_VAULT_ADDRESS,
                vaultType: TYPE.TYPE_1,
                supplyToken: ETH_ADDRESS,
                borrowToken: sUSDs_ADDRESS,
                baseWithdrawalLimitInUSD: 90, // $90
                baseBorrowLimitInUSD: 4, // $4
                maxBorrowLimitInUSD: 10 // $10
            });

            setVaultLimits(VAULT_ETH_sUSDs); // TYPE_1 => 84
        }

        // Pause limits for wstETH-sUSDS T1 Vault (Vault 85)
        {
            address wstETH_sUSDs_VAULT = getVaultAddress(85);

            // [TYPE 1] wstETH<>sUSDs | collateral & debt
            Vault memory VAULT_wstETH_sUSDs = Vault({
                vault: wstETH_sUSDs_VAULT,
                vaultType: TYPE.TYPE_1,
                supplyToken: wstETH_ADDRESS,
                borrowToken: sUSDs_ADDRESS,
                baseWithdrawalLimitInUSD: 100_000, // $100k
                baseBorrowLimitInUSD: 10_000, // $10k
                maxBorrowLimitInUSD: 30_000 // $30k
            });

            setVaultLimits(VAULT_wstETH_sUSDs); // TYPE_1 => 85
        }

        // Pause limits for cbBTC-sUSDS T1 Vault (Vault 86)
        {
            address cbBTC_sUSDS_VAULT_ADDRESS = getVaultAddress(86);
            // Pause supply and borrow limits for sUSDs
            setSupplyProtocolLimitsPaused(
                cbBTC_sUSDS_VAULT_ADDRESS,
                cbBTC_ADDRESS
            );
            setBorrowProtocolLimitsPaused(
                cbBTC_sUSDS_VAULT_ADDRESS,
                sUSDs_ADDRESS
            );
        }

        // Pause limits for weETH-sUSDS T1 Vault (Vault 91)
        {
            address weETH_sUSDS_VAULT_ADDRESS = getVaultAddress(91);
            // [TYPE 1] weETH<>sUSDs | collateral & debt
            Vault memory VAULT_weETH_sUSDs = Vault({
                vault: weETH_sUSDS_VAULT_ADDRESS,
                vaultType: TYPE.TYPE_1,
                supplyToken: weETH_ADDRESS,
                borrowToken: sUSDs_ADDRESS,
                baseWithdrawalLimitInUSD: 60, // $60
                baseBorrowLimitInUSD: 4, // $4
                maxBorrowLimitInUSD: 10 // $10
            });

            setVaultLimits(VAULT_weETH_sUSDs); // TYPE_1 => 91
        }
    }

    /// @notice Action 9: Pause limits for sUSDS DEX and Smart Lending
    function action9() internal isActionSkippable(9) {
        // Pause limits for sUSDS DEX (DEX 31)
        {
            address sUSDS_USDT_DEX_ADDRESS = getDexAddress(31);
            // Pause supply and borrow limits for both tokens
            setSupplyProtocolLimitsPaused(
                sUSDS_USDT_DEX_ADDRESS,
                sUSDs_ADDRESS
            );
            setSupplyProtocolLimitsPaused(
                sUSDS_USDT_DEX_ADDRESS,
                USDT_ADDRESS
            );
            setBorrowProtocolLimitsPaused(
                sUSDS_USDT_DEX_ADDRESS,
                sUSDs_ADDRESS
            );
            setBorrowProtocolLimitsPaused(
                sUSDS_USDT_DEX_ADDRESS,
                USDT_ADDRESS
            );
                // Pause user operations
                address[] memory supplyTokens = new address[](2);
                supplyTokens[0] = sUSDs_ADDRESS;
                supplyTokens[1] = USDT_ADDRESS;

                address[] memory borrowTokens = new address[](2);
                borrowTokens[0] = sUSDs_ADDRESS;
                borrowTokens[1] = USDT_ADDRESS;

                LIQUIDITY.pauseUser(
                    sUSDS_USDT_DEX_ADDRESS,
                    supplyTokens,
                borrowTokens
            );
        }

        // Pause limits for sUSDS Smart Lending (Smart Lending 31)
        {
            address sUSDS_SMART_LENDING_ADDRESS = getSmartLendingAddress(31);
            // Pause supply and borrow limits for both tokens
            setSupplyProtocolLimitsPaused(
                sUSDS_SMART_LENDING_ADDRESS,
                sUSDs_ADDRESS
            );
            setBorrowProtocolLimitsPaused(
                sUSDS_SMART_LENDING_ADDRESS,
                sUSDs_ADDRESS
            );
        }

        address sUSDS_USDT_SL_ADDRESS = getSmartLendingAddress(31);
        {
            // USDC-BOLD DEX
            {
                setSupplyProtocolLimitsPaused(sUSDS_USDT_SL_ADDRESS, sUSDs_ADDRESS);

                setSupplyProtocolLimitsPaused(sUSDS_USDT_SL_ADDRESS, USDT_ADDRESS);
            }
        }

        {
            // Pause user supply and borrow
            address[] memory supplyTokens = new address[](2);
            supplyTokens[0] = sUSDs_ADDRESS;
            supplyTokens[1] = USDT_ADDRESS;

            address[] memory borrowTokens = new address[](0);

            // Pause the user operations
            LIQUIDITY.pauseUser(sUSDS_USDT_SL_ADDRESS, supplyTokens, borrowTokens);
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
