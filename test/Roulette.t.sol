// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {Roulette} from "../src/Roulette.sol";

contract RouletteTest is Test {
    Roulette public roulette;
    address public owner;
    address public player1;
    address public player2;

    function setUp() public {
        owner = address(this);
        player1 = address(0x123);
        player2 = address(0x456);
        
        roulette = new Roulette();
        
        // Give test addresses some ETH
        vm.deal(player1, 10 ether);
        vm.deal(player2, 10 ether);
    }

    function test_deployment() public view {
        assertEq(roulette.owner(), owner);
        assertEq(roulette.minBet(), 0.00001 ether);
        assertEq(roulette.maxBet(), 1 ether);

        assertFalse(roulette.gameActive());
        assertEq(roulette.currentGameId(), 0);
    }

    function test_deposit() public {
        vm.prank(player1);
        roulette.deposit{value: 1 ether}();
        
        assertEq(roulette.playerBalances(player1), 1 ether);
    }

    function test_withdraw() public {
        // First deposit
        vm.prank(player1);
        roulette.deposit{value: 1 ether}();
        
        // Check contract has the ETH
        assertEq(address(roulette).balance, 1 ether);
        assertEq(roulette.playerBalances(player1), 1 ether);
        
        // Then withdraw
        vm.prank(player1);
        roulette.withdraw(0.5 ether);
        
        assertEq(roulette.playerBalances(player1), 0.5 ether);
        assertEq(address(roulette).balance, 0.5 ether);
    }

    function test_startGame() public {
        roulette.startGame();
        
        assertTrue(roulette.gameActive());
        assertEq(roulette.currentGameId(), 1);
    }

    function test_startGame_onlyOwner() public {
        vm.prank(player1);
        vm.expectRevert();
        roulette.startGame();
    }

    function test_betNumber() public {
        // Setup
        vm.prank(player1);
        roulette.deposit{value: 1 ether}();
        
        roulette.startGame();
        
        // Place bet
        vm.prank(player1);
        roulette.betNumber(7, 0.1 ether);
        
        assertEq(roulette.playerBalances(player1), 0.9 ether);
    }

    function test_betNumber_gameNotActive() public {
        vm.prank(player1);
        roulette.deposit{value: 1 ether}();
        
        vm.prank(player1);
        vm.expectRevert();
        roulette.betNumber(7, 0.1 ether);
    }

    function test_betNumber_invalidNumber() public {
        roulette.startGame();
        
        vm.prank(player1);
        roulette.deposit{value: 1 ether}();
        
        vm.prank(player1);
        vm.expectRevert();
        roulette.betNumber(37, 0.1 ether); // Invalid number > 36
    }

    function test_betRed() public {
        vm.prank(player1);
        roulette.deposit{value: 1 ether}();
        
        roulette.startGame();
        
        vm.prank(player1);
        roulette.betRed(0.1 ether);
        
        assertEq(roulette.playerBalances(player1), 0.9 ether);
    }

    function test_betTooLow() public {
        vm.prank(player1);
        roulette.deposit{value: 1 ether}();
        
        roulette.startGame();
        
        vm.prank(player1);
        vm.expectRevert();
        roulette.betNumber(7, 0.000001 ether); // Below minBet
    }

    function test_betTooHigh() public {
        vm.prank(player1);
        roulette.deposit{value: 10 ether}();
        
        roulette.startGame();
        
        vm.prank(player1);
        vm.expectRevert();
        roulette.betNumber(7, 2 ether); // Above maxBet
    }

    function test_spin_noActiveBets() public {
        roulette.startGame();
        
        vm.expectRevert();
        roulette.commitSeed(keccak256(abi.encodePacked(uint256(12345))));
    }

    function test_spin_onlyOwner() public {
        roulette.startGame();
        
        vm.prank(player1);
        roulette.deposit{value: 1 ether}();
        
        vm.prank(player1);
        roulette.betNumber(7, 0.1 ether);
        
        vm.prank(player1);
        vm.expectRevert();
        roulette.commitSeed(keccak256(abi.encodePacked(uint256(12345))));
    }

    function test_fullGameFlow() public {
        // Start game
        roulette.startGame();
        
        // Players deposit and bet
        vm.prank(player1);
        roulette.deposit{value: 1 ether}();
        
        vm.prank(player2);
        roulette.deposit{value: 1 ether}();
        
        vm.prank(player1);
        roulette.betRed(0.1 ether);
        
        vm.prank(player2);
        roulette.betNumber(7, 0.1 ether);
        
        // Commit and reveal (owner only)
        uint256 secretSeed = 12345;
        roulette.commitSeed(keccak256(abi.encodePacked(secretSeed)));
        roulette.revealSeed(secretSeed);
        
        // Game should be inactive after spin
        assertFalse(roulette.gameActive());
        
        // Check game result exists
        (uint256 winningNumber, bool isRed, uint256 timestamp, uint256 totalPayout) = roulette.gameResults(1);
        assertTrue(winningNumber <= 36);
        assertTrue(timestamp > 0);
    }

    function test_redNumbers() public view {
        // Test some known red numbers
        assertTrue(roulette.isRedNumber(1));
        assertTrue(roulette.isRedNumber(3));
        assertTrue(roulette.isRedNumber(5));
        assertTrue(roulette.isRedNumber(36));
        
        // Test some known black numbers
        assertFalse(roulette.isRedNumber(2));
        assertFalse(roulette.isRedNumber(4));
        assertFalse(roulette.isRedNumber(6));
        assertFalse(roulette.isRedNumber(0)); // Green
    }
}