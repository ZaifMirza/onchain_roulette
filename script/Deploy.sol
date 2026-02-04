// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "forge-std/Script.sol";
import "../src/Rouletee.sol";

contract DeployRouletee is Script {
    function run() external {
        // Start broadcasting transactions
        vm.startBroadcast();

        // Deploy the Rouletee contract
        Rouletee roulette = new Rouletee();

        console.log("Rouletee deployed at:", address(roulette));

        // Stop broadcasting
        vm.stopBroadcast();
    }
}
