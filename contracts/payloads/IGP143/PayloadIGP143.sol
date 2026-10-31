// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.21;
pragma experimental ABIEncoderV2;

import {PayloadIGPPriceHelpers} from "../common/pricehelpers.sol";
import {
    AdminModuleStructs as FluidLiquidityAdminStructs
} from "../common/interfaces/IFluidLiquidity.sol";
import {LiquiditySlotsLink} from "../libraries/liquiditySlotsLink.sol";

/// @notice IGP143: Wind down the tBTC vaults 88, 89 and 90 to exit-only.
///
///         Action 1 fully restricts the Liquidity Layer borrow limits of the
///         tBTC T1 vaults 88 (tBTC/USDC), 89 (tBTC/USDT) and 90 (tBTC/GHO)
///         to dust, sets their tBTC withdrawal limits to current supply +
///         20% (10% expansion over 12 hours) and unpauses them at the
///         Liquidity Layer (supply and borrow legs). The Team Multisig
///         paused the three vaults at the Liquidity Layer (tx 0xf833...8d).
///         After this action users can repay and withdraw, but no new
///         borrow is possible.
contract PayloadIGP143 is PayloadIGPPriceHelpers {
    uint256 public constant PROPOSAL_ID = 143;

    // --- Action 1 ---
    uint256 public constant VAULT_TBTC_USDC_ID = 88; // T1: tBTC / USDC
    uint256 public constant VAULT_TBTC_USDT_ID = 89; // T1: tBTC / USDT
    uint256 public constant VAULT_TBTC_GHO_ID = 90; // T1: tBTC / GHO

    /// @dev Base withdrawal limits (tBTC, 18 decimals) = Liquidity Layer
    ///      supply at block 26313811 + 20%, rounded up to 4 decimals.
    ///      Vault 88: supply ≈0.5589 tBTC (≈$43k) -> 0.6707 tBTC (≈$52k)
    uint256 public constant VAULT_88_BASE_WITHDRAWAL_LIMIT = 6_707 * 1e14;
    ///      Vault 89: supply ≈1.1440 tBTC (≈$89k) -> 1.3729 tBTC (≈$107k)
    uint256 public constant VAULT_89_BASE_WITHDRAWAL_LIMIT = 13_729 * 1e14;
    ///      Vault 90: supply ≈0.0004 tBTC (≈$31) -> 0.0005 tBTC (≈$39)
    uint256 public constant VAULT_90_BASE_WITHDRAWAL_LIMIT = 5 * 1e14;

    uint256 public constant WITHDRAWAL_EXPAND_PERCENT = 10 * 1e2; // 10%
    uint256 public constant WITHDRAWAL_EXPAND_DURATION = 12 hours;

    function execute() public virtual override {
        super.execute();

        // Action 1: Restrict tBTC vaults 88/89/90 borrow to dust, set withdrawal limits and unpause them (exit-only).
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

    /// @notice Action 1: Set the tBTC vaults 88, 89 and 90 to exit-only.
    ///         - borrow (USDC / USDT / GHO) at the Liquidity Layer: debt
    ///           ceiling to dust (10 / 20), 0.01% expansion over max duration
    ///         - supply (tBTC): base withdrawal limit = current supply +
    ///           20%, 10% expansion over 12 hours
    ///         - unpause supply and borrow at the Liquidity Layer (only the
    ///           legs that are paused, so the action runs whether or not the
    ///           Team Multisig pause was executed)
    function action1() internal isActionSkippable(1) {
        _setExitOnly(
            getVaultAddress(VAULT_TBTC_USDC_ID),
            USDC_ADDRESS,
            VAULT_88_BASE_WITHDRAWAL_LIMIT
        );
        _setExitOnly(
            getVaultAddress(VAULT_TBTC_USDT_ID),
            USDT_ADDRESS,
            VAULT_89_BASE_WITHDRAWAL_LIMIT
        );
        _setExitOnly(
            getVaultAddress(VAULT_TBTC_GHO_ID),
            GHO_ADDRESS,
            VAULT_90_BASE_WITHDRAWAL_LIMIT
        );
    }

    /**
     * |
     * |     Payload Actions End Here      |
     * |__________________________________
     */

    function _setExitOnly(
        address vault_,
        address borrowToken_,
        uint256 baseWithdrawalLimit_
    ) internal {
        // Borrow: max restrict
        setBorrowProtocolLimitsPaused(vault_, borrowToken_);

        // Supply: current supply + 20%, 10% expansion over 12 hours
        FluidLiquidityAdminStructs.UserSupplyConfig[]
            memory configs_ = new FluidLiquidityAdminStructs.UserSupplyConfig[](
                1
            );
        configs_[0] = FluidLiquidityAdminStructs.UserSupplyConfig({
            user: vault_,
            token: tBTC_ADDRESS,
            mode: 1,
            expandPercent: WITHDRAWAL_EXPAND_PERCENT,
            expandDuration: WITHDRAWAL_EXPAND_DURATION,
            baseWithdrawalLimit: baseWithdrawalLimit_
        });
        LIQUIDITY.updateUserSupplyConfigs(configs_);

        // Unpause the paused legs
        _unpauseUserAtLiquidity(vault_, tBTC_ADDRESS, borrowToken_);
    }

    /// @dev `unpauseUser` reverts with UserNotPaused for a leg that is not
    ///      paused, so only the paused legs are passed in.
    function _unpauseUserAtLiquidity(
        address user_,
        address supplyToken_,
        address borrowToken_
    ) internal {
        bool supplyPaused_ = _isPaused(
            LiquiditySlotsLink.LIQUIDITY_USER_SUPPLY_DOUBLE_MAPPING_SLOT,
            user_,
            supplyToken_,
            LiquiditySlotsLink.BITS_USER_SUPPLY_IS_PAUSED
        );
        bool borrowPaused_ = _isPaused(
            LiquiditySlotsLink.LIQUIDITY_USER_BORROW_DOUBLE_MAPPING_SLOT,
            user_,
            borrowToken_,
            LiquiditySlotsLink.BITS_USER_BORROW_IS_PAUSED
        );
        if (!supplyPaused_ && !borrowPaused_) return;

        address[] memory supplyTokens_ = new address[](supplyPaused_ ? 1 : 0);
        if (supplyPaused_) supplyTokens_[0] = supplyToken_;
        address[] memory borrowTokens_ = new address[](borrowPaused_ ? 1 : 0);
        if (borrowPaused_) borrowTokens_[0] = borrowToken_;

        LIQUIDITY.unpauseUser(user_, supplyTokens_, borrowTokens_);
    }

    function _isPaused(
        uint256 mappingSlot_,
        address user_,
        address token_,
        uint256 pauseBit_
    ) internal view returns (bool) {
        uint256 userData_ = LIQUIDITY.readFromStorage(
            LiquiditySlotsLink.calculateDoubleMappingStorageSlot(
                mappingSlot_,
                user_,
                token_
            )
        );
        return (userData_ >> pauseBit_) & 1 == 1;
    }
}
