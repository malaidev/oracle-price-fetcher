import { BaseTest, console } from "./base/BaseTest.t.sol";

import "../main/PriceFeedV2.sol";
import "../main/interfaces/IOracleVerificationV1.sol";
import "../main/interfaces/IOracleWrapper.sol";

contract PriceFeedV2Test is BaseTest {
	bytes private constant REVERT_INVALID_VERIFACTOR = "Invalid Verificator";
	bytes private constant REVERT_INVALID_ACCESS = "Invalid access";
	bytes private constant REVERT_INVALID_PRIMARY_ORACLE = "Invalid Primary Oracle";
	bytes private constant REVERT_ORACLE_DOWN = "Oracle down";
	bytes private constant REVERT_ORACLE_NOT_FOUND = "Oracle not found";

	address private owner;
	address private user;
	address private accessActor;
	address[] private accounts;

	MockVerificator private mockVerificator;
	MockOracle private mockOraclePrimary;
	MockOracle private mockOracleSecondary;

	PriceFeedV2 private underTest;

	function setUp() public {
		vm.warp(10000);
		underTest = new PriceFeedV2();
		owner = accountsDb.PUBLIC_KEYS(0);
		user = accountsDb.PUBLIC_KEYS(1);
		accessActor = accountsDb.PUBLIC_KEYS(2);

		mockVerificator = new MockVerificator();
		mockOraclePrimary = new MockOracle();
		mockOracleSecondary = new MockOracle();

		for (uint256 i = 3; i <= 13; i++) {
			accounts.push(accountsDb.PUBLIC_KEYS(i));
		}

		vm.startPrank(owner);
		{
			underTest.setUp(address(mockVerificator));
			underTest.setAccessTo(accessActor, true);
		}
		vm.stopPrank();
	}

	function test_setUp_GivenInvalidVerificator_thenReverts() public {
		underTest = new PriceFeedV2();

		vm.expectRevert(REVERT_INVALID_VERIFACTOR);
		underTest.setUp(address(0));
	}

	function test_setUp_GivenValidVerificator_thenSetVerificatorToNewAddressAndCallerIsOwner() public {
		underTest = new PriceFeedV2();

		vm.prank(user);
		underTest.setUp(accounts[0]);

		assertEq(address(underTest.verificator()), accounts[0]);
		assertEq(underTest.owner(), user);
	}

	function test_setUp_Twice_thenRevertsSecondCall() public {
		underTest = new PriceFeedV2();

		underTest.setUp(accounts[0]);

		vm.expectRevert(REVERT_ALREADY_INITIALIZED);
		underTest.setUp(accounts[0]);
	}

	function test_setAccessTo_asUser_thenReverts() public prankAs(user) {
		vm.expectRevert(REVERT_NOT_OWNER);
		underTest.setAccessTo(address(0), true);
	}

	function test_setAccessTo_asOwner_givingAccess_thenGiveAccess() public prankAs(owner) {
		underTest.setAccessTo(user, true);
		assertTrue(underTest.accesses(user));
	}

	function test_setAccessTo_asOwner_revokeAccess_thenGiveAccess() public prankAs(owner) {
		underTest.setAccessTo(user, true);
		underTest.setAccessTo(user, false);
		assertTrue(!underTest.accesses(user));
	}

	function test_changeVerificator_asUser_thenReverts() public prankAs(user) {
		vm.expectRevert(REVERT_NOT_OWNER);
		underTest.changeVerificator(owner);
	}

	function test_changeVerificator_asOwner_givenInvalidAddress_thenReverts() public prankAs(owner) {
		vm.expectRevert(REVERT_INVALID_VERIFACTOR);
		underTest.changeVerificator(address(0));
	}

	function test_changeVerificator_asOwner_givenValidAddress_thenReverts() public prankAs(owner) {
		underTest.changeVerificator(accounts[1]);
		assertEq(address(underTest.verificator()), accounts[1]);
	}

	function test_addOracle_asUser_thenReverts() public prankAs(user) {
		vm.expectRevert(REVERT_INVALID_ACCESS);
		underTest.addOracle(accounts[0], address(mockOraclePrimary), address(mockOracleSecondary));
	}

	function test_addOracle_asOwner_givenInvalidPrimary_thenReverts() public prankAs(owner) {
		vm.expectRevert(REVERT_INVALID_PRIMARY_ORACLE);
		underTest.addOracle(accounts[0], address(0), address(mockOracleSecondary));
	}

	function test_addOracle_asOwner_givenValidOracles_thenAddNewOracle() public prankAs(owner) {
		underTest.addOracle(accounts[0], address(mockOraclePrimary), address(mockOracleSecondary));

		(address primary, address secondary) = underTest.oracles(accounts[0]);
		assertEq(primary, address(mockOraclePrimary));
		assertEq(secondary, address(mockOracleSecondary));
	}

	function test_addOracle_asOwner_givenInvalidOracles_thenReverts() public prankAs(owner) {
		mockVerificator.setGoodPrice(0);

		vm.expectRevert(REVERT_ORACLE_DOWN);
		underTest.addOracle(accounts[0], address(mockOraclePrimary), address(mockOracleSecondary));
	}

	function test_addOracle_asOwner_givenPrimaryOnly_thenAddOracle() public prankAs(owner) {
		underTest.addOracle(accounts[0], address(mockOraclePrimary), address(0));

		(address primary, address secondary) = underTest.oracles(accounts[0]);
		assertEq(primary, address(mockOraclePrimary));
		assertEq(secondary, address(0));
	}

	function test_addOracle_asAccessActor_givenValidOracles_thenAddNewOracle() public prankAs(accessActor) {
		underTest.addOracle(accounts[0], address(mockOraclePrimary), address(mockOracleSecondary));

		(address primary, address secondary) = underTest.oracles(accounts[0]);
		assertEq(primary, address(mockOraclePrimary));
		assertEq(secondary, address(mockOracleSecondary));
	}

	function test_removeOracle_asUser_thenReverts() public prankAs(user) {
		vm.expectRevert(REVERT_INVALID_ACCESS);
		underTest.removeOracle(address(0));
	}

	function test_removeOracle_asOnwer_thenRemoveOracle() public prankAs(owner) {
		underTest.addOracle(accounts[0], address(mockOraclePrimary), address(mockOracleSecondary));
		underTest.removeOracle(accounts[0]);

		(address primary, address secondary) = underTest.oracles(accounts[0]);
		assertEq(primary, address(0));
		assertEq(secondary, address(0));
	}

	function test_removeOracle_asAccessActor_thenRemoveOracle() public prankAs(accessActor) {
		underTest.addOracle(accounts[0], address(mockOraclePrimary), address(mockOracleSecondary));
		underTest.removeOracle(accounts[0]);

		(address primary, address secondary) = underTest.oracles(accounts[0]);
		assertEq(primary, address(0));
		assertEq(secondary, address(0));
	}

	function test_fetchPrice_givenUnsupportedToken_thenReverts() public {
		vm.expectRevert(REVERT_ORACLE_NOT_FOUND);
		underTest.fetchPrice(address(0));
	}

	function test_fetchPrice_givenSupportedToken_thenReturnAndSavePrice() public {
		vm.prank(owner);
		underTest.addOracle(accounts[0], address(mockOraclePrimary), address(mockOracleSecondary));

		uint256 receivedValue = underTest.fetchPrice(accounts[0]);
		assertEq(receivedValue, mockVerificator.goodPrice());
		assertEq(underTest.lastGoodPrice(accounts[0]), mockVerificator.goodPrice());
	}
}

contract MockOracle {
	uint256 private price = 1;
	uint256 private lastPrice = 2;
	uint256 private lastUpdate = 3;

	function setData(
		uint256 _price,
		uint256 _lastPrice,
		uint256 _lastUpdate
	) external {
		price = _price;
		lastPrice = _lastPrice;
		lastUpdate = _lastUpdate;
	}

	function retriveSavedResponses(address _token)
		external
		view
		returns (
			uint256,
			uint256,
			uint256
		)
	{
		return (price, lastPrice, lastUpdate);
	}
}

contract MockVerificator is IOracleVerificationV1 {
	uint256 public goodPrice = 100;

	function setGoodPrice(uint256 _good) external {
		goodPrice = _good;
	}

	function verify(RequestVerification memory request) external view override returns (uint256) {
		return goodPrice;
	}
}
