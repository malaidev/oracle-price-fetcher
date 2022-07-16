// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.13;

/**
 * @dev Oracle contract for fetching a certain token price
 * Centralization issue still exists when adopting this contract for global uses
 * For special uses of supporting built-in protocols only
 */
interface IPriceOracleV1 {
	function setDecimals(uint8 _decimals) external;

	/**
	 * @dev register address as a trusted Node
	 * Trusted node has permission to update price data
	 */
	function registerTrustedNode(address _node) external;

	/**
	 * @dev remove address from tursted list
	 */
	function unregisterTrustedNode(address _node) external;

	/**
	 * @dev update price data
	 * This function is supposed to be called by trusted node only
	 */
	function update(uint256 newPrice) external;

	/**
	 * @dev returns current price data including price, round & time of last update
	 */
	function getPriceData()
		external
		view
		returns (
			uint256 _currentPrice,
			uint256 _lastPrice,
			uint256 _lastUpdate
		);
}
