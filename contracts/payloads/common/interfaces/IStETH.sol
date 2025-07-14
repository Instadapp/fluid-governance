pragma solidity ^0.8.21;

interface IStETH {
    function submit(address referral) external payable returns (uint256);
}