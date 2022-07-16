// SPDX-License-Identifier: SEE LICENSE IN LICENSE

pragma solidity ^0.8.11;

import { BaseTest, console } from "../base/BaseTest.t.sol";
import "../../main/oracle/PriceOracleV1.sol";

contract PriceOracleV1Test is BaseTest {
	string private constant REVERT_INVALID_NODE = "ZeroAddress()";
	string private constant REVERT_NOT_TRUSTED_NODE = "AddressNotTrusted()";

	PriceOracleV1 private underTest;

	address private owner;
	address private trustedNode;
	address private user;

	function setUp() public {
		vm.warp(10000);

		underTest = new PriceOracleV1();
		owner = accountsDb.PUBLIC_KEYS(0);
		trustedNode = accountsDb.PUBLIC_KEYS(1);
		user = accountsDb.PUBLIC_KEYS(2);

		vm.startPrank(owner);
		{
			underTest.setUp(10, 11, 1);
			underTest.registerTrustedNode(trustedNode);
		}
		vm.stopPrank();
	}

	function test_setUp_CallerIsOwner() public prankAs(user) {
		underTest = new PriceOracleV1();

		underTest.setUp(10, 11, 1);
		assertEq(underTest.owner(), user);
	}

	function test_registerTrustedNode_asUser_thenReverts() public prankAs(user) {
		vm.expectRevert(REVERT_NOT_OWNER);
		underTest.registerTrustedNode(trustedNode);
	}

	function test_registerTrustedNode_asOwner_givenInvalidAddress_thenReverts() public prankAs(owner) {
		vm.expectRevert(abi.encodeWithSignature(REVERT_INVALID_NODE));
		underTest.registerTrustedNode(address(0));
	}

	function test_update_givenNotTrustedNode_thenReverts() public {
		vm.prank(owner);
		underTest.unregisterTrustedNode(trustedNode);

		vm.startPrank(trustedNode);
		{
			vm.expectRevert(abi.encodeWithSignature(REVERT_NOT_TRUSTED_NODE));
			underTest.update(12);
		}
		vm.stopPrank();
	}

	function test_update_asTrustedNode_givenNewPrice_thenGetPriceCorrectly() public {
		vm.prank(owner);
		underTest.registerTrustedNode(trustedNode);

		(uint256 _currentPrice, , uint256 _lastUpdate) = underTest.getPriceData();

		vm.prank(trustedNode);
		underTest.update(12);

		(uint256 currentPrice, uint256 lastPrice, uint256 lastUpdate) = underTest.getPriceData();

		assertEq(currentPrice, 12);
		assertEq(_currentPrice, lastPrice);
		assertTrue(_lastUpdate <= lastUpdate);
	}
}
