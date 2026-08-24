// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.21;
pragma experimental ABIEncoderV2;

import {
    AdminModuleStructs as FluidLiquidityAdminStructs
} from "../common/interfaces/IFluidLiquidity.sol";
import {IFluidDex} from "../common/interfaces/IFluidDex.sol";
import {PayloadIGPPriceHelpers} from "../common/pricehelpers.sol";

/// @notice IGP138: Tighten borrow surface area on osETH, tBTC, eBTC, LBTC,
///         and ezETH vaults; update reUSD and osETH-ETH DEX ranges; and set
///         initial limits for the USDat/USDC (id 49) and USDC/trUSD (id 50)
///         smart-lending DEXes.
///
///         Actions 1–4 cap borrow exposure on legacy collateral vaults so
///         limits can be raised later if demand returns. Action 5 trims the
///         reUSD-USDT DEX (44) range; Action 6 widens the osETH-ETH DEX (43)
///         upper range; Action 7 sets USDat/USDC pool limits and grants Team
///         Multisig dex auth; Action 8 swaps the weETH-ETH DEX (9) fee-handler
///         auth to the new handler; Action 9 raises the legacy ETH/USDC vault
///         (1) ETH base withdrawal limit to 2 ETH (10% / 12h expansion) to
///         unblock suppliers stuck above the wind-down limit; Action 10 sets
///         USDC/trUSD pool (id 50) limits and grants Team Multisig dex auth.
contract PayloadIGP138 is PayloadIGPPriceHelpers {
    uint256 public constant PROPOSAL_ID = 138;

    // --- legacy vault ids ---
    uint256 public constant VAULT_ETH_USDC_ID = 1; // T1: ETH / USDC (legacy, wound down)

    // --- osETH vault ids (verified on-chain via getVaultAddress) ---
    uint256 public constant VAULT_OSETH_USDC_ID = 153; // T1: osETH / USDC
    uint256 public constant VAULT_OSETH_USDT_ID = 154; // T1: osETH / USDT
    uint256 public constant VAULT_OSETH_GHO_ID = 155; // T1: osETH / GHO
    uint256 public constant VAULT_OSETH__USDC_USDT_ID = 156; // T3: osETH / USDC-USDT
    uint256 public constant VAULT_OSETH__USDC_USDT_CONC_ID = 157; // T3: osETH / USDC-USDT concentrated

    // --- tBTC / eBTC / LBTC / ezETH vault ids ---
    uint256 public constant VAULT_TBTC_USDC_ID = 88; // T1: tBTC / USDC
    uint256 public constant VAULT_TBTC_USDT_ID = 89; // T1: tBTC / USDT
    uint256 public constant VAULT_TBTC_GHO_ID = 90; // T1: tBTC / GHO
    uint256 public constant VAULT_EBTC_WBTC_ID = 94; // T1: eBTC / WBTC
    uint256 public constant VAULT_LBTC_USDC_ID = 107; // T1: LBTC / USDC
    uint256 public constant VAULT_LBTC_USDT_ID = 108; // T1: LBTC / USDT
    uint256 public constant VAULT_LBTC_GHO_ID = 109; // T1: LBTC / GHO
    uint256 public constant VAULT_LBTC_CBBTC_WBTC_ID = 97; // T2: LBTC-cbBTC / WBTC
    uint256 public constant VAULT_LBTC_CBBTC_CBBTC_ID = 114; // T2: LBTC-cbBTC / cbBTC
    uint256 public constant VAULT_WBTC_LBTC_WBTC_ID = 115; // T2: WBTC-LBTC / WBTC
    uint256 public constant VAULT_EZETH_WSTETH_ID = 103; // T1: ezETH / wstETH
    uint256 public constant VAULT_EZETH_ETH__WSTETH_ID = 104; // T2: ezETH-ETH / wstETH

    // --- DEX ids ---
    uint256 public constant OSETH_ETH_DEX_ID = 43; // osETH-ETH
    uint256 public constant REUSD_USDT_DEX_ID = 44; // reUSD-USDT
    uint256 public constant USDC_USDT_DEX_ID = 2; // USDC-USDT
    uint256 public constant USDC_USDT_CONC_DEX_ID = 34; // USDC-USDT concentrated
    uint256 public constant USDAT_USDC_DEX_ID = 49; // USDat-USDC (new smart-lending pool)
    uint256 public constant USDC_TRUSD_DEX_ID = 50; // USDC-trUSD (new smart-lending pool, deployed after USDat-USDC)
    uint256 public constant WEETH_ETH_DEX_ID = 9; // weETH-ETH

    address public constant OLD_DEX_FEE_HANDLER =
        0xD43d85f4F4eEDdA3ed3BbE2Ca7351eE32b8bB44a;
    address public constant NEW_DEX_FEE_HANDLER =
        0x534633b92E67e59D90FBCb73fb6F28CbB8c5FB6E;

    function execute() public virtual override {
        super.execute();

        // Action 1: Cap osETH vault borrow at $100k (5 vaults).
        action1();

        // Action 2: Cap tBTC (3) + eBTC/WBTC (1) vault borrow at $100k.
        action2();

        // Action 3: Cap all LBTC vault max borrow at $1M (6 vaults).
        action3();

        // Action 4: Cap ezETH T1 at $100k and T2 at $1M borrow.
        action4();

        // Action 5: Trim reUSD-USDT DEX (44) range.
        action5();

        // Action 6: Widen osETH-ETH DEX (43) upper range.
        action6();

        // Action 7: Set USDat/USDC DEX (49) limits + grant Team MS auth.
        action7();

        // Action 8: Swap weETH-ETH DEX (9) fee-handler auth old → new.
        action8();

        // Action 9: Raise legacy ETH/USDC vault (1) ETH base withdrawal
        // limit to 2 ETH (10% / 12h expansion) to unblock stuck suppliers.
        action9();

        // Action 10: Set USDC/trUSD DEX (50) limits + grant Team MS auth.
        action10();
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

    /// @notice Action 1: Reduce the five osETH vaults to $100k borrow
    ///         (base = max). T1 vaults 153–155 at the Liquidity Layer;
    ///         T3 vaults 156–157 at the USDC-USDT (id 2) and concentrated
    ///         (id 34) DEXes. Withdrawal limits are unchanged.
    function action1() internal isActionSkippable(1) {
        FluidLiquidityAdminStructs.UserBorrowConfig[]
            memory configs_ = new FluidLiquidityAdminStructs.UserBorrowConfig[](
                3
            );

        configs_[0] = _borrowConfigUSD(
            VAULT_OSETH_USDC_ID,
            USDC_ADDRESS,
            25 * 1e2,
            100_000,
            100_000
        );
        configs_[1] = _borrowConfigUSD(
            VAULT_OSETH_USDT_ID,
            USDT_ADDRESS,
            25 * 1e2,
            100_000,
            100_000
        );
        configs_[2] = _borrowConfigUSD(
            VAULT_OSETH_GHO_ID,
            GHO_ADDRESS,
            25 * 1e2,
            100_000,
            100_000
        );

        LIQUIDITY.updateUserBorrowConfigs(configs_);

        address usdcUsdtDex_ = getDexAddress(USDC_USDT_DEX_ID);
        address usdcUsdtConcDex_ = getDexAddress(USDC_USDT_CONC_DEX_ID);

        // Vault 156: osETH / USDC-USDT — $100k base / $100k max (from $1M max)
        setDexBorrowProtocolLimitsInShares(
            DexBorrowProtocolConfigInShares({
                dex: usdcUsdtDex_,
                protocol: getVaultAddress(VAULT_OSETH__USDC_USDT_ID),
                expandPercent: 25 * 1e2, // 25% (unchanged)
                expandDuration: 3 hours, // (unchanged)
                baseBorrowLimit: 45_000 * 1e18, // $100K in shares
                maxBorrowLimit: 45_000 * 1e18 // $100K in shares
            })
        );

        // Vault 157: osETH / USDC-USDT concentrated — $100k base / $100k max
        setDexBorrowProtocolLimitsInShares(
            DexBorrowProtocolConfigInShares({
                dex: usdcUsdtConcDex_,
                protocol: getVaultAddress(VAULT_OSETH__USDC_USDT_CONC_ID),
                expandPercent: 25 * 1e2, // 25% (unchanged)
                expandDuration: 3 hours, // (unchanged)
                baseBorrowLimit: 47_000 * 1e18, // $100K in shares
                maxBorrowLimit: 47_000 * 1e18 // $100K in shares
            })
        );
    }

    /// @notice Action 2: Reduce the three tBTC T1 vaults (88–90) and the
    ///         eBTC/WBTC T1 vault (94) to $100k borrow (base = max).
    function action2() internal isActionSkippable(2) {
        FluidLiquidityAdminStructs.UserBorrowConfig[]
            memory configs_ = new FluidLiquidityAdminStructs.UserBorrowConfig[](
                4
            );

        configs_[0] = _borrowConfigUSD(
            VAULT_TBTC_USDC_ID,
            USDC_ADDRESS,
            25 * 1e2,
            100_000,
            100_000
        );
        configs_[1] = _borrowConfigUSD(
            VAULT_TBTC_USDT_ID,
            USDT_ADDRESS,
            25 * 1e2,
            100_000,
            100_000
        );
        configs_[2] = _borrowConfigUSD(
            VAULT_TBTC_GHO_ID,
            GHO_ADDRESS,
            25 * 1e2,
            100_000,
            100_000
        );
        configs_[3] = _borrowConfigUSD(
            VAULT_EBTC_WBTC_ID,
            WBTC_ADDRESS,
            25 * 1e2,
            100_000,
            100_000
        );

        LIQUIDITY.updateUserBorrowConfigs(configs_);
    }

    /// @notice Action 3: Reduce all LBTC vault max borrow to $1M (base = max).
    ///         Covers T1 vaults 107–109 and T2 vaults 97, 114, 115.
    function action3() internal isActionSkippable(3) {
        FluidLiquidityAdminStructs.UserBorrowConfig[]
            memory configs_ = new FluidLiquidityAdminStructs.UserBorrowConfig[](
                6
            );

        configs_[0] = _borrowConfigUSD(
            VAULT_LBTC_USDC_ID,
            USDC_ADDRESS,
            25 * 1e2,
            1_000_000,
            1_000_000
        );
        configs_[1] = _borrowConfigUSD(
            VAULT_LBTC_USDT_ID,
            USDT_ADDRESS,
            25 * 1e2,
            1_000_000,
            1_000_000
        );
        configs_[2] = _borrowConfigUSD(
            VAULT_LBTC_GHO_ID,
            GHO_ADDRESS,
            25 * 1e2,
            1_000_000,
            1_000_000
        );
        configs_[3] = _borrowConfigUSD(
            VAULT_LBTC_CBBTC_WBTC_ID,
            WBTC_ADDRESS,
            25 * 1e2,
            1_000_000,
            1_000_000
        );
        configs_[4] = _borrowConfigUSD(
            VAULT_LBTC_CBBTC_CBBTC_ID,
            cbBTC_ADDRESS,
            25 * 1e2,
            1_000_000,
            1_000_000
        );
        configs_[5] = _borrowConfigUSD(
            VAULT_WBTC_LBTC_WBTC_ID,
            WBTC_ADDRESS,
            25 * 1e2,
            1_000_000,
            1_000_000
        );

        LIQUIDITY.updateUserBorrowConfigs(configs_);
    }

    /// @notice Action 4: Reduce ezETH T1 vault (103) borrow to $100k and
    ///         ezETH-ETH T2 vault (104) borrow to $1M (base = max each).
    function action4() internal isActionSkippable(4) {
        FluidLiquidityAdminStructs.UserBorrowConfig[]
            memory configs_ = new FluidLiquidityAdminStructs.UserBorrowConfig[](
                2
            );

        configs_[0] = _borrowConfigUSD(
            VAULT_EZETH_WSTETH_ID,
            wstETH_ADDRESS,
            25 * 1e2,
            100_000,
            100_000
        );
        configs_[1] = _borrowConfigUSD(
            VAULT_EZETH_ETH__WSTETH_ID,
            wstETH_ADDRESS,
            25 * 1e2,
            1_000_000,
            1_000_000
        );

        LIQUIDITY.updateUserBorrowConfigs(configs_);
    }

    /// @notice Action 5: Trim the reUSD-USDT DEX (44) upper range to 0.15%
    ///         and lower range to 0.4% over 4 days (IGP-128 sUSDe-USDT pattern).
    function action5() internal isActionSkippable(5) {
        IFluidDex(getDexAddress(REUSD_USDT_DEX_ID)).updateRangePercents(
            0.15 * 1e4, // upper range: 0.15%
            0.4 * 1e4, // lower range: 0.4%
            4 days
        );
    }

    /// @notice Action 6: Increase the osETH-ETH DEX (43) upper range to 0.5%
    ///         over 12 days. Lower range is left at the current 0.0001%
    ///         on-chain value.
    function action6() internal isActionSkippable(6) {
        IFluidDex(getDexAddress(OSETH_ETH_DEX_ID)).updateRangePercents(
            0.5 * 1e4, // upper range: 0.5%
            0.0001 * 1e4, // lower range: 0.0001% (unchanged)
            12 days
        );
    }

    /// @notice Action 7: Set $5M/token LL withdrawal limits for the
    ///         USDat/USDC DEX (id 49) and grant Team Multisig dex auth.
    function action7() internal isActionSkippable(7) {
        address usdatUsdcDex_ = getDexAddress(USDAT_USDC_DEX_ID);

        DexConfig memory DEX_USDAT_USDC = DexConfig({
            dex: usdatUsdcDex_,
            tokenA: USDAT_ADDRESS,
            tokenB: USDC_ADDRESS,
            smartCollateral: true,
            smartDebt: false,
            baseWithdrawalLimitInUSD: 5_000_000, // $5M per token
            baseBorrowLimitInUSD: 0,
            maxBorrowLimitInUSD: 0
        });
        setDexLimits(DEX_USDAT_USDC);

        DEX_FACTORY.setDexAuth(usdatUsdcDex_, TEAM_MULTISIG, true);
    }

    /// @notice Action 8: Swap the weETH-ETH DEX (9) fee-handler auth from the
    ///         old handler (added in IGP-113) to the new handler, revoking the
    ///         old address.
    function action8() internal isActionSkippable(8) {
        address weethEthDex_ = getDexAddress(WEETH_ETH_DEX_ID);

        DEX_FACTORY.setDexAuth(weethEthDex_, OLD_DEX_FEE_HANDLER, false);
        DEX_FACTORY.setDexAuth(weethEthDex_, NEW_DEX_FEE_HANDLER, true);
    }

    /// @notice Action 9: Raise the legacy ETH/USDC vault (id 1) ETH base
    ///         withdrawal limit to 2 ETH and restore a normal 10% / 12h
    ///         withdrawal-limit expansion. The vault was wound down with the
    ///         base limit at/below the currently supplied balance and
    ///         expansion frozen at 0.01% over max duration, leaving suppliers
    ///         stuck and unable to withdraw. A 2 ETH base limit sits above the
    ///         vault's total supplied ETH so stuck positions can exit in full.
    function action9() internal isActionSkippable(9) {
        FluidLiquidityAdminStructs.UserSupplyConfig[]
            memory configs_ = new FluidLiquidityAdminStructs.UserSupplyConfig[](
                1
            );

        configs_[0] = FluidLiquidityAdminStructs.UserSupplyConfig({
            user: getVaultAddress(VAULT_ETH_USDC_ID),
            token: ETH_ADDRESS,
            mode: 1,
            expandPercent: 10 * 1e2, // 10% (from frozen 0.01%)
            expandDuration: 12 hours, // (from max duration)
            baseWithdrawalLimit: getRawAmount(ETH_ADDRESS, 2 ether, 0, true)
        });

        LIQUIDITY.updateUserSupplyConfigs(configs_);
    }

    /// @notice Action 10: Set $5M/token LL withdrawal limits for the
    ///         USDC/trUSD DEX (id 50) and grant Team Multisig dex auth.
    function action10() internal isActionSkippable(10) {
        address usdcTrusdDex_ = getDexAddress(USDC_TRUSD_DEX_ID);

        DexConfig memory DEX_USDC_TRUSD = DexConfig({
            dex: usdcTrusdDex_,
            tokenA: USDC_ADDRESS,
            tokenB: TRUSD_ADDRESS,
            smartCollateral: true,
            smartDebt: false,
            baseWithdrawalLimitInUSD: 5_000_000, // $5M per token
            baseBorrowLimitInUSD: 0,
            maxBorrowLimitInUSD: 0
        });
        setDexLimits(DEX_USDC_TRUSD);

        DEX_FACTORY.setDexAuth(usdcTrusdDex_, TEAM_MULTISIG, true);
    }

    /**
     * |
     * |     Payload Actions End Here      |
     * |__________________________________
     */

    /// @dev Build a Liquidity Layer borrow config from USD targets.
    function _borrowConfigUSD(
        uint256 vaultId_,
        address token_,
        uint256 expandPercent_,
        uint256 baseUSD_,
        uint256 maxUSD_
    )
        internal
        view
        returns (FluidLiquidityAdminStructs.UserBorrowConfig memory)
    {
        return
            FluidLiquidityAdminStructs.UserBorrowConfig({
                user: getVaultAddress(vaultId_),
                token: token_,
                mode: 1,
                expandPercent: expandPercent_,
                expandDuration: 3 hours,
                baseDebtCeiling: getRawAmount(token_, 0, baseUSD_, false),
                maxDebtCeiling: getRawAmount(token_, 0, maxUSD_, false)
            });
    }

    // --- BEGIN AUTO-GENERATED PRICES (scripts/verify/prepare-prices.ts) ---
    // fetched: 2026-08-15T12:55:24.038Z, source: coingecko
    function BTC_USD_PRICE()    public pure override returns (uint256) { return 63_000 * 1e2; }
    function STABLE_USD_PRICE() public pure override returns (uint256) { return 1 * 1e2; }
    function wstETH_USD_PRICE() public pure override returns (uint256) { return 2_330 * 1e2; }
    // --- END AUTO-GENERATED PRICES ---
}
