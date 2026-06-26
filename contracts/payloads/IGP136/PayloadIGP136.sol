// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.21;
pragma experimental ABIEncoderV2;

import {IERC20} from "../common/interfaces/IERC20.sol";
import {IFluidReserveContractV2} from "../common/interfaces/IFluidReserveContract.sol";
import {IFluidVault, IFluidVaultT1} from "../common/interfaces/IFluidVault.sol";
import {IFluidDex} from "../common/interfaces/IFluidDex.sol";
import {PayloadIGPPriceHelpers} from "../common/pricehelpers.sol";

/// @notice IGP136: Collect accrued protocol revenue into the Reserve Contract
///         and forward it to Team Multisig, then migrate the sUSDai vault
///         oracles to the newly deployed capped-rate oracles.
///
///         Action 1 collects the iETHv2 (Fluid Lite ETH) stETH revenue plus the
///         Liquidity Layer revenue for every token currently accruing more than
///         $5k of uncollected revenue (USDC, USDT, ETH, GHO, weETH) into the
///         Fluid Reserve, then forwards the swept balances to Team Multisig.
///         Both the iETHv2 treasury and the Liquidity Layer revenue collector
///         are the Fluid Reserve, so each `collectRevenue` lands the funds in
///         the Reserve before the single `withdrawFunds` forward.
///
///         Action 2 points the 8 live sUSDai vaults (171–173, 175–179) at the
///         newly deployed oracles that reference CappedRateChainlink_SUSDAI
///         (DF nonce 258) instead of the raw exchange-rate contract. T1 vaults
///         take the new oracle address; T2/T3/T4 vaults take the DeployerFactory
///         nonce. It also re-points the sUSDai-USDC (DEX 46) and sUSDai-USDT
///         (DEX 48) DEX center prices to the same capped rate (DF nonce 258).
///         Max operate-rate delta vs the current oracles is < 0.01%.
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

    /// @dev iETHv2 (Lite) collectable stETH revenue at preparation time
    ///      (`ILite.revenue()` = 33.909507713113132477 stETH on 2026-06-26).
    ///      Lite revenue accrues over time, so the collected amount is held a
    ///      touch below the live value to stay within the collectable balance
    ///      at execution.
    uint256 public constant LITE_STETH_REVENUE = 33.9 ether;

    function execute() public virtual override {
        super.execute();

        // Action 1: Collect iETHv2 (Lite) + Liquidity Layer revenue (>$5k tokens)
        // into the Reserve and forward it to Team Multisig.
        action1();

        // Action 2: Migrate the 8 sUSDai vault oracles to the new capped-rate oracles.
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

    /// @notice Action 1: Collect iETHv2 (Lite) stETH revenue and the Liquidity
    ///         Layer revenue for tokens accruing >$5k (USDC, USDT, ETH, GHO,
    ///         weETH) into the Reserve, then forward the balances to Team
    ///         Multisig.
    function action1() internal isActionSkippable(1) {
        address reserve_ = address(FLUID_RESERVE);

        // Step 1: Collect iETHv2 (Lite) stETH revenue to its treasury (Reserve).
        IETHV2.collectRevenue(LITE_STETH_REVENUE);

        // Step 2: Collect Liquidity Layer revenue (>$5k tokens) to the revenue
        // collector (Reserve).
        address[] memory liquidityTokens_ = new address[](5);
        liquidityTokens_[0] = USDC_ADDRESS; // ~$84.7k
        liquidityTokens_[1] = USDT_ADDRESS; // ~$50.8k
        liquidityTokens_[2] = ETH_ADDRESS; // ~$36.5k
        liquidityTokens_[3] = GHO_ADDRESS; // ~$8.8k
        liquidityTokens_[4] = weETH_ADDRESS; // ~$5.4k

        LIQUIDITY.collectRevenue(liquidityTokens_);

        // Step 3: Forward the swept balances (collected revenue + pre-existing
        // dust) from the Reserve to Team Multisig, leaving operational dust.
        address[] memory tokens_ = new address[](6);
        uint256[] memory amounts_ = new uint256[](6);

        tokens_[0] = stETH_ADDRESS;
        amounts_[0] = IERC20(stETH_ADDRESS).balanceOf(reserve_) - 0.1 ether;

        tokens_[1] = USDC_ADDRESS;
        amounts_[1] = IERC20(USDC_ADDRESS).balanceOf(reserve_) - 10;

        tokens_[2] = USDT_ADDRESS;
        amounts_[2] = IERC20(USDT_ADDRESS).balanceOf(reserve_) - 10;

        tokens_[3] = ETH_ADDRESS;
        amounts_[3] = reserve_.balance - 0.1 ether;

        tokens_[4] = GHO_ADDRESS;
        amounts_[4] = IERC20(GHO_ADDRESS).balanceOf(reserve_) - 0.1 ether;

        tokens_[5] = weETH_ADDRESS;
        amounts_[5] = IERC20(weETH_ADDRESS).balanceOf(reserve_) - 0.1 ether;

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

    /**
     * |
     * |     Payload Actions End Here      |
     * |__________________________________
     */

    // --- BEGIN AUTO-GENERATED PRICES (scripts/verify/prepare-prices.ts) ---
    // --- END AUTO-GENERATED PRICES ---
}
