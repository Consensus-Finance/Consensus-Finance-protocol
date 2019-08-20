pragma solidity ^0.5.0;

import "./TownToken.sol";


contract Town {
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

    struct TownTokenRequest {
        address _address;
        TransactionsInfo _info;
    }

    struct RemunerationsInfo {
        address _address;
        uint256 _priority;
        uint256 _amount;
    }

    //////////////////////////////////////////////////////////

    uint256 private _distributionPeriodType;
    uint256 private _distributionPeriodsNumber;
    uint256 private _startRate;

    TownToken private _token;

    uint256 private _buyersCount;
    uint256 private _minTokenBuyAmount;
    uint256 private _durationOfMinTokenBuyAmount;
    uint256 private _maxTokenBuyAmount;

    uint256 private _minExternalTokensAmount;
    uint256 private _lastDistributionsDate;

    mapping (address => TransactionsInfo[]) private _historyTransactions;

    TownTokenRequest[] private _queueTownTokenRequests;

    RemunerationsInfo[] private _remunerationsQueue;

    mapping (address => ExternalToken) private _externalTokens;
    address[] private _externalTokensAddresses;

    mapping (address => mapping (address => uint256)) private _townHoldersLedger;
    mapping (address => address[]) private _ledgerExternalTokensAddresses;

    mapping (address => uint256) private _officialsLedger;
    address[] private _officialsLedgerAddresses;

    //////////////////////////////////////////////////////////

    modifier onlyTownTokenSmartContract {
        require(msg.sender == address(_token));
        _;
    }
    //////////////////////////////////////////////////////////

    function token() external view returns (IERC20) {
        return _token;
    }

    function currentRate() external view returns (uint256) {
        return _startRate;
    }

    function getLengthRemunerationQueue() external view returns (uint256) {
        return _remunerationsQueue.length;
    }

    function getRemunerationQueue(uint256 index) external view returns (address, uint256, uint256) {
        return (_remunerationsQueue[index]._address, _remunerationsQueue[index]._priority, _remunerationsQueue[index]._amount);
    }

    function getLengthQueueTownTokenRequests() external view returns (uint256) {
        return _queueTownTokenRequests.length;
    }

    function getQueueTownTokenRequests(uint256 index) external  view returns (address, uint256, uint256) {
        TownTokenRequest memory tokenRequest = _queueTownTokenRequests[index];
        return (tokenRequest._address, tokenRequest._info._rate, tokenRequest._info._amount);
    }

    function getMyTownTokens() external view returns (uint256, uint256) {
        uint256 amount = 0;
        uint256 tokenAmount = 0;
        for (uint256 i = 0; i < _historyTransactions[msg.sender].length; ++i) {
            amount = amount.add(_historyTransactions[msg.sender][i]._amount.mul(_historyTransactions[msg.sender][i]._rate));
            tokenAmount = tokenAmount.add(_historyTransactions[msg.sender][i]._amount);
        }
        return (amount, tokenAmount);
    }

    function checkProposal(address proposal) external returns (bool) {
        if (_externalTokens[proposal]._entities.length > 0) {
            return true;
        }
        return false;
    }

    //////////////////////////////////////////////////////////

    function sendExternalTokens(address official, address externalToken) external returns (bool) {
        ERC20 tokenERC20 = ERC20(externalToken);
        uint256 balance = tokenERC20.allowance(official, address(this));
        require(tokenERC20.balanceOf(official) >= balance, "Official should have external tokens for approved");
        require(balance > 0, "External tokens must be approved for town smart contract");
        tokenERC20.transferFrom(official, address(this), balance);

        ExternalTokenDistributionsInfo memory tokenInfo;
        tokenInfo._official = official;
        tokenInfo._fullBalance = balance;
        tokenInfo._distributionsCount = _distributionPeriodsNumber;
        tokenInfo._distributionAmount = balance / _distributionPeriodsNumber;

        ExternalToken storage tokenObj = _externalTokens[externalToken];
        tokenObj._entities.push(tokenInfo);

        return true;
    }

    function refunds(uint256 tokensAmount) external returns (bool) {
        require(_token.balanceOf(msg.sender) >= tokensAmount, "Town tokens not found");
        require(_token.allowance(msg.sender, address(this)) >= tokensAmount, "Town tokens must be approved for town smart contract");

        uint256 debt = 0;
        uint256 restOfTokens = tokensAmount;
        uint256 executedRequestCount = 0;
        for (uint256 i = 0; i < _queueTownTokenRequests.length; ++i) {
            address user = _queueTownTokenRequests[i]._address;
            uint256 rate = _queueTownTokenRequests[i]._info._rate;
            uint256 amount = _queueTownTokenRequests[i]._info._amount;
            if (restOfTokens > amount) {
                _token.transferFrom(msg.sender, user, amount);
                restOfTokens = restOfTokens.sub(amount);
                debt = debt.add(amount.mul(rate));
                executedRequestCount++;
            } else {
                break;
            }
        }

        if (executedRequestCount > 0) {
            for (uint256 i = executedRequestCount; i < _queueTownTokenRequests.length; ++i) {
                _queueTownTokenRequests[i - executedRequestCount] = _queueTownTokenRequests[i];
            }

            for (uint256 i = 0; i < executedRequestCount; ++i) {
                delete _queueTownTokenRequests[_queueTownTokenRequests.length - 1];
                _queueTownTokenRequests.length--;
            }
        }

        _token.transferFrom(msg.sender, address(this), restOfTokens);

        for (uint256 i = _historyTransactions[msg.sender].length - 1; i >= 0; --i) {
            uint256 rate = _historyTransactions[msg.sender][i]._rate;
            uint256 amount = _historyTransactions[msg.sender][i]._amount;
            delete _historyTransactions[msg.sender][i];
            _historyTransactions[msg.sender].length--;

            if (restOfTokens < amount) {
                TransactionsInfo memory info = TransactionsInfo(rate, amount.sub(restOfTokens));
                _historyTransactions[msg.sender].push(info);

                debt = debt.add(rate.mul(restOfTokens));
                restOfTokens = 0;
                break;
            }
            debt = debt.add(rate.mul(amount));
            restOfTokens = restOfTokens.sub(amount);
        }

        if (debt > address(this).balance) {
            msg.sender.transfer(address(this).balance);

            RemunerationsInfo memory info = RemunerationsInfo(msg.sender, 2, debt.sub(address(this).balance));
            _remunerationsQueue.push(info);
        } else {
            msg.sender.transfer(debt);
        }

        return true;
    }

    function distributionSnapshot() external returns (bool) {
        return true;
    }

    function voteOn(address externalToken, uint256 amount) external onlyTownTokenSmartContract returns (bool) {
        require(_externalTokens[externalToken]._entities.length > 0, "external token address not found");

        _externalTokens[externalToken]._weight = _externalTokens[externalToken]._weight.add(amount);
        return true;
    }

    function claimExternalTokens(address holder) external returns (bool) {
        return true;
    }

    function claimFunds(address official) external returns (bool) {
        return true;
    }

    function checkTownTokensRate(uint256 amount) public view returns (uint256) {
        return amount.div(_startRate.mul(_buyersCount.add(1)));
    }

    function getTownTokens(address holder) public payable returns (bool) {
        require(holder != address(0), "holder address cannot be null");

        uint256 amount = msg.value;
        uint256 tokenAmount = checkTownTokensRate(amount);
        uint256 rate = _startRate.mul(_buyersCount.add(1));
        require(tokenAmount > _minTokenBuyAmount, "Cannot get tokens less that _minTokenBuyAmount");
        if (tokenAmount >= _maxTokenBuyAmount) {
            tokenAmount = _maxTokenBuyAmount;
            uint256 change = amount.sub(_maxTokenBuyAmount.mul(rate));
            msg.sender.transfer(change);
            amount = amount.sub(change);
        }

        TransactionsInfo memory transactionsInfo = TransactionsInfo(rate, tokenAmount);
        if (_token.balanceOf(address(this)) >= tokenAmount) {
            _token.transfer(holder, tokenAmount);
            _historyTransactions[holder].push(transactionsInfo);
            _buyersCount = _buyersCount.add(1);
        } else {
            if (_token.balanceOf(address(this)) > 0) {
                uint256 tokenBalance = _token.balanceOf(address(this));
                _token.transfer(holder, tokenBalance);
                tokenAmount = tokenAmount.sub(tokenBalance);
            }

            TownTokenRequest memory tokenRequest = TownTokenRequest(holder, transactionsInfo);
            _queueTownTokenRequests.push(tokenRequest);
        }
        return true;
    }
}
