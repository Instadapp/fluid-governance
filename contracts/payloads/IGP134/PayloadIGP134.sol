// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.21;
pragma experimental ABIEncoderV2;

import {PayloadIGPPriceHelpers} from "../common/pricehelpers.sol";

/// @notice IGP134: Raise the USDai ecosystem from dust limits (IGP-133) to
///         launch limits (except vault 180, held at dust), and claim accrued
///         iETHv2 (Lite) stETH revenue to Team Multisig.
///
///         Action 1 raises the Liquidity Layer supply / borrow limits on two
///         USDai DEXes (ids 46 and 48) and vaults 171–173 and 175–179 to their
///         launch-scale targets and removes Team Multisig auth on each.
///         Per-market config (collateral factor, liquidation threshold /
///         max-limit / penalty, DEX max supply shares, range, and fee) is
///         intentionally NOT touched here. DEX and vault ids are verified
///         against the live Fluid factories on mainnet.
///
///         Action 2 holds the USDai-USDC market (DEX 47 + vault 180) until it
///         launches in a later IGP: vault 180 gets borrow-side dust limits only,
///         and Team Multisig auth is explicitly retained on both DEX 47 and
///         vault 180 (DEX 47 launch limits are deferred to the vault's launch).
///
///         Action 3 deprecates the wrongly deployed T1 vault 174 with a full
///         pause and removes its Team Multisig auth.
///
///         Action 4 collects a Team-Multisig-configured amount of iETHv2 (Lite)
///         stETH revenue into the Treasury and forwards it to Team Multisig.
contract PayloadIGP134 is PayloadIGPPriceHelpers {
    uint256 public constant PROPOSAL_ID = 134;

    // --- USDai ecosystem DEX ids (verified on-chain) ---
    uint256 public constant SUSDAI_USDC_DEX_ID = 46; // sUSDai / USDC
    uint256 public constant USDAI_USDC_DEX_ID = 47; // USDai / USDC
    uint256 public constant SUSDAI_USDT_DEX_ID = 48; // sUSDai / USDT

    // --- USDai ecosystem vault ids (verified on-chain) ---
    uint256 public constant VAULT_SUSDAI_USDC_ID = 171; // T1: sUSDai / USDC
    uint256 public constant VAULT_SUSDAI_USDT_ID = 172; // T1: sUSDai / USDT
    uint256 public constant VAULT_SUSDAI__USDC_USDT_ID = 173; // T3: sUSDai / USDC-USDT
    uint256 public constant VAULT_USDAI_USDC_ID = 174; // T1: USDai / USDC (wrongly deployed — deprecated)
    uint256 public constant VAULT_SUSDAI_USDC__USDC_USDT_ID = 175; // T4: sUSDai-USDC / USDC-USDT
    uint256 public constant VAULT_SUSDAI_USDT__USDC_USDT_ID = 176; // T4: sUSDai-USDT / USDC-USDT
    uint256 public constant VAULT_SUSDAI_USDT__USDT_ID = 177; // T2: sUSDai-USDT / USDT
    uint256 public constant VAULT_SUSDAI_USDC__USDC_ID = 178; // T2: sUSDai-USDC / USDC
    uint256 public constant VAULT_SUSDAI_GHO_ID = 179; // T1: sUSDai / GHO
    uint256 public constant VAULT_USDAI_USDC__USDC_ID = 180; // T2: USDai-USDC / USDC

    // Smart-debt limits on the USDC-USDT DEX (id 2) are denominated in DEX
    // shares (~$2.20/share atm).

    // --- iETHv2 (Lite) stETH revenue claim (Action 3) ---
    // stETH wei to collect from iETHv2 and forward to Team Multisig. Set by
    // Team Multisig via setLiteStethRevenueAmount() before execution; a zero
    // value makes Action 3 revert so it cannot run unconfigured.
    uint256 public liteStethRevenueAmount;

    function setLiteStethRevenueAmount(
        uint256 liteStethRevenueAmount_
    ) external {
        require(msg.sender == TEAM_MULTISIG, "not-team-multisig");
        liteStethRevenueAmount = liteStethRevenueAmount_;
    }

    function execute() public virtual override {
        super.execute();

        // Action 1: Raise USDai ecosystem to launch limits (DEXes 46 and 48,
        // vaults 171-173, 175-179), removing Team MS auth on each
        action1();

        // Action 2: Hold the USDai-USDC market (DEX 47 + vault 180) - vault 180
        // dust limits, keep Team MS auth on both, defer their launch
        action2();

        // Action 3: Deprecate wrongly deployed vault 174
        action3();

        // Action 4: Claim iETHv2 (Lite) stETH revenue to Team Multisig
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

    /// @notice Action 1: USDai ecosystem launch limits (DEXes 46 and 48, vaults
    ///         171–173 and 175–179) and remove Team Multisig auth on each.
    ///         The USDai-USDC DEX 47 and vault 180 are handled in Action 2.
    function action1() internal isActionSkippable(1) {
        address USDC_USDT_DEX = getDexAddress(2);

        // DEX 46: sUSDai-USDC — smart-collateral token limits $10M each
        {
            address SUSDAI_USDC_DEX = getDexAddress(SUSDAI_USDC_DEX_ID);
            DexConfig memory DEX_SUSDAI_USDC = DexConfig({
                dex: SUSDAI_USDC_DEX,
                tokenA: SUSDAI_ADDRESS,
                tokenB: USDC_ADDRESS,
                smartCollateral: true,
                smartDebt: false,
                baseWithdrawalLimitInUSD: 10_000_000, // $10M
                baseBorrowLimitInUSD: 0,
                maxBorrowLimitInUSD: 0
            });
            setDexLimits(DEX_SUSDAI_USDC);
            DEX_FACTORY.setDexAuth(SUSDAI_USDC_DEX, TEAM_MULTISIG, false);
        }

        // DEX 47 (USDai-USDC) is intentionally skipped here: it is held back
        // and launched together with vault 180 in a later IGP. Action 2 keeps
        // Team MS auth on it; its launch limits are deferred to that IGP.

        // DEX 48: sUSDai-USDT — smart-collateral token limits $10M each
        {
            address SUSDAI_USDT_DEX = getDexAddress(SUSDAI_USDT_DEX_ID);
            DexConfig memory DEX_SUSDAI_USDT = DexConfig({
                dex: SUSDAI_USDT_DEX,
                tokenA: SUSDAI_ADDRESS,
                tokenB: USDT_ADDRESS,
                smartCollateral: true,
                smartDebt: false,
                baseWithdrawalLimitInUSD: 10_000_000, // $10M
                baseBorrowLimitInUSD: 0,
                maxBorrowLimitInUSD: 0
            });
            setDexLimits(DEX_SUSDAI_USDT);
            DEX_FACTORY.setDexAuth(SUSDAI_USDT_DEX, TEAM_MULTISIG, false);
        }

        // Vault 171: sUSDai / USDC (TYPE_1) — $8M / $8M / $15M
        {
            address SUSDAI_USDC_VAULT = getVaultAddress(VAULT_SUSDAI_USDC_ID);
            VaultConfig memory VAULT_SUSDAI_USDC = VaultConfig({
                vault: SUSDAI_USDC_VAULT,
                vaultType: VAULT_TYPE.TYPE_1,
                supplyToken: SUSDAI_ADDRESS,
                borrowToken: USDC_ADDRESS,
                baseWithdrawalLimitInUSD: 8_000_000, // $8M
                baseBorrowLimitInUSD: 8_000_000, // $8M
                maxBorrowLimitInUSD: 15_000_000 // $15M
            });
            setVaultLimits(VAULT_SUSDAI_USDC);
            VAULT_FACTORY_WRAPPER_OWNER.setVaultAuth(SUSDAI_USDC_VAULT, TEAM_MULTISIG, false);
        }

        // Vault 172: sUSDai / USDT (TYPE_1) — $8M / $8M / $15M
        {
            address SUSDAI_USDT_VAULT = getVaultAddress(VAULT_SUSDAI_USDT_ID);
            VaultConfig memory VAULT_SUSDAI_USDT = VaultConfig({
                vault: SUSDAI_USDT_VAULT,
                vaultType: VAULT_TYPE.TYPE_1,
                supplyToken: SUSDAI_ADDRESS,
                borrowToken: USDT_ADDRESS,
                baseWithdrawalLimitInUSD: 8_000_000, // $8M
                baseBorrowLimitInUSD: 8_000_000, // $8M
                maxBorrowLimitInUSD: 15_000_000 // $15M
            });
            setVaultLimits(VAULT_SUSDAI_USDT);
            VAULT_FACTORY_WRAPPER_OWNER.setVaultAuth(SUSDAI_USDT_VAULT, TEAM_MULTISIG, false);
        }

        // Vault 173: sUSDai / USDC-USDT (TYPE_3) — $8M sUSDai supply;
        // USDC-USDT DEX (id 2) borrow shares ~$8M / ~$15M (3.6M / 6.75M shares)
        {
            address SUSDAI__USDC_USDT_VAULT = getVaultAddress(
                VAULT_SUSDAI__USDC_USDT_ID
            );
            VaultConfig memory VAULT_SUSDAI__USDC_USDT = VaultConfig({
                vault: SUSDAI__USDC_USDT_VAULT,
                vaultType: VAULT_TYPE.TYPE_3,
                supplyToken: SUSDAI_ADDRESS,
                borrowToken: address(0),
                baseWithdrawalLimitInUSD: 8_000_000, // $8M
                baseBorrowLimitInUSD: 0,
                maxBorrowLimitInUSD: 0
            });
            setVaultLimits(VAULT_SUSDAI__USDC_USDT);

            DexBorrowProtocolConfigInShares
                memory config_ = DexBorrowProtocolConfigInShares({
                    dex: USDC_USDT_DEX,
                    protocol: SUSDAI__USDC_USDT_VAULT,
                    expandPercent: 30 * 1e2, // 30%
                    expandDuration: 6 hours,
                    baseBorrowLimit: 3_600_000 * 1e18, // ~$8M at ~$2.20/share
                    maxBorrowLimit: 6_750_000 * 1e18 // ~$15M at ~$2.20/share
                });
            setDexBorrowProtocolLimitsInShares(config_);
            VAULT_FACTORY_WRAPPER_OWNER.setVaultAuth(
                SUSDAI__USDC_USDT_VAULT,
                TEAM_MULTISIG,
                false
            );
        }

        // Vault 175: sUSDai-USDC / USDC-USDT (TYPE_4) — collateral at DEX 46;
        // USDC-USDT DEX (id 2) borrow shares ~$8M / ~$20M (3.6M / 9M shares)
        {
            address SUSDAI_USDC__USDC_USDT_VAULT = getVaultAddress(
                VAULT_SUSDAI_USDC__USDC_USDT_ID
            );

            DexBorrowProtocolConfigInShares
                memory config_ = DexBorrowProtocolConfigInShares({
                    dex: USDC_USDT_DEX,
                    protocol: SUSDAI_USDC__USDC_USDT_VAULT,
                    expandPercent: 30 * 1e2, // 30%
                    expandDuration: 6 hours,
                    baseBorrowLimit: 3_600_000 * 1e18, // ~$8M at ~$2.20/share
                    maxBorrowLimit: 9_000_000 * 1e18 // ~$20M at ~$2.20/share
                });
            setDexBorrowProtocolLimitsInShares(config_);
            VAULT_FACTORY_WRAPPER_OWNER.setVaultAuth(
                SUSDAI_USDC__USDC_USDT_VAULT,
                TEAM_MULTISIG,
                false
            );
        }

        // Vault 176: sUSDai-USDT / USDC-USDT (TYPE_4) — collateral at DEX 48;
        // USDC-USDT DEX (id 2) borrow shares ~$8M / ~$20M (3.6M / 9M shares)
        {
            address SUSDAI_USDT__USDC_USDT_VAULT = getVaultAddress(
                VAULT_SUSDAI_USDT__USDC_USDT_ID
            );

            DexBorrowProtocolConfigInShares
                memory config_ = DexBorrowProtocolConfigInShares({
                    dex: USDC_USDT_DEX,
                    protocol: SUSDAI_USDT__USDC_USDT_VAULT,
                    expandPercent: 30 * 1e2, // 30%
                    expandDuration: 6 hours,
                    baseBorrowLimit: 3_600_000 * 1e18, // ~$8M at ~$2.20/share
                    maxBorrowLimit: 9_000_000 * 1e18 // ~$20M at ~$2.20/share
                });
            setDexBorrowProtocolLimitsInShares(config_);
            VAULT_FACTORY_WRAPPER_OWNER.setVaultAuth(
                SUSDAI_USDT__USDC_USDT_VAULT,
                TEAM_MULTISIG,
                false
            );
        }

        // Vault 177: sUSDai-USDT / USDT (TYPE_2) — collateral at DEX 48;
        // USDT debt $8M / $20M
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
                baseBorrowLimitInUSD: 8_000_000, // $8M
                maxBorrowLimitInUSD: 20_000_000 // $20M
            });
            setVaultLimits(VAULT_SUSDAI_USDT__USDT);
            VAULT_FACTORY_WRAPPER_OWNER.setVaultAuth(
                SUSDAI_USDT__USDT_VAULT,
                TEAM_MULTISIG,
                false
            );
        }

        // Vault 178: sUSDai-USDC / USDC (TYPE_2) — collateral at DEX 46;
        // USDC debt $8M / $20M
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
                baseBorrowLimitInUSD: 8_000_000, // $8M
                maxBorrowLimitInUSD: 20_000_000 // $20M
            });
            setVaultLimits(VAULT_SUSDAI_USDC__USDC);
            VAULT_FACTORY_WRAPPER_OWNER.setVaultAuth(
                SUSDAI_USDC__USDC_VAULT,
                TEAM_MULTISIG,
                false
            );
        }

        // Vault 179: sUSDai / GHO (TYPE_1) — $8M / $8M / $15M
        {
            address SUSDAI_GHO_VAULT = getVaultAddress(VAULT_SUSDAI_GHO_ID);
            VaultConfig memory VAULT_SUSDAI_GHO = VaultConfig({
                vault: SUSDAI_GHO_VAULT,
                vaultType: VAULT_TYPE.TYPE_1,
                supplyToken: SUSDAI_ADDRESS,
                borrowToken: GHO_ADDRESS,
                baseWithdrawalLimitInUSD: 8_000_000, // $8M
                baseBorrowLimitInUSD: 8_000_000, // $8M
                maxBorrowLimitInUSD: 15_000_000 // $15M
            });
            setVaultLimits(VAULT_SUSDAI_GHO);
            VAULT_FACTORY_WRAPPER_OWNER.setVaultAuth(SUSDAI_GHO_VAULT, TEAM_MULTISIG, false);
        }
    }

    /// @notice Action 2: Hold the USDai-USDC market (DEX 47 + vault 180) until it
    ///         launches in a later IGP. Vault 180 (USDai-USDC / USDC, TYPE_2)
    ///         gets borrow-side dust limits ($7k / $9k) only. Team Multisig auth
    ///         is explicitly retained (set to true) on both DEX 47 and vault 180.
    ///         DEX 47 launch limits are deferred to the vault's launch, so no
    ///         DEX 47 limits are changed here.
    function action2() internal isActionSkippable(2) {
        // DEX 47 (USDai-USDC): keep Team MS auth; launch limits are deferred to
        // the IGP that launches vault 180, so no DEX limits are set here.
        address USDAI_USDC_DEX = getDexAddress(USDAI_USDC_DEX_ID);
        DEX_FACTORY.setDexAuth(USDAI_USDC_DEX, TEAM_MULTISIG, true);

        // Vault 180 (USDai-USDC / USDC, TYPE_2): borrow-side dust limits only,
        // keep Team MS auth.
        address USDAI_USDC__USDC_VAULT = getVaultAddress(
            VAULT_USDAI_USDC__USDC_ID
        );
        VaultConfig memory VAULT_USDAI_USDC__USDC = VaultConfig({
            vault: USDAI_USDC__USDC_VAULT,
            vaultType: VAULT_TYPE.TYPE_2,
            supplyToken: address(0),
            borrowToken: USDC_ADDRESS,
            baseWithdrawalLimitInUSD: 0,
            baseBorrowLimitInUSD: 7_000, // $7k
            maxBorrowLimitInUSD: 9_000 // $9k
        });
        setVaultLimits(VAULT_USDAI_USDC__USDC);
        VAULT_FACTORY_WRAPPER_OWNER.setVaultAuth(
            USDAI_USDC__USDC_VAULT,
            TEAM_MULTISIG,
            true
        );
    }

    /// @notice Action 3: Deprecate wrongly deployed T1 vault 174 (USDai / USDC).
    ///         Removes dust limits, applies a full pause, and removes Team MS auth.
    function action3() internal isActionSkippable(3) {
        address USDAI_USDC_VAULT = getVaultAddress(VAULT_USDAI_USDC_ID);

        setSupplyProtocolLimitsPaused(USDAI_USDC_VAULT, USDAI_ADDRESS);
        setBorrowProtocolLimitsPaused(USDAI_USDC_VAULT, USDC_ADDRESS);

        address[] memory supplyTokens_ = new address[](1);
        supplyTokens_[0] = USDAI_ADDRESS;

        address[] memory borrowTokens_ = new address[](1);
        borrowTokens_[0] = USDC_ADDRESS;

        LIQUIDITY.pauseUser(USDAI_USDC_VAULT, supplyTokens_, borrowTokens_);

        VAULT_FACTORY_WRAPPER_OWNER.setVaultAuth(USDAI_USDC_VAULT, TEAM_MULTISIG, false);
    }

    /// @notice Action 4: Claim iETHv2 (Lite) stETH revenue to Team Multisig.
    /// @dev Collects `liteStethRevenueAmount` (set by Team Multisig) of stETH
    ///      revenue from iETHv2 into the Treasury, then forwards it to Team
    ///      Multisig via the Treasury DSA `BASIC-A` connector.
    function action4() internal isActionSkippable(4) {
        uint256 stethAmount_ = PayloadIGP134(ADDRESS_THIS)
            .liteStethRevenueAmount();
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
    // fetched: 2026-06-09T05:41:48.073Z, source: coingecko
    function STABLE_USD_PRICE() public pure override returns (uint256) {
        return 1 * 1e2;
    }
    // sUSDai is yield-bearing; the coingecko "usdai" id prices the base token
    // (~$1), so this is overridden to the yield-bearing value as in IGP-133.
    function SUSDAI_USD_PRICE() public pure override returns (uint256) {
        return 1.09 * 1e2;
    }
    // --- END AUTO-GENERATED PRICES ---
}
