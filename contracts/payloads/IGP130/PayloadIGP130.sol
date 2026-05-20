// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.21;
pragma experimental ABIEncoderV2;

import {IERC20} from "../common/interfaces/IERC20.sol";
import {IFluidReserveContractV2} from "../common/interfaces/IFluidReserveContract.sol";
import {
    AdminModuleStructs as FluidLiquidityAdminStructs
} from "../common/interfaces/IFluidLiquidity.sol";
import {PayloadIGPPriceHelpers} from "../common/pricehelpers.sol";

/// @notice IGP130: (1) Collect Liquidity Layer revenue into the Reserve
///         Contract and forward to Team Multisig to cover Fluid Lite ETH
///         (iETHv2) user losses; (2) Set dust limits + Team Multisig auth on
///         the new PST ecosystem (PST-USDC DEX + five PST vaults);
///         (3) Raise Fluid Lite ETH (iETHv2) max risk ratio of Aave V3 to 94%
///         and Spark to 92%; (4) Raise stETH redemption protocol ETH borrow
///         limit to 20,000 ETH and max LTV to 97%.
contract PayloadIGP130 is PayloadIGPPriceHelpers {
    uint256 public constant PROPOSAL_ID = 130;

    // --- PST ecosystem ids ---------------------------------------------
    // PST-USDC DEX id used by vaults 3 and 5 below for smart collateral.
    uint256 public constant PST_USDC_DEX_ID = 45;

    // Vault ids for the five PST vaults.
    uint256 public constant VAULT_PST_USDC_ID = 165; // T1: PST / USDC
    uint256 public constant VAULT_PST_USDT_ID = 166; // T1: PST / USDT
    uint256 public constant VAULT_PST_USDC__USDC_ID = 167; // T2: PST-USDC / USDC
    uint256 public constant VAULT_PST__USDC_USDT_ID = 168; // T3: PST / USDC-USDT
    uint256 public constant VAULT_PST_USDC__USDC_USDT_ID = 169; // T4: PST-USDC / USDC-USDT

    function execute() public virtual override {
        super.execute();

        // Action 1: Collect Liquidity Layer revenue across 22 tokens into the Reserve Contract and forward to Team Multisig.
        action1();

        // Action 2: Dust limits + Team Multisig auth for the new PST ecosystem (PST-USDC DEX, plus five PST vaults).
        action2();

        // Action 3: Raise Lite ETH (iETHv2) max risk ratio of Aave V3 to 94% and Spark to 92%.
        action3();

        // Action 4: Raise stETH redemption protocol ETH borrow limit to 20,000 ETH and max LTV to 97%.
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

    /// @notice Action 1: Collect Liquidity Layer revenue across 22 tokens into the Reserve Contract and forward to Team Multisig
    function action1() internal isActionSkippable(1) {
        // Step 1: Build the 22-token revenue list
        address[] memory tokens_ = new address[](22);

        // Above $10k revenue
        tokens_[0] = USDC_ADDRESS;
        tokens_[1] = ETH_ADDRESS;
        tokens_[2] = USDT_ADDRESS;
        tokens_[3] = wstETH_ADDRESS;
        tokens_[4] = cbBTC_ADDRESS;
        tokens_[5] = GHO_ADDRESS;
        tokens_[6] = USDe_ADDRESS;
        tokens_[7] = WBTC_ADDRESS;
        tokens_[8] = weETH_ADDRESS;
        tokens_[9] = syrupUSDC_ADDRESS;
        tokens_[10] = sUSDe_ADDRESS;

        // Below $10k revenue
        tokens_[11] = XAUT_ADDRESS;
        tokens_[12] = USDTb_ADDRESS;
        tokens_[13] = PAXG_ADDRESS;
        tokens_[14] = rsETH_ADDRESS;
        tokens_[15] = ezETH_ADDRESS;
        tokens_[16] = RLP_ADDRESS;
        tokens_[17] = REUSD_ADDRESS;
        tokens_[18] = USD0_ADDRESS;
        tokens_[19] = eBTC_ADDRESS;
        tokens_[20] = lBTC_ADDRESS;
        tokens_[21] = fxUSD_ADDRESS;

        // Step 2: Collect accrued Liquidity Layer revenue for those tokens.

        LIQUIDITY.collectRevenue(tokens_);

        // Step 3: Forward balances of each token to Team Multisig
        address reserve_ = address(FLUID_RESERVE);

        uint256[] memory amounts_ = new uint256[](22);

        amounts_[0] = IERC20(USDC_ADDRESS).balanceOf(reserve_) - 10;
        amounts_[1] = reserve_.balance - 0.1 ether;
        amounts_[2] = IERC20(USDT_ADDRESS).balanceOf(reserve_) - 10;
        amounts_[3] = IERC20(wstETH_ADDRESS).balanceOf(reserve_) - 0.1 ether;
        amounts_[4] = IERC20(cbBTC_ADDRESS).balanceOf(reserve_) - 10;
        amounts_[5] = IERC20(GHO_ADDRESS).balanceOf(reserve_) - 0.1 ether;
        amounts_[6] = IERC20(USDe_ADDRESS).balanceOf(reserve_) - 0.1 ether;
        amounts_[7] = IERC20(WBTC_ADDRESS).balanceOf(reserve_) - 10;
        amounts_[8] = IERC20(weETH_ADDRESS).balanceOf(reserve_) - 0.1 ether;
        amounts_[9] = IERC20(syrupUSDC_ADDRESS).balanceOf(reserve_) - 10;
        amounts_[10] = IERC20(sUSDe_ADDRESS).balanceOf(reserve_) - 0.1 ether;

        amounts_[11] = IERC20(XAUT_ADDRESS).balanceOf(reserve_) - 10;
        amounts_[12] = IERC20(USDTb_ADDRESS).balanceOf(reserve_) - 0.1 ether;
        amounts_[13] = IERC20(PAXG_ADDRESS).balanceOf(reserve_) - 0.1 ether;
        amounts_[14] = IERC20(rsETH_ADDRESS).balanceOf(reserve_) - 0.1 ether;
        amounts_[15] = IERC20(ezETH_ADDRESS).balanceOf(reserve_) - 0.1 ether;
        amounts_[16] = IERC20(RLP_ADDRESS).balanceOf(reserve_) - 0.1 ether;
        amounts_[17] = IERC20(REUSD_ADDRESS).balanceOf(reserve_) - 0.1 ether;
        amounts_[18] = IERC20(USD0_ADDRESS).balanceOf(reserve_) - 0.1 ether;
        amounts_[19] = IERC20(eBTC_ADDRESS).balanceOf(reserve_) - 10;
        amounts_[20] = IERC20(lBTC_ADDRESS).balanceOf(reserve_) - 10;
        amounts_[21] = IERC20(fxUSD_ADDRESS).balanceOf(reserve_) - 0.1 ether;

        IFluidReserveContractV2(address(FLUID_RESERVE)).withdrawFunds(
            tokens_,
            amounts_,
            TEAM_MULTISIG,
            "RESOLV CLEANUP"
        );
    }

    /// @notice Action 2: Dust limits + Team MS auth for the PST ecosystem (PST-USDC DEX + 5 PST vaults).
    function action2() internal isActionSkippable(2) {
        address USDC_USDT_DEX = getDexAddress(2);

        // Vault 1: PST / USDC (TYPE_1)
        {
            address PST_USDC_VAULT = getVaultAddress(VAULT_PST_USDC_ID);
            VaultConfig memory VAULT_PST_USDC = VaultConfig({
                vault: PST_USDC_VAULT,
                vaultType: VAULT_TYPE.TYPE_1,
                supplyToken: PST_ADDRESS,
                borrowToken: USDC_ADDRESS,
                baseWithdrawalLimitInUSD: 7_000, // $7k
                baseBorrowLimitInUSD: 7_000, // $7k
                maxBorrowLimitInUSD: 9_000 // $9k
            });
            setVaultLimits(VAULT_PST_USDC);
            VAULT_FACTORY_OWNER.setVaultAuth(
                PST_USDC_VAULT,
                TEAM_MULTISIG,
                true
            );
        }

        // Vault 2: PST / USDT (TYPE_1)
        {
            address PST_USDT_VAULT = getVaultAddress(VAULT_PST_USDT_ID);
            VaultConfig memory VAULT_PST_USDT = VaultConfig({
                vault: PST_USDT_VAULT,
                vaultType: VAULT_TYPE.TYPE_1,
                supplyToken: PST_ADDRESS,
                borrowToken: USDT_ADDRESS,
                baseWithdrawalLimitInUSD: 7_000, // $7k
                baseBorrowLimitInUSD: 7_000, // $7k
                maxBorrowLimitInUSD: 9_000 // $9k
            });
            setVaultLimits(VAULT_PST_USDT);
            VAULT_FACTORY_OWNER.setVaultAuth(
                PST_USDT_VAULT,
                TEAM_MULTISIG,
                true
            );
        }

        // Vault 3: PST-USDC / USDC (TYPE_2) - USDC debt at LL, smart col at DEX
        {
            address PST_USDC__USDC_VAULT = getVaultAddress(
                VAULT_PST_USDC__USDC_ID
            );
            VaultConfig memory VAULT_PST_USDC__USDC = VaultConfig({
                vault: PST_USDC__USDC_VAULT,
                vaultType: VAULT_TYPE.TYPE_2,
                supplyToken: address(0),
                borrowToken: USDC_ADDRESS,
                baseWithdrawalLimitInUSD: 0,
                baseBorrowLimitInUSD: 7_000, // $7k
                maxBorrowLimitInUSD: 9_000 // $9k
            });
            setVaultLimits(VAULT_PST_USDC__USDC);
            VAULT_FACTORY_OWNER.setVaultAuth(
                PST_USDC__USDC_VAULT,
                TEAM_MULTISIG,
                true
            );
        }

        // Vault 4: PST / USDC-USDT (TYPE_3) - smart debt at USDC-USDT DEX (id 2)
        {
            address PST__USDC_USDT_VAULT = getVaultAddress(
                VAULT_PST__USDC_USDT_ID
            );
            VaultConfig memory VAULT_PST__USDC_USDT = VaultConfig({
                vault: PST__USDC_USDT_VAULT,
                vaultType: VAULT_TYPE.TYPE_3,
                supplyToken: PST_ADDRESS,
                borrowToken: address(0),
                baseWithdrawalLimitInUSD: 7_000, // $7k
                baseBorrowLimitInUSD: 0,
                maxBorrowLimitInUSD: 0
            });
            setVaultLimits(VAULT_PST__USDC_USDT);
            VAULT_FACTORY_OWNER.setVaultAuth(
                PST__USDC_USDT_VAULT,
                TEAM_MULTISIG,
                true
            );

            DexBorrowProtocolConfigInShares
                memory config_ = DexBorrowProtocolConfigInShares({
                    dex: USDC_USDT_DEX,
                    protocol: PST__USDC_USDT_VAULT,
                    expandPercent: 30 * 1e2, // 30%
                    expandDuration: 6 hours,
                    baseBorrowLimit: 3500 * 1e18, // ~$7k shares
                    maxBorrowLimit: 4500 * 1e18 // ~$9k shares
                });
            setDexBorrowProtocolLimitsInShares(config_);
        }

        // Vault 5: PST-USDC / USDC-USDT (TYPE_4) - smart col at PST-USDC DEX, smart debt at USDC-USDT DEX
        {
            address PST_USDC__USDC_USDT_VAULT = getVaultAddress(
                VAULT_PST_USDC__USDC_USDT_ID
            );

            VAULT_FACTORY_OWNER.setVaultAuth(
                PST_USDC__USDC_USDT_VAULT,
                TEAM_MULTISIG,
                true
            );

            DexBorrowProtocolConfigInShares
                memory config_ = DexBorrowProtocolConfigInShares({
                    dex: USDC_USDT_DEX,
                    protocol: PST_USDC__USDC_USDT_VAULT,
                    expandPercent: 30 * 1e2, // 30%
                    expandDuration: 6 hours,
                    baseBorrowLimit: 3500 * 1e18, // ~$7k shares
                    maxBorrowLimit: 4500 * 1e18 // ~$9k shares
                });
            setDexBorrowProtocolLimitsInShares(config_);
        }

        // PST-USDC DEX: smart-col dust limits + Team MS auth
        {
            address PST_USDC_DEX = getDexAddress(PST_USDC_DEX_ID);
            DexConfig memory DEX_PST_USDC = DexConfig({
                dex: PST_USDC_DEX,
                tokenA: PST_ADDRESS,
                tokenB: USDC_ADDRESS,
                smartCollateral: true,
                smartDebt: false,
                baseWithdrawalLimitInUSD: 10_000, // $10k
                baseBorrowLimitInUSD: 0,
                maxBorrowLimitInUSD: 0
            });
            setDexLimits(DEX_PST_USDC);
            DEX_FACTORY.setDexAuth(PST_USDC_DEX, TEAM_MULTISIG, true);
        }
    }

    /// @notice Action 3: Raise Fluid Lite ETH (iETHv2) max risk ratio of Aave V3 and Spark.
    function action3() internal isActionSkippable(3) {
        uint8[] memory protocolIds_ = new uint8[](2);
        uint256[] memory newRiskRatios_ = new uint256[](2);

        // Aave V3: 94%. Protocol Id: 2
        protocolIds_[0] = 2;
        newRiskRatios_[0] = 94 * 1e4;

        // Spark: 92%. Protocol Id: 7
        protocolIds_[1] = 7;
        newRiskRatios_[1] = 92 * 1e4;

        IETHV2.updateMaxRiskRatio(protocolIds_, newRiskRatios_);
    }

    /// @notice Action 4: Raise stETH redemption protocol ETH borrow limit to 20,000 ETH and max LTV to 97%.
    function action4() internal isActionSkippable(4) {
        // Step 1: Raise ETH borrow limit to 20,000 ETH on the Liquidity Layer.

        {
            uint256 amount_ = getRawAmount(
                ETH_ADDRESS,
                20_000 ether,
                0,
                false
            );

            FluidLiquidityAdminStructs.UserBorrowConfig[]
                memory configs_ = new FluidLiquidityAdminStructs.UserBorrowConfig[](
                    1
                );

            configs_[0] = FluidLiquidityAdminStructs.UserBorrowConfig({
                user: address(STETH_REDEMPTION_PROTOCOL),
                token: ETH_ADDRESS,
                mode: 1,
                expandPercent: 0,
                expandDuration: 1,
                baseDebtCeiling: amount_,
                maxDebtCeiling: (amount_ * 1001) / 1000
            });

            LIQUIDITY.updateUserBorrowConfigs(configs_);
        }

        // Step 2: Raise max LTV to 97%.
        {
            STETH_REDEMPTION_PROTOCOL.setMaxLTV(97 * 1e2);
        }
    }

    /**
     * |
     * |     Payload Actions End Here      |
     * |__________________________________
     */

    // --- BEGIN AUTO-GENERATED PRICES (scripts/verify/prepare-prices.ts) ---
    // fetched: 2026-05-20T20:04:31.189Z, source: coingecko
    function BTC_USD_PRICE()       public pure override returns (uint256) { return 78_000 * 1e2; }
    function ETH_USD_PRICE()       public pure override returns (uint256) { return 2_130 * 1e2; }
    function ezETH_USD_PRICE()     public pure override returns (uint256) { return 2_300 * 1e2; }
    function STABLE_USD_PRICE()    public pure override returns (uint256) { return 1 * 1e2; }
    function PAXG_USD_PRICE()      public pure override returns (uint256) { return 4_540 * 1e2; }
    function PST_USD_PRICE()       public pure override returns (uint256) { return 1.10 * 1e2; }
    function REUSD_USD_PRICE()     public pure override returns (uint256) { return 1.08 * 1e2; }
    function RLP_USD_PRICE()       public pure override returns (uint256) { return 0.41 * 1e2; }
    function rsETH_USD_PRICE()     public pure override returns (uint256) { return 2_280 * 1e2; }
    function sUSDe_USD_PRICE()     public pure override returns (uint256) { return 1.23 * 1e2; }
    function syrupUSDC_USD_PRICE() public pure override returns (uint256) { return 1.16 * 1e2; }
    function weETH_USD_PRICE()     public pure override returns (uint256) { return 2_340 * 1e2; }
    function wstETH_USD_PRICE()    public pure override returns (uint256) { return 2_640 * 1e2; }
    function XAUT_USD_PRICE()      public pure override returns (uint256) { return 4_540 * 1e2; }
    // --- END AUTO-GENERATED PRICES ---
}
