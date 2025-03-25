
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "https://github.com/openzeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC20/IERC20.sol";
import "https://github.com/pancakeswap/pancake-swap-periphery/blob/master/contracts/interfaces/IPancakeRouter02.sol";
import "https://github.com/Uniswap/v3-periphery/blob/main/contracts/interfaces/ISwapRouter.sol";
import "https://github.com/aave/aave-v3-core/blob/master/contracts/flashloan/base/FlashLoanSimpleReceiverBase.sol";
import "https://github.com/aave/aave-v3-core/blob/master/contracts/interfaces/IPoolAddressesProvider.sol";
contract SimpleFlashLoan is FlashLoanSimpleReceiverBase {
    address payable owner;
    address public USDC;
    address public another_token;
    address public pancakeV2;
    address public pancakeV3;
    uint24 public out;
    uint24 public time =30;
    uint24 public fee_v3;


    constructor(address _addressProvider,address _pancakeV3, address _pancakeV2, address _USDC, address _another_token,uint24 _fee3)
        FlashLoanSimpleReceiverBase(IPoolAddressesProvider(_addressProvider))
    {
    owner = payable(msg.sender);
    pancakeV2 = _pancakeV2;
    USDC = _USDC;
    pancakeV3 = _pancakeV3;
    fee_v3 = _fee3;
    another_token = _another_token;
    out = 95;
    }

    function fn_RequestFlashLoan(address _another_token,uint256 _amount,address _USDC,uint24 _fee3) public {  
        address receiverAddress = address(this);
        USDC = _USDC;
        address asset = USDC; 
        uint256 amount = uint256(_amount);
        bytes memory params = "";
        uint16 referralCode = 0;
        another_token =_another_token;  
        fee_v3 = _fee3;
        POOL.flashLoanSimple(
            receiverAddress,
            asset,
            amount,
            params,
            referralCode
        );
    }

    /////////////////////////////////////////////////////////////////


    function executeOperation(
        address asset, 
        uint256 amount, 
        uint256 premium, 
        address initiator, 
        bytes calldata params
    ) external override returns (bool) {
        address asset = USDC;
        uint256 amountOwed = amount + premium;


        require(IERC20(asset).approve(pancakeV2, amount), "Approval for PancakeSwap V2 failed");

        address[] memory path = new address[](2);
        path[0] = asset;
        path[1] = another_token;

        uint256[] memory amountsOutMin = IPancakeRouter02(pancakeV2).getAmountsOut(amount, path);
        uint256 amountOutMin = (amountsOutMin[1] * out) / 100; // 5% slippage

        uint256[] memory amounts = IPancakeRouter02(pancakeV2).swapExactTokensForTokens(
            amount,
            amountOutMin,
            path,
            address(this),
            block.timestamp
        );

        uint256 receivedAmount = amounts[1];
        require(receivedAmount > 0, "Swap in V2 failed - No tokens received");
  
        require(IERC20(another_token).approve(pancakeV3, receivedAmount), "Approval failed");        

        uint256 amo = 0;
        uint160 sqr = 0;

        uint256 finalAmount;
        try ISwapRouter(pancakeV3).exactInputSingle(
            ISwapRouter.ExactInputSingleParams({
                tokenIn: another_token,
                tokenOut: asset,
                fee: fee_v3,
                recipient: address(this),
                amountIn: receivedAmount,
                amountOutMinimum: amo,
                sqrtPriceLimitX96: sqr,
                deadline: block.timestamp + time
            })
        ) returns (uint256 _finalAmount) {
            finalAmount = _finalAmount; 
        } catch {
            revert("Swap in V3 failed - Try/Catch");
        }

        uint256 finalUSDCBalance = IERC20(asset).balanceOf(address(this));
        if (finalUSDCBalance < amountOwed) {
            revert("Insufficient funds to repay the loan");
        }

        try IERC20(asset).approve(address(POOL), amountOwed) {

        } catch {
            revert("Loan repayment approval failed");
        }

        return true;


    }



    /////////////////////////////////////////////////////////////////

    function changeUSDC(address USDC1) external  {
        USDC = USDC1;
    }

    function change_feee (uint24 _feee) external  {
        fee_v3 = _feee;
    }

    
    function change_out (uint24 _out) external  {
        out = _out;
    }

    function setAnotherTokenAddress(address _another_token1) external  {
        another_token = _another_token1;
    }

    function getBalance(address _tokenAddress) external view returns (uint256) {
        return IERC20(_tokenAddress).balanceOf(address(this));
    }

    function withdraw(address _tokenAddress) external  {
        IERC20 token = IERC20(_tokenAddress);
        token.transfer(msg.sender, token.balanceOf(address(this)));
    }

    function change_V2(address newAddress) external  {
        pancakeV2 = newAddress;
    }

    function change_V3(address _newAddress) external  {
        pancakeV3 = _newAddress;
    }

    function setTime(uint24 _newTime) external  {
    time = _newTime;
    }

    function withdraw_network_token(uint256 _amount, address payable _to) public  {
        require(address(this).balance >= _amount, "Not enough balance");
        (bool success, ) = _to.call{value: _amount}("");
        require(success, "Transfer failed");
    }

    function getBalance_network_token() public view returns (uint256) {
        return address(this).balance;
    }

    receive() external payable {}
}
