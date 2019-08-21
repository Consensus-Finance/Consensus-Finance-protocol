pragma solidity ^0.5.0;

import "./TownToken.sol";


contract Town {
    using SafeMath for uint256;

    struct ExternalTokenDistributionsInfo {
        address _official;
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

    uint256 private _distributionPeriod;
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

    constructor (
        uint256 distributionPeriod,
        uint256 distributionPeriodsNumber,
        uint256 startRate,
        uint256 totalSupplyTownTokens,
        uint256 minTokenBuyAmount,
        uint256 durationOfMinTokenBuyAmount,
        uint256 maxTokenBuyAmount,
        uint256 minExternalTokensAmount,
        uint256 startTime) public {
        require(distributionPeriod > 0, "distributionPeriod wrong");
        require(distributionPeriodsNumber > 0, "distributionPeriodsNumber wrong");
        require(startRate > 0, "startRate wrong");
        require(totalSupplyTownTokens > 0 && totalSupplyTownTokens < 10 ** 15, "totalSupplyTownTokens wrong");
        require(minTokenBuyAmount > 0, "minTokenBuyAmount wrong");
        require(durationOfMinTokenBuyAmount > 0, "durationOfMinTokenBuyAmount wrong");
        require(maxTokenBuyAmount > 0, "maxTokenBuyAmount wrong");
        require(minExternalTokensAmount > 0, "minExternalTokensAmount wrong");
        require(startTime > 0, "startTime wrong");

        _distributionPeriod = distributionPeriod * 1 days;
        _distributionPeriodsNumber = distributionPeriodsNumber;
        _startRate = startRate;

        _token = new TownToken(totalSupplyTownTokens);

        _buyersCount = 0;
        _minTokenBuyAmount = minTokenBuyAmount;
        _durationOfMinTokenBuyAmount = durationOfMinTokenBuyAmount;
        _maxTokenBuyAmount = maxTokenBuyAmount;
        _minExternalTokensAmount = minExternalTokensAmount;
        _lastDistributionsDate = startTime;
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
        tokenInfo._distributionsCount = _distributionPeriodsNumber;
        tokenInfo._distributionAmount = balance.div(_distributionPeriodsNumber);

        ExternalToken storage tokenObj = _externalTokens[externalToken];

        if (tokenObj._entities.length == 0) {
            _externalTokensAddresses.push(externalToken);
        }

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
        require(now > (_lastDistributionsDate + _distributionPeriod), "distribution time has not yet arrived");

        uint256 sumWeight = 0;
        address[] memory externalTokensWithWight;
        for (uint256 i = 0; i < _externalTokensAddresses.length; ++i) {
            ExternalToken memory externalToken = _externalTokens[_externalTokensAddresses[i]];
            if (externalToken._weight > 0) {
                uint256 sumExternalTokens = 0;
                for (uint256 j = 0; j < externalToken._entities.length; ++j) {
                    if (externalToken._entities[j]._distributionsCount == _distributionPeriodsNumber) {
                        ExternalTokenDistributionsInfo memory info = externalToken._entities[j];
                        sumExternalTokens = sumExternalTokens.add(info._distributionAmount.mul(info._distributionsCount));
                    }
                }
                if (sumExternalTokens > _minExternalTokensAmount) {
                    sumWeight = sumWeight.add(externalToken._weight);
                    externalTokensWithWight.push[_externalTokensAddresses[i]];
                } else {
                    externalToken._weight = 0;
                }
            }
        }

        for (uint256 i = _officialsLedgerAddresses.length - 1; i >= 0 ; --i) {
            delete _officialsLedger[_officialsLedgerAddresses[i]];
            delete _officialsLedgerAddresses[i];
            _officialsLedgerAddresses.length --;
        }

        uint256 fullBalance = address(this).balance;
        for (uint256 i = 0; i < externalTokensWithWight.length; ++i) {
            ExternalToken memory externalToken = _externalTokens[externalTokensWithWight[i]];
            uint256 sumExternalTokens = 0;
            for (uint256 j = 0; j < externalToken._entities.length; ++j) {
                sumExternalTokens = sumExternalTokens.add(externalToken._entities[j]._distributionAmount);
            }
            uint256 externalTokenCost = fullBalance.mul(externalToken._weight).div(sumWeight);
            for (uint256 j = 0; j < externalToken._entities.length; ++j) {
                address official = externalToken._entities[j]._official;
                if (_officialsLedger[official] == 0) {
                    _officialsLedgerAddresses.push(official);
                }
                uint256 amount = externalToken._entities[j]._distributionAmount;
                _officialsLedger[official] = _officialsLedger[official].add(externalTokenCost.mul(amount).div(sumExternalTokens));
            }
        }

        uint256 sumHoldersTokens = _token.totalSupply().sub(_token.balanceOf(address(this)));

        if (sumHoldersTokens != 0) {
            for (uint256 i = 0; i < _token.getHoldersCount(); ++i) {
                address holder = _token.getHolderByIndex(i);
                uint256 balance = _token.balanceOf(holder);
                for (uint256 j = 0; j < _externalTokensAddresses.length; ++j) {
                    address externalTokenAddress = _externalTokensAddresses[j];
                    ExternalToken memory externalToken = _externalTokens[externalTokenAddress];
                    for (uint256 k = 0; k < externalToken._entities.length; ++k) {
                        if (holder != address(this) && externalToken._entities[k]._distributionsCount > 0) {
                            uint256 percent = balance.mul(externalToken._entities[k]._distributionAmount).div(sumHoldersTokens);
                            if (percent > (10 ** 4)) {
                                address[] memory externalTokensForHolder = _ledgerExternalTokensAddresses[holder];
                                bool found = false;
                                for (uint256 h = 0; h < externalTokensForHolder.length; ++h) {
                                    if (externalTokensForHolder[h] == externalTokenAddress) {
                                        found = true;
                                        break;
                                    }
                                }
                                if (found == false) {
                                    _ledgerExternalTokensAddresses[holder].push(externalTokenAddress);
                                }

                                _townHoldersLedger[holder][externalTokenAddress] = _townHoldersLedger[holder][externalTokenAddress].add(percent);
                            }
                        }
                    }
                }
            }
        }

        return true;
    }

    function voteOn(address externalToken, uint256 amount) external onlyTownTokenSmartContract returns (bool) {
        require(_externalTokens[externalToken]._entities.length > 0, "external token address not found");
        require(now > (_lastDistributionsDate + _distributionPeriod), "need call distributionSnapshot function");

        _externalTokens[externalToken]._weight = _externalTokens[externalToken]._weight.add(amount);
        return true;
    }

    function claimExternalTokens(address holder) external returns (bool) {
        address[] memory externalTokensForHolder = _ledgerExternalTokensAddresses[holder];
        for (uint256 i = externalTokensForHolder.length - 1; i >= 0; --i) {
            ERC20(externalTokensForHolder[i]).transfer(holder, _townHoldersLedger[holder][externalTokensForHolder[i]]);
            delete _townHoldersLedger[holder][externalTokensForHolder[i]];
            externalTokensForHolder.length--;
        }
        delete _ledgerExternalTokensAddresses[holder];
        return true;
    }

    function claimFunds(address official) external returns (bool) {
        require(_officialsLedger[official] == 0, "official address not fount in ledger");

        uint256 amount = _officialsLedger[official];
        if (address(this).balance >= amount) {
            address(this).transfer(amount);
        } else {
            RemunerationsInfo memory info = RemunerationsInfo(official, 1, amount);
            _remunerationsQueue.push(info);
        }
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
        if (_buyersCount < _durationOfMinTokenBuyAmount && tokenAmount > _minTokenBuyAmount) {
            return false;
        }
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
