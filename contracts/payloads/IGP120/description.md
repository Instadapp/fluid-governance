# Update Dex V1 Deployment Logic on DexFactory

## Summary

This proposal registers a new Dex T1 deployment logic contract (`0x3FB3FE857C1eE52e7002196E295a7ADfFeD80819`) on the DexFactory, enabling the deployment of new DEX pools using the updated logic.

## Code Changes

### Action 1: Set Dex T1 Deployment Logic on DexFactory

- **DexFactory**: `setDexDeploymentLogic(0x3FB3FE857C1eE52e7002196E295a7ADfFeD80819, true)`
- **Deployment Logic Address**: `0x3FB3FE857C1eE52e7002196E295a7ADfFeD80819`
- **Effect**: Whitelists the new T1 deployment logic on the DexFactory, allowing new T1 DEX pools to be deployed using this contract

## Description

The Fusaka upgrade introduced a per-transaction gas limit (EIP-7825). Under this limit, current DexV1 deployment logic no longer fits within a single transaction.

This proposal sets the new Dex T1 deployment logic on the DexFactory. The new logic has reduced bytecode, deprecated logic has been removed and required contracts have been optimized so that deployment stays under the new gas limit. Once this proposal is executed, new T1 DEX pools will use this implementation, and the Team Multisig can deploy pools and associated vaults as needed.

## Conclusion

IGP-120 enables the updated Dex T1 deployment logic on the DexFactory, allowing future T1 DEX pools to utilize this implementation. Parameters and permissions for new pools can be set as needed in future governance actions.
