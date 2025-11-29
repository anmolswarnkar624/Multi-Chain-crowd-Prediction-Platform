// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title Multi-Chain Crowd Prediction Platform
 * @dev A decentralized prediction market platform where users can create markets,
 * place predictions, and earn rewards based on outcomes
 */
contract Project {
    
    struct Market {
        uint256 id;
        string question;
        address creator;
        uint256 endTime;
        uint256 totalYesStake;
        uint256 totalNoStake;
        bool resolved;
        bool outcome;
        uint256 createdAt;
    }
    
    struct Prediction {
        uint256 amount;
        bool predictedYes;
        bool claimed;
    }
    
    mapping(uint256 => Market) public markets;
    mapping(uint256 => mapping(address => Prediction)) public predictions;
    
    uint256 public marketCount;
    uint256 public platformFee = 2; // 2% platform fee
    address public owner;
    
    event MarketCreated(uint256 indexed marketId, string question, address creator, uint256 endTime);
    event PredictionPlaced(uint256 indexed marketId, address indexed predictor, uint256 amount, bool predictedYes);
    event MarketResolved(uint256 indexed marketId, bool outcome);
    event RewardsClaimed(uint256 indexed marketId, address indexed claimer, uint256 amount);
    
    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call this");
        _;
    }
    
    modifier marketExists(uint256 _marketId) {
        require(_marketId < marketCount, "Market does not exist");
        _;
    }
    
    constructor() {
        owner = msg.sender;
    }
    
    /**
     * @dev Core Function 1: Create a new prediction market
     * @param _question The question for the prediction market
     * @param _duration Duration in seconds until market closes
     */
    function createMarket(string memory _question, uint256 _duration) external returns (uint256) {
        require(_duration > 0, "Duration must be positive");
        require(bytes(_question).length > 0, "Question cannot be empty");
        
        uint256 marketId = marketCount;
        uint256 endTime = block.timestamp + _duration;
        
        markets[marketId] = Market({
            id: marketId,
            question: _question,
            creator: msg.sender,
            endTime: endTime,
            totalYesStake: 0,
            totalNoStake: 0,
            resolved: false,
            outcome: false,
            createdAt: block.timestamp
        });
        
        marketCount++;
        
        emit MarketCreated(marketId, _question, msg.sender, endTime);
        
        return marketId;
    }
    
    /**
     * @dev Core Function 2: Place a prediction on a market
     * @param _marketId The ID of the market
     * @param _predictYes True for YES prediction, False for NO prediction
     */
    function placePrediction(uint256 _marketId, bool _predictYes) external payable marketExists(_marketId) {
        Market storage market = markets[_marketId];
        
        require(block.timestamp < market.endTime, "Market has ended");
        require(!market.resolved, "Market already resolved");
        require(msg.value > 0, "Must stake some amount");
        require(predictions[_marketId][msg.sender].amount == 0, "Already predicted on this market");
        
        predictions[_marketId][msg.sender] = Prediction({
            amount: msg.value,
            predictedYes: _predictYes,
            claimed: false
        });
        
        if (_predictYes) {
            market.totalYesStake += msg.value;
        } else {
            market.totalNoStake += msg.value;
        }
        
        emit PredictionPlaced(_marketId, msg.sender, msg.value, _predictYes);
    }
    
    /**
     * @dev Core Function 3: Resolve market and allow winners to claim rewards
     * @param _marketId The ID of the market to resolve
     * @param _outcome The final outcome (true for YES, false for NO)
     */
    function resolveMarket(uint256 _marketId, bool _outcome) external marketExists(_marketId) {
        Market storage market = markets[_marketId];
        
        require(msg.sender == market.creator || msg.sender == owner, "Not authorized");
        require(block.timestamp >= market.endTime, "Market not ended yet");
        require(!market.resolved, "Already resolved");
        
        market.resolved = true;
        market.outcome = _outcome;
        
        emit MarketResolved(_marketId, _outcome);
    }
    
    /**
     * @dev Claim rewards after market is resolved
     * @param _marketId The ID of the market
     */
    function claimRewards(uint256 _marketId) external marketExists(_marketId) {
        Market storage market = markets[_marketId];
        Prediction storage prediction = predictions[_marketId][msg.sender];
        
        require(market.resolved, "Market not resolved yet");
        require(prediction.amount > 0, "No prediction found");
        require(!prediction.claimed, "Already claimed");
        require(prediction.predictedYes == market.outcome, "Prediction was incorrect");
        
        uint256 totalWinningStake = market.outcome ? market.totalYesStake : market.totalNoStake;
        uint256 totalLosingStake = market.outcome ? market.totalNoStake : market.totalYesStake;
        
        uint256 winnings = prediction.amount + 
                          (prediction.amount * totalLosingStake / totalWinningStake);
        
        uint256 fee = (winnings * platformFee) / 100;
        uint256 payout = winnings - fee;
        
        prediction.claimed = true;
        
        payable(msg.sender).transfer(payout);
        payable(owner).transfer(fee);
        
        emit RewardsClaimed(_marketId, msg.sender, payout);
    }
    
    /**
     * @dev Get market details
     */
    function getMarket(uint256 _marketId) external view marketExists(_marketId) returns (Market memory) {
        return markets[_marketId];
    }
    
    /**
     * @dev Get prediction details for a user
     */
    function getPrediction(uint256 _marketId, address _user) external view marketExists(_marketId) returns (Prediction memory) {
        return predictions[_marketId][_user];
    }
    
    /**
     * @dev Update platform fee (only owner)
     */
    function updatePlatformFee(uint256 _newFee) external onlyOwner {
        require(_newFee <= 10, "Fee cannot exceed 10%");
        platformFee = _newFee;
    }
}
