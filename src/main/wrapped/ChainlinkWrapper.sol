// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import "@chainlink/contracts/src/v0.8/interfaces/FlagsInterface.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/math/SafeMathUpgradeable.sol";

import "../libs/TimeoutChecker.sol";
import "./BaseWrapper.sol";

contract ChainlinkWrapper is BaseWrapper, OwnableUpgradeable {
	using SafeMathUpgradeable for uint256;

	event OracleAdded(address indexed _token, address _priceAggregator, address _indexAggregator);

	struct SavedChainlinkResponse {
		uint256 price;
		uint256 index;
		uint256 lastUpdate;
	}

	struct OracleResponse {
		uint80 roundId;
		uint256 answer;
		uint256 timestamp;
		bool success;
		uint8 decimals;
	}

	struct Aggregators {
		AggregatorV3Interface price;
		AggregatorV3Interface index;
	}

	uint256 constant TIMEOUT = 4 hours;

	address public flagSEQOffline;
	FlagsInterface public flagsContract;

	mapping(address => Aggregators) public aggregators;
	mapping(address => SavedChainlinkResponse) public savedResponses;
	mapping(address => SavedChainlinkResponse) public lastSavedResponses;

	function setUp(address _flagSEQ, address _flagContract)
		external
		notNull(_flagSEQ)
		notNull(_flagContract)
		initializer
	{
		__Ownable_init();
		flagSEQOffline = _flagSEQ;
		flagsContract = FlagsInterface(_flagContract);
	}

	function setFlagSEQ(address _newFlagSEQ) external onlyOwner notNull(_newFlagSEQ) {
		flagSEQOffline = _newFlagSEQ;
	}

	function setFlagContract(address _flagsContract) external onlyOwner notNull(_flagsContract) {
		require(_flagsContract != address(0), INVALID_ADDRESS);
		flagsContract = FlagsInterface(_flagsContract);
	}

	function addOracle(
		address _token,
		address _priceAggregator,
		address _indexAggregator
	) external onlyOwner isContract(_priceAggregator) isNullableOrContract(_indexAggregator) {
		aggregators[_token] = Aggregators(
			AggregatorV3Interface(_priceAggregator),
			AggregatorV3Interface(_indexAggregator)
		);

		(OracleResponse memory currentResponse, ) = _getResponses(_token, false);

		(OracleResponse memory currentResponseIndex, ) = _getResponses(_token, true);

		if (_isBadOracleResponse(currentResponse)) {
			revert ResponseFromOracleIsInvalid(_token, _priceAggregator);
		}

		if (_isBadOracleResponse(currentResponseIndex)) {
			revert ResponseFromOracleIsInvalid(_token, _indexAggregator);
		}

		SavedChainlinkResponse storage response = savedResponses[_token];

		response.price = currentResponse.answer;
		response.index = currentResponseIndex.answer;
		response.lastUpdate = currentResponse.timestamp;

		lastSavedResponses[_token] = response;

		emit OracleAdded(_token, _priceAggregator, _indexAggregator);
	}

	function removeOracle(address _token) external onlyOwner {
		delete aggregators[_token];
	}

	function retriveSavedResponses(address _token) external override returns (SavedResponse memory savedResponse) {
		fetchPrice(_token);

		SavedChainlinkResponse memory current = savedResponses[_token];
		SavedChainlinkResponse memory last = lastSavedResponses[_token];

		savedResponse.currentPrice = _sanitizePrice(current.price, current.index);
		savedResponse.lastPrice = _sanitizePrice(last.price, last.index);
		savedResponse.lastUpdate = current.lastUpdate;
	}

	function fetchPrice(address _token) public override {
		(OracleResponse memory currentResponse, OracleResponse memory previousResponse) = _getResponses(_token, false);

		(OracleResponse memory currentResponseIndex, OracleResponse memory previousResponseIndex) = _getResponses(
			_token,
			true
		);

		SavedChainlinkResponse storage response = savedResponses[_token];
		SavedChainlinkResponse storage lastResponse = lastSavedResponses[_token];

		if (!_isOracleBroken(currentResponse, previousResponse)) {
			if (!TimeoutChecker.isTimeout(currentResponse.timestamp, TIMEOUT)) {
				response.price = currentResponse.answer;
				response.lastUpdate = currentResponse.timestamp;
			}

			lastResponse.price = previousResponse.answer;
			lastResponse.lastUpdate = previousResponse.timestamp;
		}

		if (!_isOracleBroken(currentResponseIndex, previousResponseIndex)) {
			response.index = currentResponseIndex.answer;
			lastResponse.index = previousResponseIndex.answer;
		}
	}

	function getCurrentPrice(address _token) external view override returns (uint256) {
		SavedChainlinkResponse memory responses = savedResponses[_token];
		return _sanitizePrice(responses.price, responses.index);
	}

	function getLastPrice(address _token) external view override returns (uint256) {
		SavedChainlinkResponse memory responses = lastSavedResponses[_token];
		return _sanitizePrice(responses.price, responses.index);
	}

	function _sanitizePrice(uint256 price, uint256 index) internal pure returns (uint256) {
		return price.mul(index).div(1e18);
	}

	function _getResponses(address _token, bool _isIndex)
		internal
		view
		returns (OracleResponse memory currentResponse, OracleResponse memory lastResponse)
	{
		Aggregators memory tokenAggregators = aggregators[_token];

		if (address(tokenAggregators.price) == address(0)) {
			revert TokenIsNotRegistered(_token);
		}

		AggregatorV3Interface oracle = _isIndex ? tokenAggregators.index : tokenAggregators.price;

		if (address(oracle) == address(0) && _isIndex) {
			currentResponse = OracleResponse(1, 1 ether, block.timestamp, true, 18);
			lastResponse = currentResponse;
		} else {
			currentResponse = _getCurrentChainlinkResponse(oracle);
			lastResponse = _getPrevChainlinkResponse(oracle, currentResponse.roundId, currentResponse.decimals);
		}

		return (currentResponse, lastResponse);
	}

	function _getCurrentChainlinkResponse(AggregatorV3Interface _oracle)
		internal
		view
		returns (OracleResponse memory oracleResponse)
	{
		if (flagsContract.getFlag(flagSEQOffline)) {
			return oracleResponse;
		}

		try _oracle.decimals() returns (uint8 decimals) {
			oracleResponse.decimals = decimals;
		} catch {
			return oracleResponse;
		}

		try _oracle.latestRoundData() returns (
			uint80 roundId,
			int256 answer,
			uint256, /* startedAt */
			uint256 timestamp,
			uint80 /* answeredInRound */
		) {
			oracleResponse.roundId = roundId;
			oracleResponse.answer = scalePriceByDigits(uint256(answer), oracleResponse.decimals);
			oracleResponse.timestamp = timestamp;
			oracleResponse.success = true;
			return oracleResponse;
		} catch {
			return oracleResponse;
		}
	}

	function _getPrevChainlinkResponse(
		AggregatorV3Interface _priceAggregator,
		uint80 _currentRoundId,
		uint8 _currentDecimals
	) internal view returns (OracleResponse memory prevOracleResponse) {
		if (_currentRoundId == 0) {
			return prevOracleResponse;
		}

		unchecked {
			try _priceAggregator.getRoundData(_currentRoundId - 1) returns (
				uint80 roundId,
				int256 answer,
				uint256, /* startedAt */
				uint256 timestamp,
				uint80 /* answeredInRound */
			) {
				prevOracleResponse.roundId = roundId;
				prevOracleResponse.answer = scalePriceByDigits(uint256(answer), _currentDecimals);
				prevOracleResponse.timestamp = timestamp;
				prevOracleResponse.decimals = _currentDecimals;
				prevOracleResponse.success = true;
				return prevOracleResponse;
			} catch {
				return prevOracleResponse;
			}
		}
	}

	function _isOracleBroken(OracleResponse memory _response, OracleResponse memory _lastResponse)
		internal
		view
		returns (bool)
	{
		return (_isBadOracleResponse(_response) || _isBadOracleResponse(_lastResponse));
	}

	function _isBadOracleResponse(OracleResponse memory _response) internal view returns (bool) {
		if (!_response.success) {
			return true;
		}
		if (_response.roundId == 0) {
			return true;
		}
		if (_response.timestamp == 0 || _response.timestamp > block.timestamp) {
			return true;
		}
		if (_response.answer <= 0) {
			return true;
		}

		return false;
	}
}
