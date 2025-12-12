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

contract PayloadIGP114 is PayloadIGPMain {
    uint256 public constant PROPOSAL_ID = 114;

    function execute() public virtual override {
        super.execute();

        // Action 1: Withdraw 2.5M GHO rewards from fGHO to Team Multisig
        action1();

        // Action 2: Set launch limits for dexV2 and moneyMarket proxies
        action2();

        // Action 3: Set launch limits for OSETH related protocols
        action3();

        // Action 4: (to be implemented)
        action4();
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

    /// @notice Action 1: Withdraw 2.5M GHO rewards from fGHO to Team Multisig
    function action1() internal isActionSkippable(1) {
        string[] memory targets = new string[](1);
        bytes[] memory encodedSpells = new bytes[](1);

        string memory withdrawSignature = "withdraw(address,uint256,address,uint256,uint256)";

        // Spell 1: Withdraw 2.5M GHO from fGHO (redeems fGHO to GHO) and send to Team Multisig
        {
            uint256 GHO_AMOUNT = 2_500_000 * 1e18; // 2.5M GHO
            targets[0] = "BASIC-D-V2";
            encodedSpells[0] = abi.encodeWithSignature(
                withdrawSignature,
                F_GHO_ADDRESS,
                GHO_AMOUNT,
                TEAM_MULTISIG,
                0,
                0
            );
        }

        IDSAV2(TREASURY).cast(targets, encodedSpells, address(this));
    }

    /// @notice Action 2: Set launch limits for DEX v2 and Money Market proxies
    function action2() internal isActionSkippable(2) {
        // ---------------------------------------------------------------------
        // Borrow (debt) limits: ETH, USDC, USDT -> $5M base, $10M max
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
                            baseBorrowLimitInUSD: 1_000_000, // $1M
                            maxBorrowLimitInUSD: 2_000_000 // $2M
                        });

                    setBorrowProtocolLimits(borrowConfig);
                }
            }
        }

        // ---------------------------------------------------------------------
        // Supply (collateral) limits: ETH, USDC, USDT, cbBTC, WBTC -> $2M base
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
                            baseWithdrawalLimitInUSD: 2_000_000 // $2M
                        });

                    setSupplyProtocolLimits(supplyConfig);
                }
            }
        }
    }

    /// @notice Action 3: Set launch limits for OSETH related protocols
    function action3() internal isActionSkippable(3) {
        // OSETH-ETH DEX (id 43) - Launch limits
        address OSETH_ETH_DEX = getDexAddress(43);
        {
            DexConfig memory DEX_OSETH_ETH = DexConfig({
                dex: OSETH_ETH_DEX,
                tokenA: OSETH_ADDRESS,
                tokenB: ETH_ADDRESS,
                smartCollateral: true,
                smartDebt: false,
                baseWithdrawalLimitInUSD: 8_000_000, // $8M base withdraw
                baseBorrowLimitInUSD: 0,
                maxBorrowLimitInUSD: 0
            });
            setDexLimits(DEX_OSETH_ETH);
        }

        // Vault ID 153: OSETH / USDC (TYPE_1) - Launch limits
        {
            address OSETH_USDC_VAULT = getVaultAddress(153);
            VaultConfig memory VAULT_OSETH_USDC = VaultConfig({
                vault: OSETH_USDC_VAULT,
                vaultType: VAULT_TYPE.TYPE_1,
                supplyToken: OSETH_ADDRESS,
                borrowToken: USDC_ADDRESS,
                baseWithdrawalLimitInUSD: 8_000_000, // $8M
                baseBorrowLimitInUSD: 5_000_000, // $5M
                maxBorrowLimitInUSD: 10_000_000 // $10M
            });
            setVaultLimits(VAULT_OSETH_USDC);
        }

        // Vault ID 154: OSETH / USDT (TYPE_1) - Launch limits
        {
            address OSETH_USDT_VAULT = getVaultAddress(154);
            VaultConfig memory VAULT_OSETH_USDT = VaultConfig({
                vault: OSETH_USDT_VAULT,
                vaultType: VAULT_TYPE.TYPE_1,
                supplyToken: OSETH_ADDRESS,
                borrowToken: USDT_ADDRESS,
                baseWithdrawalLimitInUSD: 8_000_000, // $8M
                baseBorrowLimitInUSD: 5_000_000, // $5M
                maxBorrowLimitInUSD: 10_000_000 // $10M
            });
            setVaultLimits(VAULT_OSETH_USDT);
        }

        // Vault ID 155: OSETH / GHO (TYPE_1) - Launch limits
        {
            address OSETH_GHO_VAULT = getVaultAddress(155);
            VaultConfig memory VAULT_OSETH_GHO = VaultConfig({
                vault: OSETH_GHO_VAULT,
                vaultType: VAULT_TYPE.TYPE_1,
                supplyToken: OSETH_ADDRESS,
                borrowToken: GHO_ADDRESS,
                baseWithdrawalLimitInUSD: 8_000_000, // $8M
                baseBorrowLimitInUSD: 5_000_000, // $5M
                maxBorrowLimitInUSD: 10_000_000 // $10M
            });
            setVaultLimits(VAULT_OSETH_GHO);
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
                    baseWithdrawalLimitInUSD: 8_000_000, // $8M
                    baseBorrowLimitInUSD: 0,
                    maxBorrowLimitInUSD: 0
                });
                setVaultLimits(VAULT_OSETH_USDC_USDT);
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
                        maxBorrowLimit: 5_000_000 * 1e18 // ~5M shares (~$10M)
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
                    baseWithdrawalLimitInUSD: 8_000_000, // $8M
                    baseBorrowLimitInUSD: 0,
                    maxBorrowLimitInUSD: 0
                });
                setVaultLimits(VAULT_OSETH_USDC_USDT_CONC);
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
                        maxBorrowLimit: 5_000_000 * 1e18 // ~5M shares (~$10M)
                    });
                setDexBorrowProtocolLimitsInShares(config_);
            }
        }

        // Vault ID 158: oseth-eth <> wsteth-eth (TYPE_4) - Set borrow launch limits for WSTETH-ETH DEX (id 1)
        {
            address OSETH_ETH__wstETH_ETH_VAULT = getVaultAddress(158);
            address WSTETH_ETH_DEX = getDexAddress(1);

            // For TYPE_4, borrow limits set via DexBorrowProtocolConfigInShares (launch limits)
            DexBorrowProtocolConfigInShares
                memory config_ = DexBorrowProtocolConfigInShares({
                    dex: WSTETH_ETH_DEX,
                    protocol: OSETH_ETH__wstETH_ETH_VAULT,
                    expandPercent: 30 * 1e2, // 30%
                    expandDuration: 6 hours, // 6 hours
                    baseBorrowLimit: 1_333 * 1e18, // ~1,333 shares (~$8M)
                    maxBorrowLimit: 4_167 * 1e18 // ~4,167 shares (~$25M)
                });
            setDexBorrowProtocolLimitsInShares(config_);
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

