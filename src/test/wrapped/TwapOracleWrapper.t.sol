// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.6.12;
pragma experimental ABIEncoderV2;

import { BaseTest, console } from "../base/BaseTest.t.sol";

import "../../main/wrapped/TwapOracleWrapper.sol";

contract TwapOracleWrapperTest is BaseTest {
	bytes private INVALID_ADDRESS = "Invalid Address";
	bytes private REVERT_NOT_CONTRACT = "Address is not a contract";

	address private owner;
	address private user;
	address private flagSEQ;
	address private weth;
	address private asset;
	MockPool private pool;

	address[] private accounts;

	ChainlinkOracle private mockChainlink;
	ChainlinkFlag private mockFlag;
	TwapOracleWrapper private underTest;

	function setUp() public {
		vm.warp(5 hours);

		mockChainlink = new ChainlinkOracle();
		mockFlag = new ChainlinkFlag();

		owner = accountsDb.PUBLIC_KEYS(0);
		user = accountsDb.PUBLIC_KEYS(1);
		flagSEQ = accountsDb.PUBLIC_KEYS(3);
		weth = address(new MockContract());
		asset = address(new MockContract());
		pool = new MockPool();

		for (uint256 i = 6; i < 12; i++) {
			accounts.push(accountsDb.PUBLIC_KEYS(i));
		}

		vm.startPrank(owner);
		{
			underTest = new TwapOracleWrapper(weth, address(mockChainlink), flagSEQ, address(mockFlag));
			underTest.addOracle(asset, address(pool));
			underTest.fetchEthPrice();
		}
		vm.stopPrank();
	}

	function test_createContract_givenInvalidArgs_thenReverts() public prankAs(owner) {
		vm.expectRevert(INVALID_ADDRESS);
		underTest = new TwapOracleWrapper(address(0), address(mockChainlink), flagSEQ, address(mockFlag));

		vm.expectRevert(INVALID_ADDRESS);
		underTest = new TwapOracleWrapper(weth, address(0), flagSEQ, address(mockFlag));

		vm.expectRevert(REVERT_NOT_CONTRACT);
		underTest = new TwapOracleWrapper(weth, accounts[0], flagSEQ, address(mockFlag));

		vm.expectRevert(INVALID_ADDRESS);
		underTest = new TwapOracleWrapper(weth, address(mockChainlink), address(0), address(mockFlag));

		vm.expectRevert(INVALID_ADDRESS);
		underTest = new TwapOracleWrapper(weth, address(mockChainlink), flagSEQ, address(0));

		vm.expectRevert(REVERT_NOT_CONTRACT);
		underTest = new TwapOracleWrapper(weth, accounts[0], flagSEQ, accounts[0]);
	}

	function test_createContract_givenValidArgs_argsSavedLocally() public prankAs(owner) {
		underTest = new TwapOracleWrapper(weth, address(mockChainlink), flagSEQ, address(mockFlag));
		assertEq(underTest.flagSEQOffline(), flagSEQ);
		assertEq(address(underTest.flagsContract()), address(mockFlag));
		assertEq(address(underTest.ethChainlinkAggregator()), address(mockChainlink));
		assertEq(address(underTest.weth()), weth);
	}

	function test_createContract_givenValidArgs_creatorIsOwner() public prankAs(owner) {
		underTest = new TwapOracleWrapper(weth, address(mockChainlink), flagSEQ, address(mockFlag));
		assertEq(underTest.owner(), owner);
	}

	function test_changeTwapPeriod_asUser_thenReverts() public prankAs(user) {
		vm.expectRevert(REVERT_NOT_OWNER);
		underTest.changeTwapPeriod(120);
	}

	function test_changeTwapPeriod_asOwner_thenUpdareTwapPeriod() public prankAs(owner) {
		underTest.changeTwapPeriod(120);
		assertEq(uint256(underTest.twapPeriodInSeconds()), 120);
	}

	function test_addOracle_asUser_thenReverts() public prankAs(user) {
		vm.expectRevert(REVERT_NOT_OWNER);
		underTest.addOracle(asset, address(pool));
	}

	function test_addOracle_asOwner_givenInvalidAddresses_thenReverts() public prankAs(owner) {
		vm.expectRevert(INVALID_ADDRESS);
		underTest.addOracle(address(0), address(pool));

		vm.expectRevert(INVALID_ADDRESS);
		underTest.addOracle(asset, address(0));

		vm.expectRevert(REVERT_NOT_CONTRACT);
		underTest.addOracle(accounts[0], address(pool));

		vm.expectRevert(REVERT_NOT_CONTRACT);
		underTest.addOracle(asset, accounts[0]);
	}

	function test_addOracle_asOwner_givenValidArgs_thenPriceSaved() public prankAs(owner) {
		underTest.addOracle(asset, address(pool));
		uint256 tokenPrice = underTest.getCurrentPrice(asset);

		uint256 expectingPrice = (underTest.getTokenPriceInETH(asset, 1800) * underTest.latestEthPriceFetched()) /
			1e18;

		assertEq(tokenPrice, expectingPrice);
	}

	function test_removeOracle_asUser_thenReverts() public prankAs(user) {
		vm.expectRevert(REVERT_NOT_OWNER);
		underTest.removeOracle(asset);
	}

	function test_removeOracle_asOwner_thenOracleAdded() public prankAs(owner) {
		underTest.addOracle(asset, address(pool));
		underTest.removeOracle(asset);

		assertEq(underTest.uniswapV3Pools(asset), address(0));
	}

	function test_fetchPrice_givenUnregisteredToken_thenReverts() public {
		vm.expectRevert("TokenIsNotRegistered");
		underTest.fetchPrice(address(0));
	}

	function test_fetchPrice_givenValidTokenAndUpdatedETH_thenUpdateThePrice() public {
		uint256 oldPrice = underTest.getCurrentPrice(asset);

		mockChainlink.setPrice(320e18);
		underTest.fetchPrice(asset);

		uint256 expectingPrice = (underTest.getTokenPriceInETH(asset, 1800) * underTest.latestEthPriceFetched()) /
			1e18;

		assertGt(underTest.getCurrentPrice(asset), oldPrice);
		assertEq(underTest.getCurrentPrice(asset), expectingPrice);
	}

	function test_fetchEthPrice_givenFlaggedStatus_thenReturnsOldPrice() public prankAs(owner) {
		mockFlag.setFlag(true);
		mockChainlink.setPrice(320e18);

		uint256 oldPrice = underTest.latestEthPriceFetched();
		uint256 returnedPrice = underTest.fetchEthPrice();

		assertEq(oldPrice, returnedPrice);
	}

	function test_retrieveSavedResponses_givenUnregisteredToken_thenReverts() public {
		vm.expectRevert("TokenIsNotRegistered");
		underTest.fetchPrice(address(0));
	}

	function test_retrieveSavedResponses_givenValidToken_thenReturnResponse() public {
		mockChainlink.setPrice(320e18);
		IOracleWrapper.SavedResponse memory saved = underTest.retriveSavedResponses(asset);

		uint256 expectingPrice = (underTest.getTokenPriceInETH(asset, 1800) * underTest.latestEthPriceFetched()) /
			1e18;

		assertEq(saved.currentPrice, expectingPrice);
	}

	function test_fetchEthPrice_givenInvalidRoundId_thenReturnsOldPrice() public prankAs(owner) {
		mockChainlink.setPrice(320e18);
		mockChainlink.setRoundId(0);

		uint256 oldPrice = underTest.latestEthPriceFetched();
		uint256 returnedPrice = underTest.fetchEthPrice();

		assertEq(oldPrice, returnedPrice);
	}

	function test_fetchEthPrice_givenInvalidPriceResponse_thenReturnsOldPrice() public prankAs(owner) {
		mockChainlink.setPrice(0);
		mockChainlink.setRoundId(10);

		uint256 oldPrice = underTest.latestEthPriceFetched();
		uint256 returnedPrice = underTest.fetchEthPrice();

		assertEq(oldPrice, returnedPrice);
	}

	function test_fetchEthPrice_givenValidResponse_thenReturnsNewPrice() public prankAs(owner) {
		mockChainlink.setPrice(320e8);
		mockChainlink.setRoundId(10);

		uint256 oldPrice = underTest.latestEthPriceFetched();
		uint256 returnedPrice = underTest.fetchEthPrice();

		assertGt(returnedPrice, oldPrice);
		assertEq(returnedPrice, 320e18);
	}
}

contract MockPool {
	uint256 tokenEthPrice = 108838541196503515020;
	int56[] tickCumulatives;
	uint160[] secondsPerLiquidityCumulative;

	bool private willFail = false;

	constructor() public {
		//Took those value from a mainnet contract. It should returns 108838541196503515020 with Consult + getQuoteAtTick
		tickCumulatives = [0xcb9a19e581, 0xcb9f22148d];
		secondsPerLiquidityCumulative = [0x36c0000000000023f4aa310a3799d3f73cf, 0x36c0000000000023f4b2c1fdb1827fbfcf3];
	}

	function failNextCall() external {
		willFail = true;
	}

	function observe(uint32[] memory secondsAgo) public returns (int56[] memory a, uint160[] memory b) {
		if (willFail) return (a, b);
		return (tickCumulatives, secondsPerLiquidityCumulative);
	}
}

contract MockContract {}

contract ChainlinkFlag {
	bool private flag;

	function setFlag(bool _f) external {
		flag = _f;
	}

	function getFlag(address _addr) external view returns (bool) {
		return flag;
	}
}

contract ChainlinkOracle {
	int256 public answer;
	uint8 public decimals;
	uint80 public roundId;

	constructor() public {
		answer = 100e8;
		decimals = 8;
		roundId = 10;
	}

	function setPrice(int256 price) public {
		answer = price;
	}

	function setRoundId(uint80 _roundId) public {
		roundId = _roundId;
	}

	function latestRoundData()
		external
		view
		returns (
			uint80 _roundId,
			int256 _answer,
			uint256 _startedAt,
			uint256 _timestamp,
			uint80 _answeredInRound
		)
	{
		return (roundId, answer, 0, 0, 0);
	}

	function getScaledAnswer() public view returns (uint256) {
		return decimals < 18 ? uint256(answer) * (10**(18 - decimals)) : uint256(answer) / (10**(decimals - 18));
	}
}
