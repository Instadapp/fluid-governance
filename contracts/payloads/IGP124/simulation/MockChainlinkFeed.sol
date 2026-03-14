// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * Mock Chainlink aggregator for simulation: latestRoundData() returns fixed values.
 * Used via tenderly_setCode in setup.ts so FluidGenericOracle._readChainlinkSource(feed) gets these values.
 */
contract MockChainlinkFeed {
    function latestRoundData()
        external
        pure
        returns (
            uint80 roundId,
            int256 answer,
            uint256 startedAt,
            uint256 updatedAt,
            uint80 answeredInRound
        )
    {
        return (1, 106475560, 1771926611, 1771926611, 1);
    }
}
