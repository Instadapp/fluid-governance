// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.21;
pragma experimental ABIEncoderV2;

import {IERC20} from "../common/interfaces/IERC20.sol";
import {IFluidReserveContractV2} from "../common/interfaces/IFluidReserveContract.sol";
import {IFluidVault, IFluidVaultT1} from "../common/interfaces/IFluidVault.sol";
import {IFluidDex, IFluidAdminDex} from "../common/interfaces/IFluidDex.sol";
import {PayloadIGPPriceHelpers} from "../common/pricehelpers.sol";

/// @notice IGP136: Collect Liquidity Layer revenue into the Reserve Contract
///         and forward it to Team Multisig, then migrate the sUSDai vault
///         oracles to the newly deployed capped-rate oracles.
///
///         Action 1 collects the Liquidity Layer revenue for every token
///         currently accruing more than $5k of uncollected revenue (USDC,
///         USDT, ETH, GHO, weETH) into the Fluid Reserve, then forwards the
///         swept balances to Team Multisig. The Liquidity Layer revenue
///         collector is the Fluid Reserve, so `collectRevenue` lands the
///         funds in the Reserve before the single `withdrawFunds` forward.
///
///         Action 2 points the 8 live sUSDai vaults (171–173, 175–179) at the
///         newly deployed oracles that reference CappedRateChainlink_SUSDAI
///         (DF nonce 258) instead of the raw exchange-rate contract. T1 vaults
///         take the new oracle address; T2/T3/T4 vaults take the DeployerFactory
///         nonce. It also re-points the sUSDai-USDC (DEX 46) and sUSDai-USDT
///         (DEX 48) DEX center prices to the same capped rate (DF nonce 258).
///         Max operate-rate delta vs the current oracles is < 0.01%.
///
///         Action 3 rebalances the PST T4 vault (169) supply-side drift from the
///         Reserve: approve PST + USDC, allow-list the Timelock as rebalancer,
///         rebalance the supply drift and allow positive debt drift to flow into
///         the Reserve, then revoke.
///
///         Action 4 launches reUSD DEX 44 and vaults 170 (T4) + 181 (T3) from
///         dust limits to launch limits (DEX max supply / LL limits / fee /
///         range, vault withdrawal & borrow caps) and removes Team Multisig
///         auth. Vault risk params (CF/LT/LML/LP) are configured via MS1.
///
///         Action 5 raises the PST / USDC (165) and PST / USDT (166) T1 vault
///         max borrow limits to $15.1M (from $10M). Base borrow ($5M),
///         withdrawal ($8M) and borrow expansion (50% / 6h) are unchanged.
contract PayloadIGP136 is PayloadIGPPriceHelpers {
    uint256 public constant PROPOSAL_ID = 136;

    // --- sUSDai vault ids (verified on-chain via getVaultAddress) ---
    uint256 public constant VAULT_SUSDAI_USDC_ID = 171; // T1: sUSDai / USDC
    uint256 public constant VAULT_SUSDAI_USDT_ID = 172; // T1: sUSDai / USDT
    uint256 public constant VAULT_SUSDAI__USDC_USDT_ID = 173; // T3: sUSDai / USDC-USDT
    uint256 public constant VAULT_SUSDAI_USDC__USDC_USDT_ID = 175; // T4: sUSDai-USDC / USDC-USDT
    uint256 public constant VAULT_SUSDAI_USDT__USDC_USDT_ID = 176; // T4: sUSDai-USDT / USDC-USDT
    uint256 public constant VAULT_SUSDAI_USDT__USDT_ID = 177; // T2: sUSDai-USDT / USDT
    uint256 public constant VAULT_SUSDAI_USDC__USDC_ID = 178; // T2: sUSDai-USDC / USDC
    uint256 public constant VAULT_SUSDAI_GHO_ID = 179; // T1: sUSDai / GHO

    // --- sUSDai DEX ids whose center price tracks the sUSDai rate ---
    uint256 public constant SUSDAI_USDC_DEX_ID = 46; // sUSDai / USDC
    uint256 public constant SUSDAI_USDT_DEX_ID = 48; // sUSDai / USDT

    // --- reUSD vault ids (verified on-chain via getVaultAddress) ---
    uint256 public constant REUSD_USDT_DEX_ID = 44; // reUSD-USDT
    uint256 public constant USDC_USDT_DEX_ID = 2; // USDC-USDT
    uint256 public constant GHO_USDC_DEX_ID = 4; // GHO-USDC
    uint256 public constant VAULT_REUSD_USDT__USDC_USDT_ID = 170; // T4: reUSD-USDT / USDC-USDT
    uint256 public constant VAULT_REUSD__GHO_USDC_ID = 181; // T3: reUSD / GHO-USDC

    // --- PST T1 vault ids (verified on-chain via getVaultAddress) ---
    uint256 public constant VAULT_PST_USDC_ID = 165; // T1: PST / USDC
    uint256 public constant VAULT_PST_USDT_ID = 166; // T1: PST / USDT

    // --- Shared capped sUSDai rate (CappedRateChainlink_SUSDAI) ---
    // DeployerFactory nonce, used as the DEX center-price address.
    uint256 public constant SUSDAI_CAPPED_RATE_NONCE = 258;

    // --- Newly deployed sUSDai vault oracles (DeployerFactory nonces 259–266),
    //     all referencing CappedRateChainlink_SUSDAI (DF nonce 258) ---
    // T1 oracles are passed by address; T2/T3/T4 oracles by DeployerFactory nonce.
    address public constant ORACLE_SUSDAI_USDC =
        0x08E954EfD116563894dec499EFF1Ed34F4B1Ef4e; // DF 259
    address public constant ORACLE_SUSDAI_USDT =
        0xcDC110DCE4A65c15F613D37D99450dbbC853eA72; // DF 260
    address public constant ORACLE_SUSDAI_GHO =
        0x0327cBbBFd3BfF6F32EB0A832F00c7B382b863B4; // DF 261

    function execute() public virtual override {
        super.execute();

        // Action 1: Collect Liquidity Layer revenue (>$5k tokens) into the
        // Reserve and forward it to Team Multisig.
        action1();

        // Action 2: Migrate the 8 sUSDai vault oracles to the new capped-rate oracles.
        action2();

        // Action 3: Rebalance the PST T4 vault (169) supply-side drift from the Reserve.
        action3();

        // Action 4: Raise reUSD vaults 170 + 181 from dust to launch limits.
        action4();

        // Action 5: Raise PST/USDC (165) + PST/USDT (166) max borrow to $15.1M.
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

    /// @notice Action 1: Collect the Liquidity Layer revenue for tokens
    ///         accruing >$5k (USDC, USDT, ETH, GHO, weETH) into the Reserve,
    ///         then forward the balances to Team Multisig.
    function action1() internal isActionSkippable(1) {
        address reserve_ = address(FLUID_RESERVE);

        // Step 1: Collect Liquidity Layer revenue (>$5k tokens) to the revenue
        // collector (Reserve).
        address[] memory liquidityTokens_ = new address[](5);
        liquidityTokens_[0] = USDC_ADDRESS; // ~$84.7k
        liquidityTokens_[1] = USDT_ADDRESS; // ~$50.8k
        liquidityTokens_[2] = ETH_ADDRESS; // ~$36.5k
        liquidityTokens_[3] = GHO_ADDRESS; // ~$8.8k
        liquidityTokens_[4] = weETH_ADDRESS; // ~$5.4k

        LIQUIDITY.collectRevenue(liquidityTokens_);

        // Step 2: Forward the swept balances (collected revenue + pre-existing
        // dust) from the Reserve to Team Multisig, leaving operational dust.
        address[] memory tokens_ = new address[](5);
        uint256[] memory amounts_ = new uint256[](5);

        tokens_[0] = USDC_ADDRESS;
        // Retain 3,400 USDC for the Action 3 rebalance; forward the rest.
        amounts_[0] = IERC20(USDC_ADDRESS).balanceOf(reserve_) - 3_400 * 1e6;

        tokens_[1] = USDT_ADDRESS;
        amounts_[1] = IERC20(USDT_ADDRESS).balanceOf(reserve_) - 10;

        tokens_[2] = ETH_ADDRESS;
        amounts_[2] = reserve_.balance - 0.1 ether;

        tokens_[3] = GHO_ADDRESS;
        amounts_[3] = IERC20(GHO_ADDRESS).balanceOf(reserve_) - 0.1 ether;

        tokens_[4] = weETH_ADDRESS;
        amounts_[4] = IERC20(weETH_ADDRESS).balanceOf(reserve_) - 0.1 ether;

        IFluidReserveContractV2(address(FLUID_RESERVE)).withdrawFunds(
            tokens_,
            amounts_,
            TEAM_MULTISIG,
            "REVENUE COLLECTION"
        );
    }

    /// @notice Action 2: Migrate the 8 live sUSDai vaults (171–173, 175–179)
    ///         from the raw exchange-rate oracles to the newly deployed oracles
    ///         referencing CappedRateChainlink_SUSDAI (DF nonce 258), and
    ///         re-point the sUSDai-USDC (DEX 46) and sUSDai-USDT (DEX 48) DEX
    ///         center prices to the same capped rate (DF nonce 258).
    /// @dev T1 vaults take the new oracle address via `updateOracle(address)`;
    ///      T2/T3/T4 vaults take the DeployerFactory nonce via
    ///      `updateOracle(uint256)`. `updateOracle` probes
    ///      `getExchangeRateOperate()` / `getExchangeRateLiquidate()` on the
    ///      target oracle before committing.
    function action2() internal isActionSkippable(2) {
        // --- DEX center prices: re-point to the capped sUSDai rate (DF 258) ---
        // 1% shift cap over 2 days (matching IGP-105's oracle + center-price
        // migration). The new capped-rate center price is near-identical to the
        // current one (<0.01% delta), so the transition completes well within
        // the cap. DEX 47 (USDai-USDC) does not track the sUSDai rate and is
        // intentionally left unchanged.
        IFluidDex(getDexAddress(SUSDAI_USDC_DEX_ID)).updateCenterPriceAddress(
            SUSDAI_CAPPED_RATE_NONCE,
            1e4,
            2 days
        );
        IFluidDex(getDexAddress(SUSDAI_USDT_DEX_ID)).updateCenterPriceAddress(
            SUSDAI_CAPPED_RATE_NONCE,
            1e4,
            2 days
        );

        // --- T1 vaults: updateOracle(address) ---
        IFluidVaultT1(getVaultAddress(VAULT_SUSDAI_USDC_ID)).updateOracle(
            ORACLE_SUSDAI_USDC // DF 259, GenericOracle_SUSDAI_USDC
        );
        IFluidVaultT1(getVaultAddress(VAULT_SUSDAI_USDT_ID)).updateOracle(
            ORACLE_SUSDAI_USDT // DF 260, GenericOracle_SUSDAI_USDT
        );
        IFluidVaultT1(getVaultAddress(VAULT_SUSDAI_GHO_ID)).updateOracle(
            ORACLE_SUSDAI_GHO // DF 261, GenericOracle_SUSDAI_GHO
        );

        // --- T2/T3/T4 vaults: updateOracle(uint256 DeployerFactory nonce) ---
        // Vault 178 (T2): DexSmartColPegOracle_SUSDAI-USDC_USDC
        IFluidVault(getVaultAddress(VAULT_SUSDAI_USDC__USDC_ID)).updateOracle(
            262
        );
        // Vault 177 (T2): DexSmartColPegOracle_SUSDAI-USDT_USDT
        IFluidVault(getVaultAddress(VAULT_SUSDAI_USDT__USDT_ID)).updateOracle(
            263
        );
        // Vault 173 (T3): DexSmartDebtPegOracle_SUSDAI_USDC-USDT
        IFluidVault(getVaultAddress(VAULT_SUSDAI__USDC_USDT_ID)).updateOracle(
            264
        );
        // Vault 175 (T4): DexSmartDebtPegOracle_T4_SUSDAI-USDC_USDC-USDT
        IFluidVault(getVaultAddress(VAULT_SUSDAI_USDC__USDC_USDT_ID))
            .updateOracle(265);
        // Vault 176 (T4): DexSmartDebtPegOracle_T4_SUSDAI-USDT_USDC-USDT
        IFluidVault(getVaultAddress(VAULT_SUSDAI_USDT__USDC_USDT_ID))
            .updateOracle(266);
    }

    /// @notice Action 3: Rebalance the PST T4 vault (169) supply-side drift from
    ///         the Reserve. Any positive debt drift is sent to the Reserve; the
    ///         Reserve must hold the PST + USDC at execution.
    function action3() internal isActionSkippable(3) {
        address vault_ = getVaultAddress(169);

        // Approve the vault to pull PST + USDC from the Reserve.
        {
            address[] memory protocols_ = new address[](2);
            address[] memory tokens_ = new address[](2);
            uint256[] memory amounts_ = new uint256[](2);

            protocols_[0] = vault_;
            tokens_[0] = PST_ADDRESS;
            amounts_[0] = 2_400 * 1e6;

            protocols_[1] = vault_;
            tokens_[1] = USDC_ADDRESS;
            amounts_[1] = 3_400 * 1e6;

            FLUID_RESERVE.approve(protocols_, tokens_, amounts_);
        }

        // Allow-list the Timelock as rebalancer, run the rebalance, then remove it.
        FLUID_RESERVE.updateRebalancer(address(TIMELOCK), true);
        {
            address[] memory protocols_ = new address[](1);
            uint256[] memory values_ = new uint256[](1);
            int256[] memory colToken0MinMax_ = new int256[](1);
            int256[] memory colToken1MinMax_ = new int256[](1);
            int256[] memory debtToken0MinMax_ = new int256[](1);
            int256[] memory debtToken1MinMax_ = new int256[](1);

            protocols_[0] = vault_;
            colToken0MinMax_[0] = 1e24; // PST deposit cap
            colToken1MinMax_[0] = 1e24; // USDC deposit cap
            // Permit positive smart-debt drift to be borrowed from the DEX into
            // the Reserve. One raw unit per token is the minimum accepted output.
            debtToken0MinMax_[0] = 1;
            debtToken1MinMax_[0] = 1;

            FLUID_RESERVE.rebalanceDexVaults(
                protocols_,
                values_,
                colToken0MinMax_,
                colToken1MinMax_,
                debtToken0MinMax_,
                debtToken1MinMax_
            );
        }
        FLUID_RESERVE.updateRebalancer(address(TIMELOCK), false);

        // Revoke the Reserve's PST + USDC allowance for the vault.
        {
            address[] memory protocols_ = new address[](2);
            address[] memory tokens_ = new address[](2);

            protocols_[0] = vault_;
            tokens_[0] = PST_ADDRESS;

            protocols_[1] = vault_;
            tokens_[1] = USDC_ADDRESS;

            FLUID_RESERVE.revoke(protocols_, tokens_);
        }
    }

    /// @notice Action 4: Launch reUSD-USDT DEX (44) + vault 170 (T4) and vault
    ///         181 (T3) from dust limits (IGP-135), then remove Team Multisig
    ///         auth. Vault risk params (CF/LT/LML/LP) are configured via MS1.
    function action4() internal isActionSkippable(4) {
        // DEX 44: reUSD-USDT — $24M max supply shares, $10M/token LL limits.
        // Fee (2 bps), range (0.3% symmetric), and Team MS auth are already
        // set on-chain via MS1; only limits that still need raising are here.
        {
            address REUSD_USDT_DEX = getDexAddress(REUSD_USDT_DEX_ID);

            DexConfig memory DEX_REUSD_USDT = DexConfig({
                dex: REUSD_USDT_DEX,
                tokenA: REUSD_ADDRESS,
                tokenB: USDT_ADDRESS,
                smartCollateral: true,
                smartDebt: false,
                baseWithdrawalLimitInUSD: 10_000_000, // $10M per token
                baseBorrowLimitInUSD: 0,
                maxBorrowLimitInUSD: 0
            });
            setDexLimits(DEX_REUSD_USDT);

            IFluidDex(REUSD_USDT_DEX).updateMaxSupplyShares(
                12_100_000 * 1e18 // ~$24M at ~$1.98/share (from ~6M on-chain)
            );
        }

        // Vault 170: reUSD-USDT / USDC-USDT (TYPE_4) — $8M col / $5M–$10M debt
        {
            address REUSD_USDT_DEX = getDexAddress(REUSD_USDT_DEX_ID);
            address USDC_USDT_DEX = getDexAddress(USDC_USDT_DEX_ID);
            address REUSD_USDT__USDC_USDT_VAULT = getVaultAddress(
                VAULT_REUSD_USDT__USDC_USDT_ID
            );

            {
                IFluidAdminDex.UserSupplyConfig[]
                    memory supplyConfigs_ = new IFluidAdminDex.UserSupplyConfig[](
                        1
                    );
                supplyConfigs_[0] = IFluidAdminDex.UserSupplyConfig({
                    user: REUSD_USDT__USDC_USDT_VAULT,
                    expandPercent: 35 * 1e2, // 35%
                    expandDuration: 6 hours,
                    baseWithdrawalLimit: 4_000_000 * 1e18 // ~$8M DEX 44 shares
                });
                IFluidDex(REUSD_USDT_DEX).updateUserSupplyConfigs(
                    supplyConfigs_
                );
            }

            setDexBorrowProtocolLimitsInShares(
                DexBorrowProtocolConfigInShares({
                    dex: USDC_USDT_DEX,
                    protocol: REUSD_USDT__USDC_USDT_VAULT,
                    expandPercent: 30 * 1e2, // 30%
                    expandDuration: 6 hours,
                    baseBorrowLimit: 2_500_000 * 1e18, // ~$5M DEX 2 shares
                    maxBorrowLimit: 5_000_000 * 1e18 // ~$10M DEX 2 shares
                })
            );

            VAULT_FACTORY_WRAPPER_OWNER.setVaultAuth(
                REUSD_USDT__USDC_USDT_VAULT,
                TEAM_MULTISIG,
                false
            );
        }

        // Vault 181: reUSD / GHO-USDC (TYPE_3) — $8M REUSD supply;
        // GHO-USDC DEX (id 4) borrow ~$5M / ~$10M
        {
            address GHO_USDC_DEX = getDexAddress(GHO_USDC_DEX_ID);
            address REUSD__GHO_USDC_VAULT = getVaultAddress(
                VAULT_REUSD__GHO_USDC_ID
            );

            VaultConfig memory VAULT_REUSD__GHO_USDC = VaultConfig({
                vault: REUSD__GHO_USDC_VAULT,
                vaultType: VAULT_TYPE.TYPE_3,
                supplyToken: REUSD_ADDRESS,
                borrowToken: address(0),
                baseWithdrawalLimitInUSD: 8_000_000, // $8M REUSD supply
                baseBorrowLimitInUSD: 0,
                maxBorrowLimitInUSD: 0
            });
            setVaultLimits(VAULT_REUSD__GHO_USDC);

            setDexBorrowProtocolLimitsInShares(
                DexBorrowProtocolConfigInShares({
                    dex: GHO_USDC_DEX,
                    protocol: REUSD__GHO_USDC_VAULT,
                    expandPercent: 30 * 1e2, // 30%
                    expandDuration: 6 hours,
                    baseBorrowLimit: 2_500_000 * 1e18, // ~$5M DEX 4 shares
                    maxBorrowLimit: 5_000_000 * 1e18 // ~$10M DEX 4 shares
                })
            );

            VAULT_FACTORY_WRAPPER_OWNER.setVaultAuth(
                REUSD__GHO_USDC_VAULT,
                TEAM_MULTISIG,
                false
            );
        }
    }

    /// @notice Action 5: Raise the PST / USDC (165) and PST / USDT (166) T1
    ///         vault max borrow limits to $15.1M (from $10M). The base borrow
    ///         limit ($5M), withdrawal limit ($8M) and borrow expansion
    ///         (50% / 6h) set in IGP-131 are left unchanged — only the max debt
    ///         ceiling is raised.
    function action5() internal isActionSkippable(5) {
        // Vault 165: PST / USDC (TYPE_1) — USDC LL borrow
        setBorrowProtocolLimits(
            BorrowProtocolConfig({
                protocol: getVaultAddress(VAULT_PST_USDC_ID),
                borrowToken: USDC_ADDRESS,
                expandPercent: 50 * 1e2, // 50% (unchanged)
                expandDuration: 6 hours, // (unchanged)
                baseBorrowLimitInUSD: 5_000_000, // $5M (unchanged)
                maxBorrowLimitInUSD: 15_100_000 // $15.1M (from $10M)
            })
        );

        // Vault 166: PST / USDT (TYPE_1) — USDT LL borrow
        setBorrowProtocolLimits(
            BorrowProtocolConfig({
                protocol: getVaultAddress(VAULT_PST_USDT_ID),
                borrowToken: USDT_ADDRESS,
                expandPercent: 50 * 1e2, // 50% (unchanged)
                expandDuration: 6 hours, // (unchanged)
                baseBorrowLimitInUSD: 5_000_000, // $5M (unchanged)
                maxBorrowLimitInUSD: 15_100_000 // $15.1M (from $10M)
            })
        );
    }

    /**
     * |
     * |     Payload Actions End Here      |
     * |__________________________________
     */

    // --- BEGIN AUTO-GENERATED PRICES (scripts/verify/prepare-prices.ts) ---
    // fetched: 2026-07-09T09:37:37.467Z, source: coingecko
    function REUSD_USD_PRICE()  public pure override returns (uint256) { return 1.09 * 1e2; }
    function STABLE_USD_PRICE() public pure override returns (uint256) { return 1 * 1e2; }
    // --- END AUTO-GENERATED PRICES ---
}
