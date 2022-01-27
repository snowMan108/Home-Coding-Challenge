// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.4;

import "./libraries/SafeMath.sol";
import "./libraries/SafeERC20.sol";

import "./interfaces/IERC20.sol";
import "./interfaces/IFarmCoin.sol";
import "./interfaces/IERC20Permit.sol";

import "./types/ERC20Permit.sol";
import "./types/FarmCoinAccessControlled.sol";

contract DepositContract is FarmCoinAccessControlled {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    // Tokens

    IFarmCoin public immutable FarmCoin;
    IERC20 public DepositToken;

    // Deposi matix & interest

    struct Deposit {
        uint256 depositTime;
        uint256 depositAmount;
        uint256 expire;
        uint256 rewardPerSecond;
        uint256 lastClaimTime;
    }

    mapping(address => Deposit[]) depositorMatrix;

    uint256[] public interestArray = [10, 20, 30]; 



    constructor(
        address _FarmCoin,
        address _DepositToken,
        address _authority
    ) 
    FarmCoinAccessControlled(IFarmCoinAuthority(_authority)) {
        require(_FarmCoin != address(0), "Constructor: Zero address: FarmCoin");
        FarmCoin = IFarmCoin(_FarmCoin);

        require(_DepositToken != address(0), "Constructor: Zero address: DepositToken");
        DepositToken = IERC20(_DepositToken);
    }

    /**
      @notice Deposit with their own token
      @param _amount uint256
      @param _duration uint256
     */
    function deposit(uint256 _amount, uint256 _duration) external {
        address account = msg.sender;

        require(_duration == 0 || _duration == 6 || _duration == 12, "Deposit: Deposit duration incorrect");

        require(DepositToken.balanceOf(account) >= _amount, "Deposit: Balance infuluence");

        uint256 _rewardPerSecond;

        if (_duration == 0) {
            _rewardPerSecond = uint256(10 ** 18).div(365 * 1 days);
        } else if (_duration == 6) {
            _rewardPerSecond = uint256(20 ** 18).div(365 * 1 days);
        } else if (_duration == 12) {
            _rewardPerSecond = uint256(30 ** 18).div(365 * 1 days);
        }

        DepositToken.safeTransferFrom(account, address(this), _amount);

        depositorMatrix[account].push(
            Deposit({
                depositTime: block.timestamp,
                depositAmount: _amount,
                expire: block.timestamp.add(_duration * 30 days),
                rewardPerSecond: _rewardPerSecond,
                lastClaimTime: block.timestamp
            })
        );
    }

    /**
      @notice Withdraw their deposited token selected by index
      @param index uint256
     */
    function withdraw(uint256 index) external {
        address account = msg.sender;

        require(isDepositor(account), "Withdraw: No Depositor");

        Deposit[] storage deposits = depositorMatrix[account];

        Deposit storage depoistData = getDepositDataByIndex(deposits, index);

        uint256 refundRate = 100;

        if (depoistData.expire > block.timestamp) {
            refundRate = 90;
        }

        uint256 refundAmount = depoistData.depositAmount.mul(refundRate).div(100);

        DepositToken.transfer(account, refundAmount);
    }

    /**
      @notice Get deposit info selecte by index
      @param index uint256
     */
    function getDepositData(uint256 index) external view returns (Deposit memory) {
        address account = msg.sender;

        require(isDepositor(account), "Claim By Index: No Depositor");

        Deposit[] storage deposits = depositorMatrix[account];

        Deposit storage depoistData = getDepositDataByIndex(deposits, index);
        
        return depoistData;
    }

    /**
      @notice Claim rewards selected by index
      @param index uint256
     */
    function claimRewardByIndex(uint256 index) external {
        address account = msg.sender;

        require(isDepositor(account), "Claim By Index: No Depositor");

        Deposit[] storage deposits = depositorMatrix[account];

        Deposit storage depoistData = getDepositDataByIndex(deposits, index);

        uint256 availableReward = calculateRewards(depoistData);

        depoistData.lastClaimTime = block.timestamp;

        FarmCoin.mint(account, availableReward);
    }

    /**
      @notice Claime their all available rewards
     */
    function claimRewardsAll() external {
        address account = msg.sender;

        require(isDepositor(account), "Claim By Index: No Depositor");

        Deposit[] storage deposits = depositorMatrix[account];

        Deposit storage depoistData;

        uint256 counts = deposits.length;

        uint256 totalRewards;
        uint256 availableReward;

        for (uint256 i = 0; i < counts; i ++) {
            depoistData = getDepositDataByIndex(deposits, i);

            availableReward = calculateRewards(depoistData);

            totalRewards += availableReward;

            depoistData.lastClaimTime = block.timestamp;
        }

        FarmCoin.mint(account, totalRewards);
    }

    /**
      @notice Get avaliable rewards selected by index
      @param index uint256
     */
    function getRewardByIndex(uint256 index) external view returns (uint256) {
        address account = msg.sender;

        require(isDepositor(account), "Claim By Index: No Depositor");

        Deposit[] storage deposits = depositorMatrix[account];

        Deposit storage depoistData = getDepositDataByIndex(deposits, index);

        uint256 availableReward = calculateRewards(depoistData);
        
        return availableReward;
    }

    /**
      @notice Get all available rewards
     */
    function getRewardsAll() external view returns (uint256) {
        address account = msg.sender;

        require(isDepositor(account), "Claim By Index: No Depositor");

        Deposit[] storage deposits = depositorMatrix[account];

        Deposit storage depoistData;

        uint256 counts = deposits.length;

        uint256 totalRewards;
        uint256 availableReward;

        for (uint256 i = 0; i < counts; i ++) {
            depoistData = getDepositDataByIndex(deposits, i);

            availableReward = calculateRewards(depoistData);

            totalRewards += availableReward;
        }
        
        return totalRewards;
    }

    /**
      @notice Check if user is depositor
      @param account address
     */
    function isDepositor(address account) internal view returns (bool) {
        return depositorMatrix[address(account)].length > 0;
    }

    /**
      @notice Return deposit data selected by index
      @param deposits Deposit[]
      @param index uint256
     */
    function getDepositDataByIndex(
        Deposit[] storage deposits,
        uint256 index
    ) private view returns (Deposit storage) {
        uint256 numberOfDeposits = deposits.length;

        require(numberOfDeposits > 0, "Get Index: No Depositor");

        require(index < numberOfDeposits, "Get Index: Index overflow");

        return deposits[index];
    }

    /**
      @notice Calculate available rewards
      @param _depoistData Deposit
     */
    function calculateRewards(Deposit storage _depoistData) internal view returns (uint256) {
        uint256 passedTime = block.timestamp.sub(_depoistData.lastClaimTime);
        return _depoistData.rewardPerSecond.mul(passedTime);
    }
}
