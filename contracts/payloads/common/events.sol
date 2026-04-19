pragma solidity ^0.8.21;
pragma experimental ABIEncoderV2;

abstract contract PayloadIGPEvents {
    /**
     * |
     * |     Events                     |
     * |__________________________________
     */

    /// @notice Emitted the first time `action_` is marked as skippable.
    /// Re-marking an already-skipped action is a silent no-op, so this
    /// event fires at most once per `action_`.
    event ActionSkipped(uint256 indexed action, address indexed by);

    /// @notice Emitted when the proposal creation time is (re)set.
    /// The stored value is display-only (never read by on-chain logic),
    /// so the setter is intentionally unconstrained beyond the
    /// `msg.sender` allow-list; the event is emitted on every successful
    /// write for off-chain observability.
    event ProposalCreationTimeSet(uint40 at);
}
