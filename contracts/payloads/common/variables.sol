pragma solidity ^0.8.21;
pragma experimental ABIEncoderV2;

abstract contract PayloadIGPVariables {
    /**
     * |
     * |     Timelock storage-aliasing gap      |
     * |__________________________________________
     *
     * Any descendant of this contract is invoked via `delegatecall` from
     * `InstaTimelock.executePayload`. During that delegatecall, storage
     * slots of the delegatecalled contract alias slots of the Timelock
     * itself.
     *
     * The Timelock uses the following storage layout (fixed, on-chain):
     *
     *   slot 0: admin
     *   slot 1: pendingAdmin
     *   slot 2: guardian
     *   slot 3: delay
     *   slot 4: queuedTransactions (mapping base)
     *
     * A write to any of these slots from a payload would corrupt Timelock
     * admin state. To guarantee that payload state variables never collide
     * with Timelock state, we reserve five `uint256` slots at the root of
     * the payload inheritance chain so that the first real payload state
     * variable lives at slot 5 — outside the region used by the Timelock.
     *
     * `PayloadIGPVariables` is intentionally the contract that holds ALL
     * common payload storage. Every other contract in the common chain
     * (`PayloadIGPConstants`, `PayloadIGPHelpers`, `PayloadIGPEvents`,
     * `PayloadIGPMain`) contributes only `constant`, `immutable`, function
     * or event members — none of which occupy storage. Because of that,
     * the Solidity C3-linearization of `PayloadIGPMain` places
     * `PayloadIGPVariables` as the first contract that actually writes to
     * storage, so these five `uint256` fields end up at slots 0–4 of the
     * deployed payload. The gap has zero runtime cost (empty slots are
     * never read or written).
     *
     * Do not reorder, rename, or repurpose these five variables without
     * coordinating with the Timelock storage layout.
     */
    uint256 private __timelockGap0; // aliases Timelock.admin
    uint256 private __timelockGap1; // aliases Timelock.pendingAdmin
    uint256 private __timelockGap2; // aliases Timelock.guardian
    uint256 private __timelockGap3; // aliases Timelock.delay
    uint256 private __timelockGap4; // aliases Timelock.queuedTransactions

    /**
     * |
     * |     Payload state variables     |
     * |__________________________________
     *
     * These live at slots >= 5 and are therefore safe to write to from a
     * delegatecalled `execute()` without corrupting Timelock admin state.
     *
     * In practice today's payloads still access these only via an external
     * call to `ADDRESS_THIS` (so the call re-enters the payload in its own
     * storage context) — but the gap above makes the safety structural
     * rather than convention-only.
     */

    /// @notice The unix time when the proposal was created. Display-only:
    /// never read by on-chain logic. See the `ProposalCreationTimeSet`
    /// event in `PayloadIGPEvents` and `setProposalCreationTime` in
    /// `PayloadIGPMain`.
    uint40 internal _proposalCreationTime;

    /// @notice Boolean flag gating `execute()`. Default `false` (not
    /// executable). Flipped by `TEAM_MULTISIG` via `toggleExecutable`.
    bool internal _isProposalExecutable;

    /// @notice Action indexes that `isActionSkippable` should skip. Set
    /// by `TEAM_MULTISIG` via `setActionsToSkip`; one-way (no unskip).
    mapping(uint256 => bool) internal _skipAction;
}
