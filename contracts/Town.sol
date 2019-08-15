pragma solidity ^0.5.0;

import "@openzeppelin/contracts/ownership/Ownable.sol";
import "./TownToken.sol";


contract Town is Ownable {
    using SafeMath for uint256;

    struct ExternalTokenDistributionsInfo {
        address _official;
        uint256 _fullBalance;
        uint256 _distributionAmount;
        uint256 _distributionsCount;
    }

    struct ExternalToken {
        ExternalTokenDistributionsInfo[] _entities;
        uint256 _weight;
    }

    struct TransactionsInfo {
        uint256 _rate;
        uint256 _amount;
    }

    struct RemunerationsInfo {
        uint256 _priority;
        uint256 _amount;
    }

    //////////////////////////////////////////////////////////

    uint256 private _gasSourceType;
    uint256 private _distributionPeriodType;
    uint256 private _distributionPeriodsNumber;
    uint256 private _startRate;

    TownToken private _token;
    address payable private _wallet;

    uint256 private _buyersCount;
    uint256 private _minTokenBuyAmount;
    uint256 private _durationOfMinTokenBuyAmount;
    uint256 private _maxTokenBuyAmount;

    uint256 private _minExternalTokensAmount;
    uint256 private _lastDistributionsDate;

    mapping (address => TransactionsInfo[]) private _historyTransactions;

    mapping (address => TransactionsInfo[]) private _queueBuyRequests;
    address[] private _queueBuyRequestsAddresses;

    mapping (address => RemunerationsInfo[]) private _remunerationsQueue;
    address[] private _remunerationsQueueAddresses;

    mapping (address => ExternalToken) private _externalTokens;
    address[] private _externalTokensAddresses;

    mapping (address => mapping (address => uint256)) private _townHoldersLedger;
    mapping (address => address[]) private _ledgerExternalTokensAddresses;

    mapping (address => uint256) private _officialsLedger;
    address[] private _officialsLedgerAddresses;

    //////////////////////////////////////////////////////////

    function sendExternalTokens(address official, address externalToken) external returns (bool) {
        return true;
    }

    function buyTownTokens(address holder, uint256 amount) public payable returns (bool) {
        return true;
    }

    function refunds(uint256 amount) public external returns (bool) {
        return true;
    }

    function voteOn(address externalToken, uint256 amount) public returns (bool) {
        return true;
    }

    function distributionSnapshot() public returns (bool) {
        return true;
    }

    function claimExternalTokens(address holder) public returns (bool) {
        return true;
    }

    function claimFunds(address official) public returns (bool) {
        return true;
    }

    //////////////////////////////////////////////////////////

    function token() public returns (IERC20) {
        return _token;
    }

    function currentRate() public returns (uint256) {
        return _startRate;
    }

    function findRemunerationForAddress(address user) public returns (RemunerationsInfo[]) {
        return _remunerationsQueue[user];

    }

    function findBuyRequestForAddress(address user) public returns (TransactionsInfo[]) {
        return _externalTokensAddresses;
    }
}
