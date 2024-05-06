// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {Token, IERC20} from "../src/Token.sol";
import {SablierV2Comptroller} from "@sablier/v2-core/src/SablierV2Comptroller.sol";
import {SablierV2LockupDynamic} from "@sablier/v2-core/src/SablierV2LockupDynamic.sol";
import {SablierV2LockupLinear} from "@sablier/v2-core/src/SablierV2LockupLinear.sol";
import {SablierV2NFTDescriptor} from "@sablier/v2-core/src/SablierV2NFTDescriptor.sol";
import {Errors} from "@sablier/v2-core/src/libraries/Errors.sol";
import {SablierV2Batch} from "@sablier/v2-periphery/src/SablierV2Batch.sol";
import {SablierV2MerkleStreamerFactory} from "@sablier/v2-periphery/src/SablierV2MerkleStreamerFactory.sol";
import {Lockup, LockupDynamic, Broker} from "@sablier/v2-core/src/types/DataTypes.sol";
import {ud60x18} from "@prb/math/src/UD60x18.sol";
import {ud2x18} from "@prb/math/src/UD2x18.sol";

contract SablierTest is Test {
    Token public token;
    SablierV2Comptroller sablierV2Comptroller = SablierV2Comptroller(0xb568f9Bc0dcE39B9B64e843bC19DA102B5E3E939);
    SablierV2LockupDynamic sablierV2LockupDynamic = SablierV2LockupDynamic(0x49d753422ff05daa291A9efa383E4f57daEAd889);
    SablierV2LockupLinear sablierV2LockupLinear = SablierV2LockupLinear(0x17c4f98c40e69a6A0D5c42B11E3733f076A99E20);
    SablierV2NFTDescriptor sablierV2NFTDescriptor = SablierV2NFTDescriptor(0xda55fB3E53b7d205e37B6bdCe990b789255e4302); 
    SablierV2Batch sablierV2Batch = SablierV2Batch(0x3eb9F8f80354a157315Fce64990C554434690c2f);
    SablierV2MerkleStreamerFactory sablierV2MerkleStreamerFactory = SablierV2MerkleStreamerFactory(0xdB07a1749D5Ca49909C7C4159652Fbd527c735B8);
    address owner = vm.addr(7368756837); // 0xF4C604d4b5B5f271085a59b24CC0a31C48788fdE
    address recipient = vm.addr(9384579384); // 0x47cb371758726A45dFba51CD9C834eAfb318e557
    uint streamId = 3;

    function setUp() public {
        vm.createSelectFork(vm.envString("PHEONIX_RPC_URL"), 79408828);

        vm.prank(owner);
        token = new Token();

        assertEq(token.totalSupply(), 100000 ether);

        vm.prank(owner);
        token.approve(address(sablierV2LockupDynamic), UINT256_MAX);

        vm.label(owner, "owner");
        vm.label(recipient, "recipient");
    }

    // should create vesting stream
    function testCreateVesting() public {
        LockupDynamic.CreateWithMilestones memory params = _getInputForFullVest();

        vm.prank(owner);
        streamId = sablierV2LockupDynamic.createWithMilestones(params);

        vm.warp(block.timestamp + 1);
        assertEq(sablierV2LockupDynamic.withdrawableAmountOf(streamId), 20000 ether);

        assertEq(address(sablierV2LockupDynamic.getAsset(streamId)), address(token));
        assertEq(sablierV2LockupDynamic.getStartTime(streamId), block.timestamp - 1);
        // assertEq(sablierV2LockupDynamic.getCliffTime(streamId), block.timestamp + 4 weeks);
        assertEq(sablierV2LockupDynamic.getEndTime(streamId), block.timestamp + 52 weeks - 1);
        assertEq(sablierV2LockupDynamic.getSender(streamId), owner);
        assertEq(sablierV2LockupDynamic.getRecipient(streamId), recipient);
        assertEq(uint256(sablierV2LockupDynamic.statusOf(streamId)), 1);
        assertEq(token.balanceOf(owner), 0);
        assertEq(token.balanceOf(recipient), 0);
    }

    function testUnlockCliffStream() public {
        testCreateVesting();

        LockupDynamic.Segment[] memory segments = sablierV2LockupDynamic.getSegments(streamId);

        vm.warp(segments[0].milestone);
        uint128 amount = sablierV2LockupDynamic.withdrawableAmountOf(streamId);
        assertEq(amount, 20000 ether);
        vm.prank(recipient);
        sablierV2LockupDynamic.withdraw(streamId, recipient, amount);

        vm.warp(segments[1].milestone - 1);
        assertEq(sablierV2LockupDynamic.withdrawableAmountOf(streamId), 0 ether);

        vm.warp(segments[1].milestone);
        assertEq(sablierV2LockupDynamic.withdrawableAmountOf(streamId), 0 ether);

        vm.warp(segments[1].milestone + 1);
        assertGt(sablierV2LockupDynamic.withdrawableAmountOf(streamId), 0 ether);

        vm.warp(segments[2].milestone);
        amount = sablierV2LockupDynamic.withdrawableAmountOf(streamId);
        assertEq(amount, 80000 ether);
        vm.prank(recipient);
        sablierV2LockupDynamic.withdraw(streamId, recipient, amount);
    }

    function testUnlockCliffStream(uint256 time) public {
        testCreateVesting();

        LockupDynamic.Segment[] memory segments = sablierV2LockupDynamic.getSegments(streamId);

        time = bound(time, segments[0].milestone, segments[2].milestone);

        vm.warp(time);
        uint128 amount = sablierV2LockupDynamic.withdrawableAmountOf(streamId);

        if (time <= segments[1].milestone) {
            assertEq(amount, 20000 ether);
        } else if (time >= segments[2].milestone) { 
            assertEq(amount, 100000 ether);
        } else {
            assertGt(amount, 20000 ether);
        }
    }

    // should withdraw some amount
    function testWithdrawAtMid() public returns (uint128 amount) {
        testCreateVesting();

        vm.warp(block.timestamp + 10 weeks);

        amount = sablierV2LockupDynamic.withdrawableAmountOf(streamId);

        vm.prank(recipient);
        sablierV2LockupDynamic.withdraw(streamId, recipient, amount);
    }

    // should withdraw complete amount
    function testWithdrawAtEnd() public returns (uint128 amount) {
        testCreateVesting();

        vm.warp(sablierV2LockupDynamic.getEndTime(streamId));

        amount = sablierV2LockupDynamic.withdrawableAmountOf(streamId);

        vm.prank(recipient);
        sablierV2LockupDynamic.withdraw(streamId, recipient, amount);
    }

    // withdarwble amount after final withdraw should be 0
    function testAmountAfterFinalWithdraw() public returns (uint128 amount) {
        testWithdrawAtEnd();

        vm.warp(sablierV2LockupDynamic.getEndTime(streamId) + 1);

        amount = sablierV2LockupDynamic.withdrawableAmountOf(streamId);

        assertEq(amount, 0);
    }

    // If end time passes amount left should still be withdrawable
    function testWithdrawAfterEnd() public returns (uint128 amount) {
        testCreateVesting();

        vm.warp(sablierV2LockupDynamic.getEndTime(streamId) + 1);

        amount = sablierV2LockupDynamic.withdrawableAmountOf(streamId);

        vm.prank(recipient);
        sablierV2LockupDynamic.withdraw(streamId, recipient, amount);

        assertEq(sablierV2LockupDynamic.withdrawableAmountOf(streamId), 0);
    }

    // should not allow overdraw
    function testOverdraw() public {
        uint128 amount = testWithdrawAtMid();

        vm.prank(recipient);
        vm.expectRevert(abi.encodeWithSelector(Errors.SablierV2Lockup_Overdraw.selector, streamId, amount+1, 0)); // stream id, amount requested, amount withdrawable, since last withdraw withdrawable  = 0 
        sablierV2LockupDynamic.withdraw(streamId, recipient, amount + 1);

        assertGt(token.balanceOf(recipient), 0);
    }

    function _getInputForFullVest() internal view returns(LockupDynamic.CreateWithMilestones memory params) {
        uint amount = 100000 ether;

        LockupDynamic.Segment[] memory segments = new LockupDynamic.Segment[](3);
        segments[0] = LockupDynamic.Segment({
            amount: uint128(20000e18), // 20%
            exponent: ud2x18(1 ether),
            milestone: uint40(block.timestamp + 1)
        });
        segments[1] = (
            LockupDynamic.Segment({
                amount: 0,
                exponent: ud2x18(1 ether), // the higher the exponent, the slower the stream.
                milestone: uint40(block.timestamp + 4 weeks)
            })
        );
        segments[2] = (
            LockupDynamic.Segment({
                amount: 80000e18,
                exponent: ud2x18(1 ether), // the higher the exponent, the slower the stream.
                milestone: uint40(block.timestamp + 52 weeks)
            })
        );

        return params = LockupDynamic.CreateWithMilestones({
            sender: owner,
            startTime: uint40(block.timestamp),
            cancelable: true,
            transferable: true,
            recipient: recipient,
            totalAmount: uint128(amount),
            asset: IERC20(address(token)),
            broker: Broker({
                account: address(0),
                fee: ud60x18(0)
            }),
            segments: segments
        });
    }
}
// https://sepolia.etherscan.io/tx/0xf6ff0d848e9c9ba67d5b6916fce8d5d9d426b822c90e52312f47affab445d117
// 20000.000000000000000000,1000000000000000000,1714851541, Sunday, May 5, 2024 12:39:01 AM
// 0,                       1000000000000000000,1717443540, Tuesday, June 4, 2024 12:39:00 AM
// 6593.404259303910360800, 1000000000000000000,1717443541, Tuesday, June 4, 2024 12:39:01 AM
// 73406.595740696089639200,1000000000000000000,1746301140, Sunday, May 4, 2025 12:39:00 AM

/**
 * As I said the formula is: cliffAmount - initialUnlockedAmount
 * the cliff amount is (totalAmount-initialUnlockAmount)*cliffDuration/totalDuration
 */