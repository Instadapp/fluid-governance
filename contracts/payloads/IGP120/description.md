# Update Dex T1 Deployment Logic on DexFactory

## Summary

This proposal registers a new Dex T1 deployment logic contract (`0x3FB3FE857C1eE52e7002196E295a7ADfFeD80819`) on the DexFactory, enabling the deployment of new DEX pools using the updated logic.

## Code Changes

### Action 1: Set Dex T1 Deployment Logic on DexFactory

- **DexFactory**: `setDexDeploymentLogic(0x3FB3FE857C1eE52e7002196E295a7ADfFeD80819, true)`
- **Deployment Logic Address**: `0x3FB3FE857C1eE52e7002196E295a7ADfFeD80819`
- **Effect**: Whitelists the new T1 deployment logic on the DexFactory, allowing new T1 DEX pools to be deployed using this contract

## Description

The Dex T1 deployment logic determines how new T1 DEX pools are created on the DexFactory. This proposal whitelists an updated deployment logic contract, enabling future T1 DEX deployments to use the latest logic. Once registered, the Team Multisig can deploy new T1 DEX pools and associated vaults as needed.

## Conclusion

IGP-120 enables the updated Dex T1 deployment logic on the DexFactory, allowing future T1 DEX pools to utilize this implementation. Parameters and permissions for new pools can be set as needed in future governance actions.
