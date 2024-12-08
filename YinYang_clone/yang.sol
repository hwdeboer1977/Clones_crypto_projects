// SPDX-License-Identifier: MIT
// __   __ _    _   _  ____ 
// \ \ / // \  | \ | |/ ___|
//  \ V // _ \ |  \| | |  _ 
//   | |/ ___ \| |\  | |_| |
//   |_/_/   \_\_| \_|\____|
                          
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "./Date.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "./RoundMath.sol";

// How to run?
// 1. Deploy YIN contract and save it's CA
// 2. Deploy YANG contract with YIN's CA as input
// 3. setYangContract (in YIN contract)
// 4. Set and lock price factors
//    4.1 _growthrate = 10 and _priceFactors = [5,4,3,2];
//    4.2 lockPriceFactors
// 5. doCreateBlock

// CNR (Centric Rise) uses this: 

     // Price factors for months with [28, 29, 30, 31] days,
     // price factors determine compounding hourly growth
     // from the headling monthly growthRate,
     // calculated as (1+r)^(1/t)-1
     // where:
     // r - growthRate,
    // t - number of hours in a given month
     //
     // e.g.: for growthRate=2850 (2850/GROWTH_RATE_BASE=0.285=28.5%)
     // price factors are (considering PRICE_FACTOR_BASE): [37322249, 36035043, 34833666, 33709810]

     // Price factor for a month with 30 days (= 720 hours) then is:
     // ((1 + 2850/10000)^(1/720) - 1) * PRICE_FACTOR_BASE

     

abstract contract YinInterface {
    function totalSupply() public view virtual returns (uint256);
    function balanceOf(address who) external view virtual returns (uint256);
    function mintFromYang(address to, uint256 value) public virtual returns (bool);
    function burnFromYang(address tokensOwner, uint256 value) external virtual returns (bool);
}

contract Yang is ERC20, Ownable {
    using Date for uint256;
    using SafeMath for uint256;
    using RoundMath for uint256;

    address public yinContract;
    uint256 public quarantineBalance;
    uint256 public lastBlockNumber; // number of last created block
    uint256 public lastBurnedHour;

    // Price of Yang in USD has base of PRICE_BASE
    uint256 constant PRICE_BASE = 10**8;

    // Initial price of Yang in USD
    uint256 constant INITIAL_PRICE = 100000000; // $1.0

    // Structure of a Price Block
    struct Block {
        uint256 yangPrice; // USD price of Yang for the block
        uint256 growthRate; // FutureGrowthRate value at the time of block creation
        uint256 change; // percentage (base of PRICE_BASE), YangPrice change relative to prev. block
        uint256 created; // hours, Unix epoch time
    }

    // Price Blocks for a given hour (number of hours since epoch time)
    mapping(uint256 => Block) public hoursToBlock;

    // Price factors for months with [28, 29, 30, 31] days
    mapping(uint256 => uint256[4]) public growthRateToPriceFactors;
    uint256 constant GROWTH_RATE_BASE = 10**4;
    uint256 constant PRICE_FACTOR_BASE = 10**11;

    bool public priceFactorsLocked = false;

    event DoBurn(uint256 indexed currentHour, uint256 yangAmountBurnt);
    event ConvertToYin(address indexed converter, uint256 yangAmountSent, uint256 yinAmountReceived);
    event ConvertToYang(address indexed converter, uint256 yinAmountSent, uint256 yangAmountReceived);
    event MintYin(address receiver, uint256 amount);
    event BurnYin(uint256 amountBurnt);
    event PriceFactorSet(uint256 growthRate, uint256 priceFactor0, uint256 priceFactor1, uint256 priceFactor2, uint256 priceFactor3);
    event BlockCreated(uint256 blockNumber, uint256 yangPrice, uint256 growthRate, uint256 change, uint256 created);
    event QuarantineBalanceBurnt(uint256 amount);
    event LostTokensBurnt(uint256 amount);

   // OpenZeppelin’s Ownable contract automatically sets the deployer as the contract owner 
    //without needing to call Ownable() in the constructor.
    constructor(address _yinContract)  Ownable(msg.sender) ERC20('Flux YANG ', 'YANG') {
        _mint(msg.sender, 250000000000000); // 2.5 Million
        yinContract = _yinContract;
    }

    // Override decimals function to return 8
    function decimals() public view virtual override returns (uint8) {
        return 8;
    }

    function getCurrentPrice() external view returns (uint256) {
        require(hoursToBlock[getCurrentHour()].yangPrice > 0, 'BLOCK_NOT_DEFINED');
        return hoursToBlock[getCurrentHour()].yangPrice;
    }

    function getPrice(uint256 _hour) external view returns (uint256) {
        require(hoursToBlock[_hour].yangPrice > 0, 'BLOCK_NOT_DEFINED');
        return hoursToBlock[_hour].yangPrice;
    }

    function getBlockData(uint256 _hoursEpoch)
        external
        view
        returns (
            uint256 _yangPrice,
            uint256 _growthRate,
            uint256 _change,
            uint256 _created
        )
    {
        require(_hoursEpoch > 0, 'EMPTY_HOURS_VALUE');
        require(hoursToBlock[_hoursEpoch].yangPrice > 0, 'BLOCK_NOT_DEFINED');

        _yangPrice = hoursToBlock[_hoursEpoch].yangPrice;
        _growthRate = hoursToBlock[_hoursEpoch].growthRate;
        _change = hoursToBlock[_hoursEpoch].change;
        _created = hoursToBlock[_hoursEpoch].created;

        return (_yangPrice, _growthRate, _change, _created);
    }

    function doCreateBlock(uint256 _blockNumber, uint256 _growthRate)
        external
        onlyOwner
        returns (bool _success)
    {
        require(priceFactorsLocked, 'PRICE_FACTORS_MUST_BE_LOCKED');
        require(_growthRate != 0, 'GROWTH_RATE_CAN_NOT_BE_ZERO');
        require(_growthRate < GROWTH_RATE_BASE, 'GROWTH_RATE_IS_GREATER_THAN_GROWTH_RATE_BASE');
        require(growthRateToPriceFactors[_growthRate][0] > 0, 'GROWTH_RATE_IS_NOT_SPECIFIED');
        require(_createBlock(_blockNumber, _growthRate), 'FAILED_TO_CREATE_BLOCK');
        return true;
    }

    function setPriceFactors(uint256 _growthRate, uint256[4] memory _priceFactors)
        external
        onlyOwner
        returns (bool _success)
    {
        require(priceFactorsLocked == false, 'PRICE_FACTORS_ALREADY_LOCKED');
        require(_growthRate != 0, 'GROWTH_RATE_CAN_NOT_BE_ZERO');
        require(_growthRate < GROWTH_RATE_BASE, 'GROWTH_RATE_IS_GREATER_THAN_GROWTH_RATE_BASE');
        require(_priceFactors[0] > 0, 'PRICE_FACTOR_0_CAN_NOT_BE_ZERO');
        require(_priceFactors[0] < 103200117, 'PRICE_FACTOR_0_IS_TOO_BIG');
        require(_priceFactors[1] > 0, 'PRICE_FACTOR_1_CAN_NOT_BE_ZERO');
        require(_priceFactors[1] < 99639720, 'PRICE_FACTOR_1_IS_TOO_BIG');
        require(_priceFactors[2] > 0, 'PRICE_FACTOR_2_CAN_NOT_BE_ZERO');
        require(_priceFactors[2] < 96316797, 'PRICE_FACTOR_2_IS_TOO_BIG');
        require(_priceFactors[3] > 0, 'PRICE_FACTOR_3_CAN_NOT_BE_ZERO');
        require(_priceFactors[3] < 93208356, 'PRICE_FACTOR_3_IS_TOO_BIG');
        require(_priceFactors[0] > _priceFactors[1] && _priceFactors[1] > _priceFactors[2] && _priceFactors[2] > _priceFactors[3], 'PRICE_FACTORS_ARE_NOT_VALID');

        growthRateToPriceFactors[_growthRate] = _priceFactors;

        emit PriceFactorSet(_growthRate, _priceFactors[0], _priceFactors[1], _priceFactors[2], _priceFactors[3]);
        return true;
    }

    function lockPriceFactors() external onlyOwner returns (bool _success) {
        priceFactorsLocked = true;
        return true;
    }

    function doBurn() external returns (bool _success) {
        require(hoursToBlock[getCurrentHour()].yangPrice != 0, 'CURRENT_PRICE_BLOCK_NOT_DEFINED');
        require(lastBurnedHour < getCurrentHour(), 'CHANGE_IS_ALREADY_BURNT_IN_THIS_HOUR');

        lastBurnedHour = getCurrentHour();

        uint256 _yangBurnt = _burnQuarantined();

        emit DoBurn(getCurrentHour(), _yangBurnt);
        return true;
    }

    function convertToYang(uint256 _yinAmount) external returns (bool _success) {
        require(hoursToBlock[getCurrentHour()].yangPrice != 0, 'CURRENT_PRICE_BLOCK_NOT_DEFINED');
        require(YinInterface(yinContract).balanceOf(msg.sender) >= _yinAmount, 'INSUFFICIENT_YIN_BALANCE');
        require(YinInterface(yinContract).burnFromYang(msg.sender, _yinAmount), 'BURNING_YIN_FAILED');

        emit BurnYin(_yinAmount);

        uint256 _yangToDequarantine = (_yinAmount * PRICE_BASE) / hoursToBlock[getCurrentHour()].yangPrice;
        quarantineBalance = quarantineBalance.sub(_yangToDequarantine);
        require(this.transfer(msg.sender, _yangToDequarantine), 'CONVERT_TO_YANG_FAILED');

        emit ConvertToYang(msg.sender, _yinAmount, _yangToDequarantine);
        return true;
    }

    function convertToYin(uint256 _yangAmount) external returns (uint256) {
        require(hoursToBlock[getCurrentHour()].yangPrice != 0, 'CURRENT_PRICE_BLOCK_NOT_DEFINED');
        require(balanceOf(msg.sender) >= _yangAmount, 'INSUFFICIENT_YANG_BALANCE');

        quarantineBalance = quarantineBalance.add(_yangAmount);
        require(transfer(address(this), _yangAmount), 'YANG_TRANSFER_FAILED');

        uint256 _yinToIssue = (_yangAmount.mul(hoursToBlock[getCurrentHour()].yangPrice)).div(PRICE_BASE);
        require(YinInterface(yinContract).mintFromYang(msg.sender, _yinToIssue), 'YIN_MINT_FAILED');

        emit MintYin(msg.sender, _yinToIssue);
        emit ConvertToYin(msg.sender, _yangAmount, _yinToIssue);
        return _yinToIssue;
    }

    function burnLostTokens() external onlyOwner returns (bool _success) {
        uint256 _amount = balanceOf(address(this)).sub(quarantineBalance);
        _burn(address(this), _amount);
        emit LostTokensBurnt(_amount);
        return true;
    }

    function _burnQuarantined() internal returns (uint256) {
        uint256 _quarantined = quarantineBalance;
        uint256 _currentPrice = hoursToBlock[getCurrentHour()].yangPrice;
        uint256 _yinSupply = YinInterface(yinContract).totalSupply();

        uint256 _yangToBurn = (((_quarantined.mul(_currentPrice)).div(PRICE_BASE)).sub(_yinSupply)).mul(PRICE_BASE).div(_currentPrice);
        quarantineBalance = quarantineBalance.sub(_yangToBurn);
        _burn(address(this), _yangToBurn);

        emit QuarantineBalanceBurnt(_yangToBurn);
        return _yangToBurn;
    }

    uint256 public test1;
    uint256 public test2;
    uint256 public test3;
    uint256 public test4;
   

    function _createBlock(uint256 _expectedBlockNumber, uint256 _growthRate) internal returns (bool _success) {
        uint256 _lastPrice;
        uint256 _nextBlockNumber;

        if (lastBlockNumber == 0) {
            require(_expectedBlockNumber > getCurrentHour(), 'FIRST_BLOCK_MUST_BE_IN_THE_FUTURE');
            require(_expectedBlockNumber < getCurrentHour() + 365 * 24, 'FIRST_BLOCK_MUST_BE_WITHIN_ONE_YEAR');
            _lastPrice = INITIAL_PRICE;
            _nextBlockNumber = _expectedBlockNumber;
        } else {
            _lastPrice = hoursToBlock[lastBlockNumber].yangPrice;
            _nextBlockNumber = lastBlockNumber.add(1);
        }

        require(_nextBlockNumber == _expectedBlockNumber, 'WRONG_BLOCK_NUMBER');

        uint256 _yangPriceFactor;
        uint256 _monthBlocks = (_nextBlockNumber * 60 * 60 * 1000).getHoursInMonth();

        if (_monthBlocks == 28 * 24) {
            _yangPriceFactor = growthRateToPriceFactors[_growthRate][0];
        } else if (_monthBlocks == 29 * 24) {
            _yangPriceFactor = growthRateToPriceFactors[_growthRate][1];
        } else if (_monthBlocks == 30 * 24) {
            _yangPriceFactor = growthRateToPriceFactors[_growthRate][2];
        } else {
            _yangPriceFactor = growthRateToPriceFactors[_growthRate][3];
        }

        uint256 _yangPrice = ((_yangPriceFactor.mul(_lastPrice)).add(_lastPrice.mul(PRICE_FACTOR_BASE))).ceilDiv(PRICE_FACTOR_BASE);
        uint256 _change = (_yangPrice.sub(_lastPrice)).mul(PRICE_BASE).roundDiv(_lastPrice);
        uint256 _created = getCurrentHour();

        test1 = _yangPriceFactor;
        test2 = _lastPrice;
        test3 = _yangPrice;
        test4 = _change;

        hoursToBlock[_nextBlockNumber] = Block({
            yangPrice: _yangPrice,
            growthRate: _growthRate,
            change: _change,
            created: _created
        });

        lastBlockNumber = _nextBlockNumber;

        emit BlockCreated(_nextBlockNumber, _yangPrice, _growthRate, _change, _created);
        return true;
    }

    function getAddInfo() public view returns (uint256, uint256, uint256, uint256) {
        return (test1, test2, test3, test4);
    } 

    function getCurrentTime() public view virtual returns (uint256) {
        return block.timestamp;
    }

    function getCurrentHour() public view returns (uint256) {
        return getCurrentTime().div(1 hours);
    }

    function multiTransfer(address[] memory recipients, uint256[] memory amounts) external returns (bool) {
    require(recipients.length == amounts.length, "Recipients and amounts length mismatch");
    
    for (uint256 i = 0; i < recipients.length; i++) {
        require(transfer(recipients[i], amounts[i]), "Transfer failed");
    }
    
    return true;
}
}