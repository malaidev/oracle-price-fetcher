// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.11;

interface IOracleWrapper {
	struct SavedResponse {
		uint256 currentPrice;
		uint256 lastPrice;
		uint256 lastUpdate;
	}

	error TokenIsNotRegistered(address _token);
	error ResponseFromOracleIsInvalid(address _token, address _oracle);

	function fetchPrice(address _token) external;

	//Sad typo
	function retriveSavedResponses(address _token) external returns (SavedResponse memory currentResponse);

	function getLastPrice(address _token) external view returns (uint256);

	function getCurrentPrice(address _token) external view returns (uint256);
}
