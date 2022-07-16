import { BaseTest, console } from "../base/BaseTest.t.sol";

import "../../main/wrapped/ChainlinkWrapper.sol";

contract ChainlinkWrapperTest is BaseTest {
	bytes private constant REVERT_INVALID_ADDRESS = "Invalid Address";
	bytes private constant REVERT_NOT_CONTRACT = "Address is not a contract";
	string private constant REVERT_RESPONSE_FROM_ORACLE_INVALID = "ResponseFromOracleIsInvalid(address,address)";
	string private constant REVERT_TOKEN_NOT_REGISTERED = "TokenIsNotRegistered(address)";

	ChainlinkOracle private assetOracle;
	ChainlinkOracle private assetIndexOracle;
	ChainlinkOracle private mockOracle;
	ChainlinkOracle private mockIndexOracle;
	ChainlinkFlag private flag;
	ChainlinkWrapper private underTest;

	address private owner;
	address private user;
	address private validAsset;
	address[] private accounts;

	function setUp() public {
		vm.warp(5 hours);

		assetOracle = new ChainlinkOracle();
		mockOracle = new ChainlinkOracle();
		assetIndexOracle = new ChainlinkOracle();
		mockIndexOracle = new ChainlinkOracle();
		flag = new ChainlinkFlag();

		underTest = new ChainlinkWrapper();

		owner = accountsDb.PUBLIC_KEYS(0);
		user = accountsDb.PUBLIC_KEYS(1);
		validAsset = accountsDb.PUBLIC_KEYS(3);

		for (uint256 i = 4; i < 10; i++) {
			accounts.push(accountsDb.PUBLIC_KEYS(i));
		}

		vm.startPrank(owner);
		{
			underTest.setUp(accounts[0], address(flag));

			assetIndexOracle.setUpAll(1, 7e7, block.timestamp, 7);
			underTest.addOracle(validAsset, address(assetOracle), address(assetIndexOracle));
		}
		vm.stopPrank();
	}

	function test_setup_givenInvalidFlagSEQ_thenReverts() public {
		underTest = new ChainlinkWrapper();

		vm.expectRevert(REVERT_INVALID_ADDRESS);
		underTest.setUp(address(0), address(flag));
	}

	function test_setup_givenInvalidFlagsContract_thenReverts() public {
		underTest = new ChainlinkWrapper();

		vm.expectRevert(REVERT_INVALID_ADDRESS);
		underTest.setUp(accounts[0], address(0));
	}

	function test_setup_givenValidArgs_thenCallerIsOwner() public {
		underTest = new ChainlinkWrapper();

		vm.prank(owner);
		underTest.setUp(accounts[0], address(flag));

		assertEq(underTest.owner(), owner);
	}

	function test_setup_twice_thenReverts() public {
		underTest = new ChainlinkWrapper();

		vm.prank(owner);
		underTest.setUp(accounts[0], address(flag));

		vm.expectRevert(REVERT_ALREADY_INITIALIZED);
		underTest.setUp(accounts[0], address(flag));
	}

	function test_setFlagSEQ_asUser_thenReverts() public prankAs(user) {
		vm.expectRevert(REVERT_NOT_OWNER);
		underTest.setFlagSEQ(accounts[0]);
	}

	function test_setFlagSEQ_asOwner_givenNullAddress_thenReverts() public prankAs(owner) {
		vm.expectRevert(REVERT_INVALID_ADDRESS);
		underTest.setFlagSEQ(address(0));
	}

	function test_setFlagSEQ_asOwner_givenValidAddress_thenReverts() public prankAs(owner) {
		underTest.setFlagContract(accounts[1]);
		assertEq(address(underTest.flagsContract()), accounts[1]);
	}

	function test_setFlagContract_asUser_thenReverts() public prankAs(user) {
		vm.expectRevert(REVERT_NOT_OWNER);
		underTest.setFlagContract(accounts[1]);
	}

	function test_setFlagContract_asOwner_givenInvalidAddress_thenReverts() public prankAs(owner) {
		vm.expectRevert(REVERT_INVALID_ADDRESS);
		underTest.setFlagContract(address(0));
	}

	function test_setFlagContract_asOwner_givenValidAddress_thenReverts() public prankAs(owner) {
		underTest.setFlagContract(accounts[1]);
		assertEq(address(underTest.flagsContract()), accounts[1]);
	}

	function test_addOracle_asUser_thenReverts() public prankAs(user) {
		vm.expectRevert(REVERT_NOT_OWNER);
		underTest.addOracle(address(0), address(0), address(0));
	}

	function test_addOracle_asOwner_givenInvalidPriceAggregator_thenReverts() public prankAs(owner) {
		vm.expectRevert(REVERT_INVALID_ADDRESS);
		underTest.addOracle(address(0), address(0), address(mockIndexOracle));
	}

	function test_addOracle_asOwner_givenNotContractPriceAggregator_thenReverts() public prankAs(owner) {
		vm.expectRevert(REVERT_NOT_CONTRACT);
		underTest.addOracle(address(0), user, address(mockIndexOracle));
	}

	function test_addOracle_asOwner_givenPBrokenPriceOracle_thenReverts() public prankAs(owner) {
		bytes memory errorSignature = abi.encodeWithSignature(
			REVERT_RESPONSE_FROM_ORACLE_INVALID,
			address(0),
			address(mockOracle)
		);

		mockOracle.setUpAll(0, 0, 0, 0);

		vm.expectRevert(errorSignature);
		underTest.addOracle(address(0), address(mockOracle), address(0));
	}

	function test_addOracle_asOwner_givenPBrokenIndexOracle_thenReverts() public prankAs(owner) {
		bytes memory errorSignature = abi.encodeWithSignature(
			REVERT_RESPONSE_FROM_ORACLE_INVALID,
			accounts[0],
			address(mockIndexOracle)
		);

		mockIndexOracle.setUpAll(0, 0, 0, 0);

		vm.expectRevert(errorSignature);
		underTest.addOracle(accounts[0], address(mockOracle), address(mockIndexOracle));
	}

	function test_addOracle_asOwner_givenEmptyIndex_thenAddOracle() external prankAs(owner) {
		underTest.addOracle(address(0), address(mockOracle), address(0));

		(AggregatorV3Interface priceAggregator, AggregatorV3Interface indexAggregator) = underTest.aggregators(
			address(0)
		);
		(uint256 price, uint256 index, uint256 timestamp) = underTest.savedResponses(address(0));

		assertEq(address(priceAggregator), address(mockOracle));
		assertEq(address(indexAggregator), address(0));
		assertEq(price, mockOracle.getScaledAnswer());
		assertEq(index, 1e18);
	}

	function test_addOracle_asOwner_givenIndexAggregator_thenAddOracle() external prankAs(owner) {
		mockIndexOracle.setUpAll(1, 12e6, block.timestamp, 6);
		underTest.addOracle(address(0), address(mockOracle), address(mockIndexOracle));

		(AggregatorV3Interface priceAggregator, AggregatorV3Interface indexAggregator) = underTest.aggregators(
			address(0)
		);
		(uint256 price, uint256 index, uint256 timestamp) = underTest.savedResponses(address(0));

		assertEq(address(priceAggregator), address(mockOracle));
		assertEq(address(indexAggregator), address(mockIndexOracle));
		assertEq(price, mockOracle.getScaledAnswer());
		assertEq(index, mockIndexOracle.getScaledAnswer());
	}

	function test_removeOracle_asUser_thenReverts() external prankAs(user) {
		vm.expectRevert(REVERT_NOT_OWNER);
		underTest.removeOracle(address(0));
	}

	function test_removeOracle_asOwner_thenRemovesOracle() external prankAs(owner) {
		underTest.removeOracle(validAsset);

		(AggregatorV3Interface priceAggregator, AggregatorV3Interface indexAggregator) = underTest.aggregators(
			validAsset
		);

		assertEq(address(priceAggregator), address(0));
		assertEq(address(indexAggregator), address(0));
	}

	function test_retriveSavedResponse_givenUnsupportedToken_thenReverts() public {
		bytes memory revertError = abi.encodeWithSignature(REVERT_TOKEN_NOT_REGISTERED, address(0));
		vm.expectRevert(revertError);
		underTest.retriveSavedResponses(address(0));
	}

	function test_retriveSavedResponse_givenBrokenPriceOracle_thenReturnOldValues() public {
		assetOracle.setUpAll(10, 24e18, block.timestamp, 18);
		underTest.fetchPrice(validAsset);
		IOracleWrapper.SavedResponse memory lastReponse = underTest.retriveSavedResponses(validAsset);

		assetOracle.setUp(0, 0, 0, 0, false);
		IOracleWrapper.SavedResponse memory response = underTest.retriveSavedResponses(validAsset);

		assertEq(response.currentPrice, lastReponse.currentPrice);
		assertEq(response.lastPrice, lastReponse.lastPrice);
		assertEq(response.lastUpdate, lastReponse.lastUpdate);
	}

	function test_retriveSavedResponse_givenBrokenIndexOracle_thenReturnOldValues() public {
		assetIndexOracle.setUpAll(10, 24e18, block.timestamp, 18);
		underTest.fetchPrice(validAsset);
		IOracleWrapper.SavedResponse memory lastReponse = underTest.retriveSavedResponses(validAsset);

		assetIndexOracle.setUp(0, 0, 0, 0, false);
		IOracleWrapper.SavedResponse memory response = underTest.retriveSavedResponses(validAsset);

		assertEq(response.currentPrice, lastReponse.currentPrice);
		assertEq(response.lastPrice, lastReponse.lastPrice);
		assertEq(response.lastUpdate, lastReponse.lastUpdate);
	}

	function test_retriveSavedResponse_givenValidPriceOracleAndBrokenIndexOracle_thenReturnOldValues() public {
		assetOracle.setUpAll(10, 24e18, block.timestamp, 18);
		assetIndexOracle.setUpAll(10, 2e7, block.timestamp, 7);
		underTest.fetchPrice(validAsset);
		IOracleWrapper.SavedResponse memory lastReponse = underTest.retriveSavedResponses(validAsset);

		vm.warp(block.timestamp + 1000);

		assetOracle.setUp(10, 28e18, block.timestamp, 18, false);
		assetIndexOracle.setUp(0, 0, 0, 0, false);
		IOracleWrapper.SavedResponse memory response = underTest.retriveSavedResponses(validAsset);

		assertGt(response.currentPrice, lastReponse.currentPrice);
		assertEq(response.currentPrice, (28e18 * 2e18) / 1e18);
		assertEq(response.lastPrice, lastReponse.lastPrice);
		assertEq(response.lastUpdate, block.timestamp);
	}

	function test_retriveSavedResponse_givenBrokenPriceOracleAndValidIndexOracle_thenReturnOldValues() public {
		assetOracle.setUpAll(10, 24e18, block.timestamp, 18);
		assetIndexOracle.setUpAll(10, 2e7, block.timestamp, 7);
		underTest.fetchPrice(validAsset);
		IOracleWrapper.SavedResponse memory lastReponse = underTest.retriveSavedResponses(validAsset);

		vm.warp(block.timestamp + 1000);

		assetOracle.setUpAll(0, 28e18, 0, 18);
		assetIndexOracle.setUp(10, 4e7, block.timestamp, 7, false);
		IOracleWrapper.SavedResponse memory response = underTest.retriveSavedResponses(validAsset);

		assertGt(response.currentPrice, lastReponse.currentPrice);
		assertEq(response.currentPrice, (24e18 * 4e18) / 1e18);
		assertEq(response.lastPrice, lastReponse.lastPrice);
		assertEq(response.lastUpdate, lastReponse.lastUpdate);
	}

	function test_fetchPrice_givenInvalidToken_thenReverts() public {
		bytes memory revertError = abi.encodeWithSignature(REVERT_TOKEN_NOT_REGISTERED, owner);
		vm.expectRevert(revertError);
		underTest.fetchPrice(owner);
	}

	function test_fetchPrice_givenValidTokenAndPriceOracleIsBroken_thenKeepPriceOldValue() public {
		assetOracle.setUpAll(10, 24e18, block.timestamp, 18);
		assetIndexOracle.setUpAll(10, 2e7, block.timestamp, 7);
		underTest.fetchPrice(validAsset);

		(uint256 price, uint256 index, uint256 update) = underTest.savedResponses(validAsset);
		(uint256 lastPrice, uint256 lastIndex, uint256 lastUpdate) = underTest.lastSavedResponses(validAsset);

		vm.warp(block.timestamp + 1000);

		assetOracle.setUpAll(0, 28e18, 0, 18);
		assetIndexOracle.setUpAll(10, 4e7, block.timestamp, 7);

		underTest.fetchPrice(validAsset);

		(uint256 priceCurrent, uint256 indexCurrent, uint256 updateCurrent) = underTest.savedResponses(validAsset);
		(uint256 lastPriceCurrent, uint256 lastIndexCurrent, uint256 lastUpdateCurrent) = underTest.lastSavedResponses(
			validAsset
		);

		assertEq(price, priceCurrent);
		assertEq(update, updateCurrent);
		assertGe(lastIndexCurrent, lastIndex);
		assertEq(lastIndexCurrent, 4e18);
	}

	function test_fetchPrice_givenValidTokenAndIndexOracleIsBroken_thenKeepIndexOldValue() public {
		assetOracle.setUpAll(10, 24e18, block.timestamp, 18);
		assetIndexOracle.setUpAll(10, 2e7, block.timestamp, 7);
		underTest.fetchPrice(validAsset);

		(uint256 price, uint256 index, uint256 update) = underTest.savedResponses(validAsset);
		(uint256 lastPrice, uint256 lastIndex, uint256 lastUpdate) = underTest.lastSavedResponses(validAsset);

		vm.warp(block.timestamp + 1000);

		assetOracle.setUpAll(15, 28e2, block.timestamp, 2);
		assetIndexOracle.setUpAll(10, 4e7, 0, 7);

		underTest.fetchPrice(validAsset);

		(uint256 priceCurrent, uint256 indexCurrent, uint256 updateCurrent) = underTest.savedResponses(validAsset);
		(uint256 lastPriceCurrent, uint256 lastIndexCurrent, uint256 lastUpdateCurrent) = underTest.lastSavedResponses(
			validAsset
		);

		assertGe(priceCurrent, price);
		assertEq(priceCurrent, 28e18);
		assertGe(updateCurrent, update);
		assertEq(updateCurrent, block.timestamp);
		assertEq(index, indexCurrent);
		assertEq(lastIndexCurrent, lastIndex);
	}

	function test_fetchPrice_givenValidTokenAndBothOraclesAreBroken_thenKeepOldValues() public {
		assetOracle.setUpAll(10, 24e18, block.timestamp, 18);
		assetIndexOracle.setUpAll(10, 2e7, block.timestamp, 7);
		underTest.fetchPrice(validAsset);

		(uint256 price, uint256 index, uint256 update) = underTest.savedResponses(validAsset);
		(uint256 lastPrice, uint256 lastIndex, uint256 lastUpdate) = underTest.lastSavedResponses(validAsset);

		vm.warp(block.timestamp + 1000);

		assetOracle.setUpAll(0, 28e18, 0, 18);
		assetIndexOracle.setUpAll(0, 4e7, block.timestamp, 7);

		underTest.fetchPrice(validAsset);

		(uint256 priceCurrent, uint256 indexCurrent, uint256 updateCurrent) = underTest.savedResponses(validAsset);
		(uint256 lastPriceCurrent, uint256 lastIndexCurrent, uint256 lastUpdateCurrent) = underTest.lastSavedResponses(
			validAsset
		);

		assertEq(price, priceCurrent);
		assertEq(lastPrice, lastPriceCurrent);

		assertEq(index, indexCurrent);
		assertEq(lastIndex, lastIndexCurrent);

		assertEq(update, updateCurrent);
		assertEq(lastUpdate, lastUpdateCurrent);
	}

	function test_fetchPrice_givenValidTokenAndWithBothOraclesWork_thenSaveDataCorrectly() public {
		assetOracle.setUpAll(10, 24e18, block.timestamp, 18);
		assetIndexOracle.setUpAll(10, 2e7, block.timestamp, 7);
		underTest.fetchPrice(validAsset);

		(uint256 price, uint256 index, uint256 update) = underTest.savedResponses(validAsset);
		(uint256 lastPrice, uint256 lastIndex, uint256 lastUpdate) = underTest.lastSavedResponses(validAsset);

		vm.warp(block.timestamp + 1000);

		assetOracle.setUp(4, 30e5, block.timestamp, 5, false);
		assetOracle.setUp(4, 29e5, block.timestamp - 100, 5, true);
		assetIndexOracle.setUp(4, 8e18, block.timestamp, 18, false);
		assetIndexOracle.setUp(4, 6e18, block.timestamp - 300, 18, true);

		underTest.fetchPrice(validAsset);

		(uint256 priceCurrent, uint256 indexCurrent, uint256 updateCurrent) = underTest.savedResponses(validAsset);
		(uint256 lastPriceCurrent, uint256 lastIndexCurrent, uint256 lastUpdateCurrent) = underTest.lastSavedResponses(
			validAsset
		);

		assertGt(priceCurrent, price);
		assertEq(priceCurrent, 30e18);

		assertGt(lastPriceCurrent, lastPrice);
		assertEq(lastPriceCurrent, 29e18);

		assertGt(indexCurrent, index);
		assertEq(indexCurrent, 8e18);

		assertGt(lastIndexCurrent, lastIndex);
		assertEq(lastIndexCurrent, 6e18);

		assertGt(updateCurrent, update);
		assertEq(updateCurrent, block.timestamp);

		assertGt(lastUpdateCurrent, lastUpdate);
		assertEq(lastUpdateCurrent, block.timestamp - 100);
	}

	function test_getCurrentPrice_thenReturnsCorrectPrice() public {
		assetOracle.setUp(10, 24e18, block.timestamp, 18, false);
		assetIndexOracle.setUp(10, 2e7, block.timestamp, 7, false);
		underTest.fetchPrice(validAsset);

		uint256 price = underTest.getCurrentPrice(validAsset);
		assertEq(price, (24e18 * 2e18) / 1e18);
	}

	function test_getLastPrice_thenReturnsCorrectPrice() public {
		assetOracle.setUp(10, 13e6, block.timestamp, 6, true);
		assetIndexOracle.setUp(10, 5e9, block.timestamp, 9, true);
		underTest.fetchPrice(validAsset);

		uint256 price = underTest.getLastPrice(validAsset);
		assertEq(price, (13e18 * 5e18) / 1e18);
	}
}

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
	uint80 public currentRound;
	uint80 public lastRound;

	int256 public answer;
	int256 public lastAnswer;

	uint256 public timestamp;
	uint256 public lastTimestamp;

	uint8 public decimals;

	constructor() {
		currentRound = 5;
		lastRound = 4;

		answer = 100e9;
		lastAnswer = 97e9;

		decimals = 9;

		timestamp = block.timestamp;
		lastTimestamp = block.timestamp;
	}

	function setUpAll(
		uint80 _round,
		int256 _answer,
		uint256 _timestamp,
		uint8 _decimals
	) external {
		this.setUp(_round, _answer, _timestamp, _decimals, true);
		this.setUp(_round, _answer, _timestamp, _decimals, false);
	}

	function setUp(
		uint80 _round,
		int256 _answer,
		uint256 _timestamp,
		uint8 _decimals,
		bool _isPrevious
	) external {
		if (_isPrevious) {
			lastRound = _round;
			lastAnswer = _answer;
			lastTimestamp = _timestamp;
		} else {
			currentRound = _round;
			answer = _answer;
			timestamp = _timestamp;
		}

		decimals = _decimals;
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
		return (currentRound, answer, 0, timestamp, 0);
	}

	function getRoundData(uint80 _roundId)
		external
		view
		returns (
			uint80 _roundIdReturned,
			int256 _answer,
			uint256 _startedAt,
			uint256 _timestamp,
			uint80 _answeredInRound
		)
	{
		return (lastRound, lastAnswer, 0, lastTimestamp, 0);
	}

	function getScaledAnswer() public view returns (uint256) {
		return decimals < 18 ? uint256(answer) * (10**(18 - decimals)) : uint256(answer) / (10**(decimals - 18));
	}
}
