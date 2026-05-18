// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.21;
pragma experimental ABIEncoderV2;

import {
    IFluidReserveContractV2
} from "../common/interfaces/IFluidReserveContract.sol";
import {IERC20} from "../common/interfaces/IERC20.sol";
import {PayloadIGPPriceHelpers} from "../common/pricehelpers.sol";

/// @notice IGP130: Collect revenue from the Liquidity Layer into the Reserve
///         Contract and forward to Team Multisig in two carved-out flows:
///         (1) `WSTETH_TRANSFER_AMOUNT` wstETH for Fluid Lite (iETHv2) ETH
///             user loss coverage (multisig converts to ETH and forwards
///             off-chain to Thrilok, 0x9a403fc58CC6Efe56965Fa6baC0F01bAa11169aD);
///         (2) full Liquidity Layer revenue across 22 tokens for the monthly
///             buyback program (same flow as IGP-112 action 10).
contract PayloadIGP130 is PayloadIGPPriceHelpers {
    uint256 public constant PROPOSAL_ID = 130;

    /// @notice Amount of wstETH to forward from the Reserve Contract to the
    ///         Team Multisig (to be converted to ETH and sent to the iETHv2
    ///         loss-coverage recipient off-chain at the multisig).
    uint256 public constant WSTETH_TRANSFER_AMOUNT = 230 * 1e18;

    function execute() public virtual override {
        super.execute();

        // Action 1: Collect wstETH revenue from LL into the Reserve Contract,
        //           then forward 230 wstETH to Team Multisig. The Team Multisig
        //           will convert to ETH and forward to the iETHv2 loss-coverage
        //           recipient off-chain (Thrilok, 0x9a40…69aD).
        action1();

        // Action 2: Collect Liquidity Layer revenue across 22 tokens into the
        //           Reserve Contract, then forward the full reserve balance
        //           (minus minimal dust) to Team Multisig for the monthly
        //           buyback program.
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

    /// @notice Action 1: Collect wstETH revenue from the Liquidity Layer into
    ///         the Reserve Contract, then forward `WSTETH_TRANSFER_AMOUNT`
    ///         wstETH from the Reserve Contract to Team Multisig. The Team
    ///         Multisig will then convert the wstETH to ETH and forward it to
    ///         the iETHv2 loss-coverage recipient (Thrilok,
    ///         0x9a403fc58CC6Efe56965Fa6baC0F01bAa11169aD) to cover Fluid Lite
    ///         ETH (iETHv2) user losses.
    function action1() internal isActionSkippable(1) {
        // Step 1: Collect wstETH revenue from the Liquidity Layer.
        //         Revenue is sent to the configured revenue collector
        //         (the Fluid Reserve Contract).
        address[] memory tokens_ = new address[](1);
        tokens_[0] = wstETH_ADDRESS;
        LIQUIDITY.collectRevenue(tokens_);

        // Step 2: Forward 230 wstETH from the Reserve Contract to Team
        //         Multisig. Any wstETH revenue accrued in excess of
        //         WSTETH_TRANSFER_AMOUNT remains on the Reserve Contract and
        //         is swept to Team Multisig as part of action 2 below.
        uint256[] memory amounts_ = new uint256[](1);
        amounts_[0] = WSTETH_TRANSFER_AMOUNT;
        FLUID_RESERVE.withdrawFunds(tokens_, amounts_, TEAM_MULTISIG);
    }

    /// @notice Action 2: Collect Liquidity Layer revenue across 22 tokens into
    ///         the Reserve Contract, then forward the full Reserve balance of
    ///         each token (minus minimal dust) to the Team Multisig for the
    ///         monthly buyback program. Mirrors IGP-112 action 10.
    function action2() internal isActionSkippable(2) {
        // Step 1: Collect Liquidity Layer revenue for all 22 tokens. Revenue
        //         is routed to the configured revenue collector (the Fluid
        //         Reserve Contract).
        address[] memory tokens_ = new address[](22);

        // Above $10k revenue (per the latest snapshot)
        tokens_[0] = USDC_ADDRESS;
        tokens_[1] = ETH_ADDRESS;
        tokens_[2] = USDT_ADDRESS;
        tokens_[3] = wstETH_ADDRESS;
        tokens_[4] = cbBTC_ADDRESS;
        tokens_[5] = GHO_ADDRESS;
        tokens_[6] = USDe_ADDRESS;
        tokens_[7] = WBTC_ADDRESS;
        tokens_[8] = weETH_ADDRESS;
        tokens_[9] = syrupUSDC_ADDRESS;
        tokens_[10] = sUSDe_ADDRESS;

        // Below $10k revenue (per the latest snapshot)
        tokens_[11] = XAUT_ADDRESS;
        tokens_[12] = USDTb_ADDRESS;
        tokens_[13] = PAXG_ADDRESS;
        tokens_[14] = rsETH_ADDRESS;
        tokens_[15] = ezETH_ADDRESS;
        tokens_[16] = RLP_ADDRESS;
        tokens_[17] = REUSD_ADDRESS;
        tokens_[18] = USD0_ADDRESS;
        tokens_[19] = eBTC_ADDRESS;
        tokens_[20] = lBTC_ADDRESS;
        tokens_[21] = fxUSD_ADDRESS;

        LIQUIDITY.collectRevenue(tokens_);

        // Step 2: Withdraw the full Reserve balance of each token (minus
        //         minimal dust) to the Team Multisig. Dust is sized per
        //         token decimals to match IGP-112's convention:
        //           - 6-decimal stables / XAUt:  `- 10`
        //           - 8-decimal BTC variants:    `- 10`
        //           - 18-decimal tokens:         `- 0.1 ether`
        //           - native ETH:                `address(reserve).balance - 0.1 ether`
        address reserve_ = address(FLUID_RESERVE);

        uint256[] memory amounts_ = new uint256[](22);

        amounts_[0] = IERC20(USDC_ADDRESS).balanceOf(reserve_) - 10;
        amounts_[1] = reserve_.balance - 0.1 ether;
        amounts_[2] = IERC20(USDT_ADDRESS).balanceOf(reserve_) - 10;
        amounts_[3] = IERC20(wstETH_ADDRESS).balanceOf(reserve_) - 0.1 ether;
        amounts_[4] = IERC20(cbBTC_ADDRESS).balanceOf(reserve_) - 10;
        amounts_[5] = IERC20(GHO_ADDRESS).balanceOf(reserve_) - 0.1 ether;
        amounts_[6] = IERC20(USDe_ADDRESS).balanceOf(reserve_) - 0.1 ether;
        amounts_[7] = IERC20(WBTC_ADDRESS).balanceOf(reserve_) - 10;
        amounts_[8] = IERC20(weETH_ADDRESS).balanceOf(reserve_) - 0.1 ether;
        amounts_[9] = IERC20(syrupUSDC_ADDRESS).balanceOf(reserve_) - 10;
        amounts_[10] = IERC20(sUSDe_ADDRESS).balanceOf(reserve_) - 0.1 ether;

        amounts_[11] = IERC20(XAUT_ADDRESS).balanceOf(reserve_) - 10;
        amounts_[12] = IERC20(USDTb_ADDRESS).balanceOf(reserve_) - 0.1 ether;
        amounts_[13] = IERC20(PAXG_ADDRESS).balanceOf(reserve_) - 0.1 ether;
        amounts_[14] = IERC20(rsETH_ADDRESS).balanceOf(reserve_) - 0.1 ether;
        amounts_[15] = IERC20(ezETH_ADDRESS).balanceOf(reserve_) - 0.1 ether;
        amounts_[16] = IERC20(RLP_ADDRESS).balanceOf(reserve_) - 0.1 ether;
        amounts_[17] = IERC20(REUSD_ADDRESS).balanceOf(reserve_) - 0.1 ether;
        amounts_[18] = IERC20(USD0_ADDRESS).balanceOf(reserve_) - 0.1 ether;
        amounts_[19] = IERC20(eBTC_ADDRESS).balanceOf(reserve_) - 10;
        amounts_[20] = IERC20(lBTC_ADDRESS).balanceOf(reserve_) - 10;
        amounts_[21] = IERC20(fxUSD_ADDRESS).balanceOf(reserve_) - 0.1 ether;

        IFluidReserveContractV2(reserve_).withdrawFunds(
            tokens_,
            amounts_,
            TEAM_MULTISIG,
            "revenue for buybacks"
        );
    }

    /**
     * |
     * |     Payload Actions End Here      |
     * |__________________________________
     */

    // --- BEGIN AUTO-GENERATED PRICES (scripts/verify/prepare-prices.ts) ---
    // --- END AUTO-GENERATED PRICES ---
}
