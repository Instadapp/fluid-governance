// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.21;
pragma experimental ABIEncoderV2;

import {PayloadIGPPriceHelpers} from "../common/pricehelpers.sol";

/// @notice IGP130: Transfer 413.2 wstETH (~510 ETH) from the Treasury DSA to
///         the Fluid Lite ETH Vault DSA (iETHv2 DSA) to cover losses incurred
///         by Lite ETH users from recent ETH borrow rate spikes across the
///         underlying lending protocols. Follows the same compensation pattern
///         as IGP-119 (250 iETHv2 → Team Multisig).
contract PayloadIGP130 is PayloadIGPPriceHelpers {
    uint256 public constant PROPOSAL_ID = 130;

    /// @notice Fluid Lite ETH Vault DSA (iETHv2 DSA) — recipient of the wstETH refund.
    address public constant LITE_ETH_VAULT_DSA =
        0x9600A48ed0f931d0c422D574e3275a90D8b22745;

    /// @notice Amount of wstETH to transfer from the Treasury DSA to the
    ///         Lite ETH Vault DSA. 413.2 wstETH ≈ 510 ETH.
    uint256 public constant WSTETH_AMOUNT = 413.2 * 1e18;

    function execute() public virtual override {
        super.execute();

        // Action 1: Transfer 413.2 wstETH (~510 ETH) from Treasury to Lite ETH Vault DSA
        //           to cover Fluid Lite ETH user losses.
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

    /// @notice Action 1: Transfer 413.2 wstETH (~510 ETH) from the Treasury DSA
    ///         to the Fluid Lite ETH Vault DSA to cover Lite ETH user losses.
    function action1() internal isActionSkippable(1) {
        string[] memory targets_ = new string[](1);
        bytes[] memory encodedSpells_ = new bytes[](1);

        targets_[0] = "BASIC-A";
        encodedSpells_[0] = abi.encodeWithSignature(
            "withdraw(address,uint256,address,uint256,uint256)",
            wstETH_ADDRESS,
            WSTETH_AMOUNT,
            LITE_ETH_VAULT_DSA,
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
