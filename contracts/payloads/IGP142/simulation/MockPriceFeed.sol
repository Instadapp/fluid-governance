// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/// @notice Simulation-only price feed. setup.ts installs it over the live
///         Chainlink / RedStone feeds with `tenderly_setCode` and stores the
///         live answer and decimals, so the feed reports a fresh round after
///         the simulation warps past the governance delays.
contract MockPriceFeed {
    int256 private _answer;
    uint256 private _decimals;

    function decimals() external view returns (uint8) {
        return uint8(_decimals);
    }

    function latestAnswer() external view returns (int256) {
        return _answer;
    }

    function latestTimestamp() external view returns (uint256) {
        return block.timestamp;
    }

    function latestRoundData()
        external
        view
        returns (uint80, int256, uint256, uint256, uint80)
    {
        return (1, _answer, block.timestamp, block.timestamp, 1);
    }

    function getRoundData(
        uint80
    ) external view returns (uint80, int256, uint256, uint256, uint80) {
        return (1, _answer, block.timestamp, block.timestamp, 1);
    }
}
