// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.21;
pragma experimental ABIEncoderV2;

import {PayloadIGPPriceHelpers} from "../common/pricehelpers.sol";

/// @notice IGP130: Collect wstETH revenue from the Liquidity Layer into the
///         Fluid Reserve Contract and forward 230 wstETH from the Reserve
///         Contract to the Team Multisig. The Team Multisig will then convert
///         the wstETH to ETH and forward it to the iETHv2 loss-coverage
///         recipient (Thrilok, 0x9a403fc58CC6Efe56965Fa6baC0F01bAa11169aD) to
///         cover losses incurred by Fluid Lite ETH (iETHv2) users from recent
///         ETH borrow rate spikes across the underlying lending protocols.
///         Follows the same revenue → reserve → multisig pattern as IGP-94
///         and the Lite-loss compensation precedent of IGP-119.
contract PayloadIGP130 is PayloadIGPPriceHelpers {
    uint256 public constant PROPOSAL_ID = 130;

    /// @notice Amount of wstETH to forward from the Reserve Contract to the
    ///         Team Multisig (to be converted to ETH and sent to the iETHv2
    ///         loss-coverage recipient off-chain at the multisig).
    uint256 public constant WSTETH_TRANSFER_AMOUNT = 230 * 1e18;

    function execute() public virtual override {
        super.execute();

        // Action 1: Collect wstETH revenue from LL into the Reserve Contract,
        //           then forward 230 wstETH to Team Multisig. The Team Multisig
        //           will convert to ETH and forward to the iETHv2 loss-coverage
        //           recipient off-chain (Thrilok, 0x9a40…69aD).
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

    /// @notice Action 1: Collect wstETH revenue from the Liquidity Layer into
    ///         the Reserve Contract, then forward `WSTETH_TRANSFER_AMOUNT`
    ///         wstETH from the Reserve Contract to Team Multisig. The Team
    ///         Multisig will then convert the wstETH to ETH and forward it to
    ///         the iETHv2 loss-coverage recipient (Thrilok,
    ///         0x9a403fc58CC6Efe56965Fa6baC0F01bAa11169aD) to cover Fluid Lite
    ///         ETH (iETHv2) user losses.
    function action1() internal isActionSkippable(1) {
        // Step 1: Collect wstETH revenue from the Liquidity Layer.
        //         Revenue is sent to the configured revenue collector
        //         (the Fluid Reserve Contract).
        address[] memory tokens_ = new address[](1);
        tokens_[0] = wstETH_ADDRESS;
        LIQUIDITY.collectRevenue(tokens_);

        // Step 2: Forward 230 wstETH from the Reserve Contract to Team
        //         Multisig. Any wstETH revenue accrued in excess of
        //         WSTETH_TRANSFER_AMOUNT remains on the Reserve Contract.
        uint256[] memory amounts_ = new uint256[](1);
        amounts_[0] = WSTETH_TRANSFER_AMOUNT;
        FLUID_RESERVE.withdrawFunds(tokens_, amounts_, TEAM_MULTISIG);
    }

    /**
     * |
     * |     Payload Actions End Here      |
     * |__________________________________
     */

    // --- BEGIN AUTO-GENERATED PRICES (scripts/verify/prepare-prices.ts) ---
    // --- END AUTO-GENERATED PRICES ---
}
