// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {Token} from "../src/Token.sol";
import {SablierV2Comptroller} from "@sablier/v2-core/src/SablierV2Comptroller.sol";
import {SablierV2LockupDynamic} from "@sablier/v2-core/src/SablierV2LockupDynamic.sol";
import {SablierV2LockupLinear} from "@sablier/v2-core/src/SablierV2LockupLinear.sol";
import {SablierV2NFTDescriptor} from "@sablier/v2-core/src/SablierV2NFTDescriptor.sol";
import {SablierV2Batch} from "@sablier/v2-periphery/src/SablierV2Batch.sol";
import {SablierV2MerkleStreamerFactory} from "@sablier/v2-periphery/src/SablierV2MerkleStreamerFactory.sol";

contract SablierTest is Test {
    Token public token;
    SablierV2Comptroller sablierV2Comptroller = SablierV2Comptroller(0xb568f9Bc0dcE39B9B64e843bC19DA102B5E3E939);
    SablierV2LockupDynamic sablierV2LockupDynamic = SablierV2LockupDynamic(0x49d753422ff05daa291A9efa383E4f57daEAd889);
    SablierV2LockupLinear sablierV2LockupLinear = SablierV2LockupLinear(0x17c4f98c40e69a6A0D5c42B11E3733f076A99E20);
    SablierV2NFTDescriptor sablierV2NFTDescriptor = SablierV2NFTDescriptor(0xda55fB3E53b7d205e37B6bdCe990b789255e4302); 
    SablierV2Batch sablierV2Batch = SablierV2Batch(0x3eb9F8f80354a157315Fce64990C554434690c2f);
    SablierV2MerkleStreamerFactory sablierV2MerkleStreamerFactory = SablierV2MerkleStreamerFactory(0xdB07a1749D5Ca49909C7C4159652Fbd527c735B8);

    function setUp() public {
        token = new Token();

        assertEq(token.totalSupply(), 100000 ether);
    }

    function test_Increment() public {
    }

    function testFuzz_SetNumber(uint256 x) public {
    }
}