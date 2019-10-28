pragma solidity ^0.5.0; 

/*
   Rollo Base 
   This contract contains the factory which can instantiate 
   all contract wallets. 
   
   Author: Michael C 

*/


interface CToken {
    
    function redeemUnderlying(uint redeemAmount) external returns (uint); 
    function mint(uint amt)  external returns (uint); 
    function approve(address spender, uint256 tokens) external returns (bool success);
    function balanceOfUnderlying(address account) external returns (uint);
    function borrowBalanceCurrent(address account) external returns (uint);
    function borrow(uint borrowAmount) external returns (uint);
    function repayBorrow(uint repayAmount) external returns (uint);
    
}

interface CEther { 
  function repayBorrow() external payable;   
  function mint() external payable; 
    
}

interface CErc20 { 
    
    function totalSupply() external view returns (uint);
    function balanceOf(address tokenOwner) external view returns (uint balance);
    function allowance(address tokenOwner, address spender) external view returns (uint remaining);
    function transfer(address to, uint tokens) external returns (bool success);
    function approve(address spender, uint tokens) external returns (bool success);
    function transferFrom(address from, address to, uint tokens) external returns (bool success);
    
}

interface KyberSwapContract {
    function swapTokenToEther(CErc20 token, uint srcAmount, uint minConversionRate) external returns (uint);
    function swapEtherToToken(CErc20 token, uint minConversionRate)  external payable returns (uint);
    function swapTokenToToken(CErc20 src, uint srcAmount, CErc20 dest, uint minConversionRate) external returns (uint);
    function getExpectedRate(CErc20 src, CErc20 dest, uint srcQty) external returns (uint expectedRate, uint slippageRate);
}

interface Comptroller {
    function enterMarkets(address[] calldata cTokens)  external returns (uint[] memory) ;
    function getAccountLiquidity(address account) external returns (uint, uint, uint);

}

contract ContractType {
    enum OfferType { ShortETH,LongETH,ShortBTC,LongBTC }
    
    uint256 constant public MAX_UINT = 2**256 - 1;
    address public cDai = address(0x6D7F0754FFeb405d23C51CE938289d4835bE3b14);
    address public uDai = address(0x5592EC0cfb4dbc12D3aB100b257153436a1f0FEa); 
    address public cEther = address(0xd6801a1DfFCd0a410336Ef88DeF4320D6DF1883e);
    address public cBtc = address(0x0014F450B8Ae7708593F4A46F8fa6E5D50620F96);
    address public uBtc = address(0x577D296678535e4903D59A4C929B718e1D575e0A); 
    address public kyberInterface = address(0x8a57415F7099Af8bB3E4cbB0A73B64665DEB32f0); 
    address public magicEth = address(0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE);
    address public theComptroller = address(0x2EAa9D77AE4D8f9cdD9FAAcd44016E746485bddb);
    
    using DSMath for uint;
    
    uint public initialPrincipal; 
    uint public rolledAmount; 
    
    uint public times; 
    
    uint public valid; 
    uint public maintenance = 0.01 ether;
    
    address payable public creator; 
    address public factory; 
    
    OfferType public offerType; 
    
}

interface EnumOnly {
    enum OfferType { ShortETH,LongETH,ShortBTC,LongBTC }
}

library DSMath {
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

contract Factory is EnumOnly { 
     mapping (uint256 => address) public contracts;
     uint256 public contractCount;
     
     uint public netLongEth; 
     uint public netShortEth; 
     uint public netLongBtc; 
     uint public netShortBtc; 
     
     
     function createShortETHContract() public returns (address) { 
         address payable creator = msg.sender; 
        
       ShortETH fundingContract = new ShortETH(creator); 
       address fundingAddress = address(fundingContract); 
        
        contracts[contractCount] = fundingAddress;
        contractCount++; 
        netShortEth++; 
        
        emit ContractCreated(fundingAddress,creator,OfferType.ShortETH);
        return fundingAddress; 
     }
     
     function createLongETHContract() public returns (address) { 
         address payable creator = msg.sender; 
        
       LongETH fundingContract = new LongETH(creator); 
       address fundingAddress = address(fundingContract); 
        
        contracts[contractCount] = fundingAddress;
        contractCount++; 
        netLongEth++; 
        
        emit ContractCreated(fundingAddress,creator,OfferType.LongETH);
        return fundingAddress; 
     }
     
     function createShortBTCContract() public returns (address) { 
         address payable creator = msg.sender; 
        
         ShortBTC fundingContract = new ShortBTC(creator); 
         address fundingAddress = address(fundingContract); 
        
         contracts[contractCount] = fundingAddress;
         contractCount++; 
         netShortBtc++; 
        
         emit ContractCreated(fundingAddress,creator,OfferType.ShortBTC);
         return fundingAddress; 
     }
     
     function createLongBTCContract() public returns (address) { 
         address payable creator = msg.sender; 
        
         LongBTC fundingContract = new LongBTC(creator); 
         address fundingAddress = address(fundingContract); 
        
         contracts[contractCount] = fundingAddress;
         contractCount++; 
         netLongBtc++; 
        
         emit ContractCreated(fundingAddress,creator,OfferType.ShortBTC);
         return fundingAddress; 
     }
     
   
       event ContractCreated(address _contractwallet, address indexed _creator, OfferType indexed _type); 
      
}

contract ShortETH is ContractType { 
    
    constructor(address payable producer) public { 
        Comptroller troll = Comptroller(theComptroller); 
        creator = producer; 
        factory = msg.sender;
        offerType = OfferType.ShortETH;
        
        address[] memory markets = new address[](2);
        markets[0] = cDai; 
        markets[1] = cEther; 
        
        uint[] memory retVal  = troll.enterMarkets(markets);
        valid = retVal[0]; 
       
        CToken daiMint = CToken(cDai);
        CToken ethMint = CToken(cEther); 
        
        require(daiMint.approve(cDai,MAX_UINT) == true);
        require(ethMint.approve(cEther,MAX_UINT) == true); 
        
    }
    
    function initialDepositDai(uint256 daiAmt) public { 
         require (daiAmt > 0 && valid == 0); 
         require(msg.sender == creator); 
         
         //call into compound: 
         CToken compoundDai = CToken(cDai);
         CErc20 theDai = CErc20(uDai);
         initialPrincipal += daiAmt; 
       
         bool retVal = theDai.transferFrom(msg.sender,address(this),daiAmt);
       
         if (retVal == true) {
           theDai.approve(cDai, daiAmt); // approve the transfer
           require(compoundDai.mint(daiAmt) == 0);
          
        }
    }
    
    function rollToSupply() public { 
        require(msg.sender == creator);
        
        Comptroller troll = Comptroller(theComptroller);
        (uint error, uint liquidity, uint shortfall) = troll.getAccountLiquidity(address(this));
       
        require(error == 0, "join the Discord");
        require(shortfall == 0, "account underwater");
        require(liquidity > maintenance, "account has excess collateral");
        
        //TODO: Replace with Kyber (eth -> dai)   
        times++; 
        KyberSwapContract ky = KyberSwapContract(kyberInterface); 
        
       
        CToken ethMint = CToken(cEther); 
        uint retVal = ethMint.borrow(liquidity - maintenance);
        rolledAmount += (liquidity - maintenance); 
        
        if (retVal == 0) {
            CToken compoundDai = CToken(cDai);
            CErc20 theDai = CErc20(uDai);
            
            //Convert Ether to DAI: 
            uint receivedDai = ky.swapEtherToToken.value(liquidity - maintenance)(theDai,0);
             
           if (receivedDai > 0) {
             theDai.approve(cDai, receivedDai); // approve the transfer
             require(compoundDai.mint(receivedDai) == 0);
           }
        }
    }
    
    function widthdrawal(uint amount) public {
        require(msg.sender == creator);
        CToken compoundDai = CToken(cDai); 
        CErc20 theDai = CErc20(uDai); 
        
        uint retVal = compoundDai.redeemUnderlying(amount);
        
        if(retVal == 0) {
          require(theDai.transfer(msg.sender, amount) == true);
        }
    }
    
    function repay() public payable { 
        require(msg.sender == creator);
        require(msg.value > 0);
        
         CEther compoundEther = CEther(cEther);
         
         compoundEther.repayBorrow.value(msg.value);
        
    }
    
    function() external payable { 
        
    }
    
}

//LONG ETH 
contract LongETH is ContractType { 
   
    constructor(address payable producer) public { 
        Comptroller troll = Comptroller(theComptroller); 
        creator = producer; 
        factory = msg.sender;
        offerType = OfferType.LongETH;
        
        address[] memory markets = new address[](2);
        markets[0] = cDai; 
        markets[1] = cEther; 
        
        uint[] memory retVal  = troll.enterMarkets(markets);
        valid = retVal[0]; 
       
        CToken daiMint = CToken(cDai);
        CToken ethMint = CToken(cEther); 
        
        require(daiMint.approve(cDai,MAX_UINT) == true);
        require(ethMint.approve(cEther,MAX_UINT) == true); 
        
    }
    
    function initialDepositETH() public payable { 
        require (msg.value > 0 && valid == 0); 
        require(msg.sender == creator); 
        
        initialPrincipal += msg.value; 
        
        //call into compound: 
        CEther compoundETH = CEther(cEther);
        compoundETH.mint.value(msg.value)();
        
    }
    
    function rollToSupply() public { 
        require(msg.sender == creator);
        
        Comptroller troll = Comptroller(theComptroller);
        (uint error, uint liquidity, uint shortfall) = troll.getAccountLiquidity(address(this));
       
        require(error == 0, "join the Discord");
        require(shortfall == 0, "account underwater");
        require(liquidity > maintenance, "account has excess collateral");
        
        times++; 
        CToken daiMint = CToken(cDai); 
        CErc20 theDai = CErc20(uDai);
        CErc20 placeholder = CErc20(magicEth);
        
        KyberSwapContract ky = KyberSwapContract(kyberInterface); 
        (uint daiRate, uint slippage) = ky.getExpectedRate(theDai,placeholder,0);
        uint256 daiToTransfer = ((liquidity - maintenance) / daiRate) * 1e18; 
        
        uint retVal = daiMint.borrow(daiToTransfer);
        rolledAmount += daiToTransfer; 
        
        if (retVal == 0) {
            
            //Convert DAI to ether: 
            theDai.approve(kyberInterface,daiToTransfer);
            uint receivedEth = ky.swapTokenToEther(theDai,daiToTransfer,0);
             
           if (receivedEth > 0) {
             CEther compoundETH = CEther(cEther);
             compoundETH.mint.value(receivedEth)();
          
           }
        }
        
    }
    
     function widthdrawal(uint amount) public {
        require(msg.sender == creator);
        CToken cETH = CToken(cEther); 
       
        uint retVal = cETH.redeemUnderlying(amount);
        
        if(retVal == 0) {
          msg.sender.transfer(amount);
        }
    }
    
    function repay(uint amount) public { 
        require(msg.sender == creator);
         CToken compoundDai = CToken(cDai);
         CErc20 theDai = CErc20(uDai);
         
         bool retVal = theDai.transferFrom(msg.sender,address(this),amount);
       
         if (retVal == true) {
             require(compoundDai.repayBorrow(amount) == 0); 
         }
        
    }
    
     function() external payable { 
        
    }
}

//SHORT WBTC 
contract ShortBTC is ContractType {
   
    constructor(address payable producer) public { 
        Comptroller troll = Comptroller(theComptroller); 
        creator = producer; 
        factory = msg.sender;
        offerType = OfferType.ShortBTC;
        
        address[] memory markets = new address[](2);
        markets[0] = cDai; 
        markets[1] = cBtc; 
        
        uint[] memory retVal  = troll.enterMarkets(markets);
        valid = retVal[0]; 
       
        CToken daiMint = CToken(cDai);
        CToken btcMint = CToken(cBtc); 
        
        require(daiMint.approve(cDai,MAX_UINT) == true);
        require(btcMint.approve(cBtc,MAX_UINT) == true); 
        
    }
    
    function initialDepositDai(uint256 daiAmt) public { 
         require (daiAmt > 0 && valid == 0); 
         require(msg.sender == creator); 
         
         //call into compound: 
         CToken compoundDai = CToken(cDai);
         CErc20 theDai = CErc20(uDai);
         initialPrincipal += daiAmt; 
       
         bool retVal = theDai.transferFrom(msg.sender,address(this),daiAmt);
       
         if (retVal == true) {
           theDai.approve(cDai, daiAmt); // approve the transfer
           require(compoundDai.mint(daiAmt) == 0);
          
        }
    }
    
    function rollToSupply() public { 
        require(msg.sender == creator);
        
        Comptroller troll = Comptroller(theComptroller);
        (uint error, uint liquidity, uint shortfall) = troll.getAccountLiquidity(address(this));
       
        require(error == 0, "join the Discord");
        require(shortfall == 0, "account underwater");
        require(liquidity > maintenance, "account has excess collateral");
        
        times++; 
        CToken daiMint = CToken(cDai); 
        CErc20 theDai = CErc20(uDai);
        CErc20 placeholder = CErc20(magicEth);
        KyberSwapContract ky = KyberSwapContract(kyberInterface); 
        (uint daiRate, uint slippage) = ky.getExpectedRate(theDai,placeholder,0);
    
        uint256 btcExchange = 12600;
        uint256 daiToTransfer = ((liquidity - maintenance) / daiRate) * 1e18; 
        uint256 btcToTransfer = ((liquidity - maintenance) / daiRate) * btcExchange;
        
        CToken btcMint = CToken(cBtc); 
        uint retVal = btcMint.borrow(btcToTransfer);
        rolledAmount += btcToTransfer; 
        
        if (retVal == 0) {
            
          //Convert BTC to DAI: 
          CErc20 theBTC = CErc20(uBtc); 
          theBTC.approve(kyberInterface,btcToTransfer);
          uint receivedDai = ky.swapTokenToToken(theBTC,btcToTransfer,theDai,0);
          
       
           if (receivedDai > 0) {
             theDai.approve(cDai, receivedDai); // approve the transfer
             require(daiMint.mint(receivedDai) == 0);
           }
        }
    }
    
     function widthdrawal(uint amount) public {
        require(msg.sender == creator);
        CToken compoundDai = CToken(cDai); 
        CErc20 theDai = CErc20(uDai); 
        
        uint retVal = compoundDai.redeemUnderlying(amount);
        
        if(retVal == 0) {
          assert(theDai.transfer(msg.sender, amount) == true);
        }
    }
    
     function repay(uint amount) public { 
        require(msg.sender == creator);
         CToken compoundBtc = CToken(cBtc);
         CErc20 theBtc = CErc20(uBtc);
         
         bool retVal = theBtc.transferFrom(msg.sender,address(this),amount);
       
         if (retVal == true) {
             require(compoundBtc.repayBorrow(amount) == 0); 
         }
        
    }
    
}

//LONG WBTC 
contract LongBTC is ContractType {
    
    constructor(address payable producer) public { 
        Comptroller troll = Comptroller(theComptroller); 
        creator = producer; 
        factory = msg.sender;
        offerType = OfferType.LongBTC;
        
        address[] memory markets = new address[](2);
        markets[0] = cDai; 
        markets[1] = cBtc; 
        
        uint[] memory retVal  = troll.enterMarkets(markets);
        valid = retVal[0]; 
       
        CToken daiMint = CToken(cDai);
        CToken btcMint = CToken(cBtc); 
        
        require(daiMint.approve(cDai,MAX_UINT) == true);
        require(btcMint.approve(cBtc,MAX_UINT) == true); 
        
    }
    
    function initialDepositBTC(uint btcAmt) public {
         require (btcAmt > 0 && valid == 0); 
         require(msg.sender == creator); 
         
         //call into compound: 
         CToken compoundBTC = CToken(cBtc);
         CErc20 theBTC = CErc20(uBtc);
         initialPrincipal += btcAmt; 
       
         bool retVal = theBTC.transferFrom(msg.sender,address(this),btcAmt);
       
         if (retVal == true) {
           theBTC.approve(cBtc, btcAmt); // approve the transfer
           require(compoundBTC.mint(btcAmt) == 0);
          
        }
        
    }
    
    function rollToSupply() public { 
        require(msg.sender == creator);
        
        Comptroller troll = Comptroller(theComptroller);
        (uint error, uint liquidity, uint shortfall) = troll.getAccountLiquidity(address(this));
       
        require(error == 0, "join the Discord");
        require(shortfall == 0, "account underwater");
        require(liquidity > maintenance, "account has excess collateral");
        
        times++; 
        CToken daiMint = CToken(cDai); 
        CErc20 theDai = CErc20(uDai);
        CErc20 placeholder = CErc20(magicEth);
        KyberSwapContract ky = KyberSwapContract(kyberInterface); 
        (uint daiRate, uint slippage) = ky.getExpectedRate(theDai,placeholder,0);
    
        uint256 daiToTransfer = ((liquidity - maintenance) / daiRate) * 1e18; 
       
        CToken btcMint = CToken(cBtc); 
        uint retVal = daiMint.borrow(daiToTransfer);
        rolledAmount += daiToTransfer;
        
        if (retVal == 0) {
            
          //Convert DAI to BTC: 
          CErc20 theBTC = CErc20(uBtc); 
          theDai.approve(kyberInterface,daiToTransfer);
          uint receivedBtc = ky.swapTokenToToken(theDai,daiToTransfer,theBTC,0);
           
           if (receivedBtc > 0) {
             theBTC.approve(cBtc, receivedBtc); // approve the transfer
             require(btcMint.mint(receivedBtc) == 0);
           }
        }
    }
    
    function widthdrawal(uint amount) public {
        require(msg.sender == creator);
        CToken cBTC = CToken(cBtc); 
        CErc20 theBTC = CErc20(uBtc); 
        
        uint retVal = cBTC.redeemUnderlying(amount);
        
        if(retVal == 0) {
          assert(theBTC.transfer(msg.sender, amount) == true);
        }
    }
    
    function repay(uint amount) public { 
        require(msg.sender == creator);
         CToken compoundDai = CToken(cDai);
         CErc20 theDai = CErc20(uDai);
         
         bool retVal = theDai.transferFrom(msg.sender,address(this),amount);
       
         if (retVal == true) {
             require(compoundDai.repayBorrow(amount) == 0); 
         }
        
    }
}

