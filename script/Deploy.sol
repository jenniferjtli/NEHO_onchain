// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {Roulette} from "../src/Roulette.sol";

/**
 * Deploy script for Roulette contract
 * 
 * Usage:
 * forge script Deploy --rpc-url "https://sepolia.base.org" --account dev --sender $SENDER --broadcast -vvvv --verify --verifier-url "https://api-sepolia.basescan.org/api" --etherscan-api-key $BASESCAN_API_KEY
 */
contract Deploy is Script {
    function run() public {
        vm.startBroadcast();
        
        // Deploy Roulette contract
        Roulette roulette = new Roulette{value: 0.0001 ether}(); // Seed with 1 ETH house bankroll
        
        console.log("Roulette contract deployed at:", address(roulette));
        console.log("Owner:", roulette.owner());
        console.log("Min bet:", roulette.minBet());
        console.log("Max bet:", roulette.maxBet());
        console.log("House edge (basis points):", roulette.houseEdge());

        vm.stopBroadcast();
    }
}
