// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.21;
pragma experimental ABIEncoderV2;

import {PayloadIGPPriceHelpers} from "../common/pricehelpers.sol";
import {IFluidDex} from "../common/interfaces/IFluidDex.sol";
import {
    AdminModuleStructs as FluidLiquidityAdminStructs
} from "../common/interfaces/IFluidLiquidity.sol";

/// @notice Schedule contract the CLX stock oracles read US equity session state from.
///         `updateAuth` writes auth classes 0-3 and is Liquidity governance only.
interface IFluidUsEquityMarketHours {
    function updateAuth(address auth_, uint256 authClass_) external;
}

/// @notice IGP140: Launch the weETH/ETH T1 vault (id 182) at dust limits.
///
///         Action 1 sets the vault's Liquidity Layer supply and borrow limits
///         and grants Team Multisig vault auth so limits can be scaled up
///         post-launch without another proposal.
///
///         The vault was deployed by the Team Multisig at block 25,789,585
///         (0x0b8a681ed46EA8ec6b97D686dF0631fBf84B03d2) and is still
///         unconfigured at the Liquidity Layer, so it cannot be used until
///         this payload executes.
///
///         This action was originally Action 2 of IGP-139 (the Foundation
///         grant). It moved here because the vault-auth call went to the
///         factory instead of the factory's owner and reverted the whole
///         proposal on execution; the grant has no dependency on the vault
///         launch.
///
///         Action 2 reduces the deprecated USDC-ETH DEX (5) max supply and
///         max borrow shares to ~$1M each (500k shares at ~$2/share), down
///         from 7.5M / 5M shares (~$15M / $10M).
///
///         Action 3 fully deprecates the osETH vaults' borrow side: T1
///         vaults 153-155 (USDC/USDT/GHO) are paused at the Liquidity Layer
///         and T3 vaults 156-157 are paused at the USDC-USDT (2) and
///         concentrated (34) DEXes. IGP-138 had already capped the T1 vaults
///         at $100k borrow.
///
///         Action 4 removes the Team Multisig dex auth that IGP-138 granted
///         on the newly launched USDat/USDC (49) and USDC/trUSD (50) DEXes.
///
///         Action 5 fully deprecates the weETHs and ezETH markets' borrow
///         side the same way as Action 3: vaults 80 (weETHs) and 103/104
///         (ezETH) — all wstETH debt — are deprecated at the Liquidity
///         Layer, and the rsETH-ETH (13), weETHs-ETH (14), and ezETH-ETH
///         (21) DEXes drop to 1 wei max supply shares. The rsETH vaults
///         78/79 already hold the deprecated config, so only their DEX is
///         touched.
///
///         Action 6 sets the legacy vault 1-10 base withdrawal limits to
///         the greater of $10k and the vault's live supply, with a normal
///         10% / 6h expansion, replacing the per-vault supply-pinned limits
///         set in IGP-132 so remaining suppliers can exit without limit
///         friction. Only vault 6 (~640 weETH) sits above the $10k floor.
///
///         Action 7 moves the US equity market hours schedule appointer from
///         Team Multisig to the 24h FluidTimelockController. Appointing a
///         schedule writer stops being an instant multisig action and gains a
///         24h delay; Team Multisig keeps class 2, so it can still correct a
///         session inside the 5h pinned window without waiting.
contract PayloadIGP140 is PayloadIGPPriceHelpers {
    uint256 public constant PROPOSAL_ID = 140;

    /// @notice weETH/ETH T1 vault, deployed via the Team Multisig.
    uint256 public constant VAULT_WEETH_ETH_ID = 182; // T1: weETH / ETH

    /// @notice Deprecated USDC-ETH DEX (dust-ceilinged since IGP-96).
    uint256 public constant USDC_ETH_DEX_ID = 5;

    // --- osETH vault ids (borrow side deprecated in Action 3) ---
    uint256 public constant VAULT_OSETH_USDC_ID = 153; // T1: osETH / USDC
    uint256 public constant VAULT_OSETH_USDT_ID = 154; // T1: osETH / USDT
    uint256 public constant VAULT_OSETH_GHO_ID = 155; // T1: osETH / GHO
    uint256 public constant VAULT_OSETH__USDC_USDT_ID = 156; // T3: osETH / USDC-USDT
    uint256 public constant VAULT_OSETH__USDC_USDT_CONC_ID = 157; // T3: osETH / USDC-USDT concentrated

    // --- weETHs / ezETH vault ids (borrow side deprecated in Action 5) ---
    uint256 public constant VAULT_WEETHS_ETH__WSTETH_ID = 80; // T2: weETHs-ETH / wstETH
    uint256 public constant VAULT_EZETH_WSTETH_ID = 103; // T1: ezETH / wstETH
    uint256 public constant VAULT_EZETH_ETH__WSTETH_ID = 104; // T2: ezETH-ETH / wstETH

    // --- DEX ids ---
    uint256 public constant USDC_USDT_DEX_ID = 2; // USDC-USDT (vault 156 smart debt)
    uint256 public constant USDC_USDT_CONC_DEX_ID = 34; // USDC-USDT concentrated (vault 157 smart debt)
    uint256 public constant RSETH_ETH_DEX_ID = 13; // rsETH-ETH (vault 78 smart collateral)
    uint256 public constant WEETHS_ETH_DEX_ID = 14; // weETHs-ETH (vault 80 smart collateral)
    uint256 public constant EZETH_ETH_DEX_ID = 21; // ezETH-ETH (vault 104 smart collateral)
    uint256 public constant USDAT_USDC_DEX_ID = 49; // USDat-USDC (launched in IGP-138)
    uint256 public constant USDC_TRUSD_DEX_ID = 50; // USDC-trUSD (launched in IGP-138)

    /// @notice US equity market hours schedule; UUPS, Liquidity governance owned.
    IFluidUsEquityMarketHours public constant US_EQUITY_MARKET_HOURS =
        IFluidUsEquityMarketHours(0xde51F64b1c94dc60AA1284741F19e2f9f425Fc67);

    function execute() public virtual override {
        super.execute();

        // Action 1: Set dust limits for weETH/ETH T1 vault.
        action1();

        // Action 2: Reduce USDC-ETH DEX (5) max supply and borrow shares to ~$1M.
        action2();

        // Action 3: Fully deprecate the osETH vaults' borrow side.
        action3();

        // Action 4: Remove Team Multisig dex auth granted in IGP-138 (DEXes 49, 50).
        action4();

        // Action 5: Fully deprecate rsETH, weETHs, and ezETH markets' borrow side.
        action5();

        // Action 6: Set legacy vault 1-10 base withdrawal to $10k, 10% / 6h expansion.
        action6();

        // Action 7: Move market hours schedule appointer to the 24h timelock.
        action7();
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

    /// @notice Action 1: Set dust limits for the weETH/ETH T1 vault (id 182)
    ///         and grant Team Multisig vault auth.
    /// @dev Vault auth goes through `VAULT_FACTORY_WRAPPER_OWNER`, not the
    ///      factory itself: `setVaultAuth` is `onlyOwner` on the factory and
    ///      the factory is owned by that wrapper, which the timelock is
    ///      authorized on. Calling the factory directly reverts UNAUTHORIZED.
    function action1() internal isActionSkippable(1) {
        address weETH_ETH_VAULT = getVaultAddress(VAULT_WEETH_ETH_ID);

        // [TYPE 1] weETH/ETH vault - Dust limits
        VaultConfig memory VAULT_weETH_ETH = VaultConfig({
            vault: weETH_ETH_VAULT,
            vaultType: VAULT_TYPE.TYPE_1,
            supplyToken: weETH_ADDRESS,
            borrowToken: ETH_ADDRESS,
            baseWithdrawalLimitInUSD: 7_000, // $7k
            baseBorrowLimitInUSD: 7_000, // $7k
            maxBorrowLimitInUSD: 9_000 // $9k
        });

        setVaultLimits(VAULT_weETH_ETH);

        VAULT_FACTORY_WRAPPER_OWNER.setVaultAuth(
            weETH_ETH_VAULT,
            TEAM_MULTISIG,
            true
        );
    }

    /// @notice Action 2: Reduce the deprecated USDC-ETH DEX (5) max supply
    ///         shares and max borrow shares to ~$1M each. The pool has been
    ///         dust-ceilinged since IGP-96 and holds only dust liquidity
    ///         (~101 supply / ~100 borrow shares), so the old 7.5M / 5M share
    ///         caps (~$15M / $10M) are unnecessary surface area.
    function action2() internal isActionSkippable(2) {
        address usdcEthDex_ = getDexAddress(USDC_ETH_DEX_ID);

        IFluidDex(usdcEthDex_).updateMaxSupplyShares(
            500_000 * 1e18 // ~$1M at ~$2/share (from 7.5M shares)
        );
        IFluidDex(usdcEthDex_).updateMaxBorrowShares(
            500_000 * 1e18 // ~$1M at ~$2/share (from 5M shares)
        );
    }

    /// @notice Action 3: Fully deprecate the osETH vaults' borrow side.
    ///         T1 vaults 153-155 get paused Liquidity Layer borrow configs
    ///         (dust ceilings, 0.01% expansion over max duration); T3 vaults
    ///         156-157 get the same treatment for their smart-debt shares at
    ///         the USDC-USDT (2) and concentrated (34) DEXes. Existing
    ///         positions can still repay and withdraw; only new borrowing is
    ///         blocked.
    function action3() internal isActionSkippable(3) {
        // T1 vaults 153-155: pause LL borrow side (osETH collateral vaults).
        setBorrowProtocolLimitsPaused(
            getVaultAddress(VAULT_OSETH_USDC_ID),
            USDC_ADDRESS
        );
        setBorrowProtocolLimitsPaused(
            getVaultAddress(VAULT_OSETH_USDT_ID),
            USDT_ADDRESS
        );
        setBorrowProtocolLimitsPaused(
            getVaultAddress(VAULT_OSETH_GHO_ID),
            GHO_ADDRESS
        );

        // T3 vaults 156-157: pause smart-debt shares at their DEXes.
        setBorrowProtocolLimitsPausedDex(
            getDexAddress(USDC_USDT_DEX_ID),
            getVaultAddress(VAULT_OSETH__USDC_USDT_ID)
        );
        setBorrowProtocolLimitsPausedDex(
            getDexAddress(USDC_USDT_CONC_DEX_ID),
            getVaultAddress(VAULT_OSETH__USDC_USDT_CONC_ID)
        );
    }

    /// @notice Action 4: Remove the Team Multisig dex auth granted in IGP-138
    ///         when the USDat/USDC (49) and USDC/trUSD (50) DEXes launched.
    function action4() internal isActionSkippable(4) {
        DEX_FACTORY.setDexAuth(
            getDexAddress(USDAT_USDC_DEX_ID),
            TEAM_MULTISIG,
            false
        );
        DEX_FACTORY.setDexAuth(
            getDexAddress(USDC_TRUSD_DEX_ID),
            TEAM_MULTISIG,
            false
        );
    }

    /// @notice Action 5: Fully deprecate the rsETH, weETHs, and ezETH
    ///         markets' borrow side, mirroring Action 3. Vaults 80, 103 and
    ///         104 borrow wstETH at the Liquidity Layer and get deprecated
    ///         configs (dust ceilings, 0.01% expansion over max duration);
    ///         the three smart-collateral DEXes drop to 1 wei max supply
    ///         shares so no new shares can be minted (rsETH-ETH 13: ~1,021
    ///         outstanding / 3,200 cap; weETHs-ETH 14: ~153 / 1,600;
    ///         ezETH-ETH 21: ~141 / 3,862). Existing positions can still
    ///         repay and withdraw.
    function action5() internal isActionSkippable(5) {
        // rsETH vaults 78 and 79 already carry the deprecated borrow config on-chain; only their DEX is left to cap.

        // weETHs: T2 vault 80 — deprecate wstETH borrow at the LL.
        setBorrowProtocolLimitsPaused(
            getVaultAddress(VAULT_WEETHS_ETH__WSTETH_ID),
            wstETH_ADDRESS
        );

        // ezETH: T1 vault 103 + T2 vault 104 — deprecate wstETH borrow at the LL.
        setBorrowProtocolLimitsPaused(
            getVaultAddress(VAULT_EZETH_WSTETH_ID),
            wstETH_ADDRESS
        );
        setBorrowProtocolLimitsPaused(
            getVaultAddress(VAULT_EZETH_ETH__WSTETH_ID),
            wstETH_ADDRESS
        );

        // Smart-collateral DEXes: block new supply shares (withdrawals unaffected).
        IFluidDex(getDexAddress(RSETH_ETH_DEX_ID)).updateMaxSupplyShares(1);
        IFluidDex(getDexAddress(WEETHS_ETH_DEX_ID)).updateMaxSupplyShares(1);
        IFluidDex(getDexAddress(EZETH_ETH_DEX_ID)).updateMaxSupplyShares(1);
    }

    /// @notice Action 6: Set the legacy vault 1-10 base withdrawal limits to
    ///         the greater of $10k and the vault's live supply, with a
    ///         10% / 6h expansion. IGP-132 had pinned each base limit to the
    ///         vault's then-current supply, which leaves any remaining
    ///         suppliers exiting against a tight, slow-expanding cap. Nine
    ///         of the ten vaults hold dust and take the $10k floor; vault 6
    ///         still holds ~640 weETH and takes a token-denominated limit
    ///         above that, so its withdrawal limit stays dormant.
    function action6() internal isActionSkippable(6) {
        // Vault 1: ETH / USDC
        _legacyVaultWithdrawalLimitUSD(1, ETH_ADDRESS);
        // Vault 2: ETH / USDT
        _legacyVaultWithdrawalLimitUSD(2, ETH_ADDRESS);
        // Vault 3: wstETH / ETH
        _legacyVaultWithdrawalLimitUSD(3, wstETH_ADDRESS);
        // Vault 4: wstETH / USDC
        _legacyVaultWithdrawalLimitUSD(4, wstETH_ADDRESS);
        // Vault 5: wstETH / USDT
        _legacyVaultWithdrawalLimitUSD(5, wstETH_ADDRESS);
        // Vault 6: weETH / wstETH — ~640 weETH still supplied, so the $10k
        // floor would cap exits well below the live balance.
        _legacyVaultWithdrawalLimitRaw(6, weETH_ADDRESS, 700 * 1e18);
        // Vault 7: sUSDe / USDC
        _legacyVaultWithdrawalLimitUSD(7, sUSDe_ADDRESS);
        // Vault 8: sUSDe / USDT
        _legacyVaultWithdrawalLimitUSD(8, sUSDe_ADDRESS);
        // Vault 9: weETH / USDC
        _legacyVaultWithdrawalLimitUSD(9, weETH_ADDRESS);
        // Vault 10: weETH / USDT
        _legacyVaultWithdrawalLimitUSD(10, weETH_ADDRESS);
    }

    /// @dev $10k base withdrawal limit with 10% / 6h expansion for one legacy
    ///      vault. Named `..USD`-style so prepare-prices detects the token.
    function _legacyVaultWithdrawalLimitUSD(
        uint256 vaultId_,
        address supplyToken_
    ) internal {
        setSupplyProtocolLimits(
            SupplyProtocolConfig({
                protocol: getVaultAddress(vaultId_),
                supplyToken: supplyToken_,
                expandPercent: 10 * 1e2, // 10%
                expandDuration: 6 hours,
                baseWithdrawalLimitInUSD: 10_000 // $10k
            })
        );
    }

    /// @dev Same 10% / 6h expansion, base limit given in token terms instead.
    ///      For vaults whose live supply is above the $10k floor, where the
    ///      flat limit would activate the withdrawal rate limit and add the
    ///      exit friction this action exists to remove. The token amount is
    ///      set above current supply, so the limit stays dormant.
    function _legacyVaultWithdrawalLimitRaw(
        uint256 vaultId_,
        address supplyToken_,
        uint256 baseWithdrawalLimit_
    ) internal {
        FluidLiquidityAdminStructs.UserSupplyConfig[]
            memory configs_ = new FluidLiquidityAdminStructs.UserSupplyConfig[](
                1
            );

        configs_[0] = FluidLiquidityAdminStructs.UserSupplyConfig({
            user: getVaultAddress(vaultId_),
            token: supplyToken_,
            mode: 1,
            expandPercent: 10 * 1e2, // 10%
            expandDuration: 6 hours,
            baseWithdrawalLimit: getRawAmount(
                supplyToken_,
                baseWithdrawalLimit_,
                0,
                true
            )
        });

        LIQUIDITY.updateUserSupplyConfigs(configs_);
    }

    /// @notice Action 7: Hand the US equity market hours schedule appointer
    ///         (auth class 3) to the 24h FluidTimelockController and drop Team
    ///         Multisig to class 2.
    /// @dev Ordered grant-then-demote so the contract is never left without an
    ///      appointer. Class 2 keeps Team Multisig able to rewrite sessions
    ///      inside the 5h pinned window; only appointing a class-1 schedule
    ///      writer moves behind the timelock.
    function action7() internal isActionSkippable(7) {
        US_EQUITY_MARKET_HOURS.updateAuth(FLUID_MULTISIG_TIMELOCK_CONTROLLER, 3);
        US_EQUITY_MARKET_HOURS.updateAuth(TEAM_MULTISIG, 2);
    }

    /**
     * |
     * |     Payload Actions End Here      |
     * |__________________________________
     */

    // --- BEGIN AUTO-GENERATED PRICES (scripts/verify/prepare-prices.ts) ---
    // fetched: 2026-09-04T04:16:26.194Z, source: coingecko
    function ETH_USD_PRICE()    public pure override returns (uint256) { return 2_510 * 1e2; }
    function sUSDe_USD_PRICE()  public pure override returns (uint256) { return 1.25 * 1e2; }
    function weETH_USD_PRICE()  public pure override returns (uint256) { return 2_760 * 1e2; }
    function wstETH_USD_PRICE() public pure override returns (uint256) { return 3_120 * 1e2; }
    // --- END AUTO-GENERATED PRICES ---
}
