// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "forge-std/Script.sol";
import {RealWorldItemNFT} from "../src/Logistics.sol";

contract DeployLogistics is Script {
    function run() external {
        vm.startBroadcast();
        RealWorldItemNFT logistics = new RealWorldItemNFT(msg.sender);
        vm.stopBroadcast();

        // log the address of the deployed contract
        console.log("Logistics contract deployed at:", address(logistics));
    }
}
