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
        
        // Dummy parameters for VRF; replace with real values when deploying live
        address vrfCoordinator = address(0);
        bytes32 keyHash = bytes32(0);
        uint64 subId = 0;

        // Deploy Roulette contract
        Roulette roulette = new Roulette(vrfCoordinator, keyHash, subId);
        
        console.log("Roulette contract deployed at:", address(roulette));
        console.log("Owner:", roulette.owner());
        console.log("Min bet:", roulette.minBet());
        console.log("Max bet:", roulette.maxBet());
        console.log("House edge (basis points):", roulette.houseEdge());

        vm.stopBroadcast();
    }
}
