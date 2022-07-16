import { BaseTest, console } from "./base/BaseTest.t.sol";

import "../main/OracleVerificationV1.sol";
import { IOracleVerificationV1 as OracleStruct } from "../main/interfaces/IOracleVerificationV1.sol";
import "../main/interfaces/IOracleWrapper.sol";

contract OracleVerificationV1Test is BaseTest {
	OracleVerificationV1 private underTest;

	uint256 constant TIME = 5 hours;
	uint256 constant RESPONSE_TIME = TIME - 30 minutes;

	//VALIDS
	IOracleWrapper.SavedResponse private SAVED_VALID = IOracleWrapper.SavedResponse(100, 51, RESPONSE_TIME);
	IOracleWrapper.SavedResponse private SAVED_VALID_TWO = IOracleWrapper.SavedResponse(122, 122, RESPONSE_TIME);
	IOracleWrapper.SavedResponse private SAVED_VALID_LOWER = IOracleWrapper.SavedResponse(51, 100, RESPONSE_TIME);
	IOracleWrapper.SavedResponse private SAVED_VALID_LOWER_TWO = IOracleWrapper.SavedResponse(3, 4, RESPONSE_TIME);

	//INVALIDS
	IOracleWrapper.SavedResponse private MISSING_ORACLE = IOracleWrapper.SavedResponse(0, 0, 0);
	IOracleWrapper.SavedResponse private INVALID_SAVED_PRICE_CHANGED_50_PERCENT =
		IOracleWrapper.SavedResponse(100, 49, RESPONSE_TIME);
	IOracleWrapper.SavedResponse private INVALID_SAVED_PRICE_CHANGED_50_PERCENT_LESS =
		IOracleWrapper.SavedResponse(49, 100, RESPONSE_TIME);
	IOracleWrapper.SavedResponse private INVALID_SAVED_TIMEOUT =
		IOracleWrapper.SavedResponse(111, 100, TIME - 4 hours - 1);

	function setUp() public {
		vm.warp(TIME);
		underTest = new OracleVerificationV1();
	}

	function test_verify_givenBothOraclesWork_thenReturnPrimaryPrice() public {
		uint256 price = underTest.verify(OracleStruct.RequestVerification(20, SAVED_VALID, SAVED_VALID));
		assertEq(SAVED_VALID.currentPrice, price);
	}

	function test_verify_givenBothOraclesBroken_thenReturnsLastGoodPrice() public {
		uint256 price = underTest.verify(OracleStruct.RequestVerification(1, INVALID_SAVED_TIMEOUT, MISSING_ORACLE));
		assertEq(1, price);
	}

	function test_verify_givenPrimaryWorks_PriceChangedAboveMax_HIGHER_missingSecondary_thenReturnLastGoodPrice()
		public
	{
		uint256 price = underTest.verify(
			OracleStruct.RequestVerification(20, INVALID_SAVED_PRICE_CHANGED_50_PERCENT, MISSING_ORACLE)
		);
		assertEq(20, price);
	}

	function test_verify_givenPrimaryWorks_PriceChangedAboveMax_HIGHER_SecondaryIsBroken_thenReturnLastGoodPrice()
		public
	{
		uint256 price = underTest.verify(
			OracleStruct.RequestVerification(20, INVALID_SAVED_PRICE_CHANGED_50_PERCENT, INVALID_SAVED_TIMEOUT)
		);
		assertEq(20, price);
	}

	function test_verify_givenPrimaryWorks_PriceChangedAboveMax_LOWER_SecondaryIsBroken_thenReturnLastGoodPrice()
		public
	{
		uint256 price = underTest.verify(
			OracleStruct.RequestVerification(20, INVALID_SAVED_PRICE_CHANGED_50_PERCENT_LESS, INVALID_SAVED_TIMEOUT)
		);
		assertEq(20, price);
	}

	function test_verify_givenPrimaryWorks_PriceChangedAboveMax_HIGHER_SecondaryIsWorking_thenReturnSecondaryPrice()
		public
	{
		uint256 price = underTest.verify(
			OracleStruct.RequestVerification(20, INVALID_SAVED_PRICE_CHANGED_50_PERCENT, SAVED_VALID_TWO)
		);
		assertEq(SAVED_VALID_TWO.currentPrice, price);
	}

	function test_verify_givenPrimaryWorks_PriceChangedAboveMax_LOWER_SecondaryIsWorking_thenReturnSecondaryPrice()
		public
	{
		uint256 price = underTest.verify(
			OracleStruct.RequestVerification(20, INVALID_SAVED_PRICE_CHANGED_50_PERCENT_LESS, SAVED_VALID_TWO)
		);
		assertEq(SAVED_VALID_TWO.currentPrice, price);
	}

	function test_verify_givenPrimaryTimeoutAndSecondaryWork_PriceChangedAboveMax_HIGHER_thenReturnLastGoodPrice()
		public
	{
		uint256 price = underTest.verify(
			OracleStruct.RequestVerification(20, INVALID_SAVED_TIMEOUT, INVALID_SAVED_PRICE_CHANGED_50_PERCENT)
		);
		assertEq(20, price);
	}

	function test_verify_givenPrimaryTimeoutAndSecondaryWork_PriceChangedAboveMax_LOWER_thenReturnLastGoodPrice()
		public
	{
		uint256 price = underTest.verify(
			OracleStruct.RequestVerification(20, INVALID_SAVED_TIMEOUT, INVALID_SAVED_PRICE_CHANGED_50_PERCENT_LESS)
		);
		assertEq(20, price);
	}

	function test_verify_givenPrimaryBrokenAndSecondaryWork_NoIssueWithOracle_thenReturnSecondaryPrice() public {
		uint256 price = underTest.verify(OracleStruct.RequestVerification(20, MISSING_ORACLE, SAVED_VALID));
		assertEq(SAVED_VALID.currentPrice, price);
	}
}
