import { BaseTest, console } from "../base/BaseTest.t.sol";

import "../../main/wrapped/CustomOracleWrapper.sol";

contract CustomOracleWrapperTest is BaseTest {
	bytes private constant REVERT_INVALID_ADDRESS = "Invalid Address";
	bytes private constant REVERT_NOT_A_CONTRACT = "Address is not a contract";
	bytes private constant REVERT_INVALID_DECIMALS = "Invalid Decimals";
	string private constant REVERT_RESPONSE_FROM_ORACLE_INVALID = "ResponseFromOracleIsInvalid(address,address)";
	string private constant REVERT_TOKEN_NOT_REGISTERED = "TokenIsNotRegistered(address)";

	bytes private constant currentPriceHex = hex"9d1b464a";
	bytes private constant lastPriceHex = hex"053f14da";
	bytes private constant lastUpdateHex = hex"c0463711";
	bytes private constant decimalsHex = hex"313ce567";

	CustomOracleMock private mockOracle;
	CustomOracleMock private mockOracleValid;
	CustomOracleWrapper private underTest;

	address private owner;
	address private user;
	address private validAsset;

	address[] private accounts;

	function setUp() public {
		vm.warp(1000);

		mockOracle = new CustomOracleMock();
		mockOracleValid = new CustomOracleMock();
		underTest = new CustomOracleWrapper();

		owner = accountsDb.PUBLIC_KEYS(0);
		user = accountsDb.PUBLIC_KEYS(1);
		validAsset = accountsDb.PUBLIC_KEYS(10);

		for (uint256 i = 2; i < 6; i++) {
			accounts.push(accountsDb.PUBLIC_KEYS(i));
		}

		vm.startPrank(owner);
		{
			underTest.setUp();

			underTest.addOracle(
				validAsset,
				address(mockOracleValid),
				10,
				currentPriceHex,
				lastPriceHex,
				lastUpdateHex,
				decimalsHex
			);
		}
		vm.stopPrank();

		vm.warp(block.timestamp + 10);
	}

	function test_setup_thenCallerIsOwner() public {
		underTest = new CustomOracleWrapper();

		vm.prank(accountsDb.PUBLIC_KEYS(4));
		underTest.setUp();

		assertEq(accountsDb.PUBLIC_KEYS(4), underTest.owner());
	}

	function test_setUp_calledTwice_thenReverts() public {
		underTest = new CustomOracleWrapper();

		vm.prank(owner);
		underTest.setUp();

		vm.expectRevert(REVERT_ALREADY_INITIALIZED);
		underTest.setUp();
	}

	function test_removeOracle_asUser_thenReverts() public prankAs(user) {
		vm.expectRevert(REVERT_NOT_OWNER);
		underTest.removeOracle(address(0));
	}

	function test_removeOracle_asOwner_thenReverts() public prankAs(owner) {
		underTest.removeOracle(validAsset);

		(
			address oracleAddr,
			uint8 decimals,
			bytes memory callPrice,
			bytes memory callLastPrice,
			bytes memory callLastUpdate,
			bytes memory callDecimals
		) = underTest.oracles(validAsset);

		assertEq(oracleAddr, address(0));
		assertEq(decimals, 0);
		assertEq0(callPrice, "");
		assertEq0(callLastPrice, "");
		assertEq0(callLastUpdate, "");
		assertEq0(callDecimals, "");
	}

	function test_addOwner_asUser_thenReverts() public prankAs(user) {
		vm.expectRevert(REVERT_NOT_OWNER);
		underTest.addOracle(address(0), address(0), 8, "", "", "", "");
	}

	function test_addOwner_asOwner_givenInvalidExternalOracleAddress_thenReverts() public prankAs(owner) {
		vm.expectRevert(REVERT_INVALID_ADDRESS);
		underTest.addOracle(address(0), address(0), 1, "", "", "", "");
	}

	function test_addOwner_asOwner_givenInvalidCurrentPrice_thenReverts() public prankAs(owner) {
		bytes memory errorSignature = abi.encodeWithSignature(
			REVERT_RESPONSE_FROM_ORACLE_INVALID,
			accounts[0],
			address(mockOracle)
		);

		vm.expectRevert(errorSignature);
		underTest.addOracle(accounts[0], address(mockOracle), 1, "", lastPriceHex, lastUpdateHex, decimalsHex);
	}

	function test_addOwner_asOwner_givenInvalidLastPrice_thenReverts() public prankAs(owner) {
		bytes memory errorSignature = abi.encodeWithSignature(
			REVERT_RESPONSE_FROM_ORACLE_INVALID,
			accounts[1],
			address(mockOracle)
		);

		vm.expectRevert(errorSignature);
		underTest.addOracle(accounts[1], address(mockOracle), 1, currentPriceHex, "", lastUpdateHex, decimalsHex);
	}

	function test_addOwner_asOwner_givenInvalidDecimals_thenReverts() public prankAs(owner) {
		vm.expectRevert(REVERT_INVALID_DECIMALS);
		underTest.addOracle(
			accounts[1],
			address(mockOracle),
			0,
			currentPriceHex,
			lastPriceHex,
			lastUpdateHex,
			decimalsHex
		);
	}

	function test_addOwner_asOwner_givenInvalidOracleContract_thenReverts() public prankAs(owner) {
		bytes memory errorSignature = abi.encodeWithSignature(
			REVERT_RESPONSE_FROM_ORACLE_INVALID,
			accounts[1],
			address(this)
		);

		vm.expectRevert(errorSignature);
		underTest.addOracle(accounts[1], address(this), 1, currentPriceHex, lastPriceHex, lastUpdateHex, decimalsHex);
	}

	function test_addOwner_asOwner_givenUserAddress_thenReverts() public prankAs(owner) {
		vm.expectRevert(REVERT_NOT_A_CONTRACT);
		underTest.addOracle(accounts[1], accounts[0], 1, currentPriceHex, lastPriceHex, lastUpdateHex, decimalsHex);
	}

	function test_addOwner_asOwner_givenInvalidLastUpdate_thenAddOracle() public prankAs(owner) {
		underTest.addOracle(accounts[2], address(mockOracle), 1, currentPriceHex, lastPriceHex, "", decimalsHex);

		(
			address oracleAddr,
			uint8 decimals,
			bytes memory callPrice,
			bytes memory callLastPrice,
			bytes memory callLastUpdate,
			bytes memory callDecimals
		) = underTest.oracles(accounts[2]);

		assertEq(oracleAddr, address(mockOracle));
		assertEq(decimals, 1);
		assertEq0(callPrice, currentPriceHex);
		assertEq0(callLastPrice, lastPriceHex);
		assertEq0(callLastUpdate, "");
		assertEq0(callDecimals, decimalsHex);
	}

	function test_addOwner_asOwner_givenInvalidDecimalsCall_thenAddOracle() public prankAs(owner) {
		underTest.addOracle(accounts[2], address(mockOracle), 1, currentPriceHex, lastPriceHex, lastUpdateHex, "");

		(
			address oracleAddr,
			uint8 decimals,
			bytes memory callPrice,
			bytes memory callLastPrice,
			bytes memory callLastUpdate,
			bytes memory callDecimals
		) = underTest.oracles(accounts[2]);

		assertEq(oracleAddr, address(mockOracle));
		assertEq(decimals, 1);
		assertEq0(callPrice, currentPriceHex);
		assertEq0(callLastPrice, lastPriceHex);
		assertEq0(callLastUpdate, lastUpdateHex);
		assertEq0(callDecimals, "");
	}

	function test_addOwner_asOwner_givenAllArgs_thenAddOracle() public prankAs(owner) {
		underTest.addOracle(
			address(0),
			address(mockOracle),
			1,
			currentPriceHex,
			lastPriceHex,
			lastUpdateHex,
			decimalsHex
		);

		(
			address oracleAddr,
			uint8 decimals,
			bytes memory callPrice,
			bytes memory callLastPrice,
			bytes memory callLastUpdate,
			bytes memory callDecimals
		) = underTest.oracles(address(0));

		assertEq(oracleAddr, address(mockOracle));
		assertEq(decimals, 1);
		assertEq0(callPrice, currentPriceHex);
		assertEq0(callLastPrice, lastPriceHex);
		assertEq0(callLastUpdate, lastUpdateHex);
		assertEq0(callDecimals, decimalsHex);
	}

	function test_retriveSavedResponses_givenInvalidToken_thenReverts() public {
		bytes memory revertError = abi.encodeWithSignature(REVERT_TOKEN_NOT_REGISTERED, owner);
		vm.expectRevert(revertError);
		underTest.retriveSavedResponses(owner);
	}

	function test_retriveSavedResponses_givenValidToken_withNoOracleIssue_thenReturnsSameData() public {
		mockOracleValid.setUp(100e10, 99e10, block.timestamp, 10);
		IOracleWrapper.SavedResponse memory saved = underTest.retriveSavedResponses(validAsset);

		assertEq(saved.currentPrice, 100e18);
		assertEq(saved.lastPrice, 99e18);
		assertEq(saved.lastUpdate, block.timestamp);
	}

	function test_retriveSavedResponses_givenValidToken_withOracleFailing_thenReturnsLastValidData() public {
		mockOracleValid.setUp(17e10, 20e10, block.timestamp, 10);
		underTest.fetchPrice(validAsset);
		mockOracle.setUp(0, 0, 0, 0);

		IOracleWrapper.SavedResponse memory saved = underTest.retriveSavedResponses(validAsset);

		assertEq(saved.currentPrice, 17e18);
		assertEq(saved.lastPrice, 20e18);
		assertEq(saved.lastUpdate, block.timestamp);
	}

	function test_fetchPrice_givenInvalidToken_thenReverts() public {
		bytes memory revertError = abi.encodeWithSignature(REVERT_TOKEN_NOT_REGISTERED, owner);
		vm.expectRevert(revertError);
		underTest.fetchPrice(owner);
	}

	function test_fetchPrice_givenValidToken_NoIssueWithOracle_thenSaveDataCorrectly() public {
		mockOracleValid.setUp(19e10, 16e10, block.timestamp, 10);
		underTest.fetchPrice(validAsset);

		(uint256 currentPrice, uint256 lastPrice, uint256 lastUpdate) = underTest.savedResponses(validAsset);

		assertEq(currentPrice, 19e18);
		assertEq(lastPrice, 16e18);
		assertEq(lastUpdate, block.timestamp);
	}

	function test_fetchPrice_givenValidTokenAndOracleIsBroken_thenKeepOldValue() public {
		(uint256 currentPriceOld, uint256 lastPriceOld, uint256 lastUpdateOld) = underTest.savedResponses(validAsset);

		vm.warp(block.timestamp + 2 hours);
		mockOracleValid.setUp(0, 0, 0, 0);
		underTest.fetchPrice(validAsset);

		(uint256 currentPrice, uint256 lastPrice, uint256 lastUpdate) = underTest.savedResponses(validAsset);

		assertEq(currentPrice, currentPriceOld);
		assertEq(lastPrice, lastPriceOld);
		assertEq(lastUpdate, lastUpdateOld);
	}

	function test_getLastPrice_withValidToken_thenReturnSameSavedValue() public {
		mockOracleValid.setUp(19e10, 16e10, block.timestamp, 10);
		underTest.fetchPrice(validAsset);

		assertEq(16e18, underTest.getLastPrice(validAsset));
	}

	function test_getCurrentPrice_withValidToken_thenReturnSameSavedValue() public {
		mockOracleValid.setUp(19e10, 16e10, block.timestamp, 10);
		underTest.fetchPrice(validAsset);

		assertEq(19e18, underTest.getCurrentPrice(validAsset));
	}
}

contract CustomOracleMock {
	uint256 public currentPrice;
	uint256 public lastPrice;
	uint256 public lastUpdate;
	uint8 public decimals;

	constructor() {
		currentPrice = 100e18;
		lastPrice = 98e18;
		lastUpdate = block.timestamp;
		decimals = 18;
	}

	function setUp(
		uint256 current,
		uint256 last,
		uint256 update,
		uint8 dec
	) external {
		currentPrice = current;
		lastPrice = last;
		lastUpdate = update;
		decimals = dec;
	}

	function setDecimals(uint8 _decimals) external {
		decimals = _decimals;
	}

	function setLastPrice(uint256 _lastPrice) external {
		lastPrice = _lastPrice;
	}

	function update(uint256 newPrice) external {
		lastPrice = currentPrice;
		currentPrice = newPrice;
		lastUpdate = block.timestamp;
	}
}
