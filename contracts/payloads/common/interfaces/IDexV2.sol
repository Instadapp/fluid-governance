// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.21;

interface IDexV2 {
    function updateAuth(address auth_, bool isAuth_) external;

    function updateDexTypeToAdminImplementation(
        uint256 dexType_,
        uint256 adminImplementationId_,
        address adminImplementation_
    ) external;
}
