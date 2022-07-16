// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.13;

library AddressCalls {
	function callReturnsUint8(address _contract, bytes memory _callData) internal view returns (uint8, bool) {
		(bool success, bytes memory response) = call(_contract, _callData);

		if (success) {
			return (abi.decode(response, (uint8)), true);
		}

		return (0, false);
	}

	function callReturnsUint256(address _contract, bytes memory _callData) internal view returns (uint256, bool) {
		(bool success, bytes memory response) = call(_contract, _callData);

		if (success) {
			return (abi.decode(response, (uint256)), true);
		}

		return (0, false);
	}

	function callReturnsBytes32(address _contract, bytes memory _callData) internal view returns (bytes32, bool) {
		(bool success, bytes memory response) = call(_contract, _callData);

		if (success) {
			return (abi.decode(response, (bytes32)), true);
		}

		return ("", false);
	}

	function call(address _contract, bytes memory _callData)
		internal
		view
		returns (bool success, bytes memory response)
	{
		if (_contract == address(0)) {
			return (false, response);
		}

		return _contract.staticcall(_callData);
	}
}
