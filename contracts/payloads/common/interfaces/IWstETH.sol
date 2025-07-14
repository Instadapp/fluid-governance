pragma solidity ^0.8.21;

interface IWstETH {
    function unwrap(uint256 _wstETHAmount) external returns (uint256);
}
