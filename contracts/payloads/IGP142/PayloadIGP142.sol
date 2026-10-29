// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.21;
pragma experimental ABIEncoderV2;

import {PayloadIGPPriceHelpers} from "../common/pricehelpers.sol";
import {
    AdminModuleStructs as FluidLiquidityAdminStructs
} from "../common/interfaces/IFluidLiquidity.sol";
import {IDSAV2} from "../common/interfaces/IDSA.sol";
import {IFluidDex} from "../common/interfaces/IFluidDex.sol";
import {
    IFluidVault,
    IFluidVaultT1
} from "../common/interfaces/IFluidVault.sol";

/// @notice Liquidity Layer admin call not exposed on the shared
///         IFluidLiquidityAdmin interface. Signature added to the Liquidity
///         AdminModule in IGP-37.
interface IFluidLiquidityWithdrawalLimit {
    function updateUserWithdrawalLimit(
        address user_,
        address token_,
        uint256 newLimit_
    ) external;
}

/// @notice IGP142 (DRAFT): Close down the dexV1 test DEX at the Liquidity
///         Layer, rebalance vault 3 (wstETH/ETH), and raise the weETH/ETH
///         vault (182) from dust to launch limits. The action list may still
///         change before submission.
///
///         Action 1 fully restricts the Liquidity Layer supply and borrow
///         limits of the dexV1 test DEX 0x6d83...e03a (wstETH/ETH, deployed
///         from the early MS1 test factory, never part of the DexFactory)
///         and pins its current withdrawal limit to its full supply, so no
///         further withdrawal or borrow can happen.
///
///         Action 2 rebalances vault 3 (wstETH/ETH). Its ETH borrow at the
///         Liquidity Layer is ~0.0049 ETH below the vault's own total borrow,
///         and the rebalance cannot borrow the difference while the vault's
///         Liquidity Layer borrow limit is at dust. The action raises the
///         limit, runs the rebalance through the Reserve Contract (the
///         vault's rebalancer), and restores the dust limit.
///
///         Action 3 raises the weETH/ETH T1 vault (182) from the IGP-140 dust
///         limits to launch limits.
///
///         Action 4 reduces the Team Multisig's wstETH and cbBTC borrow limits
///         at the Liquidity Layer (IGP-107 DEX Lite credit) to dust, the same
///         treatment USDC and USDT received in IGP-132.
///
///         Action 5 exits iETHv2's residual test positions (old vault #3
///         NFT 18, vault 34 NFT 2296) through its DSA before Actions 6 and
///         7 freeze them. The Timelock sends 0.005 ETH for the ETH leg of
///         the vault 34 repayment; unused ETH is refunded.
///
///         Action 6 fully restricts the Liquidity Layer supply and borrow
///         limits of the IGP-45 test DEXes dex id1 wstETH/ETH 0x25F0...F901
///         and dex id3 WBTC/cbBTC 0x1d3e...204d (old DexFactory), same
///         pattern as Action 1. The residual supply (vault 34 dust + locked
///         init shares) stays locked.
///
///         Action 7 fully restricts and pauses at the Liquidity Layer the
///         five pre-launch vaults of the old VaultFactory (0x3B38...8C60,
///         closed in IGP-24), the old DexFactory dex id1 / dex id3, and the
///         Liquidity Layer debt configs of the T2 vaults 42 / 43 on dex id3.
///
///         Action 8 restricts and pauses at the Liquidity Layer the last
///         IGP-45 test DEX, dex id2 (USDC/USDT), and the six empty T3
///         vaults 35-40 built on it.
///
///         Action 9 restricts and pauses the hidden USDe vaults 66-73 at the
///         Liquidity Layer.
///
///         Action 10 closes the never-launched dex 5 (USDC-ETH) test market:
///         vault 62 borrow at the DEX to dust, share caps to 1.
///
///         Action 11 caps dex 27 (wstUSR-USDC) supply shares at 1.
///
///         Action 12 restricts and pauses the dust-launch vaults 95
///         (eBTC/cbBTC) and 167 (PST-USDC / USDC).
///
///         Action 13 moves the osETH vaults 153-157 and 159 from their V1
///         oracles to OracleV2 oracles. The RedStone osETH/ETH feed that the
///         V1 oracles of vaults 153-157 read is being wound down and already
///         reverts as stale.
contract PayloadIGP142 is PayloadIGPPriceHelpers {
    uint256 public constant PROPOSAL_ID = 142;

    // --- Action 1 ---
    /// @dev dexV1 test DEX (wstETH/ETH). Not deployed by the DexFactory, so
    ///      it cannot be resolved via getDexAddress().
    address public constant DEX_V1_TEST =
        0x6d83f60eEac0e50A1250760151E81Db2a278e03a;

    // --- Action 2 ---
    uint256 public constant VAULT_WSTETH_ETH_ID = 3; // T1: wstETH / ETH
    /// @dev Temporary raw ETH borrow limit (with-interest mode) for the
    ///      rebalance. Live vault borrow is ~0.454 ETH, so ~1 ETH leaves
    ///      room for the ~0.0049 ETH drift. Reset to dust in the same action.
    uint256 public constant VAULT_3_TEMP_BORROW_LIMIT_RAW = 1 ether;

    // --- Action 3 ---
    uint256 public constant VAULT_WEETH_ETH_ID = 182; // T1: weETH / ETH

    // --- Action 5 ---
    /// @dev FLUID-VAULT-T4-A connector input (operatePerfect)
    struct T4OperatePerfect {
        address vaultAddress;
        uint256 nftId;
        int256 perfectColShares;
        int256 colToken0MinMax;
        int256 colToken1MinMax;
        int256 perfectDebtShares;
        int256 debtToken0MinMax;
        int256 debtToken1MinMax;
        uint256 getNftId;
        uint256[] setIds;
    }

    /// @dev iETHv2 strategy DSA (#36121). Auths: iETHv2 vault + Timelock.
    address public constant IETHV2_DSA =
        0x9600A48ed0f931d0c422D574e3275a90D8b22745;
    /// @dev T4 wstETH/ETH vault on old dex id1.
    address public constant VAULT_34_WSTETH_ETH_T4 =
        0x57fed7c9b3c763999c519264931790cBcA331417;

    // --- Action 6 ---
    /// @dev IGP-45 test DEXes, deployed from the old DexFactory, so they
    ///      cannot be resolved via getDexAddress().
    address public constant OLD_DEX_ID1_WSTETH_ETH =
        0x25F0A3B25cBC0Ca0417770f686209628323fF901;
    address public constant OLD_DEX_ID3_WBTC_CBBTC =
        0x1d3e52a11B98Ed2AAB7eB0Bfe1cbB6525233204d;

    // --- Action 8 ---
    /// @dev IGP-45 test dex id2 (USDC/USDT), old DexFactory. Only DEX-level
    ///      users are the T3 vaults 35-40.
    address public constant OLD_DEX_ID2_USDC_USDT =
        0x085B07A30381F3Cc5A4250e10E4379d465b770ac;

    // --- Action 7 ---
    /// @dev Pre-launch vaults from the old VaultFactory 0x3B38...8C60
    ///      (closed in IGP-24). Not resolvable via getVaultAddress().
    address public constant OLD_VAULT_1_ETH_USDC =
        0x5eA9A2B42Bc9aC8CAC76E19F0Fcd5C1b06950807;
    address public constant OLD_VAULT_2_ETH_USDT =
        0xE53794f2ed0839F24170079A9F3c5368147F6c81;
    address public constant OLD_VAULT_3_WSTETH_ETH =
        0x28680f14C4Bb86B71119BC6e90E4e6D87E6D1f51;
    address public constant OLD_VAULT_4_WSTETH_USDC =
        0x460143a489729a3cA32DeA82fa48ea61175accbc;
    address public constant OLD_VAULT_5_WSTETH_USDT =
        0x2B251211f5Ff0A753A8d5B9411d736875174f375;
    /// @dev T2 vaults on old dex id3 (live VaultFactory ids) with debt
    ///      configured directly at the Liquidity Layer.
    uint256 public constant VAULT_42_ID = 42; // T2 on dex id3, USDC debt
    uint256 public constant VAULT_43_ID = 43; // T2 on dex id3, USDT debt

    // --- Action 9 ---
    uint256 public constant VAULT_USDE_USDC_ID = 66; // T1: USDe / USDC
    uint256 public constant VAULT_USDE_USDT_ID = 67; // T1: USDe / USDT
    uint256 public constant VAULT_USDE_GHO_ID = 68; // T1: USDe / GHO
    uint256 public constant VAULT_ETH_USDE_ID = 69; // T1: ETH / USDe
    uint256 public constant VAULT_WSTETH_USDE_ID = 70; // T1: wstETH / USDe
    uint256 public constant VAULT_WEETH_USDE_ID = 71; // T1: weETH / USDe
    uint256 public constant VAULT_WBTC_USDE_ID = 72; // T1: WBTC / USDe
    uint256 public constant VAULT_CBBTC_USDE_ID = 73; // T1: cbBTC / USDe

    // --- Action 10 ---
    uint256 public constant DEX_USDC_ETH_ID = 5; // Nov 2024 test DEX, never launched
    uint256 public constant VAULT_T4_DEX5_ID = 62; // T4 smart col / smart debt on dex 5

    // --- Action 11 ---
    uint256 public constant DEX_WSTUSR_USDC_ID = 27;

    // --- Action 12 ---
    uint256 public constant VAULT_EBTC_CBBTC_ID = 95; // T1: eBTC / cbBTC
    uint256 public constant VAULT_PST_USDC_ID = 167; // T2: PST-USDC (dex 45) / USDC
    uint256 public constant DEX_PST_USDC_ID = 45;

    // --- Action 13 ---
    uint256 public constant VAULT_OSETH_USDC_ID = 153; // T1: osETH / USDC
    uint256 public constant VAULT_OSETH_USDT_ID = 154; // T1: osETH / USDT
    uint256 public constant VAULT_OSETH_GHO_ID = 155; // T1: osETH / GHO
    uint256 public constant VAULT_OSETH_USDC_USDT_ID = 156; // T3: osETH / USDC-USDT debt
    uint256 public constant VAULT_OSETH_USDC_USDT_CONC_ID = 157; // T3: osETH / USDC-USDT debt (concentrated)
    uint256 public constant VAULT_ETH_OSETH_WSTETH_ID = 159; // T2: ETH-osETH / wstETH
    /// @dev VaultT1OracleV2_OSETH_USDC (DeployerFactory nonce 383)
    address public constant ORACLE_OSETH_USDC =
        0x0Bc3DA8C4Aa67E86B7A1c20e8b72049105571Ea9;
    /// @dev VaultT1OracleV2_OSETH_USDT (DeployerFactory nonce 384)
    address public constant ORACLE_OSETH_USDT =
        0x5c7eF1F1901a201A6bAd703D6588CF8FfC6a05F6;
    /// @dev VaultT1OracleV2_OSETH_GHO (DeployerFactory nonce 385)
    address public constant ORACLE_OSETH_GHO =
        0xfa18A2ea5Bf97C2F9D8a5680ecdA494256376Fd9;

    function execute() public virtual override {
        super.execute();

        // Action 1: Fully restrict the dexV1 test DEX at the Liquidity Layer.
        action1();

        // Action 2: Rebalance vault 3 (wstETH/ETH) and restore its dust limit.
        action2();

        // Action 3: Raise weETH/ETH vault (182) to launch limits.
        action3();

        // Action 4: Reduce Team Multisig wstETH & cbBTC borrow limits to dust.
        action4();

        // Action 5: iETHv2 DSA exits its residual test positions (must run before 6 and 7).
        action5();

        // Action 6: Fully restrict IGP-45 test dex id1 and dex id3 at the Liquidity Layer.
        action6();

        // Action 7: Restrict + pause old pre-launch vaults and old dex id1 / id3 at the Liquidity Layer.
        action7();

        // Action 8: Restrict + pause old dex id2 (USDC/USDT) and T3 vaults 35-40 at the Liquidity Layer.
        action8();

        // Action 9: Restrict + pause the hidden USDe vaults 66-73 at the Liquidity Layer.
        action9();

        // Action 10: Close the dex 5 (USDC-ETH) test market and its T4 vault 62.
        action10();

        // Action 11: Cap dex 27 (wstUSR-USDC) supply shares.
        action11();

        // Action 12: Restrict + pause the dust-launch vaults 95 (eBTC/cbBTC) and 167 (PST-USDC / USDC).
        action12();

        // Action 13: Move the osETH vaults 153-157 and 159 to OracleV2 oracles.
        action13();
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

    /// @notice Action 1: Fully restrict the dexV1 test DEX
    ///         (0x6d83...e03a, wstETH/ETH) at the Liquidity Layer.
    ///         - borrow: dust debt ceiling (10 / 20) for wstETH and ETH
    ///         - supply: dust base withdrawal limit (10) for wstETH and ETH
    ///         - current withdrawal limit set to the full user supply for
    ///           both tokens (updateUserWithdrawalLimit with a limit above
    ///           supply), so the residual cannot be withdrawn even once.
    ///         Without the last step the first operation after the supply
    ///         restriction could still withdraw the full residual.
    function action1() internal isActionSkippable(1) {
        setBorrowProtocolLimitsPaused(DEX_V1_TEST, wstETH_ADDRESS);
        setBorrowProtocolLimitsPaused(DEX_V1_TEST, ETH_ADDRESS);

        setSupplyProtocolLimitsPaused(DEX_V1_TEST, wstETH_ADDRESS);
        setSupplyProtocolLimitsPaused(DEX_V1_TEST, ETH_ADDRESS);

        IFluidLiquidityWithdrawalLimit(address(LIQUIDITY))
            .updateUserWithdrawalLimit(
                DEX_V1_TEST,
                wstETH_ADDRESS,
                type(uint256).max
            );
        IFluidLiquidityWithdrawalLimit(address(LIQUIDITY))
            .updateUserWithdrawalLimit(
                DEX_V1_TEST,
                ETH_ADDRESS,
                type(uint256).max
            );
    }

    /// @notice Action 2: Rebalance vault 3 (wstETH/ETH).
    ///         1. Raise the vault's ETH borrow limit at the Liquidity Layer
    ///            from dust to ~1 ETH.
    ///         2. Allow-list the Timelock as Reserve rebalancer, call
    ///            rebalanceVaults([vault 3]), remove the Timelock again.
    ///            The borrow drift (~0.0049 ETH) is borrowed to the Reserve.
    ///         3. Restore the dust ETH borrow limit (10 / 20).
    ///         The supply-side drift (~136 wei wstETH) is below Liquidity
    ///         Layer storage precision (UserModule__OperateAmountInsufficient),
    ///         so the vault's try/catch skips it; no Reserve allowance needed.
    function action2() internal isActionSkippable(2) {
        address vault_ = getVaultAddress(VAULT_WSTETH_ETH_ID);

        // Step 1: temporary borrow limit.
        {
            FluidLiquidityAdminStructs.UserBorrowConfig[]
                memory configs_ = new FluidLiquidityAdminStructs.UserBorrowConfig[](
                    1
                );
            configs_[0] = FluidLiquidityAdminStructs.UserBorrowConfig({
                user: vault_,
                token: ETH_ADDRESS,
                mode: 1,
                expandPercent: 1, // 0.01%
                expandDuration: 16777215, // max time
                baseDebtCeiling: VAULT_3_TEMP_BORROW_LIMIT_RAW,
                maxDebtCeiling: VAULT_3_TEMP_BORROW_LIMIT_RAW
            });
            LIQUIDITY.updateUserBorrowConfigs(configs_);
        }

        // Step 2: rebalance through the Reserve (vault 3's rebalancer).
        FLUID_RESERVE.updateRebalancer(address(TIMELOCK), true);
        {
            address[] memory protocols_ = new address[](1);
            uint256[] memory values_ = new uint256[](1);

            protocols_[0] = vault_;
            values_[0] = 0;

            FLUID_RESERVE.rebalanceVaults(protocols_, values_);
        }
        FLUID_RESERVE.updateRebalancer(address(TIMELOCK), false);

        // Step 3: restore the dust borrow limit.
        setBorrowProtocolLimitsPaused(vault_, ETH_ADDRESS);
    }

    /// @notice Action 3: Raise the weETH/ETH T1 vault (182) from IGP-140
    ///         dust limits to launch limits:
    ///         base withdrawal $8M, base borrow $15M, max borrow $30M,
    ///         standard T1 expansion (50% / 6h). Team Multisig vault auth
    ///         (granted in IGP-140) is unchanged.
    function action3() internal isActionSkippable(3) {
        VaultConfig memory VAULT_WEETH_ETH = VaultConfig({
            vault: getVaultAddress(VAULT_WEETH_ETH_ID),
            vaultType: VAULT_TYPE.TYPE_1,
            supplyToken: weETH_ADDRESS,
            borrowToken: ETH_ADDRESS,
            baseWithdrawalLimitInUSD: 8_000_000, // $8M
            baseBorrowLimitInUSD: 15_000_000, // $15M
            maxBorrowLimitInUSD: 30_000_000 // $30M
        });

        setVaultLimits(VAULT_WEETH_ETH);
    }

    /// @notice Action 4: Reduce the Team Multisig's wstETH & cbBTC borrow
    ///         limits on the Liquidity Layer to dust (base 10 / max 20 wei).
    /// @dev Same treatment as USDC & USDT in IGP-132 (action 2). The IGP-107
    ///      DEX Lite credit lines ($1M wstETH, $1M cbBTC) are unused (0 debt).
    ///      The AdminModule reverts `LimitZero` on a literal zero, so base 10 /
    ///      max 20 wei is the canonical dust limit. Mode 1 (with interest)
    ///      matches the existing config for both tokens, so no mode switch.
    function action4() internal isActionSkippable(4) {
        setBorrowProtocolLimitsPaused(TEAM_MULTISIG, wstETH_ADDRESS);
        setBorrowProtocolLimitsPaused(TEAM_MULTISIG, cbBTC_ADDRESS);
    }

    /// @notice Action 5: iETHv2's DSA exits its residual test positions
    ///         (old vault #3 NFT 18, vault 34 NFT 2296) before Actions 6
    ///         and 7 freeze them.
    /// @dev Only governance can move these: the DSA's auths are the iETHv2
    ///      vault and the Timelock, and iETHv2's spell() is proxy-admin
    ///      (Timelock) only. Cast directly on the DSA, like IGP-109 on
    ///      TREASURY.
    ///      - NFT 18: 0.01 wstETH, no debt, plain max withdraw. Frees the
    ///        wstETH for the vault 34 wstETH debt leg.
    ///      - NFT 2296: vault 34 books 4,000,002 more debt shares than dex
    ///        id1 records for it, so a max payback underflows. Repay the
    ///        4e15 dex-side shares explicitly (4,000,005 dust shares stay),
    ///        and keep 1e13 col shares (0.1%) behind that dust.
    ///      - The DSA holds no ETH; the Timelock sends 0.005 ETH with the
    ///        cast for the ETH leg (~0.00421 needed), unused ETH is refunded.
    ///        Payback caps 0.0045 wstETH / 0.005 ETH leave 30% / 19% headroom.
    ///      - try/catch: anyone can partially repay NFT 2296, which would
    ///        make the fixed share amount revert; that must not block the
    ///        rest of the IGP. Verify by DSA balances, not tx status.
    function action5() internal isActionSkippable(5) {
        string[] memory targets_ = new string[](2);
        bytes[] memory datas_ = new bytes[](2);

        // old vault #3 NFT 18: withdraw all 0.01 wstETH
        targets_[0] = "FLUID-A";
        datas_[0] = abi.encodeWithSignature(
            "operate(address,uint256,int256,int256,uint256)",
            OLD_VAULT_3_WSTETH_ETH,
            18,
            type(int256).min,
            int256(0),
            0
        );

        // vault 34 NFT 2296: repay the dex-side debt shares, withdraw all but 0.1% of the collateral
        targets_[1] = "FLUID-VAULT-T4-A";
        datas_[1] = abi.encodeWithSelector(
            bytes4(
                keccak256(
                    "operatePerfect((address,uint256,int256,int256,int256,int256,int256,int256,uint256,uint256[]))"
                )
            ),
            T4OperatePerfect({
                vaultAddress: VAULT_34_WSTETH_ETH_T4,
                nftId: 2296,
                perfectColShares: -9_990_000_000_000_000,
                colToken0MinMax: -1,
                colToken1MinMax: -1,
                perfectDebtShares: -4_000_000_000_000_000,
                debtToken0MinMax: -0.0045 ether,
                debtToken1MinMax: -0.005 ether,
                getNftId: 0,
                setIds: new uint256[](6)
            })
        );

        try
            IDSAV2(IETHV2_DSA).cast{value: 0.005 ether}(
                targets_,
                datas_,
                address(this)
            )
        {} catch {}
    }

    /// @notice Action 6: Fully restrict the IGP-45 test DEXes (old
    ///         DexFactory) at the Liquidity Layer, same pattern as Action 1:
    ///         - dex id1 wstETH/ETH (0x25F0...F901), tokens wstETH + ETH
    ///         - dex id3 WBTC/cbBTC (0x1d3e...204d), tokens WBTC + cbBTC
    ///         Borrow to dust (10 / 20), supply base withdrawal limit to dust
    ///         (10), and current withdrawal limit pinned to the full user
    ///         supply so the residual cannot be withdrawn even once.
    /// @dev Borrow side is already non-borrowable (limit below current
    ///      borrow) but still on the 20% / 12h expand config; this pins it.
    ///      id1 residual includes vault 34's dust position (NFT 2296, after
    ///      Action 5); id3 residual is the locked initial shares only.
    function action6() internal isActionSkippable(6) {
        _fullyRestrictDex(
            OLD_DEX_ID1_WSTETH_ETH,
            wstETH_ADDRESS,
            ETH_ADDRESS
        );
        _fullyRestrictDex(
            OLD_DEX_ID3_WBTC_CBBTC,
            WBTC_ADDRESS,
            cbBTC_ADDRESS
        );
    }

    /// @notice Action 7: Fully restrict and pause the remaining old
    ///         protocols at the Liquidity Layer.
    ///         - old VaultFactory vaults #1-#5: supply + borrow limits to
    ///           dust, withdrawal limit pinned to full supply, supply and
    ///           borrow paused at the Liquidity Layer.
    ///         - T2 vaults 42 / 43 (smart col on dex id3): Liquidity Layer
    ///           debt limits to dust and paused.
    ///         - dex id1 / dex id3 (limits already dusted in Action 6):
    ///           paused at the Liquidity Layer for supply and borrow, which
    ///           also freezes the vaults built on them (34, 41, 42, 43).
    /// @dev DEX-level configs of the old-factory dexes are not governed by
    ///      the Timelock (DexT1__NotAnAuth), so no DEX-level calls here.
    function action7() internal isActionSkippable(7) {
        // old VaultFactory vaults: (supply token, borrow token)
        _restrictAndPauseVault(OLD_VAULT_1_ETH_USDC, ETH_ADDRESS, USDC_ADDRESS);
        _restrictAndPauseVault(OLD_VAULT_2_ETH_USDT, ETH_ADDRESS, USDT_ADDRESS);
        _restrictAndPauseVault(OLD_VAULT_3_WSTETH_ETH, wstETH_ADDRESS, ETH_ADDRESS);
        _restrictAndPauseVault(OLD_VAULT_4_WSTETH_USDC, wstETH_ADDRESS, USDC_ADDRESS);
        _restrictAndPauseVault(OLD_VAULT_5_WSTETH_USDT, wstETH_ADDRESS, USDT_ADDRESS);

        // T2 vaults 42 / 43 (smart col on dex id3, debt at the Liquidity Layer)
        _restrictAndPauseBorrow(getVaultAddress(VAULT_42_ID), USDC_ADDRESS);
        _restrictAndPauseBorrow(getVaultAddress(VAULT_43_ID), USDT_ADDRESS);

        // dex id1 / id3: pause at the Liquidity Layer
        _pauseUserAtLiquidity(OLD_DEX_ID1_WSTETH_ETH, wstETH_ADDRESS, ETH_ADDRESS);
        _pauseUserAtLiquidity(OLD_DEX_ID3_WBTC_CBBTC, WBTC_ADDRESS, cbBTC_ADDRESS);
    }

    /// @notice Action 8: Restrict and pause the last IGP-45 test DEX, old
    ///         dex id2 (USDC/USDT), and the T3 vaults 35-40 built on it at
    ///         the Liquidity Layer.
    ///         - dex id2: borrow limits to dust and borrow paused (no
    ///           supply configs; its ~$227 init debt stays locked).
    ///         - vaults 35-40: 0 positions, 0 supply, but supply configs
    ///           still open (25% / 12h). Supply limits to dust and paused.
    /// @dev All seven configs are already mode 1, so the dust configs cause
    ///      no mode switch.
    function action8() internal isActionSkippable(8) {
        setBorrowProtocolLimitsPaused(OLD_DEX_ID2_USDC_USDT, USDC_ADDRESS);
        setBorrowProtocolLimitsPaused(OLD_DEX_ID2_USDC_USDT, USDT_ADDRESS);
        address[] memory borrowTokens_ = new address[](2);
        borrowTokens_[0] = USDC_ADDRESS;
        borrowTokens_[1] = USDT_ADDRESS;
        LIQUIDITY.pauseUser(
            OLD_DEX_ID2_USDC_USDT,
            new address[](0),
            borrowTokens_
        );

        _restrictAndPauseSupply(getVaultAddress(35), ETH_ADDRESS);
        _restrictAndPauseSupply(getVaultAddress(36), wstETH_ADDRESS);
        _restrictAndPauseSupply(getVaultAddress(37), weETH_ADDRESS);
        _restrictAndPauseSupply(getVaultAddress(38), WBTC_ADDRESS);
        _restrictAndPauseSupply(getVaultAddress(39), cbBTC_ADDRESS);
        _restrictAndPauseSupply(getVaultAddress(40), sUSDe_ADDRESS);
    }

    /// @notice Action 9: Restrict and pause the hidden USDe vaults at the
    ///         Liquidity Layer (dust positions only).
    ///         - vaults 66 / 67 / 68 (USDe -> USDC / USDT / GHO): borrow
    ///           limits to dust (max borrow was $53.5M / $53.3M / $21.6M).
    ///         - vaults 66-73: supply and borrow paused at the Liquidity
    ///           Layer. 69-73 (-> USDe) borrow limits are already dust.
    function action9() internal isActionSkippable(9) {
        address v66_ = getVaultAddress(VAULT_USDE_USDC_ID);
        address v67_ = getVaultAddress(VAULT_USDE_USDT_ID);
        address v68_ = getVaultAddress(VAULT_USDE_GHO_ID);

        setBorrowProtocolLimitsPaused(v66_, USDC_ADDRESS);
        setBorrowProtocolLimitsPaused(v67_, USDT_ADDRESS);
        setBorrowProtocolLimitsPaused(v68_, GHO_ADDRESS);

        _pauseVaultAtLiquidity(v66_, USDe_ADDRESS, USDC_ADDRESS);
        _pauseVaultAtLiquidity(v67_, USDe_ADDRESS, USDT_ADDRESS);
        _pauseVaultAtLiquidity(v68_, USDe_ADDRESS, GHO_ADDRESS);
        _pauseVaultAtLiquidity(getVaultAddress(VAULT_ETH_USDE_ID), ETH_ADDRESS, USDe_ADDRESS);
        _pauseVaultAtLiquidity(getVaultAddress(VAULT_WSTETH_USDE_ID), wstETH_ADDRESS, USDe_ADDRESS);
        _pauseVaultAtLiquidity(getVaultAddress(VAULT_WEETH_USDE_ID), weETH_ADDRESS, USDe_ADDRESS);
        _pauseVaultAtLiquidity(getVaultAddress(VAULT_WBTC_USDE_ID), WBTC_ADDRESS, USDe_ADDRESS);
        _pauseVaultAtLiquidity(getVaultAddress(VAULT_CBBTC_USDE_ID), cbBTC_ADDRESS, USDe_ADDRESS);
    }

    /// @notice Action 10: Close the dex 5 USDC-ETH test market (Nov 2024,
    ///         swaps and vault 62 paused since Dec 2024, never launched).
    ///         - vault 62 (T4) borrow at dex 5 to dust, then re-paused:
    ///           dex updateUserBorrowConfigs sets bit 0 (= unpaused), so the
    ///           live borrow pause must be re-applied. v62 supply at dex 5
    ///           is untouched and stays paused (pausing it again reverts).
    ///         - dex 5 max supply / borrow shares to 1.
    ///         dex 5 is already paused at the Liquidity Layer (USDC + ETH,
    ///         supply + borrow). Nothing here writes its LL config, and LL
    ///         config writes keep the pause bit anyway, so no LL pause call.
    function action10() internal isActionSkippable(10) {
        address dex_ = getDexAddress(DEX_USDC_ETH_ID);
        address v62_ = getVaultAddress(VAULT_T4_DEX5_ID);

        setBorrowProtocolLimitsPausedDex(dex_, v62_);
        IFluidDex(dex_).pauseUser(v62_, false, true);

        IFluidDex(dex_).updateMaxSupplyShares(1);
        IFluidDex(dex_).updateMaxBorrowShares(1);
    }

    /// @notice Action 11: Cap the hidden dex 27 (wstUSR-USDC) at 1 max supply
    ///         share, so no new deposits. Existing LPs can still withdraw.
    function action11() internal isActionSkippable(11) {
        IFluidDex(getDexAddress(DEX_WSTUSR_USDC_ID)).updateMaxSupplyShares(1);
    }

    /// @notice Action 12: Restrict and pause the mainnet dust-launch vaults
    ///         (1-3 positions each, tens of dollars of collateral).
    ///         - vault 95 (T1 eBTC / cbBTC): same treatment as the old vaults
    ///           in Action 7 (supply + borrow to dust, withdrawal limit
    ///           pinned, paused at the Liquidity Layer).
    ///         - vault 167 (T2 PST-USDC dex 45 / USDC): USDC borrow at the
    ///           Liquidity Layer to dust and paused; its smart-col supply at
    ///           dex 45 to dust and paused. Dex 45 itself is untouched.
    function action12() internal isActionSkippable(12) {
        _restrictAndPauseVault(
            getVaultAddress(VAULT_EBTC_CBBTC_ID),
            eBTC_ADDRESS,
            cbBTC_ADDRESS
        );

        address v167_ = getVaultAddress(VAULT_PST_USDC_ID);
        _restrictAndPauseBorrow(v167_, USDC_ADDRESS);

        address dex45_ = getDexAddress(DEX_PST_USDC_ID);
        setSupplyProtocolLimitsPausedDex(dex45_, v167_);
        IFluidDex(dex45_).pauseUser(v167_, true, false);
    }

    /// @notice Action 13: Move the osETH vaults to their OracleV2 oracles.
    /// @dev T1 vaults take the oracle address via `updateOracle(address)`;
    ///      T2/T3 vaults take the DeployerFactory nonce via
    ///      `updateOracle(uint256)`. Both probe the new oracle's
    ///      `getExchangeRateOperate()` / `getExchangeRateLiquidate()` before
    ///      committing.
    function action13() internal isActionSkippable(13) {
        // Vault 153 (T1): VaultT1OracleV2_OSETH_USDC
        IFluidVaultT1(getVaultAddress(VAULT_OSETH_USDC_ID)).updateOracle(
            ORACLE_OSETH_USDC
        );
        // Vault 154 (T1): VaultT1OracleV2_OSETH_USDT
        IFluidVaultT1(getVaultAddress(VAULT_OSETH_USDT_ID)).updateOracle(
            ORACLE_OSETH_USDT
        );
        // Vault 155 (T1): VaultT1OracleV2_OSETH_GHO
        IFluidVaultT1(getVaultAddress(VAULT_OSETH_GHO_ID)).updateOracle(
            ORACLE_OSETH_GHO
        );

        // Vault 156 (T3): VaultT3OracleV2_OSETH_USDC-USDT
        IFluidVault(getVaultAddress(VAULT_OSETH_USDC_USDT_ID)).updateOracle(
            386
        );
        // Vault 157 (T3): VaultT3OracleV2_OSETH_USDC-USDT-CONCENTRATED
        IFluidVault(getVaultAddress(VAULT_OSETH_USDC_USDT_CONC_ID))
            .updateOracle(387);
        // Vault 159 (T2): VaultT2OracleV2_ETH-OSETH_WSTETH
        IFluidVault(getVaultAddress(VAULT_ETH_OSETH_WSTETH_ID)).updateOracle(
            388
        );
    }

    function _pauseVaultAtLiquidity(
        address vault_,
        address supplyToken_,
        address borrowToken_
    ) internal {
        address[] memory supplyTokens_ = new address[](1);
        supplyTokens_[0] = supplyToken_;
        address[] memory borrowTokens_ = new address[](1);
        borrowTokens_[0] = borrowToken_;
        LIQUIDITY.pauseUser(vault_, supplyTokens_, borrowTokens_);
    }

    function _restrictAndPauseSupply(address user_, address token_) internal {
        setSupplyProtocolLimitsPaused(user_, token_);
        address[] memory supplyTokens_ = new address[](1);
        supplyTokens_[0] = token_;
        LIQUIDITY.pauseUser(user_, supplyTokens_, new address[](0));
    }

    function _restrictAndPauseVault(
        address vault_,
        address supplyToken_,
        address borrowToken_
    ) internal {
        setSupplyProtocolLimitsPaused(vault_, supplyToken_);
        setBorrowProtocolLimitsPaused(vault_, borrowToken_);
        IFluidLiquidityWithdrawalLimit(address(LIQUIDITY))
            .updateUserWithdrawalLimit(vault_, supplyToken_, type(uint256).max);

        address[] memory supplyTokens_ = new address[](1);
        supplyTokens_[0] = supplyToken_;
        address[] memory borrowTokens_ = new address[](1);
        borrowTokens_[0] = borrowToken_;
        LIQUIDITY.pauseUser(vault_, supplyTokens_, borrowTokens_);
    }

    function _restrictAndPauseBorrow(address user_, address token_) internal {
        setBorrowProtocolLimitsPaused(user_, token_);

        address[] memory supplyTokens_ = new address[](0);
        address[] memory borrowTokens_ = new address[](1);
        borrowTokens_[0] = token_;
        LIQUIDITY.pauseUser(user_, supplyTokens_, borrowTokens_);
    }

    function _pauseUserAtLiquidity(
        address user_,
        address token0_,
        address token1_
    ) internal {
        address[] memory tokens_ = new address[](2);
        tokens_[0] = token0_;
        tokens_[1] = token1_;
        LIQUIDITY.pauseUser(user_, tokens_, tokens_);
    }

    function _fullyRestrictDex(
        address dex_,
        address token0_,
        address token1_
    ) internal {
        setBorrowProtocolLimitsPaused(dex_, token0_);
        setBorrowProtocolLimitsPaused(dex_, token1_);

        setSupplyProtocolLimitsPaused(dex_, token0_);
        setSupplyProtocolLimitsPaused(dex_, token1_);

        IFluidLiquidityWithdrawalLimit(address(LIQUIDITY))
            .updateUserWithdrawalLimit(dex_, token0_, type(uint256).max);
        IFluidLiquidityWithdrawalLimit(address(LIQUIDITY))
            .updateUserWithdrawalLimit(dex_, token1_, type(uint256).max);
    }

    /**
     * |
     * |     Payload Actions End Here      |
     * |__________________________________
     */

    // --- BEGIN AUTO-GENERATED PRICES (scripts/verify/prepare-prices.ts) ---
    // fetched: 2026-10-25T10:53:13.845Z, source: coingecko
    function ETH_USD_PRICE()   public pure override returns (uint256) { return 2_320 * 1e2; }
    function weETH_USD_PRICE() public pure override returns (uint256) { return 2_570 * 1e2; }
    // --- END AUTO-GENERATED PRICES ---
}
