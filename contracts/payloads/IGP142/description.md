# Launch the weETH/ETH Vault, Upgrade osETH Vaults to OracleV2, and Close Down Legacy and Unused Markets

## Summary

This proposal fully restricts and pauses the early **dexV1 test DEX** (wstETH/ETH, `0x6d83...e03a`) at the Liquidity Layer so it can no longer withdraw or borrow, rebalances the **wstETH/ETH T1 vault (3)** borrow side that is stuck behind its dust borrow limit and then restricts and pauses it, freezing its 12 remaining small positions, raises the **weETH/ETH T1 vault (182)** from the IGP-140 dust limits to launch limits, reduces the **Team Multisig** wstETH and cbBTC borrow limits on the Liquidity Layer to dust and pauses them, withdraws **iETHv2**'s residual test positions before they are frozen, fully restricts the Liquidity Layer limits of the IGP-45 test DEXes **id1** (wstETH/ETH) and **id3** (WBTC/cbBTC), restricts and pauses at the Liquidity Layer the five **pre-launch vaults** of the old VaultFactory, the two old DEXes, and the debt of vaults **42 / 43**, restricts and pauses the last IGP-45 test DEX **id2** (USDC/USDT) and the six empty T3 vaults **35-40** built on it, restricts and pauses the **USDe vaults 66-73** and the dust-launch vaults **95 / 167**, closes the **dex 5** test market and its vault 62, and caps **dex 27** supply shares. It also moves the **osETH vaults** (153-157, 159) from V1 oracles to OracleV2 oracles; the RedStone osETH/ETH feed behind the V1 oracles currently reverts as stale.

## Code Changes

### Action 1: Fully Restrict and Pause the dexV1 Test DEX at the Liquidity Layer

- **DEX**: `0x6d83f60eEac0e50A1250760151E81Db2a278e03a` (wstETH / ETH, early dexV1 test deployment, not deployed by the DexFactory)
- **Tokens**: wstETH (`0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0`), ETH (`0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE`)

| Step | Call | Effect |
| --- | --- | --- |
| Borrow | `setBorrowProtocolLimitsPaused` for wstETH and ETH | Debt ceiling `10 / 20` (dust), expansion 0.01% over max duration |
| Supply | `setSupplyProtocolLimitsPaused` for wstETH and ETH | Base withdrawal limit `10` (dust), expansion 0.01% over max duration |
| Pause | `LIQUIDITY.pauseUser(dex, [wstETH, ETH], [wstETH, ETH])` | Supply and borrow paused for both tokens |

### Action 2: Rebalance the wstETH/ETH T1 Vault (3), Then Restrict and Pause It

- **Vault**: `0xA0F83Fc5885cEBc0420ce7C7b139Adc80c4F4D91` (T1, wstETH collateral / ETH debt)
- **Rebalancer**: Reserve Contract (`0x264786EF916af64a1DB19F513F24a3681734ce92`)

The vault's own total borrow is **≈0.00493 ETH** above its borrow at the Liquidity Layer. `rebalance()` borrows that difference to the Reserve, but the vault's Liquidity Layer ETH borrow limit is at dust (`11 / 22`), so the borrow fails and the rebalancer skips it.

| Step | Call |
| --- | --- |
| 1 | Raise the vault's ETH debt ceiling at the Liquidity Layer to `1e18` raw (≈1 ETH; vault borrow ≈0.454 ETH) |
| 2 | `FLUID_RESERVE.updateRebalancer(TIMELOCK, true)`, `rebalanceVaults([vault 3], [0])`, `updateRebalancer(TIMELOCK, false)` |
| 3 | Restrict the vault to dust (wstETH supply, ETH borrow) via `setSupplyProtocolLimitsPaused` / `setBorrowProtocolLimitsPaused`, then `LIQUIDITY.pauseUser(vault, [wstETH], [ETH])` |

The supply-side difference (≈135 wei wstETH) is left as is: the Reserve has no wstETH allowance for the vault, so that leg fails inside the vault's `try/catch` and is skipped. The borrow-side rebalance is unaffected.

**Effect on existing positions.** Vault 3 still holds 12 small user positions across 7 owners, ≈0.64 wstETH collateral and ≈0.455 ETH debt in total (~$1.8k / ~$1.0k on 30 Oct 2026). Once the vault is paused at the Liquidity Layer, these positions can no longer deposit, withdraw, repay or be liquidated. Governance can unpause the vault in a later proposal if an owner needs to exit.

### Action 3: Launch Limits for the weETH/ETH T1 Vault (182)

- **Vault**: `getVaultAddress(182)` = `0x0b8a681eD46EA8ec6b97d686dF0631Fbf84B03D2` (T1, weETH collateral / ETH debt)

| Parameter | Current (IGP-140) | New |
| --- | --- | --- |
| Base withdrawal limit | ≈$7k | **$8M** |
| Base borrow limit | ≈$7k | **$15M** |
| Max borrow limit | ≈$9k | **$30M** |

- Set via `setVaultLimits` with the standard T1 expansion (50% over 6 hours).
- Risk parameters (CF 94% / LT 96% / LML 97% / LP 1%) were set by the Team Multisig. Team Multisig vault auth (granted in IGP-140) is unchanged.

### Action 4: Reduce Team Multisig wstETH & cbBTC Borrow Limits to Dust

- **User**: Team Multisig `0x4F6F977aCDD1177DCD81aB83074855EcB9C2D49e`
- **Tokens**: wstETH (`0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0`), cbBTC (`0xcbB7C0000aB88B473b1f5aFd9ef808440eed33Bf`), plus USDC and USDT

| Parameter | Current (IGP-107 DEX Lite credit) | New |
| --- | --- | --- |
| Base / max debt ceiling | ≈185.4 wstETH / ≈9.11 cbBTC (sized at $1M each in IGP-107; ~$518k / ~$701k on 30 Oct 2026) | **`10 / 20` wei** |
| Expansion | 1% over max duration | 0.01% over max duration |

- Calls `setBorrowProtocolLimitsPaused(TEAM_MULTISIG, token)` for wstETH and cbBTC, then `pauseUser` on the borrow side of both tokens. USDC and USDT, already at dust since IGP-132, get the same dust write and `pauseUser` on the borrow side.
- Both credit lines are unused (0 debt). Mode 1 (with interest) matches the existing config, so no mode switch is triggered.

### Action 5: Exit iETHv2's Residual Test Positions

- **DSA**: iETHv2 strategy DSA `0x9600A48ed0f931d0c422D574e3275a90D8b22745` (#36121). Its auths are the iETHv2 vault and the Timelock, so the Timelock casts on it directly.
- **Connectors**: `FLUID-A` (old vault #3) and `FLUID-VAULT-T4-A` (vault 34).

| Position | Holding | Call |
| --- | --- | --- |
| NFT 18, pre-launch vault #3 wstETH/ETH `0x28680f14C4Bb86B71119BC6e90E4e6D87E6D1f51` | 0.01 wstETH, no debt | `FLUID-A.operate`: withdraw all |
| NFT 2296, vault 34 wstETH/ETH T4 `0x57fed7c9b3c763999c519264931790cBcA331417` (on dex id1) | ≈0.0085 wstETH + 0.0104 ETH collateral, ≈0.0034 wstETH + 0.0042 ETH debt | `FLUID-VAULT-T4-A.operatePerfect`: repay `4e15` debt shares, withdraw all but 1e8 collateral shares |

- The Timelock sends **0.005 ETH** with the cast to cover the ETH leg of the vault 34 repayment; any unused ETH stays with iETHv2. The wstETH leg is covered by the 0.01 wstETH freed from NFT 18.
- Vault 34 books slightly more debt shares than dex id1 records for it, so a max payback reverts. The action repays the dex-side shares explicitly; a dust debt and 1e8 collateral shares (about 1e-8 of the position) stay and are frozen by Actions 6 and 7.
- The cast is wrapped in `try/catch`, so a third-party partial repayment of NFT 2296 cannot block the rest of the proposal.
- The withdrawn funds return to iETHv2.

This action must run before Actions 6 and 7, which freeze both positions.

### Action 6: Fully Restrict IGP-45 Test DEXes id1 and id3 at the Liquidity Layer

- **dex id1**: `0x25F0A3B25cBC0Ca0417770f686209628323fF901` (wstETH / ETH, old DexFactory), tokens wstETH + ETH
- **dex id3**: `0x1d3e52a11B98Ed2AAB7eB0Bfe1cbB6525233204d` (WBTC / cbBTC, old DexFactory), tokens WBTC (`0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599`) + cbBTC (`0xcbB7C0000aB88B473b1f5aFd9ef808440eed33Bf`)

Same two steps as Action 1 for each DEX and token: `setBorrowProtocolLimitsPaused` (debt ceiling `10 / 20`), `setSupplyProtocolLimitsPaused` (base withdrawal limit `10`).

| DEX | LL supply (30 Oct 2026) | Base withdrawal limit | Borrow side |
| --- | --- | --- | --- |
| id1 | 0.0185 wstETH + 0.0227 ETH (~$103) | 17.29 wstETH / 21.24 ETH (25% / 12h) | already non-borrowable (limit below borrow), 20% / 12h |
| id3 | 0.00202 WBTC + 0.00202 cbBTC (~$311) | 0.807 WBTC / 0.808 cbBTC (25% / 12h) | already non-borrowable (limit below borrow), 20% / 12h |

- **Residual stays locked.** id1: the only user is vault 34, whose single position (NFT 2296) is reduced to dust in Action 5; the rest is the locked initial shares. id3: no user holds shares (vaults 41/42/43 whitelisted, all at 0); the residual is the locked initial shares only.

### Action 7: Restrict and Pause Pre-Launch Vaults and Old DEXes at the Liquidity Layer

**Pre-launch vaults** (old VaultFactory `0x3B38099b79a143038a3935C619B2A3eA70438C60`, created Feb 2024, closed for new activity in IGP-24):

| Vault | Supply token | Borrow token |
| --- | --- | --- |
| `0x5eA9A2B42Bc9aC8CAC76E19F0Fcd5C1b06950807` (ETH/USDC) | ETH | USDC |
| `0xE53794f2ed0839F24170079A9F3c5368147F6c81` (ETH/USDT) | ETH | USDT |
| `0x28680f14C4Bb86B71119BC6e90E4e6D87E6D1f51` (wstETH/ETH) | wstETH | ETH |
| `0x460143a489729a3cA32DeA82fa48ea61175accbc` (wstETH/USDC) | wstETH | USDC |
| `0x2B251211f5Ff0A753A8d5B9411d736875174f375` (wstETH/USDT) | wstETH | USDT |

For each: `setSupplyProtocolLimitsPaused` (base withdrawal limit `10`), `setBorrowProtocolLimitsPaused` (debt ceiling `10 / 20`), then `LIQUIDITY.pauseUser(vault, [supplyToken], [borrowToken])`.

**Vaults 42 / 43** (T2, smart collateral on dex id3, debt at the Liquidity Layer): `setBorrowProtocolLimitsPaused` for USDC (42) / USDT (43), then `pauseUser` on the borrow side. Neither vault has open positions.

**dex id1 / dex id3** (limits already restricted in Action 6): `LIQUIDITY.pauseUser(dex, [token0, token1], [token0, token1])`. This also freezes the vaults built on them (34, 41, 42, 43).

DEX-level user configs of the old-factory DEXes are not governed by the Timelock, so this action only touches the Liquidity Layer.

### Action 8: Restrict and Pause IGP-45 Test DEX id2 and Vaults 35-40 at the Liquidity Layer

**dex id2** `0x085B07A30381F3Cc5A4250e10E4379d465b770ac` (USDC / USDT, old DexFactory): borrow of ≈113.9 USDC + 113.1 USDT (locked initial debt shares, borrowable 0) still on a 20% / 12h config; no supply configs. `setBorrowProtocolLimitsPaused` for USDC and USDT (debt ceiling `10 / 20`), then `pauseUser` on the borrow side.

**Vaults 35-40** (T3, collateral at the Liquidity Layer, smart debt on dex id2): 0 positions and 0 supply, but supply configs still open at 25% / 12h. For each: `setSupplyProtocolLimitsPaused` (base withdrawal limit `10`), then `pauseUser` on the supply side.

| Vault | Address | Supply token |
| --- | --- | --- |
| 35 | `0xB58634A962A579bD01c392451a718cB5d74DfB53` | ETH |
| 36 | `0xA9FF23CfF9439c418DA08CE7954a92E46311761e` | wstETH |
| 37 | `0xB9Bb0b2354884B4B9dBDDaeb01feEcf507695e33` | weETH |
| 38 | `0x2d38ca861aC948BF90cC682fC1455138173c1923` | WBTC |
| 39 | `0x5896d226882CEdd99eA30d25DbC5025B5706144b` | cbBTC |
| 40 | `0x274D1171F06E976a4f545E6d4bf017bEDC51F752` | sUSDe |

All seven configs are already mode 1 (with interest), so no mode switch is triggered.

### Action 9: Restrict and Pause the Hidden USDe Vaults 66-73 at the Liquidity Layer

Not shown in the app; dust positions only.

| Vault | Address | Supply token | Borrow token | Change |
| --- | --- | --- | --- | --- |
| 66 | `0xB98EeA7132f1De6EC24D4Ee4AfBDf4d63Ef1a9F0` | USDe | USDC | borrow to dust (max was ≈$53.5M) + pause |
| 67 | `0x8FB5c0896C70B0056A09249EcEF7E7Ee01f037AF` | USDe | USDT | borrow to dust (max was ≈$53.3M) + pause |
| 68 | `0x75580D4be33C61700969583fDAeC566Ca84e5B69` | USDe | GHO | borrow to dust (max was ≈$21.6M) + pause |
| 69 | `0x2f6c2A725EA6c4304cdC92B49F637a7735362EF5` | ETH | USDe | pause (borrow already dust) |
| 70 | `0x903c5704Df7BF307E27e9E3dE76EA295Bc1A2970` | wstETH | USDe | pause (borrow already dust) |
| 71 | `0xC752107aE8447D85Cd5C06dA7089956Fe85dFDaB` | weETH | USDe | pause (borrow already dust) |
| 72 | `0xD170252cbeC41235795D938cA19857CA4d7824a1` | WBTC | USDe | pause (borrow already dust) |
| 73 | `0x75904e18b461eB60692264d40Adb0973D8f33b98` | cbBTC | USDe | pause (borrow already dust) |

Borrow to dust = `setBorrowProtocolLimitsPaused` (debt ceiling `10 / 20`). Pause = `LIQUIDITY.pauseUser(vault, [supplyToken], [borrowToken])`.

### Action 10: Close the dex 5 USDC-ETH Test Market and Vault 62

**dex 5** `0x2886a01a0645390872a9eb99dAe1283664b0c524` (USDC / ETH) was a Nov 2024 test market. Swaps and vault 62 were paused in Dec 2024 and it never launched, but its share caps (7.5M supply / 5M borrow shares) and the vault 62 borrow config at the DEX were never cut.

| Step | Call |
| --- | --- |
| 1 | `setBorrowProtocolLimitsPausedDex(dex 5, vault 62)`, vault 62 (`0xAF861f04304216A0CeeA709D87556C826109E7F3`, T4) borrow at the DEX to dust |
| 2 | `pauseUser(vault 62, false, true)` on dex 5: re-pauses vault 62 borrow, because the DEX borrow config write sets the user back to unpaused. Its supply side is untouched and stays paused |
| 3 | `updateMaxSupplyShares(1)` and `updateMaxBorrowShares(1)` on dex 5 |

dex 5 is already paused at the Liquidity Layer. This action does not write its Liquidity Layer config, and those writes keep the pause bit anyway, so no Liquidity Layer pause call is needed.

### Action 11: Cap dex 27 (wstUSR-USDC) Supply Shares

**dex 27** `0xd64e12101614209eE810EFDe214542A2cb68d9fD` (hidden): `updateMaxSupplyShares(1)`. No new deposits; existing LPs can still withdraw.

### Action 12: Restrict and Pause the Dust-Launch Vaults 95 and 167

| Vault | Address | Type | Change |
| --- | --- | --- | --- |
| 95 | `0xbee8D906BAc00610D8056C88EeEc5E9e9D48104C` | T1 eBTC / cbBTC | supply + borrow to dust, `pauseUser` supply + borrow (same as Action 7) |
| 167 | `0x46a719593378079F242faB86F0d7dEa50D84f28b` | T2 PST-USDC (dex 45) / USDC | USDC borrow at the Liquidity Layer to dust + `pauseUser` borrow; supply at dex 45 (`0x40D66b5f8f1521F97C2acA54dD200Fe3Ca035328`) to dust + `pauseUser(vault, true, false)` |

Dex 45 itself is left unchanged.

### Action 13: Move the osETH Vaults to OracleV2

The V1 oracles of vaults 153-157 price osETH on RedStone's osETH/ETH feed (`0x66ac...B32C`), which currently reverts as stale. Until the oracle changes, these vaults cannot take new borrows, process withdrawals or liquidate positions; deposits and repayments still work. The OracleV2 oracles price osETH on the StakeWise capped rate (`CappedRateBalancer_OSETH_CenterPriceInverted`, `0xddAF...06BB`) with Chainlink ETH/USD, and never read the RedStone feed. Vault 159 moves with them for consistency.

| Vault | Address | Type | New oracle |
| --- | --- | --- | --- |
| 153 | `0x23E4Df0b4830c6ed5F0Df8EA343C7e4a59e3482B` | T1 osETH / USDC | `0x0Bc3DA8C4Aa67E86B7A1c20e8b72049105571Ea9` (DF nonce 383) |
| 154 | `0xFAE78322463168C65b688bB275F187aE8629Ef46` | T1 osETH / USDT | `0x5c7eF1F1901a201A6bAd703D6588CF8FfC6a05F6` (DF nonce 384) |
| 155 | `0x0eF41f6D8B4eE47BC40e7874787024C8186213d5` | T1 osETH / GHO | `0xfa18A2ea5Bf97C2F9D8a5680ecdA494256376Fd9` (DF nonce 385) |
| 156 | `0xf75C00d25E76032Aa4d31dA9D49F06E4F2a771e9` | T3 osETH / USDC-USDT debt | `0xCca4446e48d9C4a9C352368022f5de56Ace022Ff` (DF nonce 386) |
| 157 | `0xe0E722E9daF03b468a05Aca6cCE8D2e9F91D1e6D` | T3 osETH / USDC-USDT debt (concentrated) | `0xcD472AE975E73a27B98d9d52f0f1bb2358812Db0` (DF nonce 387) |
| 159 | `0x40D0aA5041D4C591D26A5CE59Fb62629d0C23b8D` | T2 ETH-osETH / wstETH | `0xF63335D347E96736739f0fbaaebE85EB0b84a1FA` (DF nonce 388) |

T1 vaults take the oracle address via `updateOracle(address)`. T2/T3 vaults take the DeployerFactory nonce via `updateOracle(uint256)` and read the new oracle's operate and liquidate rates before committing it, so a broken oracle reverts the action.

## Description

1. **dexV1 test DEX**: restricts and pauses the last live Liquidity Layer limits of an early test deployment.
2. **Vault 3 rebalance**: clears the borrow-side drift the rebalancer cannot reach while the vault sits at dust borrow limits, then restricts the vault to dust and pauses it. Its 12 remaining small positions (~$1.8k collateral) are frozen with it.
3. **weETH/ETH vault**: moves vault 182 from dust to launch limits.
4. **Team Multisig credit**: closes the unused IGP-107 wstETH and cbBTC DEX Lite credit lines (dust limits and borrow paused) and pauses the USDC/USDT borrow side that IGP-132 cut to dust.
5. **iETHv2 test positions**: iETHv2 withdraws its residual test positions from the pre-launch wstETH/ETH vault (NFT 18) and vault 34 (NFT 2296) before they are frozen. The Timelock sends 0.005 ETH to cover the ETH leg of the vault 34 repayment; any unused ETH stays with iETHv2.
6. **IGP-45 test DEXes id1/id3**: closes the Liquidity Layer limits of two early test DEXes holding only dust.
7. **Pre-launch vaults and old DEXes**: restricts and pauses at the Liquidity Layer the remaining protocols from the old vault and DEX factories.
8. **IGP-45 test DEX id2 and vaults 35-40**: restricts and pauses at the Liquidity Layer the remaining IGP-45 test DEX id2 (USDC/USDT) and the six empty T3 vaults (35-40) built on it.
9. **Hidden USDe vaults 66-73**: removes the remaining open borrow limits (≈$128M combined max) and pauses all eight at the Liquidity Layer.
10. **dex 5 test market**: closes the share caps and vault 62 borrow config left open on a never-launched test DEX.
11. **dex 27**: stops new deposits into the hidden wstUSR-USDC DEX.
12. **Dust-launch vaults 95 / 167**: restricts and pauses two mainnet vaults that only hold dust launch positions.
13. **osETH vaults**: moves vaults 153-157 and 159 to OracleV2 oracles, off the RedStone osETH/ETH feed, which currently reverts as stale.

## Conclusion

IGP-142 closes the dexV1 test DEX at the Liquidity Layer, rebalances vault 3 and freezes it without leaving any borrow capacity open, launches the weETH/ETH vault, closes the Team Multisig's remaining wstETH/cbBTC credit lines, returns iETHv2's residual test positions, closes the IGP-45 test DEXes id1/id2/id3 at the Liquidity Layer, restricts and pauses the remaining pre-launch vaults, old DEXes, and vaults 35-40, and closes the USDe vaults 66-73, the dex 5 test market, dex 27 deposits and the dust-launch vaults 95 / 167. It also moves the osETH vaults 153-157 and 159 to OracleV2 oracles.
