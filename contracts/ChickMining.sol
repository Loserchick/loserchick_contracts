pragma solidity 0.6.6;

import "@openzeppelin/contracts/GSN/Context.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "./OwnableContract.sol";

contract ChickMining is OwnableContract, ReentrancyGuard, IERC721Receiver{
    using SafeMath for uint256;
    using SafeERC20 for IERC20;
    using EnumerableSet for EnumerableSet.UintSet;

    // Info of each user.
    struct UserInfo {
        uint256 amount;     // How many LP tokens the user has provided.
        uint256 rewardDebt; // Reward debt. See explanation below.
        uint256 rewardToClaim; // when deposit or withdraw, update pending reward  to rewardToClaim.
        EnumerableSet.UintSet holderTokens;
    }

    struct PoolInfo {
        address lpToken;            // Address of   LP token.
        uint256 allocPoint;         // How many allocation points assigned to this pool. mining token  distribute per block.
        uint256 lastRewardBlock;    // Last block number that mining token distribution occurs.
        uint256 accPerShare;        // Accumulated mining token per share, times 1e18. See below.
        uint256 maxAmountPerUser;   // The maximum amount of deposits per user, 0 means unlimited.
        uint256 lpTokenAmount;      // lpToken deposit amount in this pool, for calculating APY
        bool    isNFT;              // true : NFT; false: ERC20
    }

    IERC20 public miningToken; // The mining token TOKEN


    PoolInfo[] public poolInfo; // Info of each pool.
    mapping(uint256 => mapping(address => UserInfo)) private userInfo; // Info of each user that stakes LP tokens.
    uint256 public totalAllocPoint = 0;  // Total allocation points. Must be the sum of all allocation points in all pools.

    bool public whitelistSwitch = true;

    mapping(address => bool) public minerAddress;

    uint256 public minerCount;

    uint256[] public phaseEndBlockNumberArray;

    uint256[] public phasePerBlockRewardArray;

    uint256 public phase1StartBlockNumber;

    uint256 public constant blockCountPerDay = 28800; // day blockNumber total, 3s one block

    event Claim(address indexed user, uint256 pid, uint256 amount);
    event Deposit(address indexed user, uint256 pid, uint256 amount);
    event Withdraw(address indexed user, uint256 pid, uint256 amount);
    event EmergencyWithdraw(address indexed user, uint256 pid, uint256 amount);

    mapping(address => bool) private whitelist;

    modifier onlyWhitelisted() {
        if(whitelistSwitch){
            require(isWhitelisted(msg.sender), "The address is not on the whitelist");
        }
        _;
    }

    constructor(address _mining_token, uint256 _mining_start_block) public {
        miningToken = IERC20(_mining_token);



        phase1StartBlockNumber = _mining_start_block;

        phaseEndBlockNumberArray = new uint256[](7);
        phaseEndBlockNumberArray[0] = phase1StartBlockNumber.add(blockCountPerDay.mul(14));
        phaseEndBlockNumberArray[1] = phaseEndBlockNumberArray[0].add(blockCountPerDay.mul(14));
        phaseEndBlockNumberArray[2] = phaseEndBlockNumberArray[1].add(blockCountPerDay.mul(14));
        phaseEndBlockNumberArray[3] = phaseEndBlockNumberArray[2].add(blockCountPerDay.mul(90));
        phaseEndBlockNumberArray[4] = phaseEndBlockNumberArray[3].add(blockCountPerDay.mul(90));
        phaseEndBlockNumberArray[5] = phaseEndBlockNumberArray[4].add(blockCountPerDay.mul(90));
        phaseEndBlockNumberArray[6] = phaseEndBlockNumberArray[5].add(blockCountPerDay.mul(90));

        phasePerBlockRewardArray = new uint256[](7);
        phasePerBlockRewardArray[0] = 576 * 1e16;
        phasePerBlockRewardArray[1] = 288 * 1e16;
        phasePerBlockRewardArray[2] = 144 * 1e16;
        phasePerBlockRewardArray[3] = 72 * 1e16;
        phasePerBlockRewardArray[4] = 36 * 1e16;
        phasePerBlockRewardArray[5] = 18 * 1e16;
        phasePerBlockRewardArray[6] = 9 * 1e16;
    }

    function updateBlockReward(uint256 _phaseIndex, uint256 _reward) public onlyOwner {
        require(_phaseIndex < phasePerBlockRewardArray.length, "invalid _phaseIndex");
        phasePerBlockRewardArray[_phaseIndex] = _reward;
    }

    function updatePhaseEndBlockNumber(uint256 _phaseIndex, uint256 _endBlockNumber) public onlyOwner {
        require(_phaseIndex < phaseEndBlockNumberArray.length, "invalid _phaseIndex");
        phaseEndBlockNumberArray[_phaseIndex] = _endBlockNumber;
    }

    function addMiningPhase(uint256 _phaseEndBlockNumber, uint256 _phasePerBlockReward) public onlyOwner {
        require(_phaseEndBlockNumber > phaseEndBlockNumberArray[phaseEndBlockNumberArray.length - 1], "invalid _phaseEndBlockNumber");
        phaseEndBlockNumberArray.push(_phaseEndBlockNumber);
        phasePerBlockRewardArray.push(_phasePerBlockReward);
    }

    function getUserInfo(uint256 _pid, address _user) public view returns (
        uint256 _amount, uint256 _rewardDebt, uint256 _rewardToClaim) {
        require(_pid < poolInfo.length, "invalid _pid");
        UserInfo memory info = userInfo[_pid][_user];
        _amount = info.amount;
        _rewardDebt = info.rewardDebt;
        _rewardToClaim = info.rewardToClaim;
    }

    function getUserStakingNftTokenIdArray(uint256 _pid, address _user, uint256 _pageNumber, uint256 _pageSize) public view returns (uint256[] memory) {
        require(_pageSize <= 50, 'The maximum PageSize is 50！');
        require(_pid < poolInfo.length, "invalid _pid");
        PoolInfo storage pool = poolInfo[_pid];
        require(pool.isNFT, 'invalid _pid');
        UserInfo storage user = userInfo[_pid][_user];
        uint256 start;
        start = _pageNumber * _pageSize;
        require(start < user.holderTokens.length(), '_pageNumber input error！');
        uint256 end;
        if(start + _pageSize > user.holderTokens.length()){
            end = user.holderTokens.length();
        }else{
            end = start + _pageSize;
        }
        uint256[] memory tokenIds = new uint256[](end - start);
        uint256 count = 0;
        for(uint256 i=start; i<end; i++){
            uint256 tokenId = user.holderTokens.at(i);
            tokenIds[count] = tokenId;
            count++;
        }
        return tokenIds;
    }
    
    function poolLength() external view returns (uint256) {
        return poolInfo.length;
    }

    // Add a new lp to the pool. Can only be called by the owner.
    function add(uint256 _allocPoint, address _lpToken, uint256 _maxAmountPerUser, bool _withUpdate, bool _isNFT) public onlyAdmin {
        if (_withUpdate) {
            massUpdatePools();
        }
        uint256 lastRewardBlock = block.number > phase1StartBlockNumber ? block.number : phase1StartBlockNumber;
        totalAllocPoint = totalAllocPoint.add(_allocPoint);

        PoolInfo memory _poolInfo;
        _poolInfo.isNFT = _isNFT;
        _poolInfo.lpToken = _lpToken;
        _poolInfo.allocPoint = _allocPoint;
        _poolInfo.lastRewardBlock = lastRewardBlock;
        _poolInfo.accPerShare = 0;
        _poolInfo.maxAmountPerUser = _maxAmountPerUser;
        _poolInfo.lpTokenAmount = 0;

        poolInfo.push(_poolInfo);
    }

    function set(uint256 _pid, uint256 _allocPoint, uint256 _maxAmountPerUser, bool _withUpdate) public onlyAdmin {
        require(_pid < poolInfo.length, "invalid _pid");
        if (_withUpdate) {
            massUpdatePools();
        }
        totalAllocPoint = totalAllocPoint.sub(poolInfo[_pid].allocPoint).add(_allocPoint);
        poolInfo[_pid].allocPoint = _allocPoint;
        poolInfo[_pid].maxAmountPerUser = _maxAmountPerUser;
    }

    function getCurrentRewardsPerBlock() public view returns (uint256) {
        return getMultiplier(block.number - 1, block.number);
    }

    // Return reward  over the given _from to _to block. Suppose it doesn't span greater than  two phases
    function getMultiplier(uint256 _from, uint256 _to) public view returns (uint256) {
        require(_to > _from, "_to should greater than _from");
        if(_to <= phase1StartBlockNumber || _from > phaseEndBlockNumberArray[phaseEndBlockNumberArray.length - 1]){
            return 0;
        }
        if(_from < phase1StartBlockNumber){
            _from = phase1StartBlockNumber;
        }

        if(_to > phaseEndBlockNumberArray[phaseEndBlockNumberArray.length - 1]){
            _to = phaseEndBlockNumberArray[phaseEndBlockNumberArray.length - 1];
        }

        // _from  and _to between first phase :
        if( phase1StartBlockNumber <= _from && _to <= phaseEndBlockNumberArray[0]){
            return  _to.sub(_from).mul(phasePerBlockRewardArray[0]);
        }

        
        for(uint256 i=1; i< phaseEndBlockNumberArray.length; i++){

            // _from  and _to between one  phase:
            if( phaseEndBlockNumberArray[i-1] <= _from && _to <= phaseEndBlockNumberArray[i]){
                return _to.sub(_from).mul(phasePerBlockRewardArray[i]);                
            }

            // _from and _to span two  phase: 
            if(_from < phaseEndBlockNumberArray[i - 1] &&  phaseEndBlockNumberArray[i - 1] <  _to  && _to <= phaseEndBlockNumberArray[i]){
                uint256 reword1 = phaseEndBlockNumberArray[i - 1].sub(_from).mul(phasePerBlockRewardArray[i - 1]);
                uint256 reword2 = _to.sub(phaseEndBlockNumberArray[i - 1]).mul(phasePerBlockRewardArray[i]);
                return  reword1.add(reword2);
            }
        } 


        return 0;
    }

    function massUpdatePools() public {
        uint256 length = poolInfo.length;
        for (uint256 pid = 0; pid < length; ++pid) {
            updatePool(pid);
        }
    }

    function updatePool(uint256 _pid) public {
        require(_pid < poolInfo.length, "invalid _pid");
        PoolInfo storage pool = poolInfo[_pid];
        if (block.number <= pool.lastRewardBlock) {
            return;
        }
        uint256 lpSupply = pool.lpTokenAmount;
        if (lpSupply == 0) {
            pool.lastRewardBlock = block.number;
            return;
        }
        uint256 multiplier = getMultiplier(pool.lastRewardBlock, block.number);
        uint256 reward = multiplier.mul(pool.allocPoint).div(totalAllocPoint);
        pool.accPerShare = pool.accPerShare.add(reward.mul(1e18).div(lpSupply));
        pool.lastRewardBlock = block.number;
    }

    function getPendingAmount(uint256 _pid, address _user) public view returns (uint256) {
        require(_pid < poolInfo.length, "invalid _pid");
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][_user];
        uint256 accPerShare = pool.accPerShare;
        uint256 lpSupply = pool.lpTokenAmount;
        if (block.number > pool.lastRewardBlock && lpSupply != 0) {
            uint256 multiplier = getMultiplier(pool.lastRewardBlock, block.number);
            uint256 reward = multiplier.mul(pool.allocPoint).div(totalAllocPoint);
            accPerShare = accPerShare.add(reward.mul(1e18).div(lpSupply));
        }
        uint256 pending = user.amount.mul(accPerShare).div(1e18).sub(user.rewardDebt);
        uint256 totalPendingAmount = user.rewardToClaim.add(pending);
        return totalPendingAmount;
    }

    function getAllPendingAmount(address _user) external view returns (uint256) {
        uint256 length = poolInfo.length;
        uint256 allAmount = 0;
        for (uint256 pid = 0; pid < length; ++pid) {
            allAmount = allAmount.add(getPendingAmount(pid, _user));
        }
        return allAmount;
    }

    function claimAll() public {
        uint256 length = poolInfo.length;
        for (uint256 pid = 0; pid < length; ++pid) {
            if (getPendingAmount(pid, msg.sender) > 0) {
                claim(pid);
            }
        }
    }

    function claim(uint256 _pid) public {
        require(_pid < poolInfo.length, "invalid _pid");
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        updatePool(_pid);
        if (user.amount > 0) {
            uint256 pending = user.amount.mul(pool.accPerShare).div(1e18).sub(user.rewardDebt);
            user.rewardToClaim = user.rewardToClaim.add(pending);
        }
        user.rewardDebt = user.amount.mul(pool.accPerShare).div(1e18);
        safeMiningTokenTransfer(msg.sender, user.rewardToClaim);
        emit Claim(msg.sender, _pid, user.rewardToClaim);
        user.rewardToClaim = 0;
    }

    // Deposit LP tokens to Mining for token allocation.
    function depositERC20(uint256 _pid, uint256 _amount) public nonReentrant onlyWhitelisted {
        require(_amount > 0, '_amount should be greater than 0');
        require(_pid < poolInfo.length, "invalid _pid");
        PoolInfo storage pool = poolInfo[_pid];
        require(!pool.isNFT, 'invalid _pid');
        UserInfo storage user = userInfo[_pid][msg.sender];
        if(pool.maxAmountPerUser != 0){
            uint256 allowance = pool.maxAmountPerUser.sub(user.amount);
            require(_amount <= allowance, "deposit amount exceeds allowance");
        }
        updatePool(_pid);
        if (user.amount > 0) {
            uint256 pending = user.amount.mul(pool.accPerShare).div(1e18).sub(user.rewardDebt);
            user.rewardToClaim = user.rewardToClaim.add(pending);
        }
        IERC20 erc20 = IERC20(pool.lpToken);
        erc20.safeTransferFrom(address(msg.sender), address(this), _amount);
        user.amount = user.amount.add(_amount);
        emit Deposit(msg.sender, _pid, _amount);

        pool.lpTokenAmount = pool.lpTokenAmount.add(_amount);
        user.rewardDebt = user.amount.mul(pool.accPerShare).div(1e18);

        if(!minerAddress[msg.sender]){
            minerAddress[msg.sender] = true;
            minerCount++;
        }
    }

    // Withdraw LP tokens from Mining.
    function withdrawERC20(uint256 _pid, uint256 _amount) public nonReentrant {
        require(_pid < poolInfo.length, "invalid _pid");
        PoolInfo storage pool = poolInfo[_pid];
        require(!pool.isNFT, 'PID error, please send the PID of erc20');
        UserInfo storage user = userInfo[_pid][msg.sender];
        require(user.amount >= _amount, "withdraw: user.amount is not enough");
        updatePool(_pid);
        uint256 pending = user.amount.mul(pool.accPerShare).div(1e18).sub(user.rewardDebt);
        user.rewardToClaim = user.rewardToClaim.add(pending);
        user.amount = user.amount.sub(_amount);
        user.rewardDebt = user.amount.mul(pool.accPerShare).div(1e18);
        IERC20 erc20 = IERC20(pool.lpToken);
        erc20.safeTransfer(address(msg.sender), _amount);
        pool.lpTokenAmount = pool.lpTokenAmount.sub(_amount);
        emit Withdraw(msg.sender, _pid, _amount);
    }

    // Withdraw without caring about rewards. EMERGENCY ONLY.
    function emergencyWithdrawERC20(uint256 _pid) public nonReentrant {
        require(_pid < poolInfo.length, "invalid _pid");
        PoolInfo storage pool = poolInfo[_pid];
        require(!pool.isNFT, 'PID error, please send the PID of erc20');
        UserInfo storage user = userInfo[_pid][msg.sender];
        IERC20 erc20 = IERC20(pool.lpToken);
        erc20.safeTransfer(address(msg.sender), user.amount);
        pool.lpTokenAmount = pool.lpTokenAmount.sub(user.amount);
        emit EmergencyWithdraw(msg.sender, _pid, user.amount);
        user.amount = 0;
        user.rewardDebt = 0;
        user.rewardToClaim = 0;
    }

    function depositNFT(uint256 _pid, uint256 _amount) public nonReentrant {
        require(_pid < poolInfo.length, "invalid _pid");
        PoolInfo storage pool = poolInfo[_pid];
        require(pool.isNFT, 'invalid _pid');
        ERC721 erc721 = ERC721(pool.lpToken);
        uint256 tokenIdLength = erc721.balanceOf(msg.sender);
        require(tokenIdLength > 0, "there is no chick in your account！");
        require(_amount <= tokenIdLength, "invalid _amount ");
        UserInfo storage user = userInfo[_pid][msg.sender];
        updatePool(_pid);
        if (user.amount > 0) {
            uint256 pending = user.amount.mul(pool.accPerShare).div(1e18).sub(user.rewardDebt);
            user.rewardToClaim = user.rewardToClaim.add(pending);
        }

        
        for(uint256 i=0; i<_amount; i++){
            // after call erc721.safeTransferFrom(address(msg.sender), address(this), tokenId),  the tokenId of index 0 will change
            uint256 tokenId = erc721.tokenOfOwnerByIndex(msg.sender, 0); // index = 0 
            user.holderTokens.add(tokenId);
            erc721.safeTransferFrom(address(msg.sender), address(this), tokenId);
        }
        user.amount = user.amount.add(_amount);
        pool.lpTokenAmount = pool.lpTokenAmount.add(_amount);
        user.rewardDebt = user.amount.mul(pool.accPerShare).div(1e18);

        emit Deposit(msg.sender, _pid, _amount);

        if(!minerAddress[msg.sender]){
            minerAddress[msg.sender] = true;
            minerCount++;
        }

        require(user.amount == user.holderTokens.length(), "user.amount != user.holderTokens.length()");
    }

    function withdrawNFT(uint256 _pid, uint256 _amount) public nonReentrant{
        require(_pid < poolInfo.length, "invalid _pid");
        PoolInfo storage pool = poolInfo[_pid];
        require(pool.isNFT, 'invalid _pid');
        UserInfo storage user = userInfo[_pid][msg.sender];
        require(_amount <= user.holderTokens.length(), "invalid _amount");
        updatePool(_pid);
        uint256 pending = user.amount.mul(pool.accPerShare).div(1e18).sub(user.rewardDebt);
        user.rewardToClaim = user.rewardToClaim.add(pending);
        user.amount = user.holderTokens.length().sub(_amount);
        user.rewardDebt = user.amount.mul(pool.accPerShare).div(1e18);

        ERC721 erc721 = ERC721(pool.lpToken);

        for(uint256 i=0; i < _amount; i++){
            uint256 tokenId = user.holderTokens.at(0); 
            erc721.safeTransferFrom(address(this), address(msg.sender), tokenId);
            user.holderTokens.remove(tokenId);
        }
        pool.lpTokenAmount = pool.lpTokenAmount.sub(_amount);
        emit Withdraw(msg.sender, _pid, _amount);
        require(user.amount == user.holderTokens.length(), "user.amount != user.holderTokens.length()");
    }

    // Withdraw without caring about rewards. EMERGENCY ONLY.
    function emergencyWithdrawNFT(uint256 _pid, uint256 _amount) public nonReentrant {
        require(_pid < poolInfo.length, "invalid _pid");
        PoolInfo storage pool = poolInfo[_pid];
        require(pool.isNFT, 'invalid _pid');
        UserInfo storage user = userInfo[_pid][msg.sender];
        require(_amount <= user.holderTokens.length(), "invalid _amount");

        ERC721 erc721 = ERC721(pool.lpToken);
        
        for(uint256 i=0; i < _amount; i++){
            uint256 tokenId = user.holderTokens.at(0); 
            erc721.safeTransferFrom(address(this), address(msg.sender), tokenId);
            user.holderTokens.remove(tokenId);
        }

        pool.lpTokenAmount = pool.lpTokenAmount.sub(_amount);
        
        emit EmergencyWithdraw(msg.sender, _pid, _amount);
        user.amount = 0; // set amount to 0, there will be no rewards.
        user.rewardDebt = 0;
        user.rewardToClaim = 0;        
    }

    // Safe token transfer function, just in case if rounding error causes pool to not have enough mining token.
    function safeMiningTokenTransfer(address _to, uint256 _amount) internal {
        uint256 bal = miningToken.balanceOf(address(this));
        require(bal >= _amount, "balance is not enough.");
        miningToken.safeTransfer(_to, _amount);
    }

    function addAddressToWhitelist(address[] memory _addresses) public onlyAdmin {
        require(_addresses.length > 0, "_addresses is empty");
        for (uint256 i = 0; i < _addresses.length; i++) {
            address addr = _addresses[i];
            whitelist[addr] = true;
        }
    }

    function removeAddressFromWhitelist(address[] memory _addresses) public onlyAdmin {
        require(_addresses.length > 0, "_addresses is empty");
        for (uint256 i = 0; i < _addresses.length; i++) {
            address addr = _addresses[i];
            whitelist[addr] = false;
        }
    }

    // Whether the address is on the whitelist
    function isWhitelisted(address _address) public view returns (bool) {
        return whitelist[_address];
    }

    function updateWhitelistSwitch(bool _whitelistSwitch) public onlyAdmin {
        whitelistSwitch = _whitelistSwitch;
    }

    function onERC721Received(address operator, address from, uint256 tokenId, bytes calldata data) external override returns (bytes4){
        return 0x150b7a02;
    }
}
