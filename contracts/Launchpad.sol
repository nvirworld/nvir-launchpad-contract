// SPDX-License-Identifier: MIT

// Nvir Launchpad Smart Contract

//  The Nvir Launchpad contract is a comprehensive solution for managing token staking,
//  token sales, and distribution processes in a decentralized manner.
//  This contract is designed to facilitate the initial offering of tokens
//  and to handle the staking-based tier system for participants.

//  Key Features:
//  - Staking: Users can stake tokens within a specified timeframe.
//    Staking volume influences the user's tier and eligibility in the token sale.

//  - Token Sale: The contract allows conducting a token sale,
//    with the sale parameters (start and end times, pricing, and token details)
//    pre-configured. A whitelist mechanism can be enabled to restrict participation.

//  - Distribution: Post-sale, the tokens purchased are subject to a vesting schedule.
//    The contract handles the periodic release of these tokens to buyers.

//  - Fund Withdrawal: After the sale ends, the contract enables the collection
//    of raised funds and unsold tokens by the contract owner.

//  - Whitelisting: Provides the ability to manage a list of addresses
//    that are allowed to participate in the token sale.

//  Security Measures:
//  - The contract leverages OpenZeppelin's Ownable, SafeCast, and IERC20Metadata
//    for standard compliant, secure, and reliable operations.

//  - Functions critical to contract management and token movements
//    are restricted to the contract owner.

//  - Input validations and error handling are implemented to ensure
//    integrity and proper functioning throughout the contract's lifecycle.

//  The Nvir Launchpad contract is intended to be deployed by the project team
//  and requires initial configuration for staking and sale parameters.
//  Post-deployment, the contract owner manages the staking periods,
//  token sale, and distribution phases.

pragma solidity ^0.8.20;

import '@openzeppelin/contracts/access/Ownable.sol';
import '@openzeppelin/contracts/utils/math/SafeCast.sol';
import '@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol';

contract NvirLaunchpad is Ownable {
  using SafeCast for uint;

  // Public state variables
  string public name;
  uint GU = 10 ** 18;

  // Staking related state variables
  IERC20 public stakingToken;
  uint public stakingStartTs;
  uint public stakingEndTs;
  uint public stakingVolumeMax;
  uint public stakingVolumeMin;
  uint public stakingVolumeTier2;
  uint public stakingVolumeTier3;

  // Token sale related state variables
  uint public saleStartTs;
  uint public saleEndTs;
  uint public salePrice;
  uint public saleTotalAmount;
  uint public soldTotalAmount;
  IERC20 public saleToken;
  IERC20 public purchaseToken;
  uint public saleRatioTier1;
  uint public saleRatioTier2;
  uint public saleRatioTier3;
  bool isSaleWhitelistEnabled;
  mapping(address => bool) saleWhitelist;

  // Vesting related state variables
  uint public vestingStartTs;
  uint public vestingPeriod;
  uint public vestingRatio;

  // Struct to store user positions
  struct Position {
    uint stakingAmount;
    bool isUnstaked;
    uint buyAmount;
    uint vestedAmount;
  }
  mapping(address => Position) public positions;

  mapping(address => bool) stakedUserMap;
  uint public stakedUserMapSize;
  address[] public stakedUserList;

  mapping(address => bool) soldUserMap;
  uint public soldUserMapSize;
  address[] public soldUserList;

  // Events
  event SaleTokensDeposited(uint amount);
  event TokensStaked(address indexed user, uint amount);
  event TokensUnstaked(address indexed user, uint amount);
  event SaleParticipated(address indexed user, uint amount);
  event SaleFinalized(uint purchasedAmount, uint unsoldAmount);
  event TokensVested(address indexed user, uint amount);

  constructor(
    string memory _name,
    address[3] memory _stakingPurchaseToken,
    uint[2] memory _stakingStartEnd,
    uint[2] memory _stakingVolumeMinMax,
    uint[2] memory _stakingVolumeTier,
    uint[2] memory _saleStartEnd,
    uint _salePrice,
    uint[3] memory _saleRatioTier,
    uint[3] memory _vestingStartPeriodRatio
  ) Ownable(msg.sender) {
    name = _name;

    stakingToken = IERC20(_stakingPurchaseToken[0]);
    saleToken = IERC20(_stakingPurchaseToken[1]);
    purchaseToken = IERC20(_stakingPurchaseToken[2]);

    require(address(stakingToken) != address(0), 'Staking Token is not supported');
    require(address(saleToken) != address(0), 'Sale Token is not supported');

    stakingStartTs = _stakingStartEnd[0];
    stakingEndTs = _stakingStartEnd[1];
    stakingVolumeMin = _stakingVolumeMinMax[0];
    stakingVolumeMax = _stakingVolumeMinMax[1];
    stakingVolumeTier2 = _stakingVolumeTier[0];
    stakingVolumeTier3 = _stakingVolumeTier[1];

    require(stakingStartTs < stakingEndTs, 'Staking start time must be earlier than end time');
    require(stakingVolumeMax > stakingVolumeMin, 'Staking volume max must be greater than min');
    require(stakingVolumeMin > 0, 'Staking volume min must be greater than zero');
    require(0 <= stakingVolumeTier2, 'Staking volume tier2 must be greater than zero');
    require(stakingVolumeTier2 <= stakingVolumeTier3, 'Staking volume tier3 must be greater than or equal to tier2');

    saleStartTs = _saleStartEnd[0];
    saleEndTs = _saleStartEnd[1];
    salePrice = _salePrice;

    saleRatioTier1 = _saleRatioTier[0];
    saleRatioTier2 = _saleRatioTier[1];
    saleRatioTier3 = _saleRatioTier[2];

    isSaleWhitelistEnabled = false;

    require(stakingEndTs < saleStartTs, 'Staking end time must be earlier than sale start time');
    require(saleStartTs < saleEndTs, 'Sale start time must be earlier than end time');
    require(salePrice > 0, 'Sale price must be greater than zero');
    require(0 < saleRatioTier1, 'Sale ratio tier1 must be greater than zero');
    require(saleRatioTier1 <= saleRatioTier2, 'Sale ratio tier1 must be greater than or equal to tier2');
    require(saleRatioTier2 <= saleRatioTier3, 'Sale ratio tier2 must be greater than or equal to tier3');

    vestingStartTs = _vestingStartPeriodRatio[0];
    vestingPeriod = _vestingStartPeriodRatio[1];
    vestingRatio = _vestingStartPeriodRatio[2];

    require(saleEndTs <= vestingStartTs, 'Vesting start time must be later than sale end time');
    require(vestingPeriod > 0, 'Vesting period must be greater than zero');
    require(vestingRatio > 0, 'Vesting ratio must be greater than zero');
  }

  function _min(uint _a, uint _b) internal pure returns (uint) {
    if (_a < _b) return _a;
    return _b;
  }

  function _max(uint _a, uint _b) internal pure returns (uint) {
    if (_a < _b) return _b;
    return _a;
  }

  function addStakedUser(address _user) internal {
    if (!stakedUserMap[_user]) {
      stakedUserMap[_user] = true;
      stakedUserMapSize++;
      stakedUserList.push(_user);
    }
  }

  function removeStakedUser(address _user) internal {
    if (stakedUserMap[_user]) {
      stakedUserMap[_user] = false;
      stakedUserMapSize--;
    }
  }

  function addSoldUser(address _user) internal {
    if (!soldUserMap[_user]) {
      soldUserMap[_user] = true;
      soldUserMapSize++;
      soldUserList.push(_user);
    }
  }

  function removeSoldUser(address _user) internal {
    if (soldUserMap[_user]) {
      soldUserMap[_user] = false;
      soldUserMapSize--;
    }
  }

  // Enables the sale whitelist and adds addresses to it
  function enableSaleWhitelist(address[] memory _users) public onlyOwner {
    require(block.timestamp < saleStartTs, 'Sale is started');

    isSaleWhitelistEnabled = true;
    for (uint i = 0; i < _users.length; i++) {
      saleWhitelist[_users[i]] = true;
    }
  }

  // Allows the owner to deposit tokens for the sale
  function depositSaleTokens(uint _amount) public onlyOwner {
    require(block.timestamp < saleEndTs, 'Sale is ended');
    require(_amount > 0, 'Amount must be greater than zero');
    require(saleToken.balanceOf(msg.sender) >= _amount, 'Insufficient token balance');
    require(saleToken.allowance(msg.sender, address(this)) >= _amount, 'Token allowance too low');

    saleTotalAmount += _amount;
    saleToken.transferFrom(msg.sender, address(this), _amount);

    emit SaleTokensDeposited(_amount);
  }

  // Allows users to stake tokens within the staking period
  function stake(uint _amount) public {
    require(block.timestamp <= stakingStartTs, 'Staking only allowed before start time');
    require(_amount >= stakingVolumeMin, 'Staking amount is too small');

    Position storage _pos = positions[msg.sender];
    require(_pos.stakingAmount + _amount <= stakingVolumeMax, 'Staking amount is too large');

    _pos.stakingAmount += _amount;
    addStakedUser(msg.sender);

    stakingToken.transferFrom(msg.sender, address(this), _amount);

    emit TokensStaked(msg.sender, _amount);
  }

  // Allows users to unstake their tokens after the staking period ends
  function unstake(address _user) public {
    require(block.timestamp >= stakingEndTs, 'Staking is not ended');

    Position storage _pos = positions[_user];
    require(!_pos.isUnstaked, 'Already unstaked');

    _pos.isUnstaked = true;
    removeStakedUser(_user);

    stakingToken.transfer(_user, _pos.stakingAmount);

    emit TokensUnstaked(_user, _pos.stakingAmount);
  }

  // Allows the owner to unstake tokens for multiple users
  function unstakeMulti(address[] memory _users) public {
    require(block.timestamp >= stakingEndTs, 'Staking is not ended');

    for (uint i = 0; i < _users.length; i++) {
      Position storage _pos = positions[_users[i]];
      if (_pos.isUnstaked) {
        continue;
      }

      _pos.isUnstaked = true;
      removeStakedUser(_users[i]);

      stakingToken.transfer(_users[i], _pos.stakingAmount);

      emit TokensUnstaked(_users[i], _pos.stakingAmount);
    }
  }

  function getMaxBuyAmount(address _user) public view returns (uint) {
    Position storage _pos = positions[_user];
    if (_pos.stakingAmount == 0) {
      return 0;
    }

    uint _ratio = _pos.stakingAmount >= stakingVolumeTier3
      ? saleRatioTier3
      : (_pos.stakingAmount >= stakingVolumeTier2 ? saleRatioTier2 : saleRatioTier1);

    return (_pos.stakingAmount * _ratio) / GU;
  }

  // Allows users to participate in the token sale
  function participateInSale(uint _amount) public payable {
    require(block.timestamp >= saleStartTs && block.timestamp <= saleEndTs, 'Sale is not active');

    if (isSaleWhitelistEnabled) {
      require(saleWhitelist[msg.sender], 'Your wallet is not whitelisted');
    }

    Position storage _pos = positions[msg.sender];
    require(_pos.stakingAmount > 0, 'Your wallet is not staked');
    require(_pos.isUnstaked, 'Your wallet is not unstaked');

    uint _maxBuyAmount = getMaxBuyAmount(msg.sender);
    require(_pos.buyAmount + _amount <= _maxBuyAmount, 'Buy amount is too large');

    uint _purchaseAmount = (_amount * salePrice) / GU;

    _pos.buyAmount += _amount;
    soldTotalAmount += _amount;
    addSoldUser(msg.sender);

    if (address(purchaseToken) == address(0)) {
      // ETH
      require(msg.value == _purchaseAmount, 'Purchase amount is not matched');
    } else {
      // ERC-20
      require(purchaseToken.balanceOf(msg.sender) >= _purchaseAmount, 'Purchase token amount is not enough');
      require(
        purchaseToken.allowance(msg.sender, address(this)) >= _purchaseAmount,
        'Purchase token amount is not approved'
      );
      purchaseToken.transferFrom(msg.sender, address(this), _purchaseAmount);
    }

    emit SaleParticipated(msg.sender, _amount);
  }

  // Calculates the amount of tokens available for vesting for a user
  function getVestingAmount(address _user) public view returns (uint) {
    if (block.timestamp < vestingStartTs) {
      return 0;
    }

    Position storage _pos = positions[_user];
    if (_pos.buyAmount == 0) {
      return 0;
    }

    uint _currentStep = ((block.timestamp - vestingStartTs) / vestingPeriod) + 1;
    uint _currentRatio = _min(_currentStep * vestingRatio, 1 * GU);
    uint _currentAmount = (_pos.buyAmount * _currentRatio) / GU;

    if (_currentAmount <= _pos.vestedAmount) {
      return 0;
    }
    return _currentAmount - _pos.vestedAmount;
  }

  // Allows users to claim their vested tokens
  function releaseVestedTokens(address _user) public {
    require(block.timestamp >= saleEndTs, 'Sale is not ended');
    require(block.timestamp >= vestingStartTs, 'Vesting is not started');

    Position storage _pos = positions[_user];
    require(_pos.stakingAmount > 0, 'Your wallet is not staked');
    require(_pos.buyAmount > 0, 'Your wallet is not bought');

    uint _vestingAmount = getVestingAmount(_user);
    require(_vestingAmount > 0, 'No vested tokens to release');
    require(_pos.vestedAmount + _vestingAmount <= _pos.buyAmount, 'Already vested all tokens');

    _pos.vestedAmount += _vestingAmount;
    if (_pos.vestedAmount == _pos.buyAmount) {
      removeSoldUser(_user);
    }
    saleToken.transfer(msg.sender, _vestingAmount);

    emit TokensVested(msg.sender, _vestingAmount);
  }

  // Allows the owner to claim vested tokens for multiple users
  function releaseVestedTokensMulti(address[] memory _users) public {
    require(block.timestamp >= saleEndTs, 'Sale is not ended');
    require(block.timestamp >= vestingStartTs, 'Vesting is not started');

    for (uint i = 0; i < _users.length; i++) {
      Position storage _pos = positions[_users[i]];
      if (_pos.stakingAmount == 0 || _pos.buyAmount == 0) {
        continue;
      }

      uint _vestingAmount = getVestingAmount(_users[i]);
      if (_vestingAmount == 0) {
        continue;
      }
      if (_pos.vestedAmount + _vestingAmount >= _pos.buyAmount) {
        continue;
      }

      _pos.vestedAmount += _vestingAmount;
      if (_pos.vestedAmount == _pos.buyAmount) {
        removeSoldUser(_users[i]);
      }
      saleToken.transfer(_users[i], _vestingAmount);

      emit TokensVested(_users[i], _vestingAmount);
    }
  }

  // Finalizes the sale, enabling fund withdrawal and token distribution
  function finalizeSale() public onlyOwner {
    require(block.timestamp >= saleEndTs, 'Sale is not ended');

    uint _purchasedAmount = 0;
    if (address(purchaseToken) == address(0)) {
      // ETH
      _purchasedAmount = address(this).balance;
      payable(owner()).transfer(_purchasedAmount);
    } else {
      // ERC-20
      _purchasedAmount = purchaseToken.balanceOf(address(this));
      purchaseToken.transfer(owner(), _purchasedAmount);
    }

    uint _unsoldAmount = saleTotalAmount - soldTotalAmount;
    saleToken.transfer(owner(), _unsoldAmount);

    emit SaleFinalized(_purchasedAmount, _unsoldAmount);
  }
}
