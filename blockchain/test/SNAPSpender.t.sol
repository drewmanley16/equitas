// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {MockUSDC} from "../src/MockUSDC.sol";
import {SNAPSpender} from "../src/SNAPSpender.sol";

contract SNAPSpenderTest is Test {
    MockUSDC internal usdc;
    SNAPSpender internal spender;

    address internal owner = address(0xA11CE);
    address internal user = address(0xBEEF);
    address internal merchant = address(0xCAFE);

    uint256 internal constant UNIT = 1e6;

    function setUp() public {
        vm.prank(owner);
        usdc = new MockUSDC();
        vm.prank(owner);
        spender = new SNAPSpender(owner, address(usdc));

        usdc.mint(owner, 1_000_000 * UNIT);
        vm.prank(owner);
        usdc.approve(address(spender), type(uint256).max);
    }

    function test_MerchantApproval() public {
        assertFalse(spender.approvedMerchants(merchant));
        vm.prank(owner);
        spender.setMerchant(merchant, true);
        assertTrue(spender.approvedMerchants(merchant));
    }

    function test_UserEligibility() public {
        assertFalse(spender.approvedUsers(user));
        vm.prank(owner);
        spender.setUserEligibility(user, true, 0);
        assertTrue(spender.approvedUsers(user));
    }

    function test_Deposit() public {
        vm.prank(owner);
        spender.depositBenefits(500 * UNIT);
        assertEq(usdc.balanceOf(address(spender)), 500 * UNIT);
    }

    function test_PaymentSuccess() public {
        _configureUserAndMerchant();
        vm.prank(owner);
        spender.depositBenefits(200 * UNIT);

        vm.prank(user);
        spender.payMerchant(merchant, 50 * UNIT);

        assertEq(usdc.balanceOf(merchant), 50 * UNIT);
        assertEq(spender.userSpent(user), 50 * UNIT);
    }

    function test_PaymentFails_NotApprovedMerchant() public {
        vm.prank(owner);
        spender.setUserEligibility(user, true, 0);
        vm.prank(owner);
        spender.setUserAllowance(user, 100 * UNIT);

        vm.prank(owner);
        spender.depositBenefits(200 * UNIT);

        vm.prank(user);
        vm.expectRevert(SNAPSpender.NotApprovedMerchant.selector);
        spender.payMerchant(merchant, 10 * UNIT);
    }

    function test_PaymentFails_NotApprovedUser() public {
        vm.prank(owner);
        spender.setMerchant(merchant, true);
        vm.prank(owner);
        spender.depositBenefits(200 * UNIT);

        vm.prank(user);
        vm.expectRevert(SNAPSpender.NotApprovedUser.selector);
        spender.payMerchant(merchant, 10 * UNIT);
    }

    function test_AllowanceLimit() public {
        _configureUserAndMerchant();
        vm.prank(owner);
        spender.depositBenefits(200 * UNIT);

        vm.prank(user);
        spender.payMerchant(merchant, 60 * UNIT);

        vm.prank(user);
        vm.expectRevert(SNAPSpender.AllowanceExceeded.selector);
        spender.payMerchant(merchant, 50 * UNIT);
    }

    function test_Pause_BlocksPayAndDeposit() public {
        _configureUserAndMerchant();
        vm.prank(owner);
        spender.depositBenefits(200 * UNIT);

        vm.prank(owner);
        spender.pause();

        vm.prank(owner);
        vm.expectRevert();
        spender.depositBenefits(1 * UNIT);

        vm.prank(user);
        vm.expectRevert();
        spender.payMerchant(merchant, 1 * UNIT);
    }

    function test_Unpause_AllowsFlow() public {
        _configureUserAndMerchant();
        vm.prank(owner);
        spender.pause();
        vm.prank(owner);
        spender.unpause();

        vm.prank(owner);
        spender.depositBenefits(100 * UNIT);
        vm.prank(user);
        spender.payMerchant(merchant, 10 * UNIT);
        assertEq(spender.userSpent(user), 10 * UNIT);
    }

    function _configureUserAndMerchant() internal {
        vm.prank(owner);
        spender.setMerchant(merchant, true);
        vm.prank(owner);
        spender.setUserEligibility(user, true, 0);
        vm.prank(owner);
        spender.setUserAllowance(user, 100 * UNIT);
    }
}
