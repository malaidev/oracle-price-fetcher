// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.13;

import "../interfaces/IPriceOracleV1.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

contract PriceOracleV1 is IPriceOracleV1, OwnableUpgradeable {
	uint256 public currentPrice;
	uint256 public lastPrice;
	uint256 public lastUpdate;

	mapping(address => bool) trusted;

	uint8 public decimals;

	error AddressNotTrusted();
	error ZeroAddress();

	modifier hasTrusted() {
		if (!trusted[msg.sender]) revert AddressNotTrusted();
		_;
	}

	modifier checkNonZeroAddress(address _addr) {
		if (_addr == address(0)) revert ZeroAddress();
		_;
	}

	function setUp(
		uint256 current,
		uint256 last,
		uint8 dec
	) external initializer {
		decimals = dec;

		currentPrice = current;
		lastPrice = last;
		lastUpdate = block.timestamp;

		__Ownable_init();
	}

	function setDecimals(uint8 _decimals) external onlyOwner {
		decimals = _decimals;
	}

	function registerTrustedNode(address _node) external checkNonZeroAddress(_node) onlyOwner {
		trusted[_node] = true;
	}

	function unregisterTrustedNode(address _node) external checkNonZeroAddress(_node) onlyOwner {
		trusted[_node] = false;
	}

	function update(uint256 newPrice) external hasTrusted {
		lastPrice = currentPrice;
		currentPrice = newPrice;
		lastUpdate = block.timestamp;
	}

	function getPriceData()
		external
		view
		returns (
			uint256 _currentPrice,
			uint256 _lastPrice,
			uint256 _lastUpdate
		)
	{
		return (currentPrice, lastPrice, lastUpdate);
	}
}
