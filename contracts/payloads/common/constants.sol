pragma solidity ^0.8.21;
pragma experimental ABIEncoderV2;

import {BigMathMinified} from "../libraries/bigMathMinified.sol";
import {LiquidityCalcs} from "../libraries/liquidityCalcs.sol";
import {LiquiditySlotsLink} from "../libraries/liquiditySlotsLink.sol";

import {IGovernorBravo} from "./interfaces/IGovernorBravo.sol";
import {ITimelock} from "./interfaces/ITimelock.sol";

import {IFluidLiquidityAdmin} from "./interfaces/IFluidLiquidity.sol";
import {IFluidReserveContract} from "./interfaces/IFluidReserveContract.sol";

import {IFluidVaultFactory} from "./interfaces/IFluidVaultFactory.sol";
import {IFluidDexFactory} from "./interfaces/IFluidDexFactory.sol";
import {IFluidSmartLendingFactory} from "./interfaces/IFluidSmartLendingFactory.sol";
import {IFluidLendingFactory} from "./interfaces/IFluidLendingFactory.sol";

import {IFluidDex} from "./interfaces/IFluidDex.sol";
import {IFluidDexResolver} from "./interfaces/IFluidDex.sol";

import {IFluidVault} from "./interfaces/IFluidVault.sol";
import {IFluidVaultT1} from "./interfaces/IFluidVault.sol";

import {IFTokenAdmin} from "./interfaces/IFToken.sol";
import {ILendingRewards} from "./interfaces/IFToken.sol";

import {IDSAV2} from "./interfaces/IDSA.sol";

import {ILite} from "./interfaces/ILite.sol";

import { IDSAConnectorsV2 } from "./interfaces/IDSA.sol";

contract PayloadIGPConstants {
    address public immutable ADDRESS_THIS;

    // Proposal Creators
    address public constant PROPOSER =
        0xA45f7bD6A5Ff45D31aaCE6bCD3d426D9328cea01;
    address public constant PROPOSER_AVO_MULTISIG =
        0x059A94A72951c0ae1cc1CE3BF0dB52421bbE8210;
    address public constant PROPOSER_AVO_MULTISIG_2 =
        0x9efdE135CA4832AbF0408c44c6f5f370eB0f35e8;
    address public constant PROPOSER_AVO_MULTISIG_3 =
        0x5C43AAC965ff230AC1cF63e924D0153291D78BaD;
    address public constant PROPOSER_AVO_MULTISIG_4 =
        0x3dAff61fe5cfB1f1B4eA7FBa8173A58532Ef1841;
    address public constant PROPOSER_AVO_MULTISIG_5 =
        0xE7EB63a8B6392481A9FDEbb108Cfd580DC8664d3;

    // Governance Addresses
    IGovernorBravo public constant GOVERNOR =
        IGovernorBravo(0x0204Cd037B2ec03605CFdFe482D8e257C765fA1B);
    ITimelock public constant TIMELOCK =
        ITimelock(0x2386DC45AdDed673317eF068992F19421B481F4c);
    IDSAV2 public constant TREASURY =
        IDSAV2(0x28849D2b63fA8D361e5fc15cB8aBB13019884d09);
    IDSAConnectorsV2 public constant DSA_CONNECTORS_V2 =
        IDSAConnectorsV2(0x97b0B3A8bDeFE8cB9563a3c610019Ad10DB8aD11);

    // Team Multisig
    address public constant TEAM_MULTISIG =
        0x4F6F977aCDD1177DCD81aB83074855EcB9C2D49e;
    address public constant TEAM_MULTISIG_2 =
        0x1e2e1aeD876f67Fe4Fd54090FD7B8F57Ce234219;

    // Fluid Addresses
    IFluidLiquidityAdmin public constant LIQUIDITY =
        IFluidLiquidityAdmin(0x52Aa899454998Be5b000Ad077a46Bbe360F4e497);
    IFluidReserveContract public constant FLUID_RESERVE =
        IFluidReserveContract(0x264786EF916af64a1DB19F513F24a3681734ce92);

    // Fluid Factory Addresses
    IFluidVaultFactory public constant VAULT_FACTORY =
        IFluidVaultFactory(0x324c5Dc1fC42c7a4D43d92df1eBA58a54d13Bf2d);
    IFluidDexFactory public constant DEX_FACTORY =
        IFluidDexFactory(0x91716C4EDA1Fb55e84Bf8b4c7085f84285c19085);
    IFluidSmartLendingFactory public constant SMART_LENDING_FACTORY =
        IFluidSmartLendingFactory(0xe57227C7d5900165344b190fc7aa580bceb53B9B);
    IFluidLendingFactory public constant LENDING_FACTORY =
        IFluidLendingFactory(0x54B91A0D94cb471F37f949c60F7Fa7935b551D03);

    ILite public constant IETHV2 =
        ILite(0xA0D3707c569ff8C87FA923d3823eC5D81c98Be78);

    // Tokens
    address internal constant ETH_ADDRESS =
        0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;
    address internal constant WETH_ADDRESS =
        0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address internal constant wstETH_ADDRESS =
        0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0;
    address internal constant stETH_ADDRESS =
        0xae7ab96520DE3A18E5e111B5EaAb095312D7fE84;
    address internal constant weETH_ADDRESS =
        0xCd5fE23C85820F7B72D0926FC9b05b43E359b7ee;
    address internal constant rsETH_ADDRESS =
        0xA1290d69c65A6Fe4DF752f95823fae25cB99e5A7;
    address internal constant weETHs_ADDRESS =
        0x917ceE801a67f933F2e6b33fC0cD1ED2d5909D88;
    address internal constant mETH_ADDRESS =
        0xd5F7838F5C461fefF7FE49ea5ebaF7728bB0ADfa;
    address internal constant ezETH_ADDRESS =
        0xbf5495Efe5DB9ce00f80364C8B423567e58d2110;

    address internal constant USDC_ADDRESS =
        0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address internal constant USDT_ADDRESS =
        0xdAC17F958D2ee523a2206206994597C13D831ec7;
    address internal constant sUSDe_ADDRESS =
        0x9D39A5DE30e57443BfF2A8307A4256c8797A3497;
    address internal constant syrupUSDC_ADDRESS =
        0x80ac24aA929eaF5013f6436cdA2a7ba190f5Cc0b;
    address internal constant syrupUSDT_ADDRESS =
        0x356B8d89c1e1239Cbbb9dE4815c39A1474d5BA7D;
    address internal constant sUSDs_ADDRESS =
        0xa3931d71877C0E7a3148CB7Eb4463524FEc27fbD;
    address internal constant USDe_ADDRESS =
        0x4c9EDD5852cd905f086C759E8383e09bff1E68B3;
    address internal constant GHO_ADDRESS =
        0x40D16FC0246aD3160Ccc09B8D0D3A2cD28aE6C2f;
    address internal constant iUSD_ADDRESS =
        0x48f9e38f3070AD8945DFEae3FA70987722E3D89c;
    address internal constant deUSD_ADDRESS =
        0x15700B564Ca08D9439C58cA5053166E8317aa138;
    address internal constant USR_ADDRESS =
        0x66a1E37c9b0eAddca17d3662D6c05F4DECf3e110;
    address internal constant USD0_ADDRESS =
        0x73A15FeD60Bf67631dC6cd7Bc5B6e8da8190aCF5;
    address internal constant fxUSD_ADDRESS =
        0x085780639CC2cACd35E474e71f4d000e2405d8f6;
    address internal constant BOLD_ADDRESS =
        0xb01dd87B29d187F3E3a4Bf6cdAebfb97F3D9aB98;
    address internal constant USDTb_ADDRESS =
        0xC139190F447e929f090Edeb554D95AbB8b18aC1C;
    address internal constant csUSDL_ADDRESS =
        0xbEeFc011e94f43b8B7b455eBaB290C7Ab4E216f1;
    address internal constant JRUSDE_ADDRESS =
        0xC58D044404d8B14e953C115E67823784dEA53d8F;
    address internal constant SRUSDE_ADDRESS =
        0x3d7d6fdf07EE548B939A80edbc9B2256d0cdc003;

    address internal constant WBTC_ADDRESS =
        0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599;
    address internal constant cbBTC_ADDRESS =
        0xcbB7C0000aB88B473b1f5aFd9ef808440eed33Bf;
    address internal constant tBTC_ADDRESS =
        0x18084fbA666a33d37592fA2633fD49a74DD93a88;
    address internal constant eBTC_ADDRESS =
        0x657e8C867D8B37dCC18fA4Caead9C45EB088C642;
    address internal constant lBTC_ADDRESS =
        0x8236a87084f8B84306f72007F36F2618A5634494;

    address internal constant INST_ADDRESS =
        0x6f40d4A6237C257fff2dB00FA0510DeEECd303eb;
    address internal constant FLUID_ADDRESS =
        0x6f40d4A6237C257fff2dB00FA0510DeEECd303eb;

    address internal constant RLP_ADDRESS =
        0x4956b52aE2fF65D74CA2d61207523288e4528f96;
    address internal constant wstUSR_ADDRESS =
        0x1202F5C7b4B9E47a1A484E8B270be34dbbC75055;

    address internal constant XAUT_ADDRESS =
        0x68749665FF8D2d112Fa859AA293F07A622782F38;
    address internal constant PAXG_ADDRESS =
        0x45804880De22913dAFE09f4980848ECE6EcbAf78;

    // fTokens
    address internal constant F_USDT_ADDRESS =
        0x5C20B550819128074FD538Edf79791733ccEdd18;
    address internal constant F_USDC_ADDRESS =
        0x9Fb7b4477576Fe5B32be4C1843aFB1e55F251B33;
    address internal constant F_WETH_ADDRESS =
        0x90551c1795392094FE6D29B758EcCD233cFAa260;
    address internal constant F_WSTETH_ADDRESS =
        0x2411802D8BEA09be0aF8fD8D08314a63e706b29C;
    address internal constant F_GHO_ADDRESS =
        0x6A29A46E21C730DcA1d8b23d637c101cec605C5B;
    address internal constant F_SUSDs_ADDRESS =
        0x2BBE31d63E6813E3AC858C04dae43FB2a72B0D11;
    address internal constant F_USDTb_ADDRESS =
        0x15e8c742614b5D8Db4083A41Df1A14F5D2bFB400;

    // Constants
    uint256 internal constant X8 = 0xff;
    uint256 internal constant X10 = 0x3ff;
    uint256 internal constant X14 = 0x3fff;
    uint256 internal constant X15 = 0x7fff;
    uint256 internal constant X16 = 0xffff;
    uint256 internal constant X17 = 0x1ffff;
    uint256 internal constant X18 = 0x3ffff;
    uint256 internal constant X24 = 0xffffff;
    uint256 internal constant X64 = 0xffffffffffffffff;

    uint256 internal constant DEFAULT_EXPONENT_SIZE = 8;
    uint256 internal constant DEFAULT_EXPONENT_MASK = 0xff;

    constructor() {
        ADDRESS_THIS = address(this);
    }
}
