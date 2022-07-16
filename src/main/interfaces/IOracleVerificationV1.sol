// SPDX-License-Identifier:SEE LICENSE IN LICENSE
pragma solidity ^0.8.13;

import "./IOracleWrapper.sol";

interface IOracleVerificationV1 {
	enum Status {
		PrimaryOracleWorking,
		SecondaryOracleWorking,
		BothUntrusted
	}

	struct RequestVerification {
		uint256 lastGoodPrice;
		IOracleWrapper.SavedResponse primaryResponse;
		IOracleWrapper.SavedResponse secondaryResponse;
	}

	function verify(RequestVerification memory request) external view returns (uint256);
}
