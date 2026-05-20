pragma solidity ^0.8.21;

interface IStETHRedemptionProtocol {
    /// @notice Sets `maxLTV` to `maxLTV_` (in 1e2: 1% = 100, 100% = 10000). Must be > 0 and < 100%.
    function setMaxLTV(uint16 maxLTV_) external;
}
