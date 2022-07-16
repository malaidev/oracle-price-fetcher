// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.13;

library TimeoutChecker {
	function isTimeout(uint256 timestamp, uint256 timeout) internal view returns (bool) {
		if (block.timestamp < timestamp) return true;
		return block.timestamp - timestamp > timeout;
	}
}
