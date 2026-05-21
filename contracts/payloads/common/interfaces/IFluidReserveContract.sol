pragma solidity ^0.8.21;
pragma experimental ABIEncoderV2;

interface IFluidReserveContract {
    function isRebalancer(address user) external returns (bool);

    function rebalanceFToken(address protocol_) external;

    function rebalanceVault(address protocol_) external;

    function transferFunds(address token_) external;

    function withdrawFunds(
        address[] memory tokens_,
        uint256[] memory amounts_,
        address to_
    ) external;

    function getProtocolTokens(address protocol_) external;

    function updateAuth(address auth_, bool isAuth_) external;

    function updateRebalancer(address rebalancer_, bool isRebalancer_) external;

    function approve(
        address[] memory protocols_,
        address[] memory tokens_,
        uint256[] memory amounts_
    ) external;

    function revoke(
        address[] memory protocols_,
        address[] memory tokens_
    ) external;
}

interface IFluidReserveContractV2 {
    function withdrawFunds(
        address[] memory tokens_,
        uint256[] memory amounts_,
        address to_,
        string memory reason_
    ) external;
}
