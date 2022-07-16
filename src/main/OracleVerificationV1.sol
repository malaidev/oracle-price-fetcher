// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.13;

import "./interfaces/IOracleVerificationV1.sol";
import "./libs/TimeoutChecker.sol";

import "@openzeppelin/contracts-upgradeable/utils/math/SafeMathUpgradeable.sol";

contract OracleVerificationV1 is IOracleVerificationV1 {
	using SafeMathUpgradeable for uint256;

	uint256 public constant MAX_PRICE_DEVIATION_FROM_PREVIOUS_ROUND = 5e17; // 50%
	uint256 public constant MAX_PRICE_DIFFERENCE_BETWEEN_ORACLES = 5e16; // 5%
	uint256 public constant TIMEOUT = 4 hours;

	function verify(RequestVerification memory request) external view override returns (uint256 value) {
		bool isPrimaryOracleBroken = _isRequestBroken(request.primaryResponse);
		bool isSecondaryOracleBroken = _isRequestBroken(request.secondaryResponse);

		bool oraclesSamePrice = _bothOraclesSimilarPrice(
			request.primaryResponse.currentPrice,
			request.secondaryResponse.currentPrice
		);

		if (!isPrimaryOracleBroken) {
			// If Oracle price has changed by > 50% between two consecutive rounds
			if (_oraclePriceChangeAboveMax(request.primaryResponse.currentPrice, request.primaryResponse.lastPrice)) {
				if (isSecondaryOracleBroken) return request.lastGoodPrice;

				return oraclesSamePrice ? request.primaryResponse.currentPrice : request.secondaryResponse.currentPrice;
			}

			return request.primaryResponse.currentPrice;
		} else if (!isSecondaryOracleBroken) {
			if (
				_oraclePriceChangeAboveMax(request.secondaryResponse.currentPrice, request.secondaryResponse.lastPrice)
			) {
				return request.lastGoodPrice;
			}

			return request.secondaryResponse.currentPrice;
		}

		return request.lastGoodPrice;
	}

	function _isRequestBroken(IOracleWrapper.SavedResponse memory response) internal view returns (bool) {
		bool isTimeout = TimeoutChecker.isTimeout(response.lastUpdate, TIMEOUT);
		return isTimeout || response.currentPrice == 0 || response.lastPrice == 0;
	}

	function _oraclePriceChangeAboveMax(uint256 _currentResponse, uint256 _prevResponse)
		internal
		pure
		returns (bool)
	{
		uint256 minPrice = _min(_currentResponse, _prevResponse);
		uint256 maxPrice = _max(_currentResponse, _prevResponse);

		/*
		 * Use the larger price as the denominator:
		 * - If price decreased, the percentage deviation is in relation to the the previous price.
		 * - If price increased, the percentage deviation is in relation to the current price.
		 */
		uint256 percentDeviation = maxPrice.sub(minPrice).mul(1e18).div(maxPrice);

		// Return true if price has more than doubled, or more than halved.
		return percentDeviation > MAX_PRICE_DEVIATION_FROM_PREVIOUS_ROUND;
	}

	function _bothOraclesSimilarPrice(uint256 _primaryOraclePrice, uint256 _secondaryOraclePrice)
		internal
		pure
		returns (bool)
	{
		if (_secondaryOraclePrice == 0 || _primaryOraclePrice == 0) return false;

		// Get the relative price difference between the oracles. Use the lower price as the denominator, i.e. the reference for the calculation.
		uint256 minPrice = _min(_primaryOraclePrice, _secondaryOraclePrice);
		uint256 maxPrice = _max(_primaryOraclePrice, _secondaryOraclePrice);

		uint256 percentPriceDifference = maxPrice.sub(minPrice).mul(1e18).div(minPrice);

		/*
		 * Return true if the relative price difference is <= 3%: if so, we assume both oracles are probably reporting
		 * the honest market price, as it is unlikely that both have been broken/hacked and are still in-sync.
		 */
		return percentPriceDifference <= MAX_PRICE_DIFFERENCE_BETWEEN_ORACLES;
	}

	function _min(uint256 _a, uint256 _b) internal pure returns (uint256) {
		return (_a < _b) ? _a : _b;
	}

	function _max(uint256 _a, uint256 _b) internal pure returns (uint256) {
		return (_a >= _b) ? _a : _b;
	}
}
