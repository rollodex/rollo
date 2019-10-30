# Rollo
## Create leveraged products on Compound 



Rollo is a simple suite of Solidity contracts that allows you to create leverage on Compound finance by borrowing a target asset and converting it back to your principal asset. This wrap is handled automatically using an exchange intermediary (in this case Kyber). 

This leverage allows you to increase your interest earning potential and short/long exposure to the target asset. 
You can leverage as many times as you are allowed based on your collateralization ratio in Compound for that market, and add principal at any time to reduce risk of liquidation. 

### Rollo currently supports 4 market positions. 
  - Short ETH (supply dai / borrow eth)
  - Long ETH (supply eth / borrow dai) 
  - Short BTC (supply dai / borrow WBTC) 
  - Long BTC (supply WBTC / borrow DAI) 

### Tips
  - You can have multiple contract wallets with different amounts of leverage for any position
  - Don't borrow (leverage) more than you can repay or leverage too tightly to avoid liquidation
  - The UI always shows the latest values including interest accured. Refresh to see it update! 
  - Clicking a wallet lets you manage supply, widthdrawl, repayment, and rolling 

### Try It!
  - Live on the rinkeby network 
  - Clone the repo and open the html or run static server 
  - IPFS: [](https://gateway.ipfs.io/ipfs/QmcysEVwu7RCyh8vNxAY3p2HC3itmnNN16cbZDREMZcXuA/)
