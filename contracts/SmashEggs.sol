pragma solidity 0.6.6;

import "@openzeppelin/contracts/math/SafeMath.sol";
import "./EggToken.sol";
import "./LoserChickNFT.sol";
import "./OwnableContract.sol";
import "./RandomInterface.sol";

contract SmashEggs is OwnableContract{

    using SafeMath for uint256;

    uint public constant PRECISION = 1e17;

    uint256 public constant SECTION_SIZE = 2000; // Length of contract initialization

    uint256 public constant LUCKY_CHICK_INDEX = 0;
    uint256 public constant LABOR_CHICK_INDEX = 1;
    uint256 public constant BOSS_CHICK_INDEX = 2;
    uint256 public constant TRUMP_CHICK_INDEX = 3;
    uint256 public constant SHRIEKING_CHICK_INDEX = 4;

    uint256 public aleadyBrokenEggAmount; // Broken eggs amount

    address[] public loserChickAddrArray;

    RandomInterface private randomContract;

    uint256 public winningProbability; // Get NFT Probability

    uint256[] public chickProbability; // Per chick Rate, 0 is luckyChick, 1 is laborChick, 2 is bossChick, 3 is trumpChick.

    EggToken public eggToken;

    mapping(uint256 => bool) public shriekingChickSection;

    mapping(uint256 => bool) public sectionHasCreatedShriekingChick;

    mapping(address => uint256) private loserFailCount;

    uint256 private seed;

    uint256 public activityNFTProbability;

    address public activityNFTAddr;

    event SmashEggsEvent(address userAddr, uint256 eggCount, uint256 chickCount, address[] chickAddrArray, uint256[] tokenIdArray);
    event ActivityEvent(address userAddr, uint256 NFTConut, address NFTAddr);

    constructor(address _shriekingChickAddr, address _luckyChickAddr, address _laborChickAddr, address _bossChickAddr, address _trumpChickAddr, address _eggTokenAddr, address _randomAddr) public{
        loserChickAddrArray = new address[](5);
        loserChickAddrArray[LUCKY_CHICK_INDEX] = _luckyChickAddr;
        loserChickAddrArray[LABOR_CHICK_INDEX] = _laborChickAddr;
        loserChickAddrArray[BOSS_CHICK_INDEX] = _bossChickAddr;
        loserChickAddrArray[TRUMP_CHICK_INDEX] = _trumpChickAddr;
        loserChickAddrArray[SHRIEKING_CHICK_INDEX] = _shriekingChickAddr;

        randomContract = RandomInterface(_randomAddr);

        eggToken = EggToken(_eggTokenAddr);

        chickProbability = new uint256[](4);
        chickProbability[LUCKY_CHICK_INDEX] = 99377250806863640; // luckyChick  0.00154093611776619 * 1e17 = 154093611776619    622749193136360 = 0.00622749193136360 = 0.62274919313636%
        chickProbability[LABOR_CHICK_INDEX] = 94393076549240510; // laborChick  0.01233288491652890 * 1e17 = 1233288491652890   4984174257623130 = 0.04984174257623130 = 4.98417425762313%
        chickProbability[BOSS_CHICK_INDEX] = 74766975289411744;  // bossChick   0.04856299874094670 * 1e17 = 4856299874094670   19626101259828766 = 0.19626101259828766 = 19.626101259828766%
        chickProbability[TRUMP_CHICK_INDEX] = 0;                 // trumpChick  0.18500406569673300 * 1e17 = 18500406569673300  74766975289411741 = 0.74766975289411741 = 74.766975289411741%

        winningProbability = 24744088547197479; // 154093611776619 + 1233288491652890 + 4856299874094670 + 18500406569673300

        initializationSection();
    }

    function initializationSection() private{
        uint8[28] memory sectionArray = [2, 17, 25, 35, 42, 56, 76, 80, 83, 86, 89, 93, 96, 103, 116, 121, 133, 138, 150, 156, 165, 175, 190, 199, 205, 216, 226, 232];
        for(uint256 i=0; i<sectionArray.length; i++){
            uint256 section = sectionArray[i];
            shriekingChickSection[section] = true;
        }
    }

    function updateActivityNFT(address _activityNFTAddr, uint256 _activityNFTProbability) public onlyAdmin{
        activityNFTAddr = _activityNFTAddr;
        activityNFTProbability = _activityNFTProbability;
    }

    function updateShriekingChickSection(uint256 section, bool isShriekingChickSection) public onlyAdmin{
        shriekingChickSection[section] = isShriekingChickSection;
    }

    function updateChickProbability(uint index, uint256 probability) public onlyAdmin{
        require(index < 4, 'Index is wrong!');
        chickProbability[index] = probability;
    }

    function updateTotalProbability(uint256 probability) public onlyAdmin{
        winningProbability = probability;
    }

    function smashEggs(uint256 amount) public{
        require(amount <= 10, 'amount should be less than or equal to 10');
        uint256 userEggAmount = eggToken.balanceOf(msg.sender);
        require(amount <= userEggAmount.div(1e18), 'user egg shortage in number!');
        eggToken.transferFrom(msg.sender, address(this), amount.mul(1e18));

        address[] memory chickAddrArray = new address[](10);
        uint256[] memory tokenIds = new uint256[](10);
        uint256 count = 0;
        for(uint256 i=0; i<amount; i++){
            aleadyBrokenEggAmount++;
            if(isWon()){
                (uint256 tokenId, address chickAddr) = getOneChickNFT();
                chickAddrArray[count] = chickAddr;
                tokenIds[count] = tokenId;

                count++;
            }
        }

        if(amount == 10 && count < 2){
            uint256 count2 = uint256(2).sub(count);
            for(uint256 i=0; i<count2; i++){
                (uint256 tokenId, address chickAddr) = getOneChickNFT();
                chickAddrArray[count] = chickAddr;
                tokenIds[count] = tokenId;

                count++;
            }
        }
        eggToken.burn(amount);

        if(count == 0){
            loserFailCount[msg.sender] += amount;
        }else{
            loserFailCount[msg.sender] = 0;
        }

        processActivity();

        emit SmashEggsEvent(msg.sender, amount, count, chickAddrArray, tokenIds);
    }

    /**
     * @notice Won or not
     */
    function isWon() internal returns(bool){
        uint256 random = updateSeed() % PRECISION;
        if(random < winningProbability){
            return true;
        }
    }

    function getOneChickNFT() internal returns(uint256, address){
        uint256 random = updateSeed() % PRECISION;
        uint256 index = TRUMP_CHICK_INDEX;
        uint256 sectionIndex = aleadyBrokenEggAmount.div(SECTION_SIZE);

        if(shouldGenerateShriekingChick(sectionIndex)){
            index = SHRIEKING_CHICK_INDEX;
            sectionHasCreatedShriekingChick[sectionIndex] = true;
        }else{
            uint256 startIndex = shriekingChickSection[sectionIndex]? 1: 0;
            for(uint256 i=startIndex; i<chickProbability.length; i++){
                if(random > chickProbability[i]){
                    index = i;
                    break;
                }
            }
        }

        address chickAddr = loserChickAddrArray[index];
        LoserChickNFT loserChickNFT = LoserChickNFT(chickAddr);

        uint256 tokenId;
        if(loserChickNFT.totalSupply() < loserChickNFT.maxSupply()){
            tokenId = loserChickNFT.createNFT(msg.sender);
        }
        return (tokenId, chickAddr);
    }

    function shouldGenerateShriekingChick(uint256 sectionIndex) internal returns(bool){
        if(!shriekingChickSection[sectionIndex]){
            return false;
        }
        if(sectionHasCreatedShriekingChick[sectionIndex]){
            return false;
        }
        uint256 number = aleadyBrokenEggAmount % SECTION_SIZE + 1;
        uint256 random = updateSeed() % SECTION_SIZE;
        return number > random;
    }

    function updateRandomAddr(address _randomAddr) public onlyOwner{
        randomContract = RandomInterface(_randomAddr);
    }

    function updateSeed() internal returns(uint256 random){
        seed += randomContract.getRandomNumber();        
        random = uint256(keccak256(abi.encodePacked(seed)));
    }

    function getLoserFailCount(address owner) public view returns(uint256){
        return loserFailCount[owner];
    }

    function processActivity() internal{
        if(activityNFTProbability == 0){
            return;
        }
        uint256 NFTCount = 0;
        uint256 random = updateSeed() % PRECISION;
        if(activityNFTProbability > random){
            ERC721 erc721 = ERC721(activityNFTAddr);
            uint256 amount = erc721.balanceOf(address(this));
            if(amount > 0){
                uint256 tokenId = erc721.tokenOfOwnerByIndex(address(this), 0);
                erc721.transferFrom(address(this), address(msg.sender), tokenId);
                NFTCount = 1;
                emit ActivityEvent(msg.sender, NFTCount, activityNFTAddr);
            }
        }        
    }

    function transferActivityNFT(address receiver, uint256 count) external onlyAdmin{
        ERC721 erc721 = ERC721(activityNFTAddr);
        uint256 amount = erc721.balanceOf(address(this));
        require(count <= amount, 'Count input error!');
        for(uint256 i=0; i<count; i++){
            uint256 tokenId = erc721.tokenOfOwnerByIndex(address(this), 0);
            erc721.transferFrom(address(this), receiver, tokenId);
        }
    }
}