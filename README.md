# Stablecoin Smart Contract

A simple Ethereum-based stablecoin protocol written in Solidity. Users can deposit ETH as collateral to mint stablecoins, redeem stablecoins for ETH, and liquidate undercollateralized positions. The contract uses Chainlink price feeds for ETH/USD pricing.

## Features
- **Minting**: Deposit ETH to mint stablecoins at a 125% collateralization ratio.
- **Redeeming**: Burn stablecoins to withdraw ETH, as long as your position remains healthy.
- **Liquidation**: Anyone can liquidate undercollateralized positions. 75% of seized collateral goes to the contract owner, 25% to the liquidator.
- **Chainlink Oracle**: Uses Chainlink for secure ETH/USD price feeds.

## How It Works
1. **Mint (BUY)**: Send ETH to the contract using the `BUY()` function. You receive stablecoins based on the current ETH/USD price and the collateralization ratio.
2. **Redeem (SELL)**: Burn your stablecoins using the `SELL(uint256 tokenAmount)` function to withdraw ETH, provided your position remains healthy.
3. **Liquidate**: If a user's collateral falls below the required ratio, anyone can call `liquidate(address user)`. 75% of the seized ETH goes to the owner, 25% to the liquidator.

## Contract Details
- **Collateral Ratio**: 125%
- **Token Decimals**: 18
- **Price Feed**: Chainlink AggregatorV3Interface

## Deployment
1. Deploy the contract with the address of a Chainlink ETH/USD price feed.
2. The deployer becomes the contract owner.

## Example Usage
```solidity
// Mint stablecoins
Stablecoin.buy{value: 1 ether}();

// Redeem stablecoins
Stablecoin.sell(1000 * 1e18);

// Liquidate undercollateralized user
Stablecoin.liquidate(userAddress);
```

## Security Notes
- No ERC20 transfer/approve functions (not a full ERC20 token).
- No reentrancy protection (for demonstration only).
- Not production-ready. For educational purposes only.

## License
MIT


## Summarized Example of BUY

- First user suppose send $1.25 of eth, 25% of amount is as extra for security due to volatility(in this case $0.25) and $1 is collatraled for token

- Then the user will get 1 SC as its bounded by $1:1 token ratio 
