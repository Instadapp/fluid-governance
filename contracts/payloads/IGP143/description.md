# Wind Down the tBTC Vaults, Move DSA Connector Control Behind a 24h Timelock, Send the Monthly Grant, Update the Vault 77 Oracle and Upgrade the Liquidity Layer Pause Setup

## Summary

This proposal performs nine actions on mainnet. Action 1 sets the three **tBTC T1 vaults** (88 tBTC/USDC, 89 tBTC/USDT, 90 tBTC/GHO) to exit-only at the Liquidity Layer: borrow limits are fully restricted to dust, tBTC withdrawal limits are set to current supply plus a 20% buffer, and the vaults are unpaused so users can repay and withdraw. Action 2 updates the **DSA connector-registry chiefs**: the five remaining chiefs are removed and the **Team Multisig 24h timelock** becomes the ConnectorsV2 chief. Action 3 collects the Liquidity Layer's **USDC**, **USDT**, **GHO**, **USDe** and **ETH** revenue into the Fluid Reserve and sends the monthly tranche of the **$350k/month** grant, mostly in stablecoins, to the **Team Multisig**. Action 4 updates the oracle on the **USDC-ETH / USDC-ETH T4 vault (77)**. Actions 5 to 9 upgrade the **Liquidity Layer pause setup**, one part per action so the parts can be skipped separately (5 and 6 only together): rollbacks registered (5), new Admin and User modules with the Liquidity guardian moved to the new PauseAuthLiquidity (6), the OracleV2 guardian (7), and the DEX pause (8) and limits (9) global auths moved to the new auth contracts.

## Code Changes

### Action 1: Restrict Borrow, Set Withdrawal Limits and Unpause the tBTC Vaults

| Vault | Address | Collateral / Debt | tBTC supply (block 26313811) | Debt at Liquidity Layer |
| --- | --- | --- | --- | --- |
| 88 | `0xd312bf768de0c9e3709fF707AB4847B197A49160` | tBTC / USDC | ≈0.5589 tBTC (≈$43k) | ≈22,072 USDC |
| 89 | `0x888f89dd277a3e69C3607f67dEd93877ED359ba7` | tBTC / USDT | ≈1.1440 tBTC (≈$89k) | ≈53,392 USDT |
| 90 | `0x1810278703934B8E9e68cf535bDBB46d920F0470` | tBTC / GHO | ≈0.0004 tBTC (≈$31) | ≈11.31 GHO |

| Step | Call | Effect |
| --- | --- | --- |
| Borrow | `setBorrowProtocolLimitsPaused` for USDC / USDT / GHO | Debt ceiling `10 / 20` (dust), expansion 0.01% over max duration. Repayments still work. |
| Supply | `LIQUIDITY.updateUserSupplyConfigs` for tBTC | Base withdrawal limit = supply + 20%: **0.6707 / 1.3729 / 0.0005 tBTC**, expansion **10% over 12 hours** |
| Unpause | `LIQUIDITY.unpauseUser(vault, [tBTC], [debt token])` | Supply and borrow legs unpaused at the Liquidity Layer |

The Team Multisig pauses the three vaults at the Liquidity Layer (both legs) in the meantime. `unpauseUser` reverts for a leg that is not paused, so the payload reads each leg's pause bit and only unpauses the paused legs. The action runs whether or not the Team Multisig pause was executed.

### Action 2: Update the DSA Connector Chiefs and Add the 24h Timelock as Chief

The InstaIndex (`0x2971AdFa57b20E5a416aE5a708A8655A9c74f723`) master is already the governance timelock (`0x2386DC45AdDed673317eF068992F19421B481F4c`) and stays unchanged. Only the InstaIndex master can add or remove chiefs on ConnectorsV2, so this needs governance.

| Registry | Address | Call | Chief change |
| --- | --- | --- | --- |
| ConnectorsV2 (used by DSA v2 `cast`) | `0x97b0B3A8bDeFE8cB9563a3c610019Ad10DB8aD11` | `toggleChief(address)` | remove Team Multisig `0x4F6F977aCDD1177DCD81aB83074855EcB9C2D49e` |
| | | `toggleChief(address)` | add Team Multisig timelock `0x4d6CE4F4498d59Eed397bCbC687805a07f9b2346` |
| Legacy v1 InstaConnectors (InstaIndex `connectors(1)`) | `0xD6A602C01a023B98Ecfb29Df02FBA380d3B21E0c` | `disableChief(address)` | remove `0xb1DC62EC38E6E3857a887210C38418E4A17Da5B2` |
| | | `disableChief(address)` | remove `0x495E5bE71B3fD3ec6dFe54a9e5ccb22550BeF994` |
| | | `disableChief(address)` | remove `0x27AC3fFdB94B80Daf5A421e8338dCF6eE23aF73E` |
| | | `disableChief(address)` | remove `0xDE13DF1c51364C67dA5cC6360CF5F2e64F1Ae4bd` |

- `toggleChief` flips the flag, so the payload only calls it while each address is not yet in its target state. It can never re-grant chief to the Team Multisig or remove it from the timelock.
- **Team Multisig timelock** `0x4d6CE4F4498d59Eed397bCbC687805a07f9b2346` (OpenZeppelin `TimelockController`): minimum delay 24 hours, proposer and canceller = Team Multisig, executor = Fluid Safe `0x196Ed45eC4ACA949E7AA921ceC81e219e682775e`, admin = the timelock itself. These are the only role grants since its deployment and none was revoked.
- A ConnectorsV2 chief can only add, update and remove connectors. Adding or removing chiefs stays with the InstaIndex master (`toggleChief` is master-only), so the timelock cannot grant chief to anyone else.
- The v1 registry gets no new chief. No connector was enabled on it since June 2021; all four chiefs are removed in the same execution and v1 changes stay with governance.
- The action reverts unless all five old chiefs end with `chief == false`, the timelock is the ConnectorsV2 chief, and the InstaIndex master is still the governance timelock.
- InstaIndex `connectors(2)` (`0x7D53E606308A2E0A1D396F30dc305cc7f8483436`) has no `chief()` function, so there is nothing to remove there.


### Action 3: Collect Revenue and Send the Monthly Grant

1. `collectRevenue` on the Liquidity Layer for USDC, USDT, GHO, USDe and ETH into the Fluid Reserve.
2. `withdrawFunds` from the Fluid Reserve to the Team Multisig `0x4F6F977aCDD1177DCD81aB83074855EcB9C2D49e`, memo "FOUNDATION GRANT":

| Token | Amount | ~USD |
| --- | --- | --- |
| USDC | 98,000 | ~$98k |
| USDT | 94,000 | ~$94k |
| GHO | 51,000 | ~$51k |
| USDe | 5,000 | ~$5k |
| ETH | 17 | ~$31k |
| stETH | 39 | ~$71k |
| **Total** | | **~$350k** (~$248k, ~71%, in stablecoins) |

At authoring (block 26458491) the Reserve plus uncollected Liquidity revenue holds ~100.3k USDC, ~96.3k USDT, ~52.2k GHO, ~5.5k USDe, ~18.4 ETH and ~40.7 stETH. ETH and stETH are valued at their 7-day average price of ~$1,815 (daily closes, 13-19 Nov 2026). Amounts are fixed in token terms; any excess revenue stays in the Reserve.

### Action 4: Update the Vault 77 Oracle

| Vault | Address | Type | Old oracle (nonce) | New oracle (nonce) |
| --- | --- | --- | --- | --- |
| 77 | `0x469D8c7990b9072EEF05d6349224621a71176213` | T4 USDC-ETH / USDC-ETH | `0x9c9cad6Dd23fbDCdA3348726c306bAF20c428c4C` (60) | `0x317155C3EDdB9ae57097D98b2954CB6cC7f38f6D` (410) |

- T4 vaults take the DeployerFactory nonce via `updateOracle(uint256)` and read the new oracle's operate and liquidate rates before committing it, so a broken oracle reverts the action.

### Actions 5 to 9: Liquidity Layer Pause Upgrade

All calls are made by the governance timelock `0x2386DC45AdDed673317eF068992F19421B481F4c`, in this order. Liquidity proxy `0x52Aa899454998Be5b000Ad077a46Bbe360F4e497`, DexFactory `0x91716C4EDA1Fb55e84Bf8b4c7085f84285c19085`, OracleV2 `0x643E32D5a39C1B0a483BCF2C5c2c55C4b982ac06`. Each part is its own action. Actions 7, 8 and 9 can each be skipped on their own; Actions 5 and 6 should only be skipped together.

| Action | Contract | Call |
| --- | --- | --- |
| 5. Liquidity rollbacks | Liquidity | `cleanupExpiredRollbackImplementation` for `0x2e4015880367b7C2613Df77f816739D97A8C46aD` and `0x53EFFA0e612d88f39Ab32eb5274F2fae478d261C`; then `registerRollbackImplementation(old, new)` for the Admin module (`0xea78faBC13D603895FE9efe8BB4A4F2c56e5698E` → `0x20ad698963BCc194dd3b5A0b5458ac3c52dE9C56`) and the User module (`0x4bDC8816F2f56914B66EbF3786D78872D3a73Ab7` → `0x6a887dad0852b1A8fa5429FB9c7F83a943469F06`), and `registerRollbackDummyImplementation()` |
| 6. Liquidity module swap and guardian | Liquidity | `removeImplementation` for the old Admin module, the old User module and the Zircuit transfer module (`0x9191b9539DD588dB81076900deFDd79Cb1115f72`); `addImplementation` for the new Admin module (20 selectors from its ABI) and the new User module (`operate`, `operateOnBehalfOf`); `setDummyImplementation(0x8bDD171da967345a23Af927051E8860E6b9fAFe7)`; `updateGuardians`: add `0x30f8B1FaE1937992556f28c961aE0a1E088ED48c` (new PauseAuthLiquidity), remove `0xE9332F2d45e3216B7634cA4C7ab88945CD84ab76` (old PauseAuthLiquidity) |
| 7. OracleV2 guardian | OracleV2 | `setGuardian(0x8fcC728708b2D9d6a2B4d49477Ada6042d43dd63, true)` (PauseAuthOracleV2) |
| 8. DEX pause auth | DexFactory | `setGlobalAuth`: add `0x19684DdA3c27735861f6197DE738F5C3ca0c8eE3` (new PauseAuthDex), remove `0x735BA3772c2cCC0b92Ff6993bd71da88236C1495` (old PauseAuthDex) |
| 9. DEX limits auth | DexFactory | `setGlobalAuth`: add `0x1E1fcA3cC4436aAE73e9C97Ea0E1584c749DB300` (new LimitsAuthDex), remove `0x5A09B07DFCc0852ADA327Dc81A9cb676B6c676f2` (old LimitsAuthDex) |

- Action 5: the rollback cleanup is permissionless. The payload only calls it while a registration still exists, so the action also runs if someone clears it before execution. Registration reverts while the expired registrations exist, so cleanup and registration stay in one action.
- Action 6: the module swap and the Liquidity guardian change stay in one action, because the old PauseAuthLiquidity only calls the old Admin module's pause functions and the new PauseAuthLiquidity only the new module's. After the swap the action checks that `pauseUserBorrow` routes to the new Admin module and that the old `pauseUser`, `pauseTokens(address[])` and `unpauseTokens(address[])` are no longer routed.
- Action 6 runs after Action 1: the new Admin module no longer routes `unpauseUser`, which Action 1 uses. Rollbacks can only be registered while the old modules are routed, so skipping Action 5 while executing Action 6 leaves the swap without a registered rollback. Skipping Action 6 while executing Action 5 leaves rollback registrations for the old modules and the dummy implementation that cannot be cleared or replaced for 7 days, so a later swap would have to wait or go without a rollback.
- A rollback (Team Multisig, within 7 days of execution) only restores the module routing. The guardian stays the new PauseAuthLiquidity, which cannot pause on the old modules, so after a rollback pausing is manual by the Team Multisig until governance sets the guardian again.
- Actions 7, 8 and 9 are independent of each other and of Actions 5 and 6.

## Description

1. **tBTC vaults 88 / 89 / 90**: closes all new borrowing and reopens the vaults for exits only. The withdrawal limits sit 20% above current supply, so every user can withdraw their full collateral after repaying.
2. **DSA connector chiefs**: the Team Multisig schedules ConnectorsV2 changes on its 24h timelock; governance keeps full control as InstaIndex master.
3. **Monthly grant**: the monthly tranche of the $350,000/month grant approved in IGP-139, sent to the Team Multisig, mostly in stablecoins.
4. **Vault 77 oracle**: updates the oracle on the USDC-ETH / USDC-ETH T4 vault.
5. **Liquidity Layer rollbacks**: registers rollbacks for the new Liquidity Layer Admin and User modules and the dummy implementation.
6. **Liquidity Layer module swap**: upgrades the Liquidity Layer Admin and User modules and moves the Liquidity guardian to the new PauseAuthLiquidity.
7. **OracleV2 guardian**: adds PauseAuthOracleV2 as OracleV2 guardian.
8. **DEX pause auth**: moves the DexFactory pause global auth to the new PauseAuthDex.
9. **DEX limits auth**: moves the DexFactory limits global auth to the new LimitsAuthDex.

## Conclusion

IGP-143 moves the tBTC vaults 88, 89 and 90 to exit-only (borrow restricted to dust, withdrawal limits at current supply + 20% with 10% expansion over 12 hours, vaults unpaused at the Liquidity Layer) and updates the DSA connector chiefs, with the Team Multisig 24h timelock as the ConnectorsV2 chief. It also sends the monthly grant tranche from the Fluid Reserve to the Team Multisig, mostly in stablecoins, funded by its existing holdings plus the Liquidity Layer revenue collected in the same transaction. It updates the oracle on vault 77 and, finally, upgrades the Liquidity Layer pause setup.
