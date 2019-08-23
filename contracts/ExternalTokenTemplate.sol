pragma solidity ^0.5.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";


contract ExternalTokenTemplate is ERC20 {
    using SafeMath for uint256;

    string public constant name = "Town Token";
    string public constant symbol = "TTW";
    uint8 public constant decimals = 18;

    constructor (uint256 totalSupply) public {
        _mint(msg.sender, totalSupply);
    }
}
