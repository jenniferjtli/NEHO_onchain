// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

/// @notice A decentralized roulette game contract
contract Roulette {
    // Bet types
    enum BetType {
        Number,     // Single number (0-36)
        Red,        // Red color
        Black,      // Black color
        Odd,        // Odd numbers
        Even,       // Even numbers
        Low,        // 1-18
        High,       // 19-36
        Dozen1,     // 1-12
        Dozen2,     // 13-24
        Dozen3,     // 25-36
        Column1,    // 1,4,7,10,13,16,19,22,25,28,31,34
        Column2,    // 2,5,8,11,14,17,20,23,26,29,32,35
        Column3     // 3,6,9,12,15,18,21,24,27,30,33,36
    }

    struct Bet {
        address player;
        BetType betType;
        uint256 number; // Only used for Number bets
        uint256 amount;
        bool settled;
    }

    struct GameResult {
        uint256 winningNumber;
        bool isRed;
        uint256 timestamp;
        uint256 totalPayout;
    }

    address public owner;
    uint256 public houseEdge = 275; // 2.75% (275 basis points)
    uint256 public constant BASIS_POINTS = 10000;
    uint256 public minBet = 0.001 ether;
    uint256 public maxBet = 1 ether;
    
    uint256 public currentGameId;
    bool public gameActive;
    
    // Red numbers in roulette
    mapping(uint256 => bool) public isRedNumber;
    
    // Game data
    mapping(uint256 => Bet[]) public gameBets;
    mapping(uint256 => GameResult) public gameResults;
    mapping(address => uint256) public playerBalances;
    
    // Events
    event BetPlaced(uint256 indexed gameId, address indexed player, BetType betType, uint256 number, uint256 amount);
    event GameResult(uint256 indexed gameId, uint256 winningNumber, bool isRed, uint256 totalPayout);
    event Payout(address indexed player, uint256 amount);
    event GameStarted(uint256 indexed gameId);
    event FundsDeposited(address indexed player, uint256 amount);
    event FundsWithdrawn(address indexed player, uint256 amount);

    // Errors
    error NotOwner();
    error GameNotActive();
    error GameAlreadyActive();
    error BetTooLow();
    error BetTooHigh();
    error InsufficientBalance();
    error InvalidNumber();
    error NoActiveBets();
    error BetsAlreadySettled();

    constructor() {
        owner = msg.sender;
        
        // Initialize red numbers (European roulette)
        uint256[18] memory redNumbers = [1, 3, 5, 7, 9, 12, 14, 16, 18, 19, 21, 23, 25, 27, 30, 32, 34, 36];
        for (uint256 i = 0; i < redNumbers.length; i++) {
            isRedNumber[redNumbers[i]] = true;
        }
    }

    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner();
        _;
    }

    /// @notice Deposit funds to play
    function deposit() external payable {
        playerBalances[msg.sender] += msg.value;
        emit FundsDeposited(msg.sender, msg.value);
    }

    /// @notice Withdraw funds from balance
    function withdraw(uint256 amount) external {
        if (playerBalances[msg.sender] < amount) revert InsufficientBalance();
        
        playerBalances[msg.sender] -= amount;
        payable(msg.sender).transfer(amount);
        
        emit FundsWithdrawn(msg.sender, amount);
    }

    /// @notice Start a new game
    function startGame() external onlyOwner {
        if (gameActive) revert GameAlreadyActive();
        
        gameActive = true;
        currentGameId++;
        
        emit GameStarted(currentGameId);
    }

    /// @notice Place a bet on a specific number (0-36)
    function betNumber(uint256 number, uint256 amount) external {
        if (!gameActive) revert GameNotActive();
        if (number > 36) revert InvalidNumber();
        
        _placeBet(BetType.Number, number, amount);
    }

    /// @notice Place a bet on red
    function betRed(uint256 amount) external {
        if (!gameActive) revert GameNotActive();
        _placeBet(BetType.Red, 0, amount);
    }

    /// @notice Place a bet on black
    function betBlack(uint256 amount) external {
        if (!gameActive) revert GameNotActive();
        _placeBet(BetType.Black, 0, amount);
    }

    /// @notice Place a bet on odd numbers
    function betOdd(uint256 amount) external {
        if (!gameActive) revert GameNotActive();
        _placeBet(BetType.Odd, 0, amount);
    }

    /// @notice Place a bet on even numbers
    function betEven(uint256 amount) external {
        if (!gameActive) revert GameNotActive();
        _placeBet(BetType.Even, 0, amount);
    }

    /// @notice Place a bet on low numbers (1-18)
    function betLow(uint256 amount) external {
        if (!gameActive) revert GameNotActive();
        _placeBet(BetType.Low, 0, amount);
    }

    /// @notice Place a bet on high numbers (19-36)
    function betHigh(uint256 amount) external {
        if (!gameActive) revert GameNotActive();
        _placeBet(BetType.High, 0, amount);
    }

    /// @notice Spin the wheel and settle bets
    function spin() external onlyOwner {
        if (!gameActive) revert GameNotActive();
        if (gameBets[currentGameId].length == 0) revert NoActiveBets();
        
        // Generate random number (0-36)
        uint256 winningNumber = _generateRandomNumber();
        bool isRed = isRedNumber[winningNumber];
        
        // Settle all bets
        uint256 totalPayout = _settleBets(winningNumber, isRed);
        
        // Store result
        gameResults[currentGameId] = GameResult({
            winningNumber: winningNumber,
            isRed: isRed,
            timestamp: block.timestamp,
            totalPayout: totalPayout
        });
        
        gameActive = false;
        
        emit GameResult(currentGameId, winningNumber, isRed, totalPayout);
    }

    /// @notice Internal function to place a bet
    function _placeBet(BetType betType, uint256 number, uint256 amount) internal {
        if (amount < minBet) revert BetTooLow();
        if (amount > maxBet) revert BetTooHigh();
        if (playerBalances[msg.sender] < amount) revert InsufficientBalance();
        
        playerBalances[msg.sender] -= amount;
        
        gameBets[currentGameId].push(Bet({
            player: msg.sender,
            betType: betType,
            number: number,
            amount: amount,
            settled: false
        }));
        
        emit BetPlaced(currentGameId, msg.sender, betType, number, amount);
    }

    /// @notice Generate a random number (simplified - in production use VRF)
    function _generateRandomNumber() internal view returns (uint256) {
        return uint256(keccak256(abi.encodePacked(
            block.timestamp,
            block.difficulty,
            msg.sender,
            currentGameId
        ))) % 37;
    }

    /// @notice Settle all bets for the current game
    function _settleBets(uint256 winningNumber, bool isRed) internal returns (uint256 totalPayout) {
        Bet[] storage bets = gameBets[currentGameId];
        
        for (uint256 i = 0; i < bets.length; i++) {
            Bet storage bet = bets[i];
            if (bet.settled) continue;
            
            uint256 payout = _calculatePayout(bet, winningNumber, isRed);
            
            if (payout > 0) {
                playerBalances[bet.player] += payout;
                totalPayout += payout;
                emit Payout(bet.player, payout);
            }
            
            bet.settled = true;
        }
    }

    /// @notice Calculate payout for a bet
    function _calculatePayout(Bet memory bet, uint256 winningNumber, bool isRed) internal pure returns (uint256) {
        bool wins = false;
        uint256 multiplier = 0;
        
        if (bet.betType == BetType.Number && bet.number == winningNumber) {
            wins = true;
            multiplier = 35; // 35:1
        } else if (bet.betType == BetType.Red && isRed && winningNumber != 0) {
            wins = true;
            multiplier = 1; // 1:1
        } else if (bet.betType == BetType.Black && !isRed && winningNumber != 0) {
            wins = true;
            multiplier = 1; // 1:1
        } else if (bet.betType == BetType.Odd && winningNumber % 2 == 1 && winningNumber != 0) {
            wins = true;
            multiplier = 1; // 1:1
        } else if (bet.betType == BetType.Even && winningNumber % 2 == 0 && winningNumber != 0) {
            wins = true;
            multiplier = 1; // 1:1
        } else if (bet.betType == BetType.Low && winningNumber >= 1 && winningNumber <= 18) {
            wins = true;
            multiplier = 1; // 1:1
        } else if (bet.betType == BetType.High && winningNumber >= 19 && winningNumber <= 36) {
            wins = true;
            multiplier = 1; // 1:1
        }
        
        if (wins) {
            uint256 payoutBeforeEdge = bet.amount * multiplier;   // gross winnings
            uint256 rake = payoutBeforeEdge * houseEdge / BASIS_POINTS;  // house’s cut
            return bet.amount + payoutBeforeEdge - rake;          // net payout to player
        }
        
        return 0;
    }

    /// @notice Get game bets
    function getGameBets(uint256 gameId) external view returns (Bet[] memory) {
        return gameBets[gameId];
    }

    /// @notice Update house edge (only owner)
    function setHouseEdge(uint256 newHouseEdge) external onlyOwner {
        houseEdge = newHouseEdge;
    }

    /// @notice Update bet limits (only owner)
    function setBetLimits(uint256 newMinBet, uint256 newMaxBet) external onlyOwner {
        minBet = newMinBet;
        maxBet = newMaxBet;
    }

    /// @notice Withdraw house funds (only owner)
    function withdrawHouseFunds(uint256 amount) external onlyOwner {
        payable(owner).transfer(amount);
    }

    /// @notice Receive function to accept ETH
    receive() external payable {
        // Allow contract to receive ETH
    }
}
