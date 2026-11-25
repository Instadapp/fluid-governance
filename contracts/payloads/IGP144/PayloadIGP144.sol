// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.21;
pragma experimental ABIEncoderV2;

import {PayloadIGPPriceHelpers} from "../common/pricehelpers.sol";

/// @notice IGP144: DexV2 and Money Market launch limits on the Liquidity
///         Layer.
///
///         Action 1 raises the DexV2 proxy's and the Money Market proxy's
///         Liquidity Layer limits from the IGP-141 private-beta $50k to the
///         public launch limits, and adds cbBTC and wstETH, for ETH, USDC,
///         USDT, WBTC, cbBTC and wstETH:
///         - supply: base withdrawal limit $5M, expand 50% / 6h
///         - borrow: base debt ceiling $5M, max debt ceiling $30M (ETH, USDC,
///           USDT, wstETH), $15M (WBTC) or $5M (cbBTC), expand 50% / 6h
///         and, on the DexV2 proxy only, FLUID supply: base withdrawal limit
///         $5M, expand 50% / 6h.
///
///         Action 2 transfers the ETH/FLUID Fluid Dex V1 position (NFT 3192,
///         vault 76) from the Treasury to the Team Multisig.
///
///         Action 3 restricts and pauses the first-generation DexV2 and Money
///         Market proxies (replaced in IGP-141) at the Liquidity Layer for
///         ETH, USDC, USDT, WBTC and cbBTC.
contract PayloadIGP144 is PayloadIGPPriceHelpers {
    uint256 public constant PROPOSAL_ID = 144;

    // --- Action 1 ---
    /// @dev DexV2 / Money Market proxies on Ethereum, the same addresses as
    ///      IGP-141 (Liquidity Layer users since IGP-141).
    address public constant DEXV2_LAUNCH_PROXY = 0xaBE4D5AA1Bb188f4B5d3a1aE3B8ec5e300A78261;
    address public constant MONEY_MARKET_LAUNCH_PROXY = 0x92fC6445a6d57fCA94c3B847E80504B95e2D9e2F;

    uint256 public constant LAUNCH_EXPAND_PERCENT = 50 * 1e2; // 50%
    uint256 public constant LAUNCH_EXPAND_DURATION = 6 hours;

    uint256 public constant LAUNCH_BASE_WITHDRAWAL_LIMIT_USD = 5_000_000; // $5M
    uint256 public constant LAUNCH_BASE_BORROW_LIMIT_USD = 5_000_000; // $5M

    uint256 public constant MAX_BORROW_LIMIT_USD_MAJORS = 30_000_000; // $30M: ETH, USDC, USDT, wstETH
    uint256 public constant MAX_BORROW_LIMIT_USD_WBTC = 15_000_000; // $15M
    uint256 public constant MAX_BORROW_LIMIT_USD_CBBTC = 5_000_000; // $5M

    // --- Action 2 ---
    /// @dev ETH/FLUID Fluid Dex V1 position: vault 76 NFT (VAULT_FACTORY token
    ///      id), held by the Treasury.
    uint256 public constant VAULT_76_POSITION_NFT_ID = 3192;

    // --- Action 3 ---
    /// @dev First-generation DexV2 / Money Market proxies (IGP-113), replaced
    ///      by the launch proxies in IGP-141. Nothing supplied or borrowed.
    address public constant OLD_DEXV2_PROXY = 0x4E42f9e626FAcDdd97EDFA537AA52C5024448625;
    address public constant OLD_MONEY_MARKET_PROXY = 0xe3B7e3f4da603FC40fD889caBdEe30a4cf15DD34;

    function execute() public virtual override {
        super.execute();

        // Action 1: DexV2 and Money Market launch limits on the Liquidity Layer.
        action1();

        // Action 2: Transfer the ETH/FLUID Fluid Dex V1 position (NFT 3192) from the Treasury to the Team Multisig.
        action2();

        // Action 3: Restrict and pause the old DexV2 and Money Market proxies at the Liquidity Layer.
        action3();
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

    /// @notice Action 1: Liquidity Layer launch limits for the DexV2 proxy
    ///         and the Money Market proxy. For each proxy and each token:
    ///         - supply: base withdrawal limit $5M, mode 1 (with interest),
    ///           expand 50% / 6h
    ///         - borrow: base debt ceiling $5M, max debt ceiling per token,
    ///           mode 1, expand 50% / 6h
    ///         ETH, USDC, USDT and WBTC replace the IGP-141 $50k configs;
    ///         cbBTC and wstETH are new for both proxies.
    ///         FLUID: DexV2 proxy only, supply side only ($5M base withdrawal
    ///         limit, mode 1, expand 50% / 6h).
    function action1() internal isActionSkippable(1) {
        address[2] memory protocols_ = [DEXV2_LAUNCH_PROXY, MONEY_MARKET_LAUNCH_PROXY];

        for (uint256 p = 0; p < protocols_.length; p++) {
            _setLaunchLimitsUSD(protocols_[p], ETH_ADDRESS, MAX_BORROW_LIMIT_USD_MAJORS);
            _setLaunchLimitsUSD(protocols_[p], USDC_ADDRESS, MAX_BORROW_LIMIT_USD_MAJORS);
            _setLaunchLimitsUSD(protocols_[p], USDT_ADDRESS, MAX_BORROW_LIMIT_USD_MAJORS);
            _setLaunchLimitsUSD(protocols_[p], wstETH_ADDRESS, MAX_BORROW_LIMIT_USD_MAJORS);
            _setLaunchLimitsUSD(protocols_[p], WBTC_ADDRESS, MAX_BORROW_LIMIT_USD_WBTC);
            _setLaunchLimitsUSD(protocols_[p], cbBTC_ADDRESS, MAX_BORROW_LIMIT_USD_CBBTC);
        }

        setSupplyProtocolLimits(
            SupplyProtocolConfig({
                protocol: DEXV2_LAUNCH_PROXY,
                supplyToken: FLUID_ADDRESS,
                expandPercent: LAUNCH_EXPAND_PERCENT,
                expandDuration: LAUNCH_EXPAND_DURATION,
                baseWithdrawalLimitInUSD: LAUNCH_BASE_WITHDRAWAL_LIMIT_USD
            })
        );
    }

    /// @notice Action 2: Transfer the ETH/FLUID Fluid Dex V1 position (vault 76,
    ///         NFT 3192) from the Treasury to the Team Multisig.
    function action2() internal isActionSkippable(2) {
        string[] memory targets_ = new string[](1);
        bytes[] memory encodedSpells_ = new bytes[](1);

        targets_[0] = "BASIC-B"; // BASIC-ERC721-v1.0
        encodedSpells_[0] = abi.encodeWithSignature(
            "withdrawERC721(address,uint256,address,uint256,uint256)",
            address(VAULT_FACTORY),
            VAULT_76_POSITION_NFT_ID,
            TEAM_MULTISIG,
            0,
            0
        );

        TREASURY.cast(targets_, encodedSpells_, address(this));
    }

    /// @notice Action 3: Restrict and pause the first-generation DexV2 and
    ///         Money Market proxies at the Liquidity Layer. For each proxy and
    ///         each of ETH, USDC, USDT, WBTC and cbBTC:
    ///         - borrow: dust debt ceiling (10 / 20)
    ///         - supply: dust base withdrawal limit (10)
    ///         - supply, withdraw, borrow and payback paused
    /// @dev Uses `pauseUserSupply` / `pauseUserBorrow` of the Admin module
    ///      set in IGP-143 (which no longer routes `pauseUser`). Both proxies
    ///      are user class 0 and hold nothing at the Liquidity Layer.
    function action3() internal isActionSkippable(3) {
        address[2] memory protocols_ = [OLD_DEXV2_PROXY, OLD_MONEY_MARKET_PROXY];

        address[] memory tokens_ = new address[](5);
        tokens_[0] = ETH_ADDRESS;
        tokens_[1] = USDC_ADDRESS;
        tokens_[2] = USDT_ADDRESS;
        tokens_[3] = WBTC_ADDRESS;
        tokens_[4] = cbBTC_ADDRESS;

        for (uint256 p = 0; p < protocols_.length; p++) {
            for (uint256 t = 0; t < tokens_.length; t++) {
                setBorrowProtocolLimitsPaused(protocols_[p], tokens_[t]);
                setSupplyProtocolLimitsPaused(protocols_[p], tokens_[t]);
            }
            LIQUIDITY.pauseUserSupply(protocols_[p], tokens_, true, true);
            LIQUIDITY.pauseUserBorrow(protocols_[p], tokens_, true, true);
        }
    }

    /**
     * |
     * |     Payload Actions End Here      |
     * |__________________________________
     */

    /// @dev Supply ($5M base withdrawal) + borrow ($5M base, `maxBorrowLimitInUSD_`
    ///      max debt ceiling) config at the Liquidity Layer, mode 1, 50% / 6h.
    function _setLaunchLimitsUSD(
        address protocol_,
        address token_,
        uint256 maxBorrowLimitInUSD_
    ) internal {
        setSupplyProtocolLimits(
            SupplyProtocolConfig({
                protocol: protocol_,
                supplyToken: token_,
                expandPercent: LAUNCH_EXPAND_PERCENT,
                expandDuration: LAUNCH_EXPAND_DURATION,
                baseWithdrawalLimitInUSD: LAUNCH_BASE_WITHDRAWAL_LIMIT_USD
            })
        );
        setBorrowProtocolLimits(
            BorrowProtocolConfig({
                protocol: protocol_,
                borrowToken: token_,
                expandPercent: LAUNCH_EXPAND_PERCENT,
                expandDuration: LAUNCH_EXPAND_DURATION,
                baseBorrowLimitInUSD: LAUNCH_BASE_BORROW_LIMIT_USD,
                maxBorrowLimitInUSD: maxBorrowLimitInUSD_
            })
        );
    }

    // --- BEGIN AUTO-GENERATED PRICES (scripts/verify/prepare-prices.ts) ---
    // fetched: 2026-11-23T15:56:00.000Z, source: coingecko (via DefiLlama coins API)
    function ETH_USD_PRICE()    public pure override returns (uint256) { return 1_770 * 1e2; }
    function wstETH_USD_PRICE() public pure override returns (uint256) { return 2_230 * 1e2; }
    function BTC_USD_PRICE()    public pure override returns (uint256) { return 63_000 * 1e2; }
    function STABLE_USD_PRICE() public pure override returns (uint256) { return 1 * 1e2; }
    // fetched: 2026-11-24T17:54:19.000Z, source: coingecko (via DefiLlama coins API)
    function FLUID_USD_PRICE()  public pure override returns (uint256) { return 1.48 * 1e2; }
    // --- END AUTO-GENERATED PRICES ---
}
