// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.21;
pragma experimental ABIEncoderV2;

import {PayloadIGPPriceHelpers} from "../common/pricehelpers.sol";
import {IFluidVaultFactory} from "../common/interfaces/IFluidVaultFactory.sol";

/// @notice IGP133: Launch the USDai ecosystem on Ethereum at dust limits.
///         Sets conservative "dust" supply / borrow limits and grants Team
///         Multisig auth on the three USDai DEXes (ids 46–48) and the nine
///         USDai / sUSDai vaults (ids 171–179), so each market is live but
///         effectively capped near zero until launch limits ship in a later
///         proposal. DEX and vault ids are verified against the live Fluid
///         factories on mainnet.
contract PayloadIGP133 is PayloadIGPPriceHelpers {
    uint256 public constant PROPOSAL_ID = 133;

    // --- USDai ecosystem DEX ids (verified on-chain) ---
    uint256 public constant SUSDAI_USDC_DEX_ID = 46; // sUSDai / USDC
    uint256 public constant USDAI_USDC_DEX_ID = 47; // USDai / USDC
    uint256 public constant SUSDAI_USDT_DEX_ID = 48; // sUSDai / USDT

    // --- USDai ecosystem vault ids (verified on-chain) ---
    uint256 public constant VAULT_SUSDAI_USDC_ID = 171; // T1: sUSDai / USDC
    uint256 public constant VAULT_SUSDAI_USDT_ID = 172; // T1: sUSDai / USDT
    uint256 public constant VAULT_SUSDAI__USDC_USDT_ID = 173; // T3: sUSDai / USDC-USDT
    uint256 public constant VAULT_USDAI_USDC_ID = 174; // T1: USDai / USDC
    uint256 public constant VAULT_SUSDAI_USDC__USDC_USDT_ID = 175; // T4: sUSDai-USDC / USDC-USDT
    uint256 public constant VAULT_SUSDAI_USDT__USDC_USDT_ID = 176; // T4: sUSDai-USDT / USDC-USDT
    uint256 public constant VAULT_SUSDAI_USDT__USDT_ID = 177; // T2: sUSDai-USDT / USDT
    uint256 public constant VAULT_SUSDAI_USDC__USDC_ID = 178; // T2: sUSDai-USDC / USDC
    uint256 public constant VAULT_SUSDAI_GHO_ID = 179; // T1: sUSDai / GHO

    // VaultFactory is owned by the VaultFactoryOwner wrapper, so vault auth
    // must be routed through it: governance (the timelock) is authorized on
    // the wrapper, not directly on the factory.
    IFluidVaultFactory public constant VAULT_FACTORY_WRAPPER_OWNER =
        IFluidVaultFactory(0xB031913cB7AD81b8A4Ba412B471c2dA69BEA410B);

    function execute() public virtual override {
        super.execute();

        // Action 1: USDai ecosystem dust limits (DEXes 46–48, vaults 171–179)
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

    /// @notice Action 1: Dust limits + Team Multisig auth for the USDai ecosystem
    ///         (DEXes 46–48, vaults 171–179). All collateral/debt ceilings are
    ///         set to dust ($10k per DEX token; $7k/$7k/$9k withdraw/base/max
    ///         per vault) so the markets are live but effectively capped near
    ///         zero until launch limits ship.
    function action1() internal isActionSkippable(1) {
        address USDC_USDT_DEX = getDexAddress(2);

        // DEX 46: sUSDai-USDC
        {
            address SUSDAI_USDC_DEX = getDexAddress(SUSDAI_USDC_DEX_ID);
            DexConfig memory DEX_SUSDAI_USDC = DexConfig({
                dex: SUSDAI_USDC_DEX,
                tokenA: SUSDAI_ADDRESS,
                tokenB: USDC_ADDRESS,
                smartCollateral: true,
                smartDebt: false,
                baseWithdrawalLimitInUSD: 10_000, // $10k
                baseBorrowLimitInUSD: 0,
                maxBorrowLimitInUSD: 0
            });
            setDexLimits(DEX_SUSDAI_USDC);
            DEX_FACTORY.setDexAuth(SUSDAI_USDC_DEX, TEAM_MULTISIG, true);
        }

        // DEX 47: USDai-USDC
        {
            address USDAI_USDC_DEX = getDexAddress(USDAI_USDC_DEX_ID);
            DexConfig memory DEX_USDAI_USDC = DexConfig({
                dex: USDAI_USDC_DEX,
                tokenA: USDAI_ADDRESS,
                tokenB: USDC_ADDRESS,
                smartCollateral: true,
                smartDebt: false,
                baseWithdrawalLimitInUSD: 10_000, // $10k
                baseBorrowLimitInUSD: 0,
                maxBorrowLimitInUSD: 0
            });
            setDexLimits(DEX_USDAI_USDC);
            DEX_FACTORY.setDexAuth(USDAI_USDC_DEX, TEAM_MULTISIG, true);
        }

        // DEX 48: sUSDai-USDT
        {
            address SUSDAI_USDT_DEX = getDexAddress(SUSDAI_USDT_DEX_ID);
            DexConfig memory DEX_SUSDAI_USDT = DexConfig({
                dex: SUSDAI_USDT_DEX,
                tokenA: SUSDAI_ADDRESS,
                tokenB: USDT_ADDRESS,
                smartCollateral: true,
                smartDebt: false,
                baseWithdrawalLimitInUSD: 10_000, // $10k
                baseBorrowLimitInUSD: 0,
                maxBorrowLimitInUSD: 0
            });
            setDexLimits(DEX_SUSDAI_USDT);
            DEX_FACTORY.setDexAuth(SUSDAI_USDT_DEX, TEAM_MULTISIG, true);
        }

        // Vault 171: sUSDai / USDC (TYPE_1)
        {
            address SUSDAI_USDC_VAULT = getVaultAddress(VAULT_SUSDAI_USDC_ID);
            VaultConfig memory VAULT_SUSDAI_USDC = VaultConfig({
                vault: SUSDAI_USDC_VAULT,
                vaultType: VAULT_TYPE.TYPE_1,
                supplyToken: SUSDAI_ADDRESS,
                borrowToken: USDC_ADDRESS,
                baseWithdrawalLimitInUSD: 7_000, // $7k
                baseBorrowLimitInUSD: 7_000, // $7k
                maxBorrowLimitInUSD: 9_000 // $9k
            });
            setVaultLimits(VAULT_SUSDAI_USDC);
            VAULT_FACTORY_WRAPPER_OWNER.setVaultAuth(
                SUSDAI_USDC_VAULT,
                TEAM_MULTISIG,
                true
            );
        }

        // Vault 172: sUSDai / USDT (TYPE_1)
        {
            address SUSDAI_USDT_VAULT = getVaultAddress(VAULT_SUSDAI_USDT_ID);
            VaultConfig memory VAULT_SUSDAI_USDT = VaultConfig({
                vault: SUSDAI_USDT_VAULT,
                vaultType: VAULT_TYPE.TYPE_1,
                supplyToken: SUSDAI_ADDRESS,
                borrowToken: USDT_ADDRESS,
                baseWithdrawalLimitInUSD: 7_000, // $7k
                baseBorrowLimitInUSD: 7_000, // $7k
                maxBorrowLimitInUSD: 9_000 // $9k
            });
            setVaultLimits(VAULT_SUSDAI_USDT);
            VAULT_FACTORY_WRAPPER_OWNER.setVaultAuth(
                SUSDAI_USDT_VAULT,
                TEAM_MULTISIG,
                true
            );
        }

        // Vault 173: sUSDai / USDC-USDT (TYPE_3)
        {
            address SUSDAI__USDC_USDT_VAULT = getVaultAddress(
                VAULT_SUSDAI__USDC_USDT_ID
            );
            VaultConfig memory VAULT_SUSDAI__USDC_USDT = VaultConfig({
                vault: SUSDAI__USDC_USDT_VAULT,
                vaultType: VAULT_TYPE.TYPE_3,
                supplyToken: SUSDAI_ADDRESS,
                borrowToken: address(0),
                baseWithdrawalLimitInUSD: 7_000, // $7k
                baseBorrowLimitInUSD: 0,
                maxBorrowLimitInUSD: 0
            });
            setVaultLimits(VAULT_SUSDAI__USDC_USDT);
            VAULT_FACTORY_WRAPPER_OWNER.setVaultAuth(
                SUSDAI__USDC_USDT_VAULT,
                TEAM_MULTISIG,
                true
            );

            DexBorrowProtocolConfigInShares
                memory config_ = DexBorrowProtocolConfigInShares({
                    dex: USDC_USDT_DEX,
                    protocol: SUSDAI__USDC_USDT_VAULT,
                    expandPercent: 30 * 1e2, // 30%
                    expandDuration: 6 hours,
                    baseBorrowLimit: 3500 * 1e18, // ~$7k shares
                    maxBorrowLimit: 4500 * 1e18 // ~$9k shares
                });
            setDexBorrowProtocolLimitsInShares(config_);
        }

        // Vault 174: USDai / USDC (TYPE_1)
        {
            address USDAI_USDC_VAULT = getVaultAddress(VAULT_USDAI_USDC_ID);
            VaultConfig memory VAULT_USDAI_USDC = VaultConfig({
                vault: USDAI_USDC_VAULT,
                vaultType: VAULT_TYPE.TYPE_1,
                supplyToken: USDAI_ADDRESS,
                borrowToken: USDC_ADDRESS,
                baseWithdrawalLimitInUSD: 7_000, // $7k
                baseBorrowLimitInUSD: 7_000, // $7k
                maxBorrowLimitInUSD: 9_000 // $9k
            });
            setVaultLimits(VAULT_USDAI_USDC);
            VAULT_FACTORY_WRAPPER_OWNER.setVaultAuth(
                USDAI_USDC_VAULT,
                TEAM_MULTISIG,
                true
            );
        }

        // Vault 175: sUSDai-USDC / USDC-USDT (TYPE_4) — collateral at DEX 46
        {
            address SUSDAI_USDC__USDC_USDT_VAULT = getVaultAddress(
                VAULT_SUSDAI_USDC__USDC_USDT_ID
            );
            VAULT_FACTORY_WRAPPER_OWNER.setVaultAuth(
                SUSDAI_USDC__USDC_USDT_VAULT,
                TEAM_MULTISIG,
                true
            );

            DexBorrowProtocolConfigInShares
                memory config_ = DexBorrowProtocolConfigInShares({
                    dex: USDC_USDT_DEX,
                    protocol: SUSDAI_USDC__USDC_USDT_VAULT,
                    expandPercent: 30 * 1e2, // 30%
                    expandDuration: 6 hours,
                    baseBorrowLimit: 3500 * 1e18, // ~$7k shares
                    maxBorrowLimit: 4500 * 1e18 // ~$9k shares
                });
            setDexBorrowProtocolLimitsInShares(config_);
        }

        // Vault 176: sUSDai-USDT / USDC-USDT (TYPE_4) — collateral at DEX 48
        {
            address SUSDAI_USDT__USDC_USDT_VAULT = getVaultAddress(
                VAULT_SUSDAI_USDT__USDC_USDT_ID
            );
            VAULT_FACTORY_WRAPPER_OWNER.setVaultAuth(
                SUSDAI_USDT__USDC_USDT_VAULT,
                TEAM_MULTISIG,
                true
            );

            DexBorrowProtocolConfigInShares
                memory config_ = DexBorrowProtocolConfigInShares({
                    dex: USDC_USDT_DEX,
                    protocol: SUSDAI_USDT__USDC_USDT_VAULT,
                    expandPercent: 30 * 1e2, // 30%
                    expandDuration: 6 hours,
                    baseBorrowLimit: 3500 * 1e18, // ~$7k shares
                    maxBorrowLimit: 4500 * 1e18 // ~$9k shares
                });
            setDexBorrowProtocolLimitsInShares(config_);
        }

        // Vault 177: sUSDai-USDT / USDT (TYPE_2) — collateral at DEX 48
        {
            address SUSDAI_USDT__USDT_VAULT = getVaultAddress(
                VAULT_SUSDAI_USDT__USDT_ID
            );
            VaultConfig memory VAULT_SUSDAI_USDT__USDT = VaultConfig({
                vault: SUSDAI_USDT__USDT_VAULT,
                vaultType: VAULT_TYPE.TYPE_2,
                supplyToken: address(0),
                borrowToken: USDT_ADDRESS,
                baseWithdrawalLimitInUSD: 0,
                baseBorrowLimitInUSD: 7_000, // $7k
                maxBorrowLimitInUSD: 9_000 // $9k
            });
            setVaultLimits(VAULT_SUSDAI_USDT__USDT);
            VAULT_FACTORY_WRAPPER_OWNER.setVaultAuth(
                SUSDAI_USDT__USDT_VAULT,
                TEAM_MULTISIG,
                true
            );
        }

        // Vault 178: sUSDai-USDC / USDC (TYPE_2) — collateral at DEX 46
        {
            address SUSDAI_USDC__USDC_VAULT = getVaultAddress(
                VAULT_SUSDAI_USDC__USDC_ID
            );
            VaultConfig memory VAULT_SUSDAI_USDC__USDC = VaultConfig({
                vault: SUSDAI_USDC__USDC_VAULT,
                vaultType: VAULT_TYPE.TYPE_2,
                supplyToken: address(0),
                borrowToken: USDC_ADDRESS,
                baseWithdrawalLimitInUSD: 0,
                baseBorrowLimitInUSD: 7_000, // $7k
                maxBorrowLimitInUSD: 9_000 // $9k
            });
            setVaultLimits(VAULT_SUSDAI_USDC__USDC);
            VAULT_FACTORY_WRAPPER_OWNER.setVaultAuth(
                SUSDAI_USDC__USDC_VAULT,
                TEAM_MULTISIG,
                true
            );
        }

        // Vault 179: sUSDai / GHO (TYPE_1)
        {
            address SUSDAI_GHO_VAULT = getVaultAddress(VAULT_SUSDAI_GHO_ID);
            VaultConfig memory VAULT_SUSDAI_GHO = VaultConfig({
                vault: SUSDAI_GHO_VAULT,
                vaultType: VAULT_TYPE.TYPE_1,
                supplyToken: SUSDAI_ADDRESS,
                borrowToken: GHO_ADDRESS,
                baseWithdrawalLimitInUSD: 7_000, // $7k
                baseBorrowLimitInUSD: 7_000, // $7k
                maxBorrowLimitInUSD: 9_000 // $9k
            });
            setVaultLimits(VAULT_SUSDAI_GHO);
            VAULT_FACTORY_WRAPPER_OWNER.setVaultAuth(
                SUSDAI_GHO_VAULT,
                TEAM_MULTISIG,
                true
            );
        }
    }

    /**
     * |
     * |     Payload Actions End Here      |
     * |__________________________________
     */

    // --- BEGIN AUTO-GENERATED PRICES (scripts/verify/prepare-prices.ts) ---
    // fetched: 2026-05-30T11:25:35.114Z, source: coingecko
    function SUSDAI_USD_PRICE() public pure override returns (uint256) { return 1.09 * 1e2; }
    function STABLE_USD_PRICE() public pure override returns (uint256) { return 1 * 1e2; }
    // --- END AUTO-GENERATED PRICES ---
}
