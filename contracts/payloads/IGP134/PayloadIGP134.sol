// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.21;
pragma experimental ABIEncoderV2;

import {
    AdminModuleStructs as FluidLiquidityAdminStructs
} from "../common/interfaces/IFluidLiquidity.sol";
import {IFluidDex} from "../common/interfaces/IFluidDex.sol";
import {PayloadIGPPriceHelpers} from "../common/pricehelpers.sol";

/// @notice IGP134: USDai ecosystem dust limits, max supply share caps on USR/RLP
///         DEXes, and iETHv2 revenue claim. Lite revenue amount is configurable
///         by Team Multisig before execution.
contract PayloadIGP134 is PayloadIGPPriceHelpers {
    uint256 public constant PROPOSAL_ID = 134;

    uint256 public constant USR_USDC_DEX_ID = 20;
    uint256 public constant RLP_USDC_DEX_ID = 28;

    // --- USDai ecosystem ids (deployments receive these ids when batched) ---
    uint256 public constant USDAI_USDC_DEX_ID = 46;
    uint256 public constant SUSDAI_USDC_DEX_ID = 47;
    uint256 public constant SUSDAI_USDT_DEX_ID = 48;

    uint256 public constant VAULT_USDAI_USDC_ID = 170; // T1: USDai / USDC
    uint256 public constant VAULT_SUSDAI_USDC_ID = 171; // T1: sUSDai / USDC
    uint256 public constant VAULT_SUSDAI_USDT_ID = 172; // T1: sUSDai / USDT
    uint256 public constant VAULT_SUSDAI__USDC_USDT_ID = 173; // T3: sUSDai / USDC-USDT
    uint256 public constant VAULT_SUSDAI_USDC__USDC_USDT_ID = 174; // T4: sUSDai-USDC / USDC-USDT
    uint256 public constant VAULT_SUSDAI_USDT__USDC_USDT_ID = 175; // T4: sUSDai-USDT / USDC-USDT
    uint256 public constant VAULT_SUSDAI_USDT__USDT_ID = 176; // T2: sUSDai-USDT / USDT
    uint256 public constant VAULT_SUSDAI_USDC__USDC_ID = 177; // T2: sUSDai-USDC / USDC

    uint256 public liteStethRevenueAmount;

    function setLiteStethRevenueAmount(uint256 liteStethRevenueAmount_) external {
        require(msg.sender == TEAM_MULTISIG, "not-team-multisig");
        liteStethRevenueAmount = liteStethRevenueAmount_;
    }

    function execute() public virtual override {
        super.execute();

        // Action 1: USDai ecosystem dust limits (DEXes 46–48, vaults 170–177)
        action1();

        // Action 2: Set USR-USDC and RLP-USDC DEX max supply shares to 0
        action2();

        // Action 3: Claim iETHv2 (Lite) stETH revenue to Team Multisig
        action3();
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

    /// @notice Action 1: Dust limits for USDai ecosystem (DEXes 46–48, vaults 170–177)
    function action1() internal isActionSkippable(1) {
        address USDC_USDT_DEX = getDexAddress(2);

        // DEX 46: USDai-USDC
        {
            address USDAI_USDC_DEX = getDexAddress(USDAI_USDC_DEX_ID);
            DexConfig memory DEX_USDAI_USDC = DexConfig({
                dex: USDAI_USDC_DEX,
                tokenA: USDAI_ADDRESS,
                tokenB: USDC_ADDRESS,
                smartCollateral: true,
                smartDebt: false,
                baseWithdrawalLimitInUSD: 10_000, // $10k
                baseBorrowLimitInUSD: 0,
                maxBorrowLimitInUSD: 0
            });
            setDexLimits(DEX_USDAI_USDC);
            DEX_FACTORY.setDexAuth(USDAI_USDC_DEX, TEAM_MULTISIG, true);
        }

        // DEX 47: sUSDai-USDC
        {
            address SUSDAI_USDC_DEX = getDexAddress(SUSDAI_USDC_DEX_ID);
            DexConfig memory DEX_SUSDAI_USDC = DexConfig({
                dex: SUSDAI_USDC_DEX,
                tokenA: SUSDAI_ADDRESS,
                tokenB: USDC_ADDRESS,
                smartCollateral: true,
                smartDebt: false,
                baseWithdrawalLimitInUSD: 10_000, // $10k
                baseBorrowLimitInUSD: 0,
                maxBorrowLimitInUSD: 0
            });
            setDexLimits(DEX_SUSDAI_USDC);
            DEX_FACTORY.setDexAuth(SUSDAI_USDC_DEX, TEAM_MULTISIG, true);
        }

        // DEX 48: sUSDai-USDT
        {
            address SUSDAI_USDT_DEX = getDexAddress(SUSDAI_USDT_DEX_ID);
            DexConfig memory DEX_SUSDAI_USDT = DexConfig({
                dex: SUSDAI_USDT_DEX,
                tokenA: SUSDAI_ADDRESS,
                tokenB: USDT_ADDRESS,
                smartCollateral: true,
                smartDebt: false,
                baseWithdrawalLimitInUSD: 10_000, // $10k
                baseBorrowLimitInUSD: 0,
                maxBorrowLimitInUSD: 0
            });
            setDexLimits(DEX_SUSDAI_USDT);
            DEX_FACTORY.setDexAuth(SUSDAI_USDT_DEX, TEAM_MULTISIG, true);
        }

        // Vault 170: USDai / USDC (TYPE_1)
        {
            address USDAI_USDC_VAULT = getVaultAddress(VAULT_USDAI_USDC_ID);
            VaultConfig memory VAULT_USDAI_USDC = VaultConfig({
                vault: USDAI_USDC_VAULT,
                vaultType: VAULT_TYPE.TYPE_1,
                supplyToken: USDAI_ADDRESS,
                borrowToken: USDC_ADDRESS,
                baseWithdrawalLimitInUSD: 7_000, // $7k
                baseBorrowLimitInUSD: 7_000, // $7k
                maxBorrowLimitInUSD: 9_000 // $9k
            });
            setVaultLimits(VAULT_USDAI_USDC);
            VAULT_FACTORY.setVaultAuth(
                USDAI_USDC_VAULT,
                TEAM_MULTISIG,
                true
            );
        }

        // Vault 171: sUSDai / USDC (TYPE_1)
        {
            address SUSDAI_USDC_VAULT = getVaultAddress(VAULT_SUSDAI_USDC_ID);
            VaultConfig memory VAULT_SUSDAI_USDC = VaultConfig({
                vault: SUSDAI_USDC_VAULT,
                vaultType: VAULT_TYPE.TYPE_1,
                supplyToken: SUSDAI_ADDRESS,
                borrowToken: USDC_ADDRESS,
                baseWithdrawalLimitInUSD: 7_000, // $7k
                baseBorrowLimitInUSD: 7_000, // $7k
                maxBorrowLimitInUSD: 9_000 // $9k
            });
            setVaultLimits(VAULT_SUSDAI_USDC);
            VAULT_FACTORY.setVaultAuth(
                SUSDAI_USDC_VAULT,
                TEAM_MULTISIG,
                true
            );
        }

        // Vault 172: sUSDai / USDT (TYPE_1)
        {
            address SUSDAI_USDT_VAULT = getVaultAddress(VAULT_SUSDAI_USDT_ID);
            VaultConfig memory VAULT_SUSDAI_USDT = VaultConfig({
                vault: SUSDAI_USDT_VAULT,
                vaultType: VAULT_TYPE.TYPE_1,
                supplyToken: SUSDAI_ADDRESS,
                borrowToken: USDT_ADDRESS,
                baseWithdrawalLimitInUSD: 7_000, // $7k
                baseBorrowLimitInUSD: 7_000, // $7k
                maxBorrowLimitInUSD: 9_000 // $9k
            });
            setVaultLimits(VAULT_SUSDAI_USDT);
            VAULT_FACTORY.setVaultAuth(
                SUSDAI_USDT_VAULT,
                TEAM_MULTISIG,
                true
            );
        }

        // Vault 173: sUSDai / USDC-USDT (TYPE_3)
        {
            address SUSDAI__USDC_USDT_VAULT = getVaultAddress(
                VAULT_SUSDAI__USDC_USDT_ID
            );
            VaultConfig memory VAULT_SUSDAI__USDC_USDT = VaultConfig({
                vault: SUSDAI__USDC_USDT_VAULT,
                vaultType: VAULT_TYPE.TYPE_3,
                supplyToken: SUSDAI_ADDRESS,
                borrowToken: address(0),
                baseWithdrawalLimitInUSD: 7_000, // $7k
                baseBorrowLimitInUSD: 0,
                maxBorrowLimitInUSD: 0
            });
            setVaultLimits(VAULT_SUSDAI__USDC_USDT);
            VAULT_FACTORY.setVaultAuth(
                SUSDAI__USDC_USDT_VAULT,
                TEAM_MULTISIG,
                true
            );

            DexBorrowProtocolConfigInShares
                memory config_ = DexBorrowProtocolConfigInShares({
                    dex: USDC_USDT_DEX,
                    protocol: SUSDAI__USDC_USDT_VAULT,
                    expandPercent: 30 * 1e2, // 30%
                    expandDuration: 6 hours,
                    baseBorrowLimit: 3500 * 1e18, // ~$7k shares
                    maxBorrowLimit: 4500 * 1e18 // ~$9k shares
                });
            setDexBorrowProtocolLimitsInShares(config_);
        }

        // Vault 174: sUSDai-USDC / USDC-USDT (TYPE_4)
        {
            address SUSDAI_USDC__USDC_USDT_VAULT = getVaultAddress(
                VAULT_SUSDAI_USDC__USDC_USDT_ID
            );
            VAULT_FACTORY.setVaultAuth(
                SUSDAI_USDC__USDC_USDT_VAULT,
                TEAM_MULTISIG,
                true
            );

            DexBorrowProtocolConfigInShares
                memory config_ = DexBorrowProtocolConfigInShares({
                    dex: USDC_USDT_DEX,
                    protocol: SUSDAI_USDC__USDC_USDT_VAULT,
                    expandPercent: 30 * 1e2, // 30%
                    expandDuration: 6 hours,
                    baseBorrowLimit: 3500 * 1e18, // ~$7k shares
                    maxBorrowLimit: 4500 * 1e18 // ~$9k shares
                });
            setDexBorrowProtocolLimitsInShares(config_);
        }

        // Vault 175: sUSDai-USDT / USDC-USDT (TYPE_4)
        {
            address SUSDAI_USDT__USDC_USDT_VAULT = getVaultAddress(
                VAULT_SUSDAI_USDT__USDC_USDT_ID
            );
            VAULT_FACTORY.setVaultAuth(
                SUSDAI_USDT__USDC_USDT_VAULT,
                TEAM_MULTISIG,
                true
            );

            DexBorrowProtocolConfigInShares
                memory config_ = DexBorrowProtocolConfigInShares({
                    dex: USDC_USDT_DEX,
                    protocol: SUSDAI_USDT__USDC_USDT_VAULT,
                    expandPercent: 30 * 1e2, // 30%
                    expandDuration: 6 hours,
                    baseBorrowLimit: 3500 * 1e18, // ~$7k shares
                    maxBorrowLimit: 4500 * 1e18 // ~$9k shares
                });
            setDexBorrowProtocolLimitsInShares(config_);
        }

        // Vault 176: sUSDai-USDT / USDT (TYPE_2)
        {
            address SUSDAI_USDT__USDT_VAULT = getVaultAddress(
                VAULT_SUSDAI_USDT__USDT_ID
            );
            VaultConfig memory VAULT_SUSDAI_USDT__USDT = VaultConfig({
                vault: SUSDAI_USDT__USDT_VAULT,
                vaultType: VAULT_TYPE.TYPE_2,
                supplyToken: address(0),
                borrowToken: USDT_ADDRESS,
                baseWithdrawalLimitInUSD: 0,
                baseBorrowLimitInUSD: 7_000, // $7k
                maxBorrowLimitInUSD: 9_000 // $9k
            });
            setVaultLimits(VAULT_SUSDAI_USDT__USDT);
            VAULT_FACTORY.setVaultAuth(
                SUSDAI_USDT__USDT_VAULT,
                TEAM_MULTISIG,
                true
            );
        }

        // Vault 177: sUSDai-USDC / USDC (TYPE_2)
        {
            address SUSDAI_USDC__USDC_VAULT = getVaultAddress(
                VAULT_SUSDAI_USDC__USDC_ID
            );
            VaultConfig memory VAULT_SUSDAI_USDC__USDC = VaultConfig({
                vault: SUSDAI_USDC__USDC_VAULT,
                vaultType: VAULT_TYPE.TYPE_2,
                supplyToken: address(0),
                borrowToken: USDC_ADDRESS,
                baseWithdrawalLimitInUSD: 0,
                baseBorrowLimitInUSD: 7_000, // $7k
                maxBorrowLimitInUSD: 9_000 // $9k
            });
            setVaultLimits(VAULT_SUSDAI_USDC__USDC);
            VAULT_FACTORY.setVaultAuth(
                SUSDAI_USDC__USDC_VAULT,
                TEAM_MULTISIG,
                true
            );
        }
    }

    /// @notice Action 2: Set USR-USDC (DEX 20) and RLP-USDC (DEX 28) max supply shares to 0
    function action2() internal isActionSkippable(2) {
        IFluidDex(getDexAddress(USR_USDC_DEX_ID)).updateMaxSupplyShares(0);
        IFluidDex(getDexAddress(RLP_USDC_DEX_ID)).updateMaxSupplyShares(0);
    }

    /// @notice Action 3: Claim iETHv2 (Lite) stETH revenue to Team Multisig
    function action3() internal isActionSkippable(3) {
        uint256 stethAmount_ = PayloadIGP134(ADDRESS_THIS).liteStethRevenueAmount();
        require(stethAmount_ != 0, "lite-revenue-amount-not-set");

        IETHV2.collectRevenue(stethAmount_);

        string[] memory targets_ = new string[](1);
        bytes[] memory encodedSpells_ = new bytes[](1);

        targets_[0] = "BASIC-A";
        encodedSpells_[0] = abi.encodeWithSignature(
            "withdraw(address,uint256,address,uint256,uint256)",
            stETH_ADDRESS,
            stethAmount_,
            TEAM_MULTISIG,
            0,
            0
        );

        TREASURY.cast(targets_, encodedSpells_, address(this));
    }

    /**
     * |
     * |     Payload Actions End Here      |
     * |__________________________________
     */

    // --- BEGIN AUTO-GENERATED PRICES (scripts/verify/prepare-prices.ts) ---
    // fetched: 2026-05-30T11:25:35.114Z, source: coingecko
    function SUSDAI_USD_PRICE() public pure override returns (uint256) { return 1 * 1e2; }
    function STABLE_USD_PRICE() public pure override returns (uint256) { return 1 * 1e2; }
    // --- END AUTO-GENERATED PRICES ---
}
