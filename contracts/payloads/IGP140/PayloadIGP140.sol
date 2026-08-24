// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.21;
pragma experimental ABIEncoderV2;

import {PayloadIGPPriceHelpers} from "../common/pricehelpers.sol";

/// @notice IGP140: Launch the weETH/ETH T1 vault (id 182) at dust limits.
///
///         Action 1 sets the vault's Liquidity Layer supply and borrow limits
///         and grants Team Multisig vault auth so limits can be scaled up
///         post-launch without another proposal.
///
///         The vault was deployed by the Team Multisig at block 25,789,585
///         (0x0b8a681ed46EA8ec6b97D686dF0631fBf84B03d2) and is still
///         unconfigured at the Liquidity Layer, so it cannot be used until
///         this payload executes.
///
///         This action was originally Action 2 of IGP-139 (the Foundation
///         grant). It moved here because the vault-auth call went to the
///         factory instead of the factory's owner and reverted the whole
///         proposal on execution; the grant has no dependency on the vault
///         launch.
contract PayloadIGP140 is PayloadIGPPriceHelpers {
    uint256 public constant PROPOSAL_ID = 140;

    /// @notice weETH/ETH T1 vault, deployed via the Team Multisig.
    uint256 public constant VAULT_WEETH_ETH_ID = 182; // T1: weETH / ETH

    function execute() public virtual override {
        super.execute();

        // Action 1: Set dust limits for weETH/ETH T1 vault.
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

    /// @notice Action 1: Set dust limits for the weETH/ETH T1 vault (id 182)
    ///         and grant Team Multisig vault auth.
    /// @dev Vault auth goes through `VAULT_FACTORY_WRAPPER_OWNER`, not the
    ///      factory itself: `setVaultAuth` is `onlyOwner` on the factory and
    ///      the factory is owned by that wrapper, which the timelock is
    ///      authorized on. Calling the factory directly reverts UNAUTHORIZED.
    function action1() internal isActionSkippable(1) {
        address weETH_ETH_VAULT = getVaultAddress(VAULT_WEETH_ETH_ID);

        // [TYPE 1] weETH/ETH vault - Dust limits
        VaultConfig memory VAULT_weETH_ETH = VaultConfig({
            vault: weETH_ETH_VAULT,
            vaultType: VAULT_TYPE.TYPE_1,
            supplyToken: weETH_ADDRESS,
            borrowToken: ETH_ADDRESS,
            baseWithdrawalLimitInUSD: 7_000, // $7k
            baseBorrowLimitInUSD: 7_000, // $7k
            maxBorrowLimitInUSD: 9_000 // $9k
        });

        setVaultLimits(VAULT_weETH_ETH);

        VAULT_FACTORY_WRAPPER_OWNER.setVaultAuth(
            weETH_ETH_VAULT,
            TEAM_MULTISIG,
            true
        );
    }

    /**
     * |
     * |     Payload Actions End Here      |
     * |__________________________________
     */

    // --- BEGIN AUTO-GENERATED PRICES (scripts/verify/prepare-prices.ts) ---
    // fetched: 2026-08-24T19:48:26.071Z, source: coingecko
    function ETH_USD_PRICE()   public pure override returns (uint256) { return 2_470 * 1e2; }
    function weETH_USD_PRICE() public pure override returns (uint256) { return 2_720 * 1e2; }
    // --- END AUTO-GENERATED PRICES ---
}
