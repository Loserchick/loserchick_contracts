pragma solidity 0.6.6;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "./OwnableContract.sol";

contract ChickToken is ERC20("CHICK", "CHICK"), OwnableContract{

    using SafeMath for uint256;

    address public teamAddr;

    address public boardAddr;

    mapping(address => uint256) public addUpSwapCchickCountPerUser;

    event ChickSwapCchick(address userAddress, uint256 amount);

    constructor(address _teamAddr, address _boardAddr) public {
        teamAddr = _teamAddr;
        boardAddr = _boardAddr;

        _setupDecimals(18);
        _mint(msg.sender, uint256(13333333).mul(1e18));
    }

    function getAddUpSwapCchickCountPerUser(address userAddr) public view returns(uint256){
        return addUpSwapCchickCountPerUser[userAddr];
    }

    function chickSwapCchick(uint256 floatAmount) public{
        require(floatAmount != 0, 'floatAmount cannot be zero');
        addUpSwapCchickCountPerUser[msg.sender] = floatAmount.add(addUpSwapCchickCountPerUser[msg.sender]);

        uint256 amount = floatAmount.mul(1e18);

        uint256 teamAmount = amount.div(10);  // 10 %
        _transfer(msg.sender, teamAddr, teamAmount);

        uint256 boardAmount = amount.div(5);  // 20 %
        _transfer(msg.sender, boardAddr, boardAmount);
        
        uint256 burnAmount = amount.mul(7).div(10); // 70 %
       _burn(msg.sender, burnAmount);

        emit ChickSwapCchick(msg.sender, floatAmount);
    }

    function updateTeamAddr(address _teamAddr) public onlyOwner{
        teamAddr = _teamAddr;
    }

    function updateBoardAddr(address _boardAddr) public onlyOwner{
        boardAddr = _boardAddr;
    }
}

