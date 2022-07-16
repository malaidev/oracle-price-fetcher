// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.13;

interface IPriceFeedV2 {
	event OracleAdded(address indexed _token, address _primaryWrappedOracle, address _secondaryWrappedOracle);
	event OracleRemoved(address indexed _token);
	event AccessChanged(address indexed _token, bool _hasAccess);
	event OracleVerificationChanged(address indexed _newVerificator);
	event TokenPriceUpdated(address indexed _token, uint256 _price);

	struct Oracle {
		address primaryWrapper;
		address secondaryWrapper;
	}

	function fetchPrice(address _token) external returns (uint256);

	function addOracle(
		address _token,
		address _chainlinkOracle,
		address _chainlinkIndexOracle
	) external;
}
