// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.21;
pragma experimental ABIEncoderV2;

import {PayloadIGPPriceHelpers} from "../common/pricehelpers.sol";
import {IFluidVault, IFluidVaultT1} from "../common/interfaces/IFluidVault.sol";

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
///
///         Action 4 makes OracleV2 fully live: it switches the remaining
///         119 vaults with an OracleV2 oracle registered on the
///         VaultOracleFactory to that oracle via `updateOracle`.
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

        // Action 4: Make OracleV2 fully live: switch vaults to their OracleV2 oracles.
        action4();
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

    /// @notice Action 4: Make OracleV2 fully live: switch vaults to their
    ///         OracleV2 oracles (VaultOracleFactory
    ///         0x40C10f5f6C78d2Afcaa2db85cBF6b7BF9d168dF1
    ///         `getVaultOracleDeployment(vaultId)`).
    /// @dev T1 vaults take the oracle address via `updateOracle(address)`;
    ///      T2/T3/T4 vaults take the DeployerFactory nonce via
    ///      `updateOracle(uint256)` and probe the new oracle's
    ///      `getExchangeRateOperate()` / `getExchangeRateLiquidate()` before
    ///      committing. Vaults without an OracleV2 registration are not
    ///      switched; vaults 153-157 and 159 were switched in IGP-142.
    function action4() internal isActionSkippable(4) {
        // T1: updateOracle(address)
        _updateOracleT1(1, 0x646f1676eAb96b2F09eCE84a021ba36893D665a0); // ETH / USDC
        _updateOracleT1(2, 0x1135AEe2779243D484ccC43779472a006b055025); // ETH / USDT
        _updateOracleT1(3, 0x4D668241360F46772936d546c359725B40351121); // wstETH / ETH
        _updateOracleT1(4, 0x2717ee42385A885B782EBe8F8Fb51a52089F329B); // wstETH / USDC
        _updateOracleT1(5, 0x54aC7717A99f6Da579EC494228E0C7265e401d70); // wstETH / USDT
        _updateOracleT1(6, 0xeCaf60b6a0b78d6b358571db11e710f9984799dD); // weETH / wstETH
        _updateOracleT1(7, 0xfD8a38040066F2B698Cb31BdCdf4c14C1Ce67dfc); // sUSDe / USDC
        _updateOracleT1(8, 0x3b94a4Cd158eDFdE61168721D15FFC00EbBF1bF6); // sUSDe / USDT
        _updateOracleT1(9, 0xe374C831e4823fd816f3F7E225fa97Ee0E7F6190); // weETH / USDC
        _updateOracleT1(10, 0xD4399875b8627fa728C9BEaeeD775734b4982637); // weETH / USDT
        _updateOracleT1(11, 0x0EA882896270BF090647015259ce1c038380F160); // ETH / USDC
        _updateOracleT1(12, 0x412bF8592Dc48Cce76a2F6313a565719d5Db4D0C); // ETH / USDT
        _updateOracleT1(13, 0x621Aa6407f9e79bA342559ae48430A17f1CDfD7E); // wstETH / ETH
        _updateOracleT1(14, 0xfd11fB5207D586f8B39b9855beb46cbF8d016d0d); // wstETH / USDC
        _updateOracleT1(15, 0x59a5019FEdc5751318Ae3914C7CFf7922515e83d); // wstETH / USDT
        _updateOracleT1(16, 0xf4A1D5c75d00Cf4Eb9d14B95b69c7f50E5582575); // weETH / wstETH
        _updateOracleT1(17, 0x75216a2C68014D752F61775eaeDaB19D5eDf0B7D); // sUSDe / USDC
        _updateOracleT1(18, 0x8869a4a0335313Aa3746d0FEEDEa3eF18C71BAcf); // sUSDe / USDT
        _updateOracleT1(19, 0xe9de88Bed191E02eF90a6dCb2AB907FC329bd83c); // weETH / USDC
        _updateOracleT1(20, 0x1F6F02deEad88eA96c0952a3E3A519c66770e6a4); // weETH / USDT
        _updateOracleT1(21, 0x884F600DcCEd547682654175ED40bA7cA13A89F9); // WBTC / USDC
        _updateOracleT1(22, 0x79E56996b3ded9AaDfB1E03707A2CCE98c4bE65b); // WBTC / USDT
        _updateOracleT1(23, 0x3966DA1DE03767a6367da01866C385290447F78e); // WBTC / ETH
        _updateOracleT1(24, 0x025108DBE9d7753A1d5f08fc7101dBF577E1EaF8); // ETH / WBTC
        _updateOracleT1(25, 0xC75f79ED280771b17a3f0281B1A09FADc341f12c); // wstETH / WBTC
        _updateOracleT1(26, 0xf55b928910FBf7de8a91b81d77813d38CF2dfd86); // weETH / WBTC
        _updateOracleT1(28, 0xc2044f08D715F215cAa136c81D474AADCd32cd83); // cbBTC / ETH
        _updateOracleT1(29, 0x0481e1B3dAe9F8E5a58D71e9dC5e8988c98f8b74); // cbBTC / USDC
        _updateOracleT1(30, 0xA5494971C8bF3f0E90Aab913D81306cB985D3d23); // cbBTC / USDT
        _updateOracleT1(31, 0x08FF2E2826B2eed907b780c512dE1b88a6aeD0d3); // ETH / cbBTC
        _updateOracleT1(32, 0x6BB4b190a7C8a6D76d7dD5F4408962e68109E149); // weETH / cbBTC
        _updateOracleT1(33, 0x494EBb94D38Ad09e6E3456A45f0a5083A5DE3042); // wstETH / cbBTC
        _updateOracleT1(54, 0x6b8180FB1936b3FF9C991ef73aD573Bb889084f6); // ETH / GHO
        _updateOracleT1(55, 0x9e745358EEA03c29ADA97c5f3902fcFE50f3d9f6); // wstETH / GHO
        _updateOracleT1(56, 0x0309D04780372A3bbE55D39C8D228C8115974713); // sUSDe / GHO
        _updateOracleT1(57, 0x91F5bb96691308e64a04Ff6aE51202709434884e); // weETH / GHO
        _updateOracleT1(59, 0x38350Afa67103008c3a0B364868B7b895F6334C3); // WBTC / GHO
        _updateOracleT1(60, 0x727A2E0bB9E4dC200dD05aFF1221ed2608f2dcbC); // cbBTC / GHO
        _updateOracleT1(88, 0x1Bd11AADF256a3B0F6Bd40957a48D03C3eA7e171); // tBTC / USDC
        _updateOracleT1(89, 0x7dc14c977D9381cf52CC0E2245154b4dCbDaC868); // tBTC / USDT
        _updateOracleT1(90, 0x2fE174d63518CF421CD27eB0EDae7E868BFbfb89); // tBTC / GHO
        _updateOracleT1(94, 0x70e4568830aD14d4cAf843b0D351B788774B2bf0); // eBTC / WBTC
        _updateOracleT1(100, 0x8f316becf3E47F7D368fa78d621621F5C71bafd7); // USDC / ETH
        _updateOracleT1(101, 0x7C0CF242Eab0A497b62E56e419B6E030787C9D44); // USDC / WBTC
        _updateOracleT1(102, 0x1070d57A8E2cd0E3A5851134e17f018D286f058f); // USDC / cbBTC
        _updateOracleT1(107, 0xc9807f6Dc16872df9A3cD0b19935C35B13129bD5); // LBTC / USDC
        _updateOracleT1(108, 0x8bD8094352ba9b769aAA49A31f646227dcACa4F4); // LBTC / USDT
        _updateOracleT1(109, 0x9a9E53aE3e56C105187A9Cd195D8B5AB0C60Be6C); // LBTC / GHO
        _updateOracleT1(116, 0x3c872d45Ca49eabbD39Ad6BDe69F3C040839C99D); // XAUt / USDC
        _updateOracleT1(117, 0xB33121EC411D1a2b67acD5d650013E905B3B2e0D); // XAUt / USDT
        _updateOracleT1(118, 0x48Eb4312D42875E20D59Dc87eC1D5D895a89adE8); // XAUt / GHO
        _updateOracleT1(119, 0x2a4090a7bFf6df8F7a021439bf6fbed7a0416f1b); // PAXG / USDC
        _updateOracleT1(120, 0xCDDFBfC30aF7F4d8dA8C2A0adB25ff0A6eA2da73); // PAXG / USDT
        _updateOracleT1(121, 0xB3dB50A5da5009cAFB603F87d72fd24f561a0D63); // PAXG / GHO
        _updateOracleT1(128, 0x74A2989f000464fF2333413180909222718C6317); // ETH / USDtb
        _updateOracleT1(129, 0xA21298B7Dcfa0A850a624820F76C578EC8a92a0f); // wstETH / USDtb
        _updateOracleT1(130, 0x19C64cD86b5612e5151129475028C486babf3e8f); // weETH / USDtb
        _updateOracleT1(131, 0x38A65816b32Cf5afc0d5f97fcFC28ebDF6F71f97); // WBTC / USDtb
        _updateOracleT1(132, 0xe5b05e2D6d6004AFdbAa0a50575C93DbFeFca8aC); // cbBTC / USDtb
        _updateOracleT1(146, 0x0d990D135C7f242fA10837BB08821F43f28C6A8f); // syrupUSDC / USDC
        _updateOracleT1(147, 0x1BC63Cc2C4b0FB18533d64834eE04755a5469614); // syrupUSDC / USDT
        _updateOracleT1(148, 0xB5397E17aA9253d2041ce49A7f0F0F83C214D909); // syrupUSDC / GHO
        _updateOracleT1(150, 0x12f24A66a044879439446b80Cc8A1Df9D32A7bec); // syrupUSDT / USDC
        _updateOracleT1(151, 0x2b06813316Fc3815411417ccD932DC0Db7431e3C); // syrupUSDT / USDT
        _updateOracleT1(152, 0xbb622B72065493bAa531BE8eF53768f30C11CACE); // syrupUSDT / GHO
        _updateOracleT1(160, 0xE2194E8aF233a9096587302414ce270cE60ABD77); // reUSD / USDC
        _updateOracleT1(161, 0xd8DDC3f55102699224316fCd595fc516d4c04F78); // reUSD / USDT
        _updateOracleT1(162, 0x8FCF66E43C27203C047FE1CdD0564353920D49f5); // reUSD / GHO
        _updateOracleT1(165, 0x8ad24a1ed3047EAe302A6a4D2ba6AfBBA9b89A8f); // PST / USDC
        _updateOracleT1(166, 0x007F6F477d8Cbc8e821ceB06613879099d28b8E5); // PST / USDT
        _updateOracleT1(171, 0x4A84C4302Ab24F44Ea31CF237A576d85aE89CD13); // sUSDai / USDC
        _updateOracleT1(172, 0xb390f9868e46852b2A9D2C76745A6A8F40938aC8); // sUSDai / USDT
        _updateOracleT1(179, 0xd68534c98Bd3F595645152454D27E01323D2AEc4); // sUSDai / GHO
        _updateOracleT1(182, 0x1D15D001Ea51AdaC16277D75286D338C005eAdBa); // weETH / ETH

        // T2 / T3 / T4: updateOracle(uint256 nonce)
        _updateOracleSmart(44, 317); // T4 wstETH-ETH / wstETH-ETH
        _updateOracleSmart(45, 318); // T3 ETH / USDC-USDT
        _updateOracleSmart(46, 319); // T3 wstETH / USDC-USDT
        _updateOracleSmart(47, 320); // T3 weETH / USDC-USDT
        _updateOracleSmart(48, 321); // T3 WBTC / USDC-USDT
        _updateOracleSmart(49, 322); // T3 cbBTC / USDC-USDT
        _updateOracleSmart(50, 323); // T3 sUSDe / USDC-USDT
        _updateOracleSmart(51, 324); // T4 WBTC-cbBTC / WBTC-cbBTC
        _updateOracleSmart(52, 325); // T2 WBTC-cbBTC / USDC
        _updateOracleSmart(53, 326); // T2 WBTC-cbBTC / USDT
        _updateOracleSmart(61, 333); // T4 GHO-USDC / GHO-USDC
        _updateOracleSmart(74, 334); // T2 weETH-ETH / wstETH
        _updateOracleSmart(92, 338); // T2 sUSDe-USDT / USDT
        _updateOracleSmart(93, 339); // T2 USDe-USDT / USDT
        _updateOracleSmart(96, 341); // T2 eBTC-cbBTC / WBTC
        _updateOracleSmart(97, 342); // T2 LBTC-cbBTC / WBTC
        _updateOracleSmart(98, 343); // T4 sUSDe-USDT / USDC-USDT
        _updateOracleSmart(99, 344); // T4 USDe-USDT / USDC-USDT
        _updateOracleSmart(114, 351); // T2 LBTC-cbBTC / cbBTC
        _updateOracleSmart(115, 352); // T2 WBTC-LBTC / WBTC
        _updateOracleSmart(122, 359); // T2 PAXG-XAUt / USDC
        _updateOracleSmart(123, 360); // T2 PAXG-XAUt / USDT
        _updateOracleSmart(124, 361); // T2 PAXG-XAUt / GHO
        _updateOracleSmart(125, 362); // T4 GHO-sUSDe / GHO-USDC
        _updateOracleSmart(126, 363); // T4 sUSDe-USDT / USDC-USDT
        _updateOracleSmart(127, 364); // T4 USDe-USDT / USDC-USDT
        _updateOracleSmart(137, 370); // T2 USDe-USDtb / USDT
        _updateOracleSmart(138, 371); // T2 USDe-USDtb / USDC
        _updateOracleSmart(139, 372); // T4 GHO-USDe / GHO-USDC
        _updateOracleSmart(140, 373); // T2 USDe-USDtb / GHO
        _updateOracleSmart(141, 374); // T2 GHO-USDe / GHO
        _updateOracleSmart(145, 375); // T2 syrupUSDC-USDC / USDC
        _updateOracleSmart(149, 379); // T2 syrupUSDT-USDT / USDT
        _updateOracleSmart(163, 392); // T3 reUSD / USDC-USDT
        _updateOracleSmart(164, 393); // T2 reUSD-USDT / USDT
        _updateOracleSmart(168, 396); // T3 PST / USDC-USDT
        _updateOracleSmart(169, 397); // T4 PST-USDC / USDC-USDT
        _updateOracleSmart(170, 398); // T4 reUSD-USDT / USDC-USDT
        _updateOracleSmart(173, 401); // T3 sUSDai / USDC-USDT
        _updateOracleSmart(175, 402); // T4 sUSDai-USDC / USDC-USDT
        _updateOracleSmart(176, 403); // T4 sUSDai-USDT / USDC-USDT
        _updateOracleSmart(177, 404); // T2 sUSDai-USDT / USDT
        _updateOracleSmart(178, 405); // T2 sUSDai-USDC / USDC
        _updateOracleSmart(180, 407); // T2 USDai-USDC / USDC
        _updateOracleSmart(181, 408); // T3 reUSD / GHO-USDC
    }

    /**
     * |
     * |     Payload Actions End Here      |
     * |__________________________________
     */

    /// @dev Action 4 helper: T1 vault oracle switch.
    function _updateOracleT1(uint256 vaultId_, address oracle_) internal {
        IFluidVaultT1(getVaultAddress(vaultId_)).updateOracle(oracle_);
    }

    /// @dev Action 4 helper: T2/T3/T4 vault oracle switch by DeployerFactory nonce.
    function _updateOracleSmart(uint256 vaultId_, uint256 nonce_) internal {
        IFluidVault(getVaultAddress(vaultId_)).updateOracle(nonce_);
    }

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
    // fetched: 2026-11-25T08:32:05.941Z, source: coingecko
    function BTC_USD_PRICE()    public pure override returns (uint256) { return 59_000 * 1e2; }
    function ETH_USD_PRICE()    public pure override returns (uint256) { return 1_650 * 1e2; }
    function STABLE_USD_PRICE() public pure override returns (uint256) { return 1 * 1e2; }
    function wstETH_USD_PRICE() public pure override returns (uint256) { return 2_060 * 1e2; }
    // prepare-prices.ts skips FLUID (NON_PRICED_EXEMPT) but action 1 prices it; set by hand, re-check on every rerun.
    // fetched: 2026-11-25, source: coingecko
    function FLUID_USD_PRICE()  public pure override returns (uint256) { return 1.43 * 1e2; }
    // --- END AUTO-GENERATED PRICES ---
}
