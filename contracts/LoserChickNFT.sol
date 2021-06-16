pragma solidity 0.6.6;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/introspection/ERC165.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "./OwnableContract.sol";
import "./RandomInterface.sol";

contract LoserChickNFT is OwnableContract, ERC721("TrumpChick", "TrumpChick"){

    using Counters for Counters.Counter;

    struct ChickAttribute{
        uint256 jacket;
        uint256 trousers;
        uint256 suit;
        uint256 expression;
        uint256 hat;
        uint256 leftHandOrnaments;
        uint256 rightHandOrnaments;
        uint256 shoes;
        uint256 bodyOrnaments;
    }

    uint256 public immutable maxSupply;

    uint256 private seed;

    address private randomAddr;

    // Private fields
    Counters.Counter private _tokenIds;

    uint256[7] public jacket = [101, 102, 103, 104, 105, 106, 107];
    uint256[8] public trousers = [201, 202, 203, 204, 205, 206, 207, 208];
    uint256[3] public suit = [301, 302, 303];
    uint256[10] public expression = [401, 402, 403, 404, 405, 406, 407, 408, 409, 410];
    uint256[7] public hat = [501, 502, 503, 504, 505, 506, 507];
    uint256[11] public leftHandOrnaments = [601, 602, 603, 604, 605, 606, 607, 608, 609, 610, 611];
    uint256[11] public rightHandOrnaments = [701, 702, 703, 704, 705, 706, 707, 708, 709, 710, 711];
    uint256[10] public shoes = [801, 802, 803, 804, 805, 806, 807, 808, 809, 810];
    uint256[11] public bodyOrnaments = [901, 902, 903, 904, 905, 906, 907, 908, 909, 910, 911];
    
    mapping(uint256 => ChickAttribute) public tokenIdChickAttribute;

    // Shrieking Chick、 Lucky Chick、Labor Chick、BOSS Chick、Trump Chick
    constructor(uint256 _maxSupply, address _randomAddr) public{
       maxSupply = _maxSupply;
       randomAddr = _randomAddr;
    }

    function getTokenIdChickAttribute(uint256 tokenId) public view returns(ChickAttribute memory){
        return tokenIdChickAttribute[tokenId];
    }

    function tokenOfOwnerPage(address owner, uint256 pageNumber, uint256 pageSize) external view returns (uint256, uint256[] memory){
        uint256 total = balanceOf(owner);
        uint256 start = pageNumber * pageSize;
        require(start < total, 'pageNumber input error！');
        uint256 end;
        if(start + pageSize > total){
            end = total;
        }else{
            end = start + pageSize;
        }
        uint256[] memory tokenIds = new uint256[](end - start);
        uint256 count = 0;
        for(uint256 i=start; i<end; i++){
            uint256 tokenId = tokenOfOwnerByIndex(owner, i);
            tokenIds[count] = tokenId;
            count++;
        }
        return (total, tokenIds);
    }

    /**
     * @notice
     * @param flag If flag is true, it means shriekingChick, otherwise luckyChick.
     */
    function createNFT(address owner) public onlyAdmin returns(uint256){
        require(totalSupply() < maxSupply, 'The limit has been reached！');

        uint256 tokenId = _mintChick(owner);
            
        ChickAttribute memory chickAttribute;
        RandomInterface randomInterface = RandomInterface(randomAddr);
        uint256 randomNumber = randomInterface.getRandomNumber();
        updateSeed();
        bytes32 random = keccak256(abi.encodePacked(now, randomNumber, seed));
        uint256 expressionIndex = uint256(random) % 10;
        uint256 hatIndex = uint256(random) % 7;
        uint256 leftHandOrnamentsIndex = uint256(random) % 11;
        uint256 rightHandOrnamentsIndex = uint256(random) % 11;
        uint256 shoesIndex = uint256(random) % 10;
        uint256 bodyOrnamentsIndex = uint256(random) % 11;

        chickAttribute.expression = expression[expressionIndex];
        chickAttribute.hat = hat[hatIndex];
        chickAttribute.leftHandOrnaments = leftHandOrnaments[leftHandOrnamentsIndex];
        chickAttribute.rightHandOrnaments = rightHandOrnaments[rightHandOrnamentsIndex];
        chickAttribute.shoes = shoes[shoesIndex];
        chickAttribute.bodyOrnaments = bodyOrnaments[bodyOrnamentsIndex];

        uint256 isSuitRandom = uint256(random) % 2;
        if(isSuitRandom == 0){
            uint256 suitIndex = uint256(random) % 3;
            chickAttribute.suit = suit[suitIndex];
        }else if(isSuitRandom == 1){
            uint256 jacketIndex = uint256(random) % 7;
            uint256 trousersIndex = uint256(random) % 8;
            
            chickAttribute.jacket = jacket[jacketIndex];
            chickAttribute.trousers = trousers[trousersIndex];
        }
        tokenIdChickAttribute[tokenId] = chickAttribute;
        return tokenId;
    }

    // Private Methods
    function _mintChick(address owner) private returns(uint256){
        _tokenIds.increment();

        uint256 newItemId = _tokenIds.current();
        _mint(owner, newItemId);
        return newItemId;
    }

    function setBaseURI(string memory newBaseURI) public onlyOwner {
        _setBaseURI(newBaseURI);
    }

    function tokenURI(uint256 tokenId) public view virtual override returns (string memory){
        require(tokenId > 0 && tokenId <= totalSupply(), "URI query for nonexistent token");
        // Fallback to centralised URI
        return string(abi.encodePacked(baseURI(), address(this), '/', tokenId.toString()));
    }

    function updateSeed() internal{
        seed = seed + now - 5;
    }

    function updateRandomAddr(address _randomAddr) public onlyOwner{
        randomAddr = _randomAddr;
    }
}