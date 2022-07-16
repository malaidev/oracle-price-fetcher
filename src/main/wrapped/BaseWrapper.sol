// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.13;
import "../interfaces/IOracleWrapper.sol";

abstract contract BaseWrapper is IOracleWrapper {
	uint256 public constant TARGET_DIGITS = 18;
	string internal constant INVALID_ADDRESS = "Invalid Address";

	modifier notNull(address _address) {
		require(_address != address(0), INVALID_ADDRESS);
		_;
	}

	modifier isNullableOrContract(address _address) {
		if (_address != address(0)) {
			uint256 size;
			assembly {
				size := extcodesize(_address)
			}

			require(size > 0, "Address is not a contract");
		}

		_;
	}

	modifier isContract(address _address) {
		require(_address != address(0), INVALID_ADDRESS);

		uint256 size;
		assembly {
			size := extcodesize(_address)
		}

		require(size > 0, "Address is not a contract");
		_;
	}

	function scalePriceByDigits(uint256 _price, uint256 _answerDigits) internal pure returns (uint256) {
		return
			_answerDigits < TARGET_DIGITS
				? _price * (10**(TARGET_DIGITS - _answerDigits))
				: _price / (10**(_answerDigits - TARGET_DIGITS));
	}
}
