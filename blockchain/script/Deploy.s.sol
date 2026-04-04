// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console2} from "forge-std/Script.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {MockUSDC} from "../src/MockUSDC.sol";
import {SNAPSpender} from "../src/SNAPSpender.sol";

contract DeployScript is Script {
    function run() external {
        uint256 pk = vm.envUint("PRIVATE_KEY");
        address admin = vm.addr(pk);
        vm.startBroadcast(pk);

        MockUSDC usdc = new MockUSDC();
        SNAPSpender spender = new SNAPSpender(admin, address(usdc));

        // Machine-friendly lines for bash parsers (run-local-arc-demo, deploy-local-contracts)
        console2.log(string.concat("SNAP_SPENDER_ADDRESS=", Strings.toHexString(uint256(uint160(address(spender))), 20)));
        console2.log(string.concat("USDC_ADDRESS=", Strings.toHexString(uint256(uint160(address(usdc))), 20)));
        console2.log(string.concat("ADMIN_ADDRESS=", Strings.toHexString(uint256(uint160(admin)), 20)));

        vm.stopBroadcast();
    }
}
