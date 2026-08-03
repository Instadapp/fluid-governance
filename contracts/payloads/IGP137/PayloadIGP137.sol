// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.21;
pragma experimental ABIEncoderV2;

import {PayloadIGPPriceHelpers} from "../common/pricehelpers.sol";

/// @notice IGP137: AGI3 Strategic Institutional Ecosystem Partnership —
///         withdraw 5,000,000 FLUID from the Treasury to Team Multisig.
///
///         Action 1 withdraws 5,000,000 FLUID (5% of the 100,000,000 total
///         supply) from the Treasury DSA to Team Multisig via the `BASIC-A`
///         connector. Team Multisig forwards the tokens to a dedicated wallet
///         before distribution to the regulated private banks and
///         institutional digital asset custodians (FINMA / MiCA / HKMA / MAS)
///         across Switzerland, the EU, Hong Kong and Singapore. The
///         distributed tokens are legally locked until 2030.
contract PayloadIGP137 is PayloadIGPPriceHelpers {
    uint256 public constant PROPOSAL_ID = 137;

    /// @notice 5,000,000 FLUID — 5% of the 100,000,000 total supply.
    uint256 public constant FLUID_WITHDRAW_AMOUNT = 5_000_000 * 1e18;

    function execute() public virtual override {
        super.execute();

        // Action 1: Withdraw 5,000,000 FLUID from Treasury to Team Multisig.
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

    /// @notice Action 1: Withdraw 5,000,000 FLUID from the Treasury to Team
    ///         Multisig for the AGI3 institutional custody allocation.
    function action1() internal isActionSkippable(1) {
        string[] memory targets_ = new string[](1);
        bytes[] memory encodedSpells_ = new bytes[](1);

        targets_[0] = "BASIC-A";
        encodedSpells_[0] = abi.encodeWithSignature(
            "withdraw(address,uint256,address,uint256,uint256)",
            FLUID_ADDRESS,
            FLUID_WITHDRAW_AMOUNT,
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
}
