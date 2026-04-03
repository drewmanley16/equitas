// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console2} from "forge-std/Script.sol";
import {MockUSDC} from "../src/MockUSDC.sol";
import {SNAPSpender} from "../src/SNAPSpender.sol";

contract DeployScript is Script {
    function run() external {
        uint256 pk = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(pk);

        MockUSDC usdc = new MockUSDC();
        SNAPSpender spender = new SNAPSpender(vm.addr(pk), address(usdc));

        console2.log("MockUSDC:", address(usdc));
        console2.log("SNAPSpender:", address(spender));

        vm.stopBroadcast();
    }
}
