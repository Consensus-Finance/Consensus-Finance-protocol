pragma solidity ^0.5.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/ownership/Ownable.sol";


contract TownToken is ERC20, Ownable {
    using SafeMath for uint256;

    string public constant name = "Town Token";
    string public constant symbol = "TTW";
    uint8 public constant decimals = 18;

    address[] private holders;

    constructor (uint256 totalSupply) public {
        _mint(this.owner(), totalSupply * (10 ** uint256(this.decimals())));
    }

    function getHoldersCount() external view returns (uint256) {
        return holders.length;
    }

    function getHolderByIndex(uint256 index) external view returns (address) {
        return holders[index];
    }

    function transfer(address recipient, uint256 amount) public returns (bool) {
        bool found = false;
        for (uint i = 0; i < holders.length; ++i) {
            if (holders[i] == recipient) {
                found = true;
                break;
            }
        }
        if (found == false) {
            holders.push(recipient);
        }
        return ERC20(address(this)).transfer(recipient, amount);
    }
}
