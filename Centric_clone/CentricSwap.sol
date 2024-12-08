//SPDX-License-Identifier: Unlicense
pragma solidity 0.8.22;

import './SafeMath.sol';
import './BEP20.sol'; 

contract CentricSwap is BEP20 {
    /* Safemath is a library that protects for unexpected behavior due to underflow and overflow */
    using SafeMath for uint256;

    address public riseContract;

    /* Constructor is only executed once (to initialize at deployment) */
    /* _mintSaver is the address passed to the constructor, representing the account where the initial mint of tokens will be sent */
    /* Here it is minting 0 tokens but probably just to initialize it */
    constructor(address _mintSaver) BEP20('Centric SWAP_TEST', 'CNS_TEST', 8) {
        _mint(_mintSaver, 0);
    }

    /* If msg.sender is not equal to riseContract, the transaction will revert, */
    /* and the error message 'CALLER_MUST_BE_RISE_CONTRACT_ONLY' will be returned */
    /* This effectively ensures that only the contract specified by riseContract can call the functions that use this modifier*/
    modifier onlyRise() {
        require(msg.sender == riseContract, 'CALLER_MUST_BE_RISE_CONTRACT_ONLY');
        _;
    }

    /* Function is external and can only be called from outside the contract */
    /* Modifier onlyContractOwner ensures that only the owner of the contract can call this function */
    /* 2 require conditions, and once met, it sets the riseContract variable to the provided address (_riseContractAddress) */
    function setRiseContract(address _riseContractAddress) external onlyContractOwner() {
        require(_riseContractAddress != address(0), 'RISE_CONTRACT_CANNOTBE_NULL_ADDRESS');
        require(riseContract == address(0), 'RISE_CONTRACT_ADDRESS_IS_ALREADY_SET');
        riseContract = _riseContractAddress;
    }

    /* Modifier = onlyRise */
    /* Function mints # tokens to certain address */
    function mintFromRise(address to, uint256 value) external onlyRise returns (bool _success) {
        _mint(to, value);
        return true;
    }

    /* Modifier = onlyRise */
    /* Function burns $ tokens from a certain address (e.g. address tokensOwner) */
    function burnFromRise(address tokensOwner, uint256 value)
        external
        virtual
        onlyRise
        returns (bool _success)
    {
        _burn(tokensOwner, value);
        return true;
    }
}
