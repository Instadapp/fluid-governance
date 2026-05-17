pragma solidity ^0.8.21;
pragma experimental ABIEncoderV2;

import {BigMathMinified} from "../libraries/bigMathMinified.sol";
import {LiquidityCalcs} from "../libraries/liquidityCalcs.sol";
import {LiquiditySlotsLink} from "../libraries/liquiditySlotsLink.sol";

import { IGovernorBravo } from "./interfaces/IGovernorBravo.sol";
import { ITimelock } from "./interfaces/ITimelock.sol";

import { IFluidLiquidityAdmin, AdminModuleStructs as FluidLiquidityAdminStructs } from "./interfaces/IFluidLiquidity.sol";
import { IFluidReserveContract } from "./interfaces/IFluidReserveContract.sol";

import { IFluidVaultFactory } from "./interfaces/IFluidVaultFactory.sol";
import { IFluidDexFactory } from "./interfaces/IFluidDexFactory.sol";

import { IFluidDex, IFluidAdminDex } from "./interfaces/IFluidDex.sol";
import { IFluidDexResolver } from "./interfaces/IFluidDex.sol";

import { IFluidVault } from "./interfaces/IFluidVault.sol";
import { IFluidVaultT1 } from "./interfaces/IFluidVault.sol";

import { IFTokenAdmin } from "./interfaces/IFToken.sol";
import { ILendingRewards } from "./interfaces/IFToken.sol";

import { IDSAV2 } from "./interfaces/IDSA.sol";

import { PayloadIGPConstants } from "./constants.sol";
import { PayloadIGPHelpers } from "./helpers.sol";
import { PayloadIGPVariables } from "./variables.sol";
import { PayloadIGPEvents } from "./events.sol";


abstract contract PayloadIGPMain is PayloadIGPHelpers, PayloadIGPVariables, PayloadIGPEvents {
    /// @notice Modifier to check if an action can be skipped
    modifier isActionSkippable(uint256 action_) {
        // If function is not skippable, then execute
        if (!PayloadIGPMain(ADDRESS_THIS).actionStatus(action_)) {
            _;
        }
    }

     /**
     * |
     * |     Team Multisig Actions      |
     * |__________________________________
     */
    function setActionsToSkip(
        uint256[] calldata actionsToSkip_
    ) external {
        if (msg.sender != TEAM_MULTISIG) {
            revert("not-team-multisig");
        }

        for (uint256 i = 0; i < actionsToSkip_.length; i++) {
            if (!_skipAction[actionsToSkip_[i]]) {
                _skipAction[actionsToSkip_[i]] = true;
                emit ActionSkipped(actionsToSkip_[i], msg.sender);
            }
        }
    }

    // @notice Allows the team multisig to toggle the proposal executable or not
    // @param isExecutable_ The boolean value to set the proposal executable or not
    function toggleExecutable(bool isExecutable_) external {
        require(msg.sender == TEAM_MULTISIG, "not-team-multisig");
        _isProposalExecutable = isExecutable_;
    }


    /**
     * |
     * |     Proposal Structure           |
     * |__________________________________
     */

     function propose(string memory description) external {
        require(
            msg.sender == PROPOSER ||
                msg.sender == TEAM_MULTISIG ||
                address(this) == PROPOSER_AVO_MULTISIG ||
                address(this) == PROPOSER_AVO_MULTISIG_2 ||
                address(this) == PROPOSER_AVO_MULTISIG_3 ||
                address(this) == PROPOSER_AVO_MULTISIG_4 ||
                address(this) == PROPOSER_AVO_MULTISIG_5,
            "msg.sender-not-allowed"
        );

        uint256 totalActions = 1;
        address[] memory targets = new address[](totalActions);
        uint256[] memory values = new uint256[](totalActions);
        string[] memory signatures = new string[](totalActions);
        bytes[] memory calldatas = new bytes[](totalActions);

        targets[0] = address(TIMELOCK);
        values[0] = 0;
        signatures[0] = "executePayload(address,string,bytes)";
        calldatas[0] = abi.encode(ADDRESS_THIS, "execute()", abi.encode());

        uint256 proposedId = GOVERNOR.propose(
            targets,
            values,
            signatures,
            calldatas,
            description
        );

        require(proposedId == _PROPOSAL_ID(), "PROPOSAL_IS_NOT_SAME");

        if (msg.sender == PROPOSER || msg.sender == TEAM_MULTISIG) {
            setProposalCreationTime(uint40(block.timestamp));
        } else {
            PayloadIGPMain(ADDRESS_THIS).setProposalCreationTime(uint40(block.timestamp));
        }
    }

    function execute() public virtual {
        require(address(this) == address(TIMELOCK), "not-valid-caller");
        require(PayloadIGPMain(ADDRESS_THIS).isProposalExecutable(), "proposal-not-executable");
    }

    function verifyProposal() public view virtual {}

    /**
     * |
     * |     Proposal Payload Helpers      |
     * |__________________________________
     */

    function _PROPOSAL_ID() internal view virtual returns(uint256) {}

    function setProposalCreationTime(uint40 proposalCreationTime_) public {
        require(
            msg.sender == PROPOSER ||
                msg.sender == TEAM_MULTISIG ||
                msg.sender == PROPOSER_AVO_MULTISIG ||
                msg.sender == PROPOSER_AVO_MULTISIG_2 ||
                msg.sender == PROPOSER_AVO_MULTISIG_3 ||
                msg.sender == PROPOSER_AVO_MULTISIG_4 ||
                msg.sender == PROPOSER_AVO_MULTISIG_5,
            "msg.sender-not-allowed"
        );
        _proposalCreationTime = proposalCreationTime_;
        emit ProposalCreationTimeSet(proposalCreationTime_);
    }


    function isProposalExecutable() public view returns (bool) {
        return _isProposalExecutable;
    }

    function getProposalCreationTime() public view returns (uint40) {
        return _proposalCreationTime;
    }

    function actionStatus(uint256 action_) public view returns (bool) {
        return _skipAction[action_];
    }
}
