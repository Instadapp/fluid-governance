// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.21;
pragma experimental ABIEncoderV2;

import {PayloadIGPPriceHelpers} from "../common/pricehelpers.sol";
import {IFluidReserveContractV2} from "../common/interfaces/IFluidReserveContract.sol";

/// @notice IGP139: Increase the Fluid Foundation monthly grant from $250,000
///         to $350,000 and execute the first disbursement at the new rate.
///
///         Action 1 withdraws 187 stETH from the Fluid Reserve to the Fluid
///         Foundation. 187 stETH is ~$350,000 at the 7-day average ETH price
///         of $1,872.43. Action 2 sets dust limits for the new weETH/ETH T1
///         vault (id 182) and grants Team Multisig vault auth.
///
///         The $250,000/month grant approved in February was never drawn:
///         IGP-124, which would have transferred the first tranche, expired
///         without execution while the treasury was absorbing Resolv-incident
///         costs. This disbursement is funded in stETH from the Fluid Reserve
///         rather than the Treasury fGHO position IGP-124 used.
contract PayloadIGP139 is PayloadIGPPriceHelpers {
    uint256 public constant PROPOSAL_ID = 139;

    /// @notice 187 stETH — ~$350,000 at the 7-day average ETH price of $1,872.43.
    uint256 public constant FOUNDATION_GRANT_AMOUNT = 187 ether;

    /// @notice New weETH/ETH T1 vault, deployed via the Team Multisig before
    ///         execution (totalVaults is 181 at authoring time).
    uint256 public constant VAULT_WEETH_ETH_ID = 182; // T1: weETH / ETH

    function execute() public virtual override {
        super.execute();

        // Action 1: Transfer the monthly grant to the Fluid Foundation.
        action1();

        // Action 2: Set dust limits for weETH/ETH T1 vault.
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

    /// @notice Action 1: Transfer the monthly grant to the Fluid Foundation.
    /// @dev Sends 187 stETH from the Fluid Reserve to the Foundation via
    ///      `FLUID_RESERVE.withdrawFunds`, the same V2 entrypoint IGP-134
    ///      Action 4 used for a fixed stETH amount. The Reserve accrues the
    ///      stETH from iETHv2 (Lite) revenue, so no `collectRevenue` is
    ///      performed here.
    function action1() internal isActionSkippable(1) {
        address[] memory tokens_ = new address[](1);
        uint256[] memory amounts_ = new uint256[](1);

        tokens_[0] = stETH_ADDRESS;
        amounts_[0] = FOUNDATION_GRANT_AMOUNT; // 187 stETH

        IFluidReserveContractV2(address(FLUID_RESERVE)).withdrawFunds(
            tokens_,
            amounts_,
            FLUID_FOUNDATION,
            "FOUNDATION GRANT"
        );
    }

    /// @notice Action 2: Set dust limits for the new weETH/ETH T1 vault
    ///         (id 182) and grant Team Multisig vault auth. Assumes the vault
    ///         is deployed via the Team Multisig before execution.
    function action2() internal isActionSkippable(2) {
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
        VAULT_FACTORY.setVaultAuth(weETH_ETH_VAULT, TEAM_MULTISIG, true);
    }

    /**
     * |
     * |     Payload Actions End Here      |
     * |__________________________________
     */

    // --- BEGIN AUTO-GENERATED PRICES (scripts/verify/prepare-prices.ts) ---
    // fetched: 2026-08-19T06:26:48.797Z, source: coingecko
    function ETH_USD_PRICE()   public pure override returns (uint256) { return 1_910 * 1e2; }
    function weETH_USD_PRICE() public pure override returns (uint256) { return 2_100 * 1e2; }
    // --- END AUTO-GENERATED PRICES ---
}
