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

/// @notice IGP123: Launch limits for REUSD protocols, DEX V2 soft launch (re-send), rollback module on LL, and DexFactory cleanup
contract PayloadIGP123 is PayloadIGPMain {
    uint256 public constant PROPOSAL_ID = 123;

    // TODO: Set after rollback module deployment
    address public rollbackModuleAddress = address(0);

    function setRollbackModuleAddress(
        address rollbackModuleAddress_
    ) external {
        require(msg.sender == TEAM_MULTISIG, "not-team-multisig");
        rollbackModuleAddress = rollbackModuleAddress_;
    }

    function execute() public virtual override {
        super.execute();

        // Action 1: Launch limits for REUSD vaults (160-164) + remove Team MS auth
        action1();

        // Action 2: Launch limits for REUSD-USDT DEX (44) + remove Team MS auth
        action2();

        // Action 3: DEX V2 soft launch - re-send limits, auth, and updated admin implementations
        action3();

        // Action 4: Roll out rollbackModule on Liquidity Layer
        action4();

        // Action 5: Cleanup - disable old DexDeploymentLogic on DexFactory
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
                baseWithdrawalLimitInUSD: 7_500_000, // to confirm $7.5M
                baseBorrowLimitInUSD: 5_000_000, // to confirm $5M
                maxBorrowLimitInUSD: 10_000_000 // to confirm $10M
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
                baseWithdrawalLimitInUSD: 7_500_000, // to confirm $7.5M
                baseBorrowLimitInUSD: 5_000_000, // to confirm $5M
                maxBorrowLimitInUSD: 10_000_000 // to confirm $10M
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
                baseWithdrawalLimitInUSD: 7_500_000, // to confirm $7.5M
                baseBorrowLimitInUSD: 5_000_000, // to confirm $5M
                maxBorrowLimitInUSD: 10_000_000 // to confirm $10M
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
                baseWithdrawalLimitInUSD: 7_500_000, // to confirm $7.5M
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
                    baseBorrowLimit: 2_500_000 * 1e18, // to confirm ~2.5M shares (~$5M)
                    maxBorrowLimit: 5_000_000 * 1e18 // to confirm ~5M shares (~$10M)
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
                baseBorrowLimitInUSD: 5_000_000, // to confirm $5M
                maxBorrowLimitInUSD: 10_000_000 // to confirm $10M
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
            baseWithdrawalLimitInUSD: 5_000_000, // TODO: confirm $5M per token
            baseBorrowLimitInUSD: 0,
            maxBorrowLimitInUSD: 0
        });
        setDexLimits(DEX_REUSD_USDT);

        // TODO: confirm max supply shares
        uint256 maxSupplyShares_ = 10_000_000 * 1e18; // ~$10M equivalent shares
        IFluidDex(REUSD_USDT_DEX).updateMaxSupplyShares(maxSupplyShares_);

        DEX_FACTORY.setDexAuth(REUSD_USDT_DEX, TEAM_MULTISIG, false);
    }

    /// @notice Action 3: DEX V2 soft launch - re-send limits ($50k MM, $75k DEX), auth, and updated admin implementations
    function action3() internal isActionSkippable(3) {
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

    /// @notice Action 4: Roll out rollbackModule on Liquidity Layer (audited by Statemind)
    function action4() internal isActionSkippable(4) {
        address newImplementation_ = PayloadIGP123(ADDRESS_THIS)
            .rollbackModuleAddress();
        require(newImplementation_ != address(0), "rollback-module-not-set");

        // TODO: Set the correct function selectors for the rollback module after deployment
        bytes4[] memory sigs_ = new bytes4[](1);
        sigs_[0] = bytes4(
            keccak256("rollback(address,address,address,uint256)")
        );

        IInfiniteProxy(address(LIQUIDITY)).addImplementation(
            newImplementation_,
            sigs_
        );
    }

    /// @notice Action 5: Cleanup - disable old DexT1DeploymentLogic on DexFactory
    function action5() internal isActionSkippable(5) {
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
