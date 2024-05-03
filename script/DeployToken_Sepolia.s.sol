// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import "./../src/Token.sol";

contract TokenDeployScript is Script {
    function setUp() public {}

    function run() public {
        vm.broadcast(vm.envUint("SEPOLIA_PK"));
        new Token();
    }
}
