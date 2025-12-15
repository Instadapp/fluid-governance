## Add Team Multisig as Vault Auth for OSETH T4 Vault

## Summary

This proposal adds Team Multisig as a vault auth for the OSETH T4 vault (Vault ID 158), ensuring Team Multisig can manage configuration for the OSETH-ETH <> wstETH-ETH vault without changing any existing limits or risk parameters.

## Code Changes

### Action 1: Add TEAM_MULTISIG as Vault Auth for OSETH T4 Vault

- **Vault ID 158**<br>
  **oseth-eth <> wsteth-eth (TYPE 4)**:
  - **Change**: Add `Team Multisig` as an authorized vault config updater on the OSETH T4 vault
  - **Method**: `VAULT_FACTORY.setVaultAuth(vault, TEAM_MULTISIG, true)`

## Description

The OSETH T4 vault (Vault ID 158, oseth-eth <> wsteth-eth) received dust limits in IGP113 and launch limits in IGP114, but Team Multisig was not added as a vault auth, which is required for Team Multisig to manage this vault’s configuration. This proposal introduces a single action that adds Team Multisig as an authorized vault config updater on the OSETH T4 vault via a direct `setVaultAuth` call, structurally matching prior IGP payloads. No changes are made to dust limits, launch limits, or any other risk parameters; the proposal strictly addresses the missing authorization needed to avoid delays to the OSETH T4 vault launch.

## Conclusion

IGP-115 is a narrowly scoped housekeeping proposal that only adds Team Multisig as a vault auth for the OSETH T4 vault (ID 158). It does not modify any limits, LL settings, or other risk parameters configured in IGP113 and IGP114, and exists solely to unblock operational readiness for the OSETH T4 vault.