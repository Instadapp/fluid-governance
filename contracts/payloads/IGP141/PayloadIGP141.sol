// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.21;
pragma experimental ABIEncoderV2;

import {PayloadIGPPriceHelpers} from "../common/pricehelpers.sol";
import {IFluidReserveContractV2} from "../common/interfaces/IFluidReserveContract.sol";

/// @notice IGP141: Liquidity Layer limits for the DexV2 and Money Market
///         proxies, and the Foundation's October grant tranche.
///
///         Action 1 sets $50k Liquidity Layer withdrawal and borrow limits
///         for ETH, USDC, USDT and WBTC on the DexV2 proxy and the Money
///         Market proxy (mainnet private beta).
///
///         Action 2 collects the Liquidity Layer's USDC, USDT and ETH revenue
///         into the Fluid Reserve and sends the October tranche of the
///         $350,000/month Foundation grant (IGP-139): 90,000 USDC + 80,000
///         USDT + 62 ETH + 13 stETH, ~$350k at the 7-day average ETH price
///         ($2,420).
contract PayloadIGP141 is PayloadIGPPriceHelpers {
    uint256 public constant PROPOSAL_ID = 141;

    // --- Action 1 ---
    /// @dev DexV2 / Money Market proxies on Ethereum (deployed via CREATE2,
    ///      initial logic = EmptyImplementationUUPS 0x9aA2B2aba70EEF169a8ad6949C0B2F68e3C6e63F,
    ///      owner Team Multisig).
    ///      The Liquidity AdminModule requires `user.code.length > 0`
    ///      (AdminModule__AddressNotAContract, 10026), so both proxies must
    ///      be deployed before this proposal executes.
    address public constant DEXV2_LAUNCH_PROXY = 0xaBE4D5AA1Bb188f4B5d3a1aE3B8ec5e300A78261;
    address public constant MONEY_MARKET_LAUNCH_PROXY = 0x92fC6445a6d57fCA94c3B847E80504B95e2D9e2F;
    uint256 public constant DEXV2_MM_LIMIT_USD = 50_000; // $50k
    uint256 public constant DEXV2_MM_EXPAND_PERCENT = 20 * 1e2; // 20%
    uint256 public constant DEXV2_MM_EXPAND_DURATION = 12 hours;

    // --- Action 2 ---
    /// @notice October 2026 tranche of the $350,000/month Foundation grant.
    ///         Sized to what the Reserve plus uncollected Liquidity revenue
    ///         holds at authoring (~93.0k USDC, ~83.7k USDT, ~65.3 ETH,
    ///         ~53.6 stETH). ~$350k at the 7-day average ETH / stETH price of
    ///         ~$2,420 (14-21 Oct 2026); fixed token amounts, so the
    ///         USD value of the ETH / stETH legs moves with the ETH price.
    uint256 public constant FOUNDATION_GRANT_USDC = 90_000 * 1e6;
    uint256 public constant FOUNDATION_GRANT_USDT = 80_000 * 1e6;
    uint256 public constant FOUNDATION_GRANT_ETH = 62 ether;
    uint256 public constant FOUNDATION_GRANT_STETH = 13 ether;

    function execute() public virtual override {
        super.execute();

        // Action 1: $50k Liquidity Layer withdrawal + borrow limits for the DexV2 and Money Market proxies.
        action1();

        // Action 2: Collect Liquidity Layer revenue and send the Foundation's October grant tranche.
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

    /// @notice Action 1: Liquidity Layer limits for the DexV2 proxy and the
    ///         Money Market proxy. For ETH, USDC, USDT and WBTC each, per
    ///         proxy:
    ///         - supply: base withdrawal limit $50k, mode 1 (with interest),
    ///           expand 20% / 12h
    ///         - borrow: base and max debt ceiling $50k, mode 1, expand
    ///           20% / 12h
    ///         Supply and borrow configs are both needed for every listed
    ///         token.
    function action1() internal isActionSkippable(1) {
        address[2] memory protocols_ = [
            DEXV2_LAUNCH_PROXY,
            MONEY_MARKET_LAUNCH_PROXY
        ];

        for (uint256 p = 0; p < protocols_.length; p++) {
            _setLaunchLimitsUSD(protocols_[p], ETH_ADDRESS);
            _setLaunchLimitsUSD(protocols_[p], USDC_ADDRESS);
            _setLaunchLimitsUSD(protocols_[p], USDT_ADDRESS);
            _setLaunchLimitsUSD(protocols_[p], WBTC_ADDRESS);
        }
    }

    /// @notice Action 2: Collect the Liquidity Layer's USDC, USDT and ETH
    ///         revenue into the Fluid Reserve and transfer the October
    ///         tranche of the Foundation's $350,000/month grant.
    /// @dev IGP-140 Action 8 pattern (`collectRevenue`, then
    ///      `FLUID_RESERVE.withdrawFunds` to `FLUID_FOUNDATION`, memo
    ///      "FOUNDATION GRANT"), plus a stETH leg from the Reserve's Lite
    ///      revenue as in IGP-139. Fixed amounts, so any excess stays in the
    ///      Reserve.
    function action2() internal isActionSkippable(2) {
        // Step 1: Collect Liquidity Layer revenue into the Reserve.
        address[] memory liquidityTokens_ = new address[](3);
        liquidityTokens_[0] = USDC_ADDRESS; // ~$71.8k uncollected
        liquidityTokens_[1] = USDT_ADDRESS; // ~$61.0k uncollected
        liquidityTokens_[2] = ETH_ADDRESS; // ~13.1 ETH uncollected

        LIQUIDITY.collectRevenue(liquidityTokens_);

        // Step 2: Transfer the tranche to the Fluid Foundation.
        address[] memory tokens_ = new address[](4);
        uint256[] memory amounts_ = new uint256[](4);

        tokens_[0] = USDC_ADDRESS;
        amounts_[0] = FOUNDATION_GRANT_USDC; // 90,000 USDC

        tokens_[1] = USDT_ADDRESS;
        amounts_[1] = FOUNDATION_GRANT_USDT; // 80,000 USDT

        tokens_[2] = ETH_ADDRESS;
        amounts_[2] = FOUNDATION_GRANT_ETH; // 62 ETH

        tokens_[3] = stETH_ADDRESS;
        amounts_[3] = FOUNDATION_GRANT_STETH; // 13 stETH

        IFluidReserveContractV2(address(FLUID_RESERVE)).withdrawFunds(
            tokens_,
            amounts_,
            FLUID_FOUNDATION,
            "FOUNDATION GRANT"
        );
    }

    /**
     * |
     * |     Payload Actions End Here      |
     * |__________________________________
     */

    /// @dev Supply ($50k base withdrawal) + borrow ($50k base = max debt
    ///      ceiling) config at the Liquidity Layer, mode 1, 20% / 12h.
    function _setLaunchLimitsUSD(address protocol_, address token_) internal {
        setSupplyProtocolLimits(
            SupplyProtocolConfig({
                protocol: protocol_,
                supplyToken: token_,
                expandPercent: DEXV2_MM_EXPAND_PERCENT,
                expandDuration: DEXV2_MM_EXPAND_DURATION,
                baseWithdrawalLimitInUSD: DEXV2_MM_LIMIT_USD
            })
        );
        setBorrowProtocolLimits(
            BorrowProtocolConfig({
                protocol: protocol_,
                borrowToken: token_,
                expandPercent: DEXV2_MM_EXPAND_PERCENT,
                expandDuration: DEXV2_MM_EXPAND_DURATION,
                baseBorrowLimitInUSD: DEXV2_MM_LIMIT_USD,
                maxBorrowLimitInUSD: DEXV2_MM_LIMIT_USD
            })
        );
    }

    // --- BEGIN AUTO-GENERATED PRICES (scripts/verify/prepare-prices.ts) ---
    // fetched: 2026-10-21T20:06:51.248Z, source: coingecko
    function ETH_USD_PRICE()    public pure override returns (uint256) { return 2_420 * 1e2; }
    function STABLE_USD_PRICE() public pure override returns (uint256) { return 1 * 1e2; }
    function BTC_USD_PRICE()    public pure override returns (uint256) { return 81_800 * 1e2; }
    // --- END AUTO-GENERATED PRICES ---
}
