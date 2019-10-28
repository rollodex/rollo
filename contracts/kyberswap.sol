pragma solidity ^0.5.0; 

/*
   Mock KyberSwap
   This contract simulates a Kyber exchange
   Deployed: 0x8a57415F7099Af8bB3E4cbB0A73B64665DEB32f0 (rinkeby)
   Author: Michael C
*/


interface CErc20 { 
    
    function totalSupply() external view returns (uint);
    function balanceOf(address tokenOwner) external view returns (uint balance);
    function allowance(address tokenOwner, address spender) external view returns (uint remaining);
    function transfer(address to, uint tokens) external returns (bool success);
    function approve(address spender, uint tokens) external returns (bool success);
    function transferFrom(address from, address to, uint tokens) external returns (bool success);
    
}


contract DSMath {
    function add(uint x, uint y) internal pure returns (uint z) {
        require((z = x + y) >= x, "ds-math-add-overflow");
    }
    function sub(uint x, uint y) internal pure returns (uint z) {
        require((z = x - y) <= x, "ds-math-sub-underflow");
    }
    function mul(uint x, uint y) internal pure returns (uint z) {
        require(y == 0 || (z = x * y) / y == x, "ds-math-mul-overflow");
    }

    function min(uint x, uint y) internal pure returns (uint z) {
        return x <= y ? x : y;
    }
    function max(uint x, uint y) internal pure returns (uint z) {
        return x >= y ? x : y;
    }
    function imin(int x, int y) internal pure returns (int z) {
        return x <= y ? x : y;
    }
    function imax(int x, int y) internal pure returns (int z) {
        return x >= y ? x : y;
    }

    uint constant WAD = 10 ** 18;
    uint constant RAY = 10 ** 27;

    function wmul(uint x, uint y) internal pure returns (uint z) {
        z = add(mul(x, y), WAD / 2) / WAD;
    }
    function rmul(uint x, uint y) internal pure returns (uint z) {
        z = add(mul(x, y), RAY / 2) / RAY;
    }
    function wdiv(uint x, uint y) internal pure returns (uint z) {
        z = add(mul(x, WAD), y / 2) / y;
    }
    function rdiv(uint x, uint y) internal pure returns (uint z) {
        z = add(mul(x, RAY), y / 2) / y;
    }

    // This famous algorithm is called "exponentiation by squaring"
    // and calculates x^n with x as fixed-point and n as regular unsigned.
    //
    // It's O(log n), instead of O(n) for naive repeated multiplication.
    //
    // These facts are why it works:
    //
    //  If n is even, then x^n = (x^2)^(n/2).
    //  If n is odd,  then x^n = x * x^(n-1),
    //   and applying the equation for even x gives
    //    x^n = x * (x^2)^((n-1) / 2).
    //
    //  Also, EVM division is flooring and
    //    floor[(n-1) / 2] = floor[n / 2].
    //
    function rpow(uint x, uint n) internal pure returns (uint z) {
        z = n % 2 != 0 ? x : RAY;

        for (n /= 2; n != 0; n /= 2) {
            x = rmul(x, x);

            if (n % 2 != 0) {
                z = rmul(z, x);
            }
        }
    }
}

contract KyberSwapContract is DSMath {
    
    address public daiAddress = address(0x5592EC0cfb4dbc12D3aB100b257153436a1f0FEa); 
    address public wbtcAddress = address(0x577D296678535e4903D59A4C929B718e1D575e0A);
    address public magicEth = address(0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE);
    
    uint public daiExchange = 0.0058 ether;
    uint public daiToETH = 177 ether; 
    uint public daiToBTC = 7444 ether; 
    
    //uint public wbtcExchange = 0.000126 ether; 
    
    function getExpectedRate(CErc20 src, CErc20 dest, uint srcQty) public view returns (uint expectedRate, uint slippageRate) {
        uint slippage = 0; 
        uint rate = 0; 
        address token1 = address(src); 
        address token2 = address(dest); 
        
        if (token2 == magicEth && token1 == daiAddress) {
            rate = daiExchange; 
        } 
        
        if (token2 == wbtcAddress && token1 == daiAddress) {
            rate = daiToBTC; 
        }
        
        if (token1 == daiAddress && token2 == wbtcAddress) {
            rate = daiToBTC; 
        }
        
        return (rate, slippage); 
    }
    
    //DAI -> ETH 
    function swapTokenToEther(CErc20 token, uint srcAmount, uint minConversionRate) public returns (uint) {
        
        address tokenAddress = address(token); 
        require (tokenAddress == daiAddress || tokenAddress == wbtcAddress); 
        uint ethToSend = 0; 
        
        if (tokenAddress == daiAddress ) { 
            token.transferFrom(msg.sender, address(this), srcAmount); 
            
            ethToSend = wdiv(srcAmount,daiToETH); 
            
            msg.sender.transfer(ethToSend); 
            
        } 
        
        return ethToSend; 
    }
    
    //ETH -> DAI 
    function swapEtherToToken(CErc20 token, uint minConversionRate) public payable returns (uint) {
        require (msg.value > 0); 
        uint daiToSend = 0; 
        
        address tokenAddress = address(token);
        
        if (tokenAddress == daiAddress) { 
            daiToSend = wdiv(msg.value,daiExchange);
            token.transfer(msg.sender, daiToSend); 
        } 
        
        return daiToSend;
    }
    
    //DAI -> WBTC 
    //WBTC -> DAI 
    function swapTokenToToken(CErc20 src, uint srcAmount, CErc20 dest, uint minConversionRate) public returns (uint) {
        address token1 = address(src); 
        address token2 = address(dest); 
        require (token1 == daiAddress || token1 == wbtcAddress); 
        require (token2 == daiAddress || token2 == wbtcAddress); 
        uint amtToSend = 0; 
        src.transferFrom(msg.sender, address(this), srcAmount); 
        
        if (token1 == daiAddress && token2 == wbtcAddress) {
            amtToSend = wdiv(srcAmount,daiToBTC);
            amtToSend /= 10**10; 
            
        } else if (token1 == wbtcAddress && token2 == daiAddress) { 
            //amtToSend = srcAmount * 10**18; 
            amtToSend = wmul(srcAmount,daiToBTC);
            amtToSend *= 10**10;
            
        }
        
        dest.transfer(msg.sender,amtToSend);
        return amtToSend; 
    }
    
    function() external payable { 
        
    }
}
