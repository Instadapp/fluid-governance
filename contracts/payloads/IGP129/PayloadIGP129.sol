// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.21;
pragma experimental ABIEncoderV2;

import {PayloadIGPPriceHelpers} from "../common/pricehelpers.sol";

/// @notice IGP129: Treasury withdrawal to Team Multisig. // Token and Amount needs to be filled before sending IGP129.
contract PayloadIGP129 is PayloadIGPPriceHelpers {
    uint256 public constant PROPOSAL_ID = 129;

    function execute() public virtual override {
        super.execute();

        // Action 1: Withdraw funds from Treasury to Team Multisig
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

    /// @notice Action 1: Withdraw funds from Treasury to Team Multisig
    function action1() internal isActionSkippable(1) {
        // TODO: fill token and amount before finalizing IGP129.
        address token_ = address(0);
        uint256 amount_ = 0;
        require(token_ != address(0), "withdraw-token-not-set");
        require(amount_ != 0, "withdraw-amount-not-set");

        string[] memory targets_ = new string[](1);
        bytes[] memory encodedSpells_ = new bytes[](1);

        targets_[0] = "BASIC-A";
        encodedSpells_[0] = abi.encodeWithSignature(
            "withdraw(address,uint256,address,uint256,uint256)",
            token_,
            amount_,
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
