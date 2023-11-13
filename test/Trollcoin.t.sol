// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "forge-std/Test.sol";
import {TrollCoin} from "../src/Trollcoin.sol";

contract TrollcoinTest is Test {
    TrollCoin public trollcoin;

    struct Defense {
        uint256 amount;
        uint256 startDefenseTime;
    }

    address public constant DEPLOYER = address(1);
    address public constant ATTACKER = address(0xBEEF);
    address public constant DEFENDER = address(0xDEAD);
    address public constant RANDO = address(4);

    uint256 public constant TOTAL_SUPPLY = 1e18;

    function setUp() public {
        vm.startPrank(DEPLOYER);
        trollcoin = new TrollCoin(TOTAL_SUPPLY, 800);
        trollcoin.transfer(DEFENDER, 10000000);
        trollcoin.transfer(ATTACKER, 10000000);
    }

    function testOwner() public view {
        assert(trollcoin.owner() == DEPLOYER);
    }

    function testBalance() public view {
        assert(trollcoin.balanceOf(DEPLOYER) == TOTAL_SUPPLY - (10000000 * 2));
        assert(trollcoin.balanceOf(DEFENDER) == 10000000);
        assert(trollcoin.balanceOf(ATTACKER) == 10000000);
    }

    function testTransfer() public {
        vm.startPrank(ATTACKER);
        uint256 balance = trollcoin.balanceOf(ATTACKER);
        trollcoin.transfer(DEFENDER, 100);
        assertEq(trollcoin.balanceOf(ATTACKER), (balance - 100));
    }

    function testTransferFrom() public {
        uint256 balanceA = trollcoin.balanceOf(ATTACKER);
        assertTrue(balanceA > 100);
        assertEq(trollcoin.totalSupply(), 1e18);

        vm.startPrank(ATTACKER);
        trollcoin.approve(address(this), 100);
        vm.stopPrank();

        assertTrue(trollcoin.transferFrom(ATTACKER, DEFENDER, 100));
        assertEq(trollcoin.balanceOf(ATTACKER), (balanceA - 100));
    }

    function testSetDefenses() public {
        uint256 balance = trollcoin.balanceOf(DEFENDER);

        vm.startPrank(DEFENDER);
        trollcoin.approve(address(trollcoin), 100);
        trollcoin.setDefenses(100);
        vm.stopPrank();

        (uint256 amount, , ) = trollcoin.defenses(DEFENDER);
        assertEq(amount, 100);
        assertEq(trollcoin.balanceOf(DEFENDER), (balance - 100));
    }

    function testUnsetDefenses() public {
        setUpDefenses(DEFENDER, 100);
        assertEq(trollcoin.balanceOf(address(trollcoin)), 100);
        vm.warp(2603000);
        vm.prank(DEFENDER);
        trollcoin.unsetDefenses();
        assertEq(trollcoin.balanceOf(DEFENDER), 1200);
    }

    function setUpDefenses(address _account, uint256 _amount) public {
        vm.startPrank(_account);
        trollcoin.approve(address(trollcoin), _amount);
        trollcoin.setDefenses(_amount);
        vm.stopPrank();
    }
}
