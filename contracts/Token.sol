// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ERC20} from '@openzeppelin/contracts/token/ERC20/ERC20.sol';

contract Token is ERC20 {
  uint8 private immutable _decimals;

  constructor(string memory _symbol, uint8 _initialDecimals, uint256 _initialSupply) ERC20(_symbol, _symbol) {
    _decimals = _initialDecimals;
    _mint(msg.sender, _initialSupply);
  }

  function decimals() public view virtual override returns (uint8) {
    return _decimals;
  }
}
