// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface IAssetFareXLayerSeiSonicUSDC {
    function decimals() external view returns (uint8);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address to,uint256 amount) external returns (bool);
    function transferFrom(address from,address to,uint256 amount) external returns (bool);
    function approve(address spender,uint256 amount) external returns (bool);
}

interface IAssetFareXLayerSeiSonicTokenMessengerV2 {
    function depositForBurnWithHook(
        uint256 amount,uint32 destinationDomain,bytes32 mintRecipient,address burnToken,
        bytes32 destinationCaller,uint256 maxFee,uint32 minFinalityThreshold,bytes calldata hookData
    ) external;
}

/// @notice Ownerless exact-1bp native-USDC CCTP V2 forwarding executor for
/// X Layer, Sei and Sonic sources to Base or Solana only.
/// @dev The caller retains custody and signs/submits every transaction. Dated
/// economic guidance is not an execution boundary.
contract AssetFareXLayerSeiSonicCctpExecutorV1 {
    IAssetFareXLayerSeiSonicUSDC public immutable USDC;
    IAssetFareXLayerSeiSonicTokenMessengerV2 public immutable TOKEN_MESSENGER;
    address public immutable FEE_RECIPIENT;
    uint32 public immutable SOURCE_DOMAIN;
    uint256 public constant ROUTE_FEE_BPS=1;
    uint256 public constant MAX_DEADLINE_WINDOW=300;
    bytes32 public constant FORWARD_EXISTING_RECIPIENT=0x636374702d666f72776172640000000000000000000000000000000000000000;
    bytes32 public constant FORWARD_SETUP_HEAD=0x636374702d666f72776172640000000000000000000000000000000000000021;
    uint256 private locked=1;

    event DirectCctpBurn(
        address indexed caller,uint32 indexed destinationDomain,bytes32 indexed mintRecipient,
        uint256 inputUSDC,uint256 feeUSDC,uint256 burnUSDC,uint256 maxCctpFee,
        uint32 minFinalityThreshold
    );

    constructor(address usdc,address tokenMessenger,address feeRecipient,uint32 sourceDomain) {
        require(usdc!=address(0)&&tokenMessenger!=address(0)&&feeRecipient!=address(0),"zero address");
        require(
            (block.chainid==196&&sourceDomain==37)||
            (block.chainid==1329&&sourceDomain==16)||
            (block.chainid==146&&sourceDomain==13),
            "source chain/domain"
        );
        require(IAssetFareXLayerSeiSonicUSDC(usdc).decimals()==6,"USDC decimals");
        USDC=IAssetFareXLayerSeiSonicUSDC(usdc);
        TOKEN_MESSENGER=IAssetFareXLayerSeiSonicTokenMessengerV2(tokenMessenger);
        FEE_RECIPIENT=feeRecipient;
        SOURCE_DOMAIN=sourceDomain;
    }

    modifier nonReentrant(){require(locked==1,"reentrant");locked=2;_;locked=1;}
    modifier beforeDeadline(uint256 deadline){
        require(block.timestamp<=deadline&&deadline<=block.timestamp+MAX_DEADLINE_WINDOW,"invalid deadline");
        _;
    }

    function bridgeUSDC(
        uint256 amountIn,uint32 destinationDomain,bytes32 mintRecipient,bytes32 destinationCaller,
        uint256 maxCctpFee,uint32 minFinalityThreshold,bytes calldata hookData,uint256 deadline
    ) external nonReentrant beforeDeadline(deadline) returns(uint256 burnUSDC) {
        require(destinationDomain==5||destinationDomain==6,"unsupported destination");
        require(mintRecipient!=bytes32(0),"zero recipient");
        require(
            (SOURCE_DOMAIN==37&&minFinalityThreshold==1000)||
            ((SOURCE_DOMAIN==16||SOURCE_DOMAIN==13)&&minFinalityThreshold==2000),
            "invalid source finality"
        );
        _validateForwardHook(hookData);
        uint256 routeFee=amountIn/10_000;
        burnUSDC=amountIn-routeFee;
        require(routeFee>0&&burnUSDC>maxCctpFee&&maxCctpFee<=burnUSDC/100,"CCTP fee out of range");
        uint256 beforeBalance=USDC.balanceOf(address(this));
        _transferFrom(msg.sender,address(this),amountIn);
        _approve(address(TOKEN_MESSENGER),burnUSDC);
        TOKEN_MESSENGER.depositForBurnWithHook(
            burnUSDC,destinationDomain,mintRecipient,address(USDC),destinationCaller,
            maxCctpFee,minFinalityThreshold,hookData
        );
        _approve(address(TOKEN_MESSENGER),0);
        _transfer(FEE_RECIPIENT,routeFee);
        require(USDC.balanceOf(address(this))==beforeBalance,"retained USDC");
        _emitBurn(
            destinationDomain,mintRecipient,amountIn,routeFee,burnUSDC,maxCctpFee,
            minFinalityThreshold
        );
    }

    function _validateForwardHook(bytes calldata hookData) private pure {
        bytes32 head;
        assembly{head:=calldataload(hookData.offset)}
        require(
            (hookData.length==32&&head==FORWARD_EXISTING_RECIPIENT)||
            (hookData.length==65&&head==FORWARD_SETUP_HEAD&&uint8(hookData[32])==1),
            "invalid forward hook"
        );
    }
    function _emitBurn(
        uint32 destinationDomain,bytes32 mintRecipient,uint256 amountIn,uint256 routeFee,
        uint256 burnUSDC,uint256 maxCctpFee,uint32 minFinalityThreshold
    ) private {
        emit DirectCctpBurn(
            msg.sender,destinationDomain,mintRecipient,amountIn,routeFee,burnUSDC,
            maxCctpFee,minFinalityThreshold
        );
    }
    function _approve(address spender,uint256 amount) private {require(USDC.approve(spender,amount),"approve");}
    function _transfer(address to,uint256 amount) private {require(USDC.transfer(to,amount),"transfer");}
    function _transferFrom(address from,address to,uint256 amount) private {require(USDC.transferFrom(from,to,amount),"transferFrom");}
}
