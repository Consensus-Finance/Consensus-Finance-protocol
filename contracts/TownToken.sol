pragma solidity ^0.5.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/ownership/Ownable.sol";

interface TownInterface {
    function checkProposal(address proposal) external returns (bool);
    function voteOn(address externalToken, uint256 amount) external returns (bool);
    function remuneration(address recipient, uint256 tokensAmount) external returns (bool);
}


contract TownToken is ERC20, Ownable {
    using SafeMath for uint256;

    string public constant name = "Town Token";
    string public constant symbol = "TTW";
    uint8 public constant decimals = 18;

    bool public initiated;

    address[] private _holders;

    TownInterface _town;

    constructor () public {
        initiated = false;
    }

    function getHoldersCount() external view returns (uint256) {
        return _holders.length;
    }

    function getHolderByIndex(uint256 index) external view returns (address) {
        return _holders[index];
    }

    function init (uint256 totalSupply, address townContract) public onlyOwner {
        require(initiated == false, "contract already initiated");
        _town = TownInterface(townContract);
        _mint(townContract, totalSupply);
        initiated = true;
    }

    function transfer(address recipient, uint256 amount) public returns (bool) {
        if (msg.sender != address(_town)) {
            if (_town.checkProposal(recipient) == true) {
                super.transfer(address(_town), amount);
                return _town.voteOn(recipient, amount);
            }

            if (recipient == address(_town)) {
                if (balanceOf(address(msg.sender)) == amount) { // remove address with 0 balance from holders list
                    uint i = 0;
                    for (; i < _holders.length; ++i) {
                        if (_holders[i] == address(msg.sender)) {
                            break;
                        }
                    }

                    if (i < (_holders.length - 1)) {
                        _holders[i] = _holders[_holders.length - 1];
                        delete _holders[_holders.length - 1];
                        _holders.length--;
                    }
                }
                super.transfer(address(_town), amount);
                return _town.remuneration(msg.sender, amount);
            }
            // check 223 ERC and call voteOn function
        }

        bool found = false;
        for (uint i = 0; i < _holders.length; ++i) {    // find recipient address in holders list
            if (_holders[i] == recipient) {
                found = true;
                break;
            }
        }
        if (found == false) {                           // if recipient not found, we push new address
            _holders.push(recipient);
        }

        if (balanceOf(address(msg.sender)) == amount && msg.sender != address(_town)) { // remove address with 0 balance from holders
            uint i = 0;
            for (; i < _holders.length; ++i) {
                if (_holders[i] == address(msg.sender)) {
                    break;
                }
            }

            if (i < (_holders.length - 1)) {
                _holders[i] = _holders[_holders.length - 1];
                delete _holders[_holders.length - 1];
                _holders.length--;
            }
        }

        return super.transfer(recipient, amount);
    }
}
