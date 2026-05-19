// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.21;
pragma experimental ABIEncoderV2;

import {IERC20} from "../common/interfaces/IERC20.sol";
import {PayloadIGPPriceHelpers} from "../common/pricehelpers.sol";

/// @notice IGP130: (1) Collect Liquidity Layer revenue into the Reserve
///         Contract and forward to Team Multisig to cover Fluid Lite ETH
///         (iETHv2) user losses; (2) Set dust limits + Team Multisig auth on
///         the new PST ecosystem (PST-USDC DEX + five PST vaults).
contract PayloadIGP130 is PayloadIGPPriceHelpers {
    uint256 public constant PROPOSAL_ID = 130;

    // --- PST ecosystem placeholders (TODO: fill before submission) -----
    // PST-USDC DEX id used by vaults 3 and 5 below for smart collateral.
    uint256 public constant PST_USDC_DEX_ID = 0;

    // Vault ids for the five PST vaults.
    uint256 public constant VAULT_PST_USDC_ID = 0;            // T1: PST / USDC
    uint256 public constant VAULT_PST_USDT_ID = 0;            // T1: PST / USDT
    uint256 public constant VAULT_PST_USDC__USDC_ID = 0;      // T2: PST-USDC / USDC
    uint256 public constant VAULT_PST__USDC_USDT_ID = 0;      // T3: PST / USDC-USDT
    uint256 public constant VAULT_PST_USDC__USDC_USDT_ID = 0; // T4: PST-USDC / USDC-USDT

    function execute() public virtual override {
        super.execute();

        // Action 1: Collect Liquidity Layer revenue across 22 tokens into the Reserve Contract and forward to Team Multisig.
        action1();

        // Action 2: Dust limits + Team Multisig auth for the new PST ecosystem (PST-USDC DEX, plus five PST vaults).
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

    /// @notice Action 1: Collect Liquidity Layer revenue across 22 tokens into
    ///         the Reserve Contract and forward to Team Multisig
    function action1() internal isActionSkippable(1) {
        // Step 1: Build the 22-token revenue list
        address[] memory tokens_ = new address[](22);

        // Above $10k revenue
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

        // Below $10k revenue
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

        // Step 2: Collect accrued Liquidity Layer revenue for those tokens.

        LIQUIDITY.collectRevenue(tokens_);

        // Step 3: Forward balances of each token to Team Multisig
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

        FLUID_RESERVE.withdrawFunds(tokens_, amounts_, TEAM_MULTISIG);
    }

    /// @notice Action 2: Dust limits + Team MS auth for the PST ecosystem
    ///         (PST-USDC DEX + 5 PST vaults). Mirrors the dust-launch pattern
    ///         from IGP-121 (REUSD vaults / REUSD-USDT DEX).
    function action2() internal isActionSkippable(2) {
        // Guard: every TODO placeholder MUST be filled before submission.
        require(PST_ADDRESS != address(0), "PST_ADDRESS unset");
        require(PST_USDC_DEX_ID != 0, "PST_USDC_DEX_ID unset");
        require(VAULT_PST_USDC_ID != 0, "VAULT_PST_USDC_ID unset");
        require(VAULT_PST_USDT_ID != 0, "VAULT_PST_USDT_ID unset");
        require(VAULT_PST_USDC__USDC_ID != 0, "VAULT_PST_USDC__USDC_ID unset");
        require(
            VAULT_PST__USDC_USDT_ID != 0,
            "VAULT_PST__USDC_USDT_ID unset"
        );
        require(
            VAULT_PST_USDC__USDC_USDT_ID != 0,
            "VAULT_PST_USDC__USDC_USDT_ID unset"
        );

        address USDC_USDT_DEX = getDexAddress(2);

        // Vault 1: PST / USDC (TYPE_1)
        {
            address PST_USDC_VAULT = getVaultAddress(VAULT_PST_USDC_ID);
            VaultConfig memory VAULT_PST_USDC = VaultConfig({
                vault: PST_USDC_VAULT,
                vaultType: VAULT_TYPE.TYPE_1,
                supplyToken: PST_ADDRESS,
                borrowToken: USDC_ADDRESS,
                baseWithdrawalLimitInUSD: 7_000, // $7k
                baseBorrowLimitInUSD: 7_000, // $7k
                maxBorrowLimitInUSD: 9_000 // $9k
            });
            setVaultLimits(VAULT_PST_USDC);
            VAULT_FACTORY.setVaultAuth(PST_USDC_VAULT, TEAM_MULTISIG, true);
        }

        // Vault 2: PST / USDT (TYPE_1)
        {
            address PST_USDT_VAULT = getVaultAddress(VAULT_PST_USDT_ID);
            VaultConfig memory VAULT_PST_USDT = VaultConfig({
                vault: PST_USDT_VAULT,
                vaultType: VAULT_TYPE.TYPE_1,
                supplyToken: PST_ADDRESS,
                borrowToken: USDT_ADDRESS,
                baseWithdrawalLimitInUSD: 7_000, // $7k
                baseBorrowLimitInUSD: 7_000, // $7k
                maxBorrowLimitInUSD: 9_000 // $9k
            });
            setVaultLimits(VAULT_PST_USDT);
            VAULT_FACTORY.setVaultAuth(PST_USDT_VAULT, TEAM_MULTISIG, true);
        }

        // Vault 3: PST-USDC / USDC (TYPE_2) - USDC debt at LL, smart col at DEX
        {
            address PST_USDC__USDC_VAULT = getVaultAddress(
                VAULT_PST_USDC__USDC_ID
            );
            VaultConfig memory VAULT_PST_USDC__USDC = VaultConfig({
                vault: PST_USDC__USDC_VAULT,
                vaultType: VAULT_TYPE.TYPE_2,
                supplyToken: address(0),
                borrowToken: USDC_ADDRESS,
                baseWithdrawalLimitInUSD: 0,
                baseBorrowLimitInUSD: 7_000, // $7k
                maxBorrowLimitInUSD: 9_000 // $9k
            });
            setVaultLimits(VAULT_PST_USDC__USDC);
            VAULT_FACTORY.setVaultAuth(
                PST_USDC__USDC_VAULT,
                TEAM_MULTISIG,
                true
            );
        }

        // Vault 4: PST / USDC-USDT (TYPE_3) - smart debt at USDC-USDT DEX (id 2)
        {
            address PST__USDC_USDT_VAULT = getVaultAddress(
                VAULT_PST__USDC_USDT_ID
            );
            VaultConfig memory VAULT_PST__USDC_USDT = VaultConfig({
                vault: PST__USDC_USDT_VAULT,
                vaultType: VAULT_TYPE.TYPE_3,
                supplyToken: PST_ADDRESS,
                borrowToken: address(0),
                baseWithdrawalLimitInUSD: 7_000, // $7k
                baseBorrowLimitInUSD: 0,
                maxBorrowLimitInUSD: 0
            });
            setVaultLimits(VAULT_PST__USDC_USDT);
            VAULT_FACTORY.setVaultAuth(
                PST__USDC_USDT_VAULT,
                TEAM_MULTISIG,
                true
            );

            DexBorrowProtocolConfigInShares
                memory config_ = DexBorrowProtocolConfigInShares({
                    dex: USDC_USDT_DEX,
                    protocol: PST__USDC_USDT_VAULT,
                    expandPercent: 30 * 1e2, // 30%
                    expandDuration: 6 hours,
                    baseBorrowLimit: 3500 * 1e18, // ~$7k shares
                    maxBorrowLimit: 4500 * 1e18 // ~$9k shares
                });
            setDexBorrowProtocolLimitsInShares(config_);
        }

        // Vault 5: PST-USDC / USDC-USDT (TYPE_4) - smart col at PST-USDC DEX, smart debt at USDC-USDT DEX
        {
            address PST_USDC__USDC_USDT_VAULT = getVaultAddress(
                VAULT_PST_USDC__USDC_USDT_ID
            );

            VAULT_FACTORY.setVaultAuth(
                PST_USDC__USDC_USDT_VAULT,
                TEAM_MULTISIG,
                true
            );

            DexBorrowProtocolConfigInShares
                memory config_ = DexBorrowProtocolConfigInShares({
                    dex: USDC_USDT_DEX,
                    protocol: PST_USDC__USDC_USDT_VAULT,
                    expandPercent: 30 * 1e2, // 30%
                    expandDuration: 6 hours,
                    baseBorrowLimit: 3500 * 1e18, // ~$7k shares
                    maxBorrowLimit: 4500 * 1e18 // ~$9k shares
                });
            setDexBorrowProtocolLimitsInShares(config_);
        }

        // PST-USDC DEX: smart-col dust limits + Team MS auth
        {
            address PST_USDC_DEX = getDexAddress(PST_USDC_DEX_ID);
            DexConfig memory DEX_PST_USDC = DexConfig({
                dex: PST_USDC_DEX,
                tokenA: PST_ADDRESS,
                tokenB: USDC_ADDRESS,
                smartCollateral: true,
                smartDebt: false,
                baseWithdrawalLimitInUSD: 10_000, // $10k
                baseBorrowLimitInUSD: 0,
                maxBorrowLimitInUSD: 0
            });
            setDexLimits(DEX_PST_USDC);
            DEX_FACTORY.setDexAuth(PST_USDC_DEX, TEAM_MULTISIG, true);
        }
    }

    /**
     * |
     * |     Payload Actions End Here      |
     * |__________________________________
     */

    // Manual PST price override — PST is not yet in tokens.ts (no mainnet
    // address / CoinGecko entry yet). Once the address is finalized, register
    // PST in scripts/verify/lib/tokens.ts and let prepare-prices.ts manage
    // this override from the auto-generated block below.
    function PST_USD_PRICE() public pure override returns (uint256) {
        return 1.10 * 1e2; // $1.10
    }

    // --- BEGIN AUTO-GENERATED PRICES (scripts/verify/prepare-prices.ts) ---
    // --- END AUTO-GENERATED PRICES ---
}
