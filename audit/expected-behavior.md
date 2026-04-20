# Expected behavior & design invariants

This document captures behaviors that are **intentional** in the Fluid governance system and are enforced **operationally** (by the governance process, multisig custody, and deployment procedures), not by the contracts themselves.

Any review of this repository should treat these as given. If any invariant below changes, the security posture of the affected contracts must be re-evaluated.

---

## I1 — Governor `admin` is always a properly deployed `InstaTimelock` contract

- Never an externally owned account (EOA).
- Never a non-`TimelockInterface` contract.
- Admin rotations go through the full on-chain governance path (proposal → quorum → timelock delay → accept) and are deeply reviewed.
- No flow that could leave `admin` pointing at an EOA or a code-less / non-Timelock account is part of the intended operation of this system.

---

## I2 — Governor `timelock == admin` at all times

- Enforced in code by [`GovernorBravoDelegate._acceptAdmin`](../contracts/GovernorBravoDelegate.sol) (`timelock = TimelockInterface(pendingAdmin)` at the moment of acceptance).
- Follows from I1 that `timelock` is therefore also never an EOA.

---

## I3 — Timelock `admin` is always the live Governor

- Ensured via the Timelock's `setPendingAdmin` / `acceptAdmin` two-step, which is invokable only through governance proposals.
- This is the direction opposite to I1/I2: it is the Timelock pointing at the Governor, not the Governor pointing at the Timelock.

---

## I4 — `InstaIndex` is immutable bytecode at `0x2971AdFa57b20E5a416aE5a708A8655A9c74f723`

- The `InstaIndex` contract is not a proxy; its logic is frozen (compiler `v0.6.0`, verified on Etherscan, exact-match).
- `InstaIndex.master()` custody is outside this repo's scope; its security is a function of whatever multisig currently holds the master role.
- Through the token's `isMaster` modifier, `master` is effectively a super-admin one layer above governance (can replace token implementation, mint, pause, rename).

---

## I5 — `PROPOSER_AVO_MULTISIG_{1..5}` are fixed Avocado multisig deployments

- The five `PROPOSER_AVO_MULTISIG_*` addresses declared in [`contracts/payloads/common/constants.sol`](../contracts/payloads/common/constants.sol) refer to immutable Avocado multisig contracts at those exact addresses.
- Those contracts cannot be migrated / replaced / re-deployed at the same address.
- This makes the `address(this) == PROPOSER_AVO_MULTISIG_N` checks inside `PayloadIGPMain.propose()` and `setProposalCreationTime()` robust, because the only way `address(this)` can equal one of those constants is to actually be the corresponding Avocado multisig executing via `delegatecall` into the payload.
