pragma solidity ^0.5.0;

import "@openzeppelin/contracts/token/ERC20/ERC20Mintable.sol";


contract TownToken is ERC20Mintable {
    using SafeMath for uint256;

    string public constant name = "Town Token";
    string public constant symbol = "TTW";
    uint8 public constant decimals = 18;

    address[] private holders;

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
        return ERC20Mintable(address(this)).transfer(recipient, amount);
    }

    function getHolders() public view returns (address[]) {
        return holders;
    }
}
