pragma solidity ^0.8.21;

interface ILiteSigs {
    // Claim Module
    function claimFromAaveV3Lido() external;
    function claimKingRewards(address rewardToken, uint256 amount, bytes32 merkleRoot, bytes32[] calldata merkleProof, uint256 index) external;

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
    function getRatioAaveV3(uint256 stEthPerWsteth_, uint256 ethPerWsteth_) external view returns (uint256 ratio_);
    function getRatioFluidWeETHWstETH(uint256 weEthPerWsteth_, uint256 ethPerWsteth_) external view returns (uint256 ratio_);

    // Admin Module
    function setFluidDexNftId(uint256 nftId_) external;

    // StethToEethModule (New Module)
    function convertAaveV3wstETHToWeETH(uint256 wstETHAmount, uint256 minWeETHAmount, uint256 route) external returns (uint256 weETHAmount);

    // FluidAaveV3WeETHRebalancerModule (New Module)
    function rebalanceFromWeETHToWstETH(uint256 weETHAmount, uint256 minWstETHAmount, uint256 route) external returns (uint256 wstETHAmount);
    function rebalanceFromWstETHToWeETH(uint256 wstETHAmount, uint256 minWeETHAmount, uint256 route) external returns (uint256 weETHAmount);

    // Rebalancer Module
    function swapKingTokensToWeth(uint256 amount, uint256 minWethAmount, string memory tokenSymbol, string memory poolSymbol) external returns (uint256 wethAmount);
    function sweepWethToWeEth() external returns (uint256 weEthAmount);
} 