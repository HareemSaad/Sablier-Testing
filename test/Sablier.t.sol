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
import {Lockup, LockupLinear, Broker} from "@sablier/v2-core/src/types/DataTypes.sol";
import {ud60x18} from "@prb/math/src/UD60x18.sol";

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
        token.approve(address(sablierV2LockupLinear), UINT256_MAX);

        vm.label(owner, "owner");
        vm.label(recipient, "recipient");
    }

    // should create vesting stream
    function testCreateVesting() public {
        LockupLinear.CreateWithDurations memory params = _getInputForFullVest();

        vm.prank(owner);
        sablierV2LockupLinear.createWithDurations(params);

        assertEq(address(sablierV2LockupLinear.getAsset(streamId)), address(token));
        assertEq(sablierV2LockupLinear.getCliffTime(streamId), block.timestamp + 4 weeks);
        assertEq(sablierV2LockupLinear.getEndTime(streamId), block.timestamp + 52 weeks);
        assertEq(sablierV2LockupLinear.getSender(streamId), owner);
        assertEq(sablierV2LockupLinear.getRecipient(streamId), recipient);
        assertEq(uint256(sablierV2LockupLinear.statusOf(streamId)), 1);
        assertEq(token.balanceOf(owner), 0);
        assertEq(token.balanceOf(recipient), 0);
    }

    // should withdraw some amount
    function testWithdrawAtMid() public returns (uint128 amount) {
        testCreateVesting();

        vm.warp(sablierV2LockupLinear.getCliffTime(streamId));

        amount = sablierV2LockupLinear.withdrawableAmountOf(streamId);

        vm.prank(recipient);
        sablierV2LockupLinear.withdraw(streamId, recipient, amount);
    }

    // should withdraw complete amount
    function testWithdrawAtEnd() public returns (uint128 amount) {
        testCreateVesting();

        vm.warp(sablierV2LockupLinear.getEndTime(streamId));

        amount = sablierV2LockupLinear.withdrawableAmountOf(streamId);

        vm.prank(recipient);
        sablierV2LockupLinear.withdraw(streamId, recipient, amount);
    }

    // withdarwble amount after final withdraw should be 0
    function testAmountAfterFinalWithdraw() public returns (uint128 amount) {
        testWithdrawAtEnd();

        vm.warp(sablierV2LockupLinear.getEndTime(streamId) + 1);

        amount = sablierV2LockupLinear.withdrawableAmountOf(streamId);

        assertEq(amount, 0);
    }

    // If end time passes amount left should still be withdrawable
    function testWithdrawAfterEnd() public returns (uint128 amount) {
        testCreateVesting();

        vm.warp(sablierV2LockupLinear.getEndTime(streamId) + 1);

        amount = sablierV2LockupLinear.withdrawableAmountOf(streamId);

        vm.prank(recipient);
        sablierV2LockupLinear.withdraw(streamId, recipient, amount);

        assertEq(sablierV2LockupLinear.withdrawableAmountOf(streamId), 0);
    }

    // should not allow overdraw
    function testOverdraw() public {
        uint128 amount = testWithdrawAtMid();

        vm.prank(recipient);
        vm.expectRevert(abi.encodeWithSelector(Errors.SablierV2Lockup_Overdraw.selector, streamId, amount+1, 0)); // stream id, amount requested, amount withdrawable, since last withdraw withdrawable  = 0 
        sablierV2LockupLinear.withdraw(streamId, recipient, amount + 1);

        assertGt(token.balanceOf(recipient), 0);
    }

    function _getInputForFullVest() internal view returns(LockupLinear.CreateWithDurations memory params) {
        return params = LockupLinear.CreateWithDurations({
            sender: owner,
            recipient: recipient,
            totalAmount: 100000 ether,
            asset: IERC20(address(token)),
            cancelable: true,
            transferable: true,
            durations: LockupLinear.Durations({
                cliff: 4 weeks,
                total: 52 weeks // inclusive of cliff, so add cliff time
            }),
            broker: Broker({
                account: address(0),
                fee: ud60x18(0)
            })
        });
    }
}
