// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

/**
 * @title Stablecoin
 * @dev Yellow Wolf
 * @notice A simple ETH-collateralized stablecoin protocol. Users deposit ETH to mint stablecoins, redeem tokens for ETH, and liquidate undercollateralized positions. Uses Chainlink price feeds for ETH/USD.
 * @dev Not ERC20-compliant. For demonstration/educational use only. Not production-ready.
 */
interface AggregatorV3Interface {
    /**
     * @notice Returns the latest price data from Chainlink.
     */
    function latestRoundData() external view returns (
        uint80 roundId, int256 answer, uint256, uint256, uint80
    );
}

contract Stablecoin {
    /**
     * @notice ETH collateral deposited by each user.
     */
    mapping(address => uint256) public collateralEth;
    /**
     * @notice Stablecoins minted by each user.
     */
    mapping(address => uint256) public mintedTokens;

    uint256 public constant COLLATERAL_RATIO = 125; // 125% collateral
    uint256 public constant COLLATERAL_DENOM = 100;
    uint256 public constant TOKEN_DECIMALS = 1e18;

    /**
     * @notice Chainlink ETH/USD price feed.
     */
    AggregatorV3Interface public immutable ethUsdPriceFeed;

    string public name = "Stablecoin";
    string public symbol = "SC";
    uint8 public decimals = 18;
    uint256 public totalSupply;

    /**
     * @notice Stablecoin balances per user.
     */
    mapping(address => uint256) public balanceOf;

    /**
     * @notice Emitted when tokens are minted.
     */
    event Mint(address indexed user, uint256 ethAmount, uint256 tokenAmount);
    /**
     * @notice Emitted when tokens are redeemed.
     */
    event Redeem(address indexed user, uint256 ethAmount, uint256 tokenAmount);
    /**
     * @notice Emitted when a liquidation occurs.
     */
    event Liquidate(address indexed user, address indexed liquidator, uint256 seizedEth);
    /**
     * @notice Owner address (deployer).
     */
    address immutable Owner;

    /**
     * @param priceFeed Address of Chainlink ETH/USD price feed.
     */
    constructor(address priceFeed) {
        Owner = msg.sender; //The variable in left is to be set with value of right
        ethUsdPriceFeed = AggregatorV3Interface(priceFeed);
    }

    /**
     * @notice Get ETH price in USD (8 decimals).
     */
    function _getEthUsdPrice() internal view returns (uint256) {
        (, int256 price,,,) = ethUsdPriceFeed.latestRoundData();
        require(price > 0, "Invalid price");
        return uint256(price);
    }

    /**
     * @notice Mint stablecoin: deposit ETH, mint tokens.
     */
    function BUY() external payable {
        require(msg.value > 0, "No ETH sent");
        uint256 ethUsd = (msg.value * _getEthUsdPrice()) / 1e8;
        uint256 mintable = (ethUsd * COLLATERAL_DENOM) / COLLATERAL_RATIO;
        require(mintable > 0, "Not enough ETH");

        collateralEth[msg.sender] += msg.value;
        mintedTokens[msg.sender] += mintable * TOKEN_DECIMALS;
        balanceOf[msg.sender] += mintable * TOKEN_DECIMALS;
        totalSupply += mintable * TOKEN_DECIMALS;

        emit Mint(msg.sender, msg.value, mintable * TOKEN_DECIMALS);
    }

    /**
     * @notice Redeem: burn tokens, withdraw ETH if healthy.
     */
    function SELL(uint256 tokenAmount) external {
        require(balanceOf[msg.sender] >= tokenAmount, "Not enough tokens");
        require(mintedTokens[msg.sender] >= tokenAmount, "Not enough minted");
        uint256 ethToReturn = _getEthForTokens(tokenAmount);
        require(collateralEth[msg.sender] >= ethToReturn, "Not enough collateral");

        // Remove tokens & collateral
        balanceOf[msg.sender] -= tokenAmount;
        mintedTokens[msg.sender] -= tokenAmount;
        collateralEth[msg.sender] -= ethToReturn;
        totalSupply -= tokenAmount;

        // Check user is still healthy after withdrawal
        require(_isHealthy(msg.sender), "Would become undercollateralized");

        (bool sent, ) = msg.sender.call{value: ethToReturn}("");
        require(sent, "ETH send failed");

        emit Redeem(msg.sender, ethToReturn, tokenAmount);
    }

    /**
     * @notice Liquidate undercollateralized positions. 75% of seized ETH goes to owner, 25% to liquidator.
     */
    function liquidate(address user) external {
        require(!_isHealthy(user), "Not undercollateralized");
        uint256 seizedEth = collateralEth[user];
        collateralEth[user] = 0;
        totalSupply -= mintedTokens[user];
        balanceOf[user] = 0;
        mintedTokens[user] = 0;
        
        uint256 ownerShare = (seizedEth * 75) / 100;
        uint256 liquidatorShare = seizedEth - ownerShare;

        // Send seized ETH: 75% to owner, 25% to liquidator
        (bool sentOwner, ) = Owner.call{value: ownerShare}("");
        require(sentOwner, "ETH send to owner failed");
        (bool sentLiquidator, ) = msg.sender.call{value: liquidatorShare}("");
        require(sentLiquidator, "ETH send to liquidator failed");

        emit Liquidate(user, msg.sender, seizedEth);
    }

    /**
     * @notice Check if user is healthy (collateral > 125% of tokens).
     */
    function _isHealthy(address user) internal view returns (bool) {
        if (mintedTokens[user] == 0) return true;
        uint256 ethUsd = (collateralEth[user] * _getEthUsdPrice()) / 1e8;
        uint256 requiredCollateral = (mintedTokens[user] * COLLATERAL_RATIO) / COLLATERAL_DENOM / TOKEN_DECIMALS;
        return ethUsd >= requiredCollateral;
    }

    /**
     * @notice Helper: How much ETH is needed per token.
     */
    function _getEthForTokens(uint256 tokenAmount) internal view returns (uint256) {
        uint256 ethUsd = (tokenAmount * COLLATERAL_RATIO) / COLLATERAL_DENOM; // $1.25 per token
        // Convert $ to ETH
        uint256 price = _getEthUsdPrice();
        return (ethUsd * 1e8) / price;
    }

    /**
     * @notice Fallback: reverts to force use of BUY().
     */
    receive() external payable { revert("Use BUY()"); }
}