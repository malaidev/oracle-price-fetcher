// SPDX-License-Identifier: MIT

pragma solidity ^0.8.13;
import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";

contract MockERC20 is ERC20Upgradeable {
	uint8 private DECIMALS;

	function setUp(
		string memory _name,
		string memory _symbol,
		uint8 _decimals
	) external initializer {
		__ERC20_init(_name, _symbol);
		DECIMALS = _decimals;
	}

	function mint(address account, uint256 amount) public {
		_mint(account, amount);
	}

	function burn(address account, uint256 amount) public {
		_burn(account, amount);
	}

	function transferInternal(
		address from,
		address to,
		uint256 value
	) public {
		_transfer(from, to, value);
	}

	function approveInternal(
		address owner,
		address spender,
		uint256 value
	) public {
		_approve(owner, spender, value);
	}

	function decimals() public view override returns (uint8) {
		if (DECIMALS == 0) return 18;
		return DECIMALS;
	}
}
