// SPDX-License-Identifier: MIT
// __   _____ _   _
// \ \ / /_ _| \ | |
//  \ V / | ||  \| |
//   | |  | || |\  |
//   |_| |___|_| \_|

pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract Yin is Ownable, ERC20 {
  address public yangContract;
  event YangContractSet(address indexed newYangContract);

  constructor() Ownable(msg.sender) ERC20("Flux YIN", "YIN") {
    _mint(msg.sender, 0);
  }
 
  modifier onlyYang() {
    require(msg.sender == yangContract, "CALLER_MUST_BE_YANG_CONTRACT_ONLY");
    _;
  }

  function setYangContract(address _yangContractAddress) external onlyOwner {
    require(
      _yangContractAddress != address(0),
      "YANG_CONTRACT_CANNOT_BE_NULL_ADDRESS"
    );
    require(yangContract == address(0), "YANG_CONTRACT_ADDRESS_IS_ALREADY_SET");
    yangContract = _yangContractAddress;
    emit YangContractSet(_yangContractAddress);
  }

  function mintFromYang(
    address to,
    uint256 value
  ) external onlyYang returns (bool) {
    _mint(to, value);
    return true;
  }

  function burnFromYang(
    address tokensOwner,
    uint256 value
  ) external virtual onlyYang returns (bool) {
    _burn(tokensOwner, value);
    return true;
  }
}
