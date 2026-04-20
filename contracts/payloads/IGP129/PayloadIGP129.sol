// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.21;
pragma experimental ABIEncoderV2;

import {PayloadIGPPriceHelpers} from "../common/pricehelpers.sol";

/// @notice IGP129: placeholder payload — actions will be filled in once the
///         proposal is finalised. Inherits `PayloadIGPPriceHelpers`, which
///         brings in `PayloadIGPMain` + the invariant `getRawAmount`
///         dispatch + the reverting virtual `<SYMBOL>_USD_PRICE()` getters.
///
///         The auto-generated price block below is maintained by
///         `scripts/verify/prepare-prices.ts`:
///
///             npm run verify:prices -- --payload IGP129
///
///         The script scans the payload for `*_ADDRESS` references, fetches
///         each needed token's current USD price from CoinGecko, rounds to
///         the per-token rule defined in `scripts/verify/lib/tokens.ts`, and
///         splices a fresh block between the BEGIN / END markers.
contract PayloadIGP129 is PayloadIGPPriceHelpers {
    uint256 public constant PROPOSAL_ID = 129;

    /// @dev Scaffold-only reference — keeps `prepare-prices.ts` detecting
    ///      ETH as a priced token while IGP129 is still being drafted.
    ///      Remove once a real action references `ETH_ADDRESS`; if no action
    ///      ends up pricing ETH, delete both this constant and the
    ///      `ETH_USD_PRICE()` override in the auto-generated block below.
    address private constant _IGP129_DRAFT_TOKEN = ETH_ADDRESS;

    function execute() public virtual override {
        super.execute();

        // TODO: add actions here. Each action typically lives in its own
        // `actionN()` function marked with the `isActionSkippable(N)`
        // modifier. See any recent payload (e.g. IGP128) for the shape.
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

    // (no actions yet — this payload is a scaffold)

    /**
     * |
     * |     Payload Actions End Here      |
     * |__________________________________
     */

    // --- BEGIN AUTO-GENERATED PRICES (scripts/verify/prepare-prices.ts) ---
    // fetched: 2026-04-20T09:05:05.437Z, source: coingecko
    function ETH_USD_PRICE() public pure override returns (uint256) {
        return 2_290 * 1e2;
    }
    // --- END AUTO-GENERATED PRICES ---
}
