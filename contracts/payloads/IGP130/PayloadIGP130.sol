// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.21;
pragma experimental ABIEncoderV2;

import {PayloadIGPPriceHelpers} from "../common/pricehelpers.sol";

/// @notice IGP130: Withdraw 512 WETH (~512 ETH) from the Treasury to the
///         Team Multisig to cover losses incurred by Fluid Lite ETH users.
///         Follows the precedent set by IGP-119 (250 iETHv2 → Team Multisig).
contract PayloadIGP130 is PayloadIGPPriceHelpers {
    uint256 public constant PROPOSAL_ID = 130;

    /// @notice Amount of WETH to withdraw from the Treasury DSA to Team Multisig.
    uint256 public constant WETH_AMOUNT = 512 * 1e18;

    function execute() public virtual override {
        super.execute();

        // Action 1: Withdraw 512 WETH to Team Multisig to cover Fluid Lite ETH user losses
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

    /// @notice Action 1: Withdraw 512 WETH (~512 ETH) from Treasury to Team Multisig
    ///         to cover losses incurred by Fluid Lite ETH users.
    function action1() internal isActionSkippable(1) {
        string[] memory targets_ = new string[](1);
        bytes[] memory encodedSpells_ = new bytes[](1);

        targets_[0] = "BASIC-A";
        encodedSpells_[0] = abi.encodeWithSignature(
            "withdraw(address,uint256,address,uint256,uint256)",
            WETH_ADDRESS,
            WETH_AMOUNT,
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
    // --- END AUTO-GENERATED PRICES ---
}
