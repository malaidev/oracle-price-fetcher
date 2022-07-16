// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.13;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

import "./interfaces/IPriceFeedV2.sol";
import { IOracleVerificationV1 as Verificator } from "./interfaces/IOracleVerificationV1.sol";
import "./interfaces/IOracleWrapper.sol";

contract PriceFeedV2 is IPriceFeedV2, OwnableUpgradeable {
	Verificator public verificator;

	mapping(address => bool) public accesses;
	mapping(address => uint256) public lastGoodPrice;
	mapping(address => Oracle) public oracles;

	modifier hasAccess() {
		require(accesses[msg.sender] || owner() == msg.sender, "Invalid access");
		_;
	}

	function setUp(address _verificator) external initializer {
		require(_verificator != address(0), "Invalid Verificator");

		__Ownable_init();
		verificator = Verificator(_verificator);
	}

	function setAccessTo(address _addr, bool _hasAccess) external onlyOwner {
		accesses[_addr] = _hasAccess;
		emit AccessChanged(_addr, _hasAccess);
	}

	function changeVerificator(address _verificator) external onlyOwner {
		require(_verificator != address(0), "Invalid Verificator");
		verificator = Verificator(_verificator);

		emit OracleVerificationChanged(_verificator);
	}

	function addOracle(
		address _token,
		address _primaryOracle,
		address _secondaryOracle
	) external override hasAccess {
		require(_primaryOracle != address(0), "Invalid Primary Oracle");

		Oracle storage oracle = oracles[_token];
		oracle.primaryWrapper = _primaryOracle;
		oracle.secondaryWrapper = _secondaryOracle;
		uint256 price = _getValidPrice(_token, _primaryOracle, _secondaryOracle);

		if (price == 0) revert("Oracle down");

		lastGoodPrice[_token] = price;

		emit OracleAdded(_token, _primaryOracle, _secondaryOracle);
	}

	function removeOracle(address _token) external hasAccess {
		delete oracles[_token];
		emit OracleRemoved(_token);
	}

	function fetchPrice(address _token) external override returns (uint256) {
		Oracle memory oracle = oracles[_token];
		require(oracle.primaryWrapper != address(0), "Oracle not found");

		uint256 goodPrice = _getValidPrice(_token, oracle.primaryWrapper, oracle.secondaryWrapper);
		lastGoodPrice[_token] = goodPrice;

		emit TokenPriceUpdated(_token, goodPrice);
		return goodPrice;
	}

	function _getValidPrice(
		address _token,
		address primary,
		address secondary
	) internal returns (uint256) {
		IOracleWrapper.SavedResponse memory primaryResponse = IOracleWrapper(primary).retriveSavedResponses(_token);

		IOracleWrapper.SavedResponse memory secondaryResponse = secondary == address(0)
			? IOracleWrapper.SavedResponse(0, 0, 0)
			: IOracleWrapper(secondary).retriveSavedResponses(_token);

		return
			verificator.verify(
				Verificator.RequestVerification(lastGoodPrice[_token], primaryResponse, secondaryResponse)
			);
	}
}
