pragma solidity ^0.8.21;

interface ILiteSigs {
    // AaveV3WstETHWeETHSwapModule
    function swapWstETHToWeETH(
        uint256 wstEthSellAmount_,
        uint256 unitAmount_,
        uint256 route_,
        string memory swapConnectorName_,
        string memory swapCallData_
    ) external;

    function swapWeETHToWstETH(
        uint256 weEthSellAmount_,
        uint256 unitAmount_,
        uint256 route_,
        string memory swapConnectorName_,
        string memory swapCallData_
    ) external;

     // ClaimModule
    function claimFromAaveV3Lido() external;

    function claimKingRewards(
        address merkleContract_,
        uint256 amount_,
        bytes32 expectedMerkleRoot_,
        bytes32[] calldata merkleProof_,
        uint256 setId_
    ) external;

    // FluidAaveV3WeETHRebalancerModule
    function rebalanceFromWeETHToWstETH(
        uint256 weEthFlashloanAmount_,
        uint256 wstEthBorrowAmount_,
        uint256 route_
    ) external returns (uint256 wstETHAmount_);

    function rebalanceFromWstETHToWeETH(
        uint256 wstEthFlashloanAmount_,
        uint256 weEthWithdrawAmount_,
        uint256 route_
    ) external;

    // FluidStethModule
    

    // Leverage Dex Module
    function leverageDexRefinance(
        uint8 protocolId_,
        uint256 route_,
        uint256 wstETHflashAmount_,
        uint256 wETHBorrowAmount_,
        uint256 withdrawAmount_,
        int256 perfectColShares_,
        int256 colToken0MinMax_, // if +, max to deposit, if -, min to withdraw
        int256 colToken1MinMax_, // if +, max to deposit, if -, min to withdraw
        int256 perfectDebtShares_,
        int256 debtToken0MinMax_, // if +, min to borrow, if -, max to payback
        int256 debtToken1MinMax_ // if +, min to borrow, if -, max to payback
    ) external returns (uint256 ratioFromProtocol_, uint256 ratioToProtocol_);

    // Leverage Module

    // Rebalancer Module
    function sweepWethToWeEth() external;

    function swapKingTokensToWeth(
        uint256 sellAmount_,
        uint256 unitAmount_,
        string memory swapConnectorName_,
        string memory swapCallData_
    ) external;

    // Unwind Dex Module
    function unwindDexRefinance(
        uint8 protocolId_,
        uint256 route_,
        uint256 wstETHflashAmount_,
        uint256 wETHPaybackAmount_,
        uint256 withdrawAmount_,
        int256 perfectColShares_,
        int256 colToken0MinMax_, // if +, max to deposit, if -, min to withdraw
        int256 colToken1MinMax_, // if +, max to deposit, if -, min to withdraw
        int256 perfectDebtShares_,
        int256 debtToken0MinMax_, // if +, min to borrow, if -, max to payback
        int256 debtToken1MinMax_ // if +, min to borrow, if -, max to payback
    ) external returns (uint256 ratioFromProtocol_, uint256 ratioToProtocol_);

    // View Module
    function maxAllocationToTeamMultisig() external view returns (uint256);

    function allocationToTeamMultisig() external view returns (uint256);

    function getRatioFluidDex(
        uint256 stEthPerWsteth_
    )
        external
        view
        returns (
            uint256 wstEthColAmount_,
            uint256 stEthColAmount_,
            uint256 ethColAmount_,
            uint256 wstEthDebtAmount_,
            uint256 stEthDebtAmount_,
            uint256 ethDebtAmount_,
            uint256 ratio_
        );

    function fluidDexNFT() external view returns (address);

    function getRatioAaveV3(
        uint256 eEthPerWeETH_,
        uint256 stEthPerWsteth_
    )
        external
        view
        returns (
            uint256 wstEthAmount_,
            uint256 weEthAmount_,
            uint256 eEthAmount_,
            uint256 stEthAmount_,
            uint256 ethAmount_,
            uint256 ratio_
        );

    function getRatioFluidWeETHWstETH(
        uint256 eEthPerWeETH_,
        uint256 stEthPerWsteth_
    )
        external
        view
        returns (
            uint256 weEthAmount_,
            uint256 wstEthAmount_,
            uint256 eEthAmount_,
            uint256 stEthAmount_,
            uint256 ratio_
        );

    // Admin Module
    function setFluidDexNftId(uint256 nftId_) external;

    // StethToEethModule (New Module)
    function convertAaveV3wstETHToWeETH(
        uint256 wEthFlashloanAmount_,
        uint256 wstEthWithdrawAmount_,
        uint256 route_
    ) external;
}