pragma solidity 0.6.6;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract ChickToken is ERC20("CHICK", "CHICK") {

    event ChickSwapCchick(address userAddress, uint256 amount);

    constructor() public {
        _setupDecimals(18);
        _mint(msg.sender, uint256(13333333).mul(1e18));
    }

    function chickSwapCchick(uint256 amount) public{
        require(amount != 0, 'burnAmount cannot be zero');
       _burn(msg.sender, amount);
        emit ChickSwapCchick(msg.sender, amount);
    }
}

