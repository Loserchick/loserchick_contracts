pragma solidity 0.6.6;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "./OwnableContract.sol";
import "./ChickToken.sol";

contract EggToken is ERC20("EGG", "EGG"), OwnableContract{

    using SafeMath for uint256;

    uint256 public constant MAX_TOTAL_SUPPLY  = 1333333 * 1e18;

    uint256 public dayIndex = 0;

    uint256 public perUserPerDayLimit;
    uint256 public marketPerDayLimit;

    uint256 public addUpClaimCount;
    uint256 public addUpBurnCount;

    address public signer1;
    address public signer2;

    mapping(uint256 => bool) public claimedOrderId;

    mapping(uint256 => mapping(address => uint256)) public userClaimCountPerDay; // Maximum per user per day.
    
    mapping(uint256 => uint256) public marketClaimCountPerDay; // Maximum market per day.

    mapping(uint256 => uint256) public burnAmountPerDay;

    uint256[4] public cChickSwapChickLimit;

    uint256[4] public ceggSwapEggProportion;

    mapping(address => uint256) public addUpSwapCeggCountPerUser;

    ChickToken public chickToken;

    event Claim(uint256 orderId, uint256 amount, address userAddress, address signer);
    event Burn(address userAddress, uint256 amount);

    constructor(address _chickAddr) public {
        chickToken = ChickToken(_chickAddr);

        _setupDecimals(18);
        perUserPerDayLimit = 100;
        marketPerDayLimit = 100000;

        cChickSwapChickLimit[0] = 10;
        cChickSwapChickLimit[1] = 20;
        cChickSwapChickLimit[2] = 100;
        cChickSwapChickLimit[3] = 115792089237316195423570985008687907853269984665640564039457584007913129639935;

        ceggSwapEggProportion[0] = 5; // special case : if  addUpSwapCchickCountPerUser[userAddr] <=10 , the max EGG count is 5 
        
        //  maxEggAmount = chickCount.mul(ceggSwapEggProportion[index]).div(100);
        ceggSwapEggProportion[1] = 50; 
        ceggSwapEggProportion[2] = 30;
        ceggSwapEggProportion[3] = 20;
    }

    function setDev1(address _signer) public onlyOwner {
        signer1 = _signer;
    }

    function setDev2(address _signer) public onlyOwner {
        signer2 = _signer;
    }

    function getUserClaimCountPerDay(uint256 _dayIndex, address userAddr) public view returns(uint256){
        return userClaimCountPerDay[_dayIndex][userAddr];
    }

    function getMarketClaimCountPerDay(uint256 _dayIndex) public view returns(uint256){
        return marketClaimCountPerDay[_dayIndex];
    }

    function getBurnAmountPerDay(uint256 _dayIndex) public view returns(uint256){
        return burnAmountPerDay[_dayIndex];
    }

    function getInCirculationCount() public view returns(uint256){
        return addUpClaimCount.sub(addUpBurnCount);
    }

    function getAwaitMiningCount() public view returns(uint256){
        return MAX_TOTAL_SUPPLY.div(1e18).sub(addUpClaimCount);
    }

    function updateCeggSwapEggProportion(uint256 index, uint256 proportion) public onlyOwner{
        require(index < 4, 'Index cannot be greater than 4 !');
        ceggSwapEggProportion[index] = proportion;
    }

    // check to avoid bad base, such as centralized db changed by hacker  
    function checkRestrictions(uint256 userAddUpCchickCount, uint256 userAddUpClaimEggCount) internal view returns(bool){
        require(userAddUpClaimEggCount <= userAddUpCchickCount, 'error: userAddUpClaimEggCount > userAddUpCchickCount');
        uint256 index = 0;
        for(uint256 i = 0; i<cChickSwapChickLimit.length; i++){
            if(userAddUpCchickCount <= cChickSwapChickLimit[i]){
                index = i;
                break;
            }
        }
        uint256 maxEggAmount;
        if(index == 0){
            maxEggAmount == ceggSwapEggProportion[0];
        }else{
            maxEggAmount = userAddUpCchickCount.mul(ceggSwapEggProportion[index]).div(100);
        }

        require(maxEggAmount >=  userAddUpClaimEggCount, 'error: maxEggAmount <  userAddUpClaimEggCount');
    }

    function claim(uint256 orderId, uint256 floatAmount, bytes memory signature) public returns(address){
        require(claimedOrderId[orderId] == false, "already claimed");
        updateDay();
        require(userClaimCountPerDay[dayIndex][msg.sender].add(floatAmount) <= perUserPerDayLimit, 'Maximum single day limit exceeded！');
        require(marketClaimCountPerDay[dayIndex].add(floatAmount) <= marketPerDayLimit, 'It has exceeded the maximum market quota！');

        bytes32 hash1 = keccak256(abi.encode(address(this), msg.sender, orderId, floatAmount));

        bytes32 hash2 = keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", hash1));

        address signer = recover(hash2, signature);
        require(signer == signer1 || signer == signer2, "invalid signer");

        uint256 userAddUpcChickCount = chickToken.getAddUpSwapCchickCountPerUser(msg.sender);
        uint256 useAddUpClaimEggCount = floatAmount.add(addUpSwapCeggCountPerUser[msg.sender]);
        checkRestrictions(userAddUpcChickCount, useAddUpClaimEggCount);

        mint(msg.sender, floatAmount);

        claimedOrderId[orderId] = true;
        userClaimCountPerDay[dayIndex][msg.sender] = floatAmount.add(userClaimCountPerDay[dayIndex][msg.sender]);
        marketClaimCountPerDay[dayIndex] = floatAmount.add(marketClaimCountPerDay[dayIndex]);
        addUpSwapCeggCountPerUser[msg.sender] = useAddUpClaimEggCount;
        addUpClaimCount = floatAmount.add(addUpClaimCount);

        emit Claim(orderId, floatAmount, msg.sender, signer);
    }

    function mint(address _to, uint256 _amount) internal{
        uint256 intAmount = _amount.mul(1e18);
        uint256 totalSupply = totalSupply();
        if(totalSupply ==  MAX_TOTAL_SUPPLY){
            return;
        }else if(totalSupply.add(intAmount) <= MAX_TOTAL_SUPPLY){
            _mint(_to, intAmount);
        }else{
            uint256 amount = MAX_TOTAL_SUPPLY.sub(totalSupply);
            _mint(_to, amount);
        }
    }

    function burn(uint256 amount) public{
        require(amount != 0, 'burnAmount cannot be zero');
        
        address deadAddress = 0x000000000000000000000000000000000000dEaD;
        transfer(deadAddress, amount.mul(1e18));
        emit Burn(msg.sender, amount);

        addUpBurnCount += amount;

        updateDay();
        burnAmountPerDay[dayIndex] += amount;
    }

    function setPerUserPerDayLimit(uint _perUserPerDayLimit) public onlyAdmin {
        perUserPerDayLimit = _perUserPerDayLimit;
    }

    function setMarketPerDayLimit(uint _marketPerDayLimit) public onlyAdmin {
        marketPerDayLimit = _marketPerDayLimit;
    }

    /**
     * @dev Returns the address that signed a hashed message (`hash`) with
     * `signature`. This address can then be used for verification purposes.
     *
     * The `ecrecover` EVM opcode allows for malleable (non-unique) signatures:
     * this function rejects them by requiring the `s` value to be in the lower
     * half order, and the `v` value to be either 27 or 28.
     *
     * IMPORTANT: `hash` _must_ be the result of a hash operation for the
     * verification to be secure: it is possible to craft signatures that
     * recover to arbitrary addresses for non-hashed data. A safe way to ensure
     * this is by receiving a hash of the original message (which may otherwise
     * be too long), and then calling {toEthSignedMessageHash} on it.
     */
    function recover(bytes32 hash, bytes memory signature) internal pure returns (address) {
        // Check the signature length
        if (signature.length != 65) {
            revert("ECDSA: invalid signature length");
        }

        // Divide the signature in r, s and v variables
        bytes32 r;
        bytes32 s;
        uint8 v;

        // ecrecover takes the signature parameters, and the only way to get them
        // currently is to use assembly.
        // solhint-disable-next-line no-inline-assembly
        assembly {
            r := mload(add(signature, 0x20))
            s := mload(add(signature, 0x40))
            v := byte(0, mload(add(signature, 0x60)))
        }

        return recover(hash, v, r, s);
    }

    /**
     * @dev Overload of {ECDSA-recover-bytes32-bytes-} that receives the `v`,
     * `r` and `s` signature fields separately.
     */
    function recover(bytes32 hash, uint8 v, bytes32 r, bytes32 s) internal pure returns (address) {
        // EIP-2 still allows signature malleability for ecrecover(). Remove this possibility and make the signature
        // unique. Appendix F in the Ethereum Yellow paper (https://ethereum.github.io/yellowpaper/paper.pdf), defines
        // the valid range for s in (281): 0 < s < secp256k1n ÷ 2 + 1, and for v in (282): v ∈ {27, 28}. Most
        // signatures from current libraries generate a unique signature with an s-value in the lower half order.
        //
        // If your library generates malleable signatures, such as s-values in the upper range, calculate a new s-value
        // with 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEBAAEDCE6AF48A03BBFD25E8CD0364141 - s1 and flip v from 27 to 28 or
        // vice versa. If your library also generates signatures with 0/1 for v instead 27/28, add 27 to v to accept
        // these malleable signatures as well.
        require(uint256(s) <= 0x7FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF5D576E7357A4501DDFE92F46681B20A0, "ECDSA: invalid signature 's' value");
        require(v == 27 || v == 28, "ECDSA: invalid signature 'v' value");

        // If the signature is valid (and not malleable), return the signer address
        address signer = ecrecover(hash, v, r, s);
        require(signer != address(0), "ECDSA: invalid signature");

        return signer;
    }

    function updateDay() internal{
        dayIndex = now / 86400;
    }
}

