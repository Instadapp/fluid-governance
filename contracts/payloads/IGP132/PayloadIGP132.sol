// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.21;
pragma experimental ABIEncoderV2;

import {
    AdminModuleStructs as FluidLiquidityAdminStructs
} from "../common/interfaces/IFluidLiquidity.sol";
import {PayloadIGPPriceHelpers} from "../common/pricehelpers.sol";

/// @notice IGP132: (1) Cap the max-utilization borrow rate of USDC, USDT and
///         GHO on the Liquidity Layer at 15% (down from the current 40%),
///         preserving every other rate-curve parameter; (2) Reduce the Team
///         Multisig's USDC and USDT borrow limits on the Liquidity Layer to the
///         minimum (base 10 / max 20 wei) — the protocol's representation of
///         "effectively 0", since the Liquidity AdminModule rejects literal-zero
///         debt ceilings.
contract PayloadIGP132 is PayloadIGPPriceHelpers {
    uint256 public constant PROPOSAL_ID = 132;

    function execute() public virtual override {
        super.execute();

        // Action 1: Cap USDC, USDT & GHO max-utilization borrow rate at 15% on the Liquidity Layer.
        action1();

        // Action 2: Set Team Multisig USDC & USDT borrow limits to the minimum (effectively 0) on the Liquidity Layer.
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

    /// @notice Action 1: Cap USDC, USDT & GHO borrow rate at max utilization to 15%.
    /// @dev Every parameter below matches the live on-chain Liquidity
    ///      `getTokenRateData(token)` at proposal preparation (all three tokens
    ///      use rate model v2); only `rateAtUtilizationMax` changes 40% -> 15%.
    ///      `rateAtUtilizationKink2 <= rateAtUtilizationMax` holds for each token.
    function action1() internal isActionSkippable(1) {
        FluidLiquidityAdminStructs.RateDataV2Params[]
            memory params_ = new FluidLiquidityAdminStructs.RateDataV2Params[](
                3
            );

        // USDC — live curve: kinks 85% / 93%, rates 0% / 5.4% / 7.5%.
        params_[0] = FluidLiquidityAdminStructs.RateDataV2Params({
            token: USDC_ADDRESS,
            kink1: 85 * 1e2, // 85%
            kink2: 93 * 1e2, // 93%
            rateAtUtilizationZero: 0, // 0%
            rateAtUtilizationKink1: 5.4 * 1e2, // 5.4%
            rateAtUtilizationKink2: 7.5 * 1e2, // 7.5%
            rateAtUtilizationMax: 15 * 1e2 // 15% (was 40% on-chain)
        });

        // USDT — live curve identical to USDC: kinks 85% / 93%, rates 0% / 5.4% / 7.5%.
        params_[1] = FluidLiquidityAdminStructs.RateDataV2Params({
            token: USDT_ADDRESS,
            kink1: 85 * 1e2, // 85%
            kink2: 93 * 1e2, // 93%
            rateAtUtilizationZero: 0, // 0%
            rateAtUtilizationKink1: 5.4 * 1e2, // 5.4%
            rateAtUtilizationKink2: 7.5 * 1e2, // 7.5%
            rateAtUtilizationMax: 15 * 1e2 // 15% (was 40% on-chain)
        });

        // GHO — live curve: kinks 85% / 93%, rates 0% / 6.5% / 9.5%.
        params_[2] = FluidLiquidityAdminStructs.RateDataV2Params({
            token: GHO_ADDRESS,
            kink1: 85 * 1e2, // 85%
            kink2: 93 * 1e2, // 93%
            rateAtUtilizationZero: 0, // 0%
            rateAtUtilizationKink1: 6.5 * 1e2, // 6.5%
            rateAtUtilizationKink2: 9.5 * 1e2, // 9.5%
            rateAtUtilizationMax: 15 * 1e2 // 15% (was 40% on-chain)
        });

        LIQUIDITY.updateRateDataV2s(params_);
    }

    /// @notice Action 2: Reduce the Team Multisig's USDC & USDT borrow limits on
    ///         the Liquidity Layer to the minimum (base 10 / max 20 wei).
    /// @dev The Liquidity AdminModule reverts `LimitZero` on a literal-zero
    ///      `baseDebtCeiling` / `maxDebtCeiling`, so the established "paused"
    ///      dust limits are the canonical way to drive borrowing to 0. Mode 1
    ///      (with interest) matches the Team Multisig's existing config for both
    ///      tokens, so no mode switch is triggered. Existing debt is unaffected;
    ///      only further borrowing above the dust ceiling is blocked.
    function action2() internal isActionSkippable(2) {
        setBorrowProtocolLimitsPaused(TEAM_MULTISIG, USDC_ADDRESS);
        setBorrowProtocolLimitsPaused(TEAM_MULTISIG, USDT_ADDRESS);
    }

    /**
     * |
     * |     Payload Actions End Here      |
     * |__________________________________
     */
}
