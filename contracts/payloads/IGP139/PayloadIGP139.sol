// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.21;
pragma experimental ABIEncoderV2;

import {PayloadIGPPriceHelpers} from "../common/pricehelpers.sol";
import {IFluidReserveContractV2} from "../common/interfaces/IFluidReserveContract.sol";

/// @notice IGP139: Increase the Fluid Foundation monthly grant from $250,000
///         to $350,000 and execute the first disbursement at the new rate.
///
///         Action 1 withdraws 155 stETH from the Fluid Reserve to the Fluid
///         Foundation. 155 stETH is ~$350,000 at the 7-day average ETH price
///         of $2,265.16 (CoinGecko hourly, 17–24 Aug 2026).
///
///         The $250,000/month grant approved in February was never drawn:
///         IGP-124, which would have transferred the first tranche, expired
///         without execution while the treasury was absorbing Resolv-incident
///         costs. This disbursement is funded in stETH from the Fluid Reserve
///         rather than the Treasury fGHO position IGP-124 used.
contract PayloadIGP139 is PayloadIGPPriceHelpers {
    uint256 public constant PROPOSAL_ID = 139;

    /// @notice 155 stETH — ~$350,000 at the 7-day average ETH price of
    ///         $2,265.16. The amount is fixed in token terms, so the USD value
    ///         actually delivered drifts with ETH until execution.
    uint256 public constant FOUNDATION_GRANT_AMOUNT = 155 ether;

    function execute() public virtual override {
        super.execute();

        // Action 1: Transfer the monthly grant to the Fluid Foundation.
        action1();
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

    /// @notice Action 1: Transfer the monthly grant to the Fluid Foundation.
    /// @dev Sends 155 stETH from the Fluid Reserve to the Foundation via
    ///      `FLUID_RESERVE.withdrawFunds`, the same V2 entrypoint IGP-134
    ///      Action 4 used for a fixed stETH amount. The Reserve accrues the
    ///      stETH from iETHv2 (Lite) revenue, so no `collectRevenue` is
    ///      performed here.
    function action1() internal isActionSkippable(1) {
        address[] memory tokens_ = new address[](1);
        uint256[] memory amounts_ = new uint256[](1);

        tokens_[0] = stETH_ADDRESS;
        amounts_[0] = FOUNDATION_GRANT_AMOUNT; // 155 stETH

        IFluidReserveContractV2(address(FLUID_RESERVE)).withdrawFunds(
            tokens_,
            amounts_,
            FLUID_FOUNDATION,
            "FOUNDATION GRANT"
        );
    }

    /**
     * |
     * |     Payload Actions End Here      |
     * |__________________________________
     */
}
