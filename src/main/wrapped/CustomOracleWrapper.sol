// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.13;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

import "./BaseWrapper.sol";

import { IOracleVerificationV1 as Verificator } from "../interfaces/IOracleVerificationV1.sol";
import "../libs/TimeoutChecker.sol";
import "../libs/AddressCalls.sol";

/*
Classic Oracles, no fancy logic, just fetch the price and we are done.
*/
contract CustomOracleWrapper is BaseWrapper, OwnableUpgradeable {
	event OracleAdded(address indexed _token, address _externalOracle);

	struct OracleResponse {
		uint256 currentPrice;
		uint256 lastPrice;
		uint256 lastUpdate;
		bool success;
	}

	struct CustomOracle {
		address contractAddress;
		uint8 decimals;
		bytes callCurrentPrice;
		bytes callLastPrice;
		bytes callLastUpdate;
		bytes callDecimals;
	}

	uint256 public constant TIMEOUT = 4 hours;

	mapping(address => CustomOracle) public oracles;
	mapping(address => SavedResponse) public savedResponses;

	function setUp() external initializer {
		__Ownable_init();
	}

	function addOracle(
		address _token,
		address _externalOracle,
		uint8 _decimals,
		bytes memory _callCurrentPrice,
		bytes memory _callLastPrice,
		bytes memory _callLastUpdate,
		bytes memory _callDecimals
	) external onlyOwner isContract(_externalOracle) {
		require(_decimals != 0, "Invalid Decimals");

		oracles[_token] = CustomOracle(
			_externalOracle,
			_decimals,
			_callCurrentPrice,
			_callLastPrice,
			_callLastUpdate,
			_callDecimals
		);

		OracleResponse memory response = _getResponses(_token);

		if (_isBadOracleResponse(response)) {
			revert ResponseFromOracleIsInvalid(_token, _externalOracle);
		}

		savedResponses[_token].currentPrice = response.currentPrice;
		savedResponses[_token].lastPrice = response.lastPrice;
		savedResponses[_token].lastUpdate = response.lastUpdate;

		emit OracleAdded(_token, _externalOracle);
	}

	function removeOracle(address _token) external onlyOwner {
		delete oracles[_token];
		delete savedResponses[_token];
	}

	function retriveSavedResponses(address _token) external override returns (SavedResponse memory savedResponse) {
		fetchPrice(_token);
		return savedResponses[_token];
	}

	function fetchPrice(address _token) public override {
		OracleResponse memory oracleResponse = _getResponses(_token);
		SavedResponse storage responses = savedResponses[_token];

		if (!_isBadOracleResponse(oracleResponse) && !TimeoutChecker.isTimeout(oracleResponse.lastUpdate, TIMEOUT)) {
			responses.currentPrice = oracleResponse.currentPrice;
			responses.lastPrice = oracleResponse.lastPrice;
			responses.lastUpdate = oracleResponse.lastUpdate;
		}
	}

	function getLastPrice(address _token) external view override returns (uint256) {
		return savedResponses[_token].lastPrice;
	}

	function getCurrentPrice(address _token) external view override returns (uint256) {
		return savedResponses[_token].currentPrice;
	}

	function _getResponses(address _token) internal view returns (OracleResponse memory response) {
		CustomOracle memory oracle = oracles[_token];
		if (oracle.contractAddress == address(0)) {
			revert TokenIsNotRegistered(_token);
		}

		uint8 decimals = _getDecimals(oracle);
		uint256 lastUpdate = _getLastUpdate(oracle);

		uint256 currentPrice = _getPrice(oracle.contractAddress, oracle.callCurrentPrice);
		uint256 lastPrice = _getPrice(oracle.contractAddress, oracle.callLastPrice);

		response.lastUpdate = lastUpdate;
		response.currentPrice = scalePriceByDigits(currentPrice, decimals);
		response.lastPrice = scalePriceByDigits(lastPrice, decimals);
		response.success = currentPrice != 0;

		return response;
	}

	function _getDecimals(CustomOracle memory _oracle) internal view returns (uint8) {
		(uint8 response, bool success) = AddressCalls.callReturnsUint8(_oracle.contractAddress, _oracle.callDecimals);

		return success ? response : _oracle.decimals;
	}

	function _getPrice(address _contractAddress, bytes memory _callData) internal view returns (uint256) {
		(uint256 response, bool success) = AddressCalls.callReturnsUint256(_contractAddress, _callData);

		return success ? response : 0;
	}

	function _getLastUpdate(CustomOracle memory _oracle) internal view returns (uint256) {
		(uint256 response, bool success) = AddressCalls.callReturnsUint256(
			_oracle.contractAddress,
			_oracle.callLastUpdate
		);

		return success ? response : block.timestamp;
	}

	function _isBadOracleResponse(OracleResponse memory _response) internal view returns (bool) {
		if (!_response.success) {
			return true;
		}
		if (_response.lastUpdate == 0 || _response.lastUpdate > block.timestamp) {
			return true;
		}
		if (_response.currentPrice <= 0 || _response.lastPrice <= 0) {
			return true;
		}

		return false;
	}
}
