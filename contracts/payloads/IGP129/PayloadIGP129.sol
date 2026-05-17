// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.21;
pragma experimental ABIEncoderV2;

import {PayloadIGPPriceHelpers} from "../common/pricehelpers.sol";

/// @notice IGP129: Withdraw the Treasury's full iETHv2 balance to Team
///         Multisig (as iETHv2) and redeem the Treasury's full fGHO position
///         to GHO, sending the GHO to Team Multisig.
contract PayloadIGP129 is PayloadIGPPriceHelpers {
    uint256 public constant PROPOSAL_ID = 129;

    function execute() public virtual override {
        super.execute();

        // Action 1: Withdraw full iETHv2 balance from Treasury to Team Multisig.
        action1();

        // Action 2: Redeem Treasury's full fGHO position to GHO and send GHO to Team Multisig.
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

    /// @notice Action 1: Withdraw full iETHv2 balance from Treasury to Team Multisig.
    function action1() internal isActionSkippable(1) {
        string[] memory targets_ = new string[](1);
        bytes[] memory encodedSpells_ = new bytes[](1);

        targets_[0] = "BASIC-A";
        encodedSpells_[0] = abi.encodeWithSignature(
            "withdraw(address,uint256,address,uint256,uint256)",
            address(IETHV2),
            type(uint256).max,
            TEAM_MULTISIG,
            0,
            0
        );

        TREASURY.cast(targets_, encodedSpells_, address(this));
    }

    /// @notice Action 2: Redeem Treasury's full fGHO position to GHO and send GHO to Team Multisig.
    function action2() internal isActionSkippable(2) {
        string[] memory targets_ = new string[](1);
        bytes[] memory encodedSpells_ = new bytes[](1);

        targets_[0] = "BASIC-D-V2";
        encodedSpells_[0] = abi.encodeWithSignature(
            "redeem(address,uint256,address,uint256,uint256)",
            F_GHO_ADDRESS,
            type(uint256).max,
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
