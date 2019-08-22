pragma solidity ^0.5.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/ownership/Ownable.sol";
import "./Town.sol";


contract TownToken is ERC20, Ownable {
    using SafeMath for uint256;

    string public constant name = "Town Token";
    string public constant symbol = "TTW";
    uint8 public constant decimals = 18;

    address[] private _holders;

    TownInterface _town;

    constructor (uint256 totalSupply, address townContract) public {
        _mint(this.owner(), totalSupply * (10 ** uint256(this.decimals())));
        _town = TownInterface(townContract);
    }

    function getHoldersCount() external view returns (uint256) {
        return _holders.length;
    }

    function getHolderByIndex(uint256 index) external view returns (address) {
        return _holders[index];
    }

    function transfer(address recipient, uint256 amount) public returns (bool) {
        if (msg.sender != this.owner()) {
            if (_town.checkProposal(recipient) == true) {
                ERC20(address(this)).transfer(this.owner(), amount);
                return _town.voteOn(recipient, amount);
            }
            // check 223 ERC and call voteOn function
        }

        bool found = false;
        for (uint i = 0; i < _holders.length; ++i) {
            if (_holders[i] == recipient) {
                found = true;
                break;
            }
        }
        if (found == false) {
            _holders.push(recipient);
        }

        if (balanceOf(address(this)) == amount && address(this) != this.owner()) {
            uint i = 0;
            for (; i < _holders.length; ++i) {
                if (_holders[i] == address(this)) {
                    found = true;
                    break;
                }
            }

            if (i < (_holders.length - 1)) {
                _holders[i] = _holders[_holders.length - 1];
                delete _holders[_holders.length - 1];
                _holders.length--;
            }
        }

        return ERC20(address(this)).transfer(recipient, amount);
    }
}
