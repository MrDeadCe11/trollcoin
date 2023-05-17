// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "../lib/solmate/src/tokens/ERC20.sol";
import "../lib/openzeppelin-contracts/contracts/access/Ownable.sol";
import "../lib/openzeppelin-contracts/contracts/utils/Counters.sol";

error InvalidAttackAmount(uint256 amount);
error InvalidBalance();
error CannotAttackThisAddress(address defender);
error InvalidId();
error InvalidDefender();
error UnderAttack(address trolled);

contract Troll is ERC20, Ownable {
    // initialize war counter
    using Counters for Counters.Counter;
    Counters.Counter internal warId;

    struct War {
        uint256 id;
        uint256 startTime;
        uint256 round;
        address attacker;
        address defender;
        address loser;
        uint256 warPool;
    }

    struct Defense {
        uint256 amount;
        uint256 startDefenseTime;
    }

    //mapping of defense amounts for each user
    mapping(address => Defense) public defenses;
    //mapping of war structs by war id
    mapping(uint256 => War) internal wars;
    // mapping of wars per address
    mapping(address => uint256[]) internal activeWars;
    // immunity timer: if you lose a round you are immune from attack for 24 hours.
    mapping(address => uint256) internal immunityTimer;
    //mapping of addresses under attack
    mapping(address => bool) internal underAttack;

    uint256 internal ANNUAL_INTEREST_RATE;

    event Attacked(
        uint256 warId,
        uint256 time,
        address attacker,
        address defender
    );
    event Surrendered(
        uint256 warId,
        address attacker,
        address defender,
        uint256 warPool
    );
    modifier peace(address defender) {
        if (underAttack[defender] == true) {
            revert UnderAttack(defender);
        }
        _;
    }
    event DefensesSet(address defender, uint256 amount, uint256 timestamp);

    event DefensesUnset(address defender, uint256 reward, uint256 timestamp);

    constructor(
        uint256 _initialSupply,
        uint256 _stakingReward
    ) ERC20("Troll", "TROLOLOL", 18) {
        warId.increment();
        _mint(msg.sender, _initialSupply);
        ANNUAL_INTEREST_RATE = _stakingReward;
    }

    function startWar(
        address _defender,
        uint256 _amount
    ) public peace(_defender) {
        uint256 startTime = block.timestamp;
        if (
            msg.sender == _defender ||
            _defender == address(0) ||
            immunityTimer[_defender] > startTime
        ) {
            revert CannotAttackThisAddress(_defender);
        }

        if (balanceOf[msg.sender] < _amount) {
            revert InvalidBalance();
        }

        //check defender defense amount
        if (_amount < defenses[_defender].amount) {
            revert InvalidAttackAmount(_amount);
        }

        for (uint256 i = 0; i < activeWars[_defender].length; i++) {
            // you cannot attack someone who is attacking you, you must defend.
            if (getWarById(activeWars[_defender][i]).defender == msg.sender)
                revert CannotAttackThisAddress(_defender);
        }

        uint256 newWarId = warId.current();

        // get defense amount

        uint256 defenderPool = calculateReward(
            defenses[_defender].amount,
            defenses[_defender].startDefenseTime,
            startTime
        );

        // reset defenses and make defender un attackable by anyone else.
        delete defenses[_defender];
        underAttack[_defender] = true;

        // create new war
        War memory newWar;
        newWar.id = newWarId;
        newWar.startTime = startTime;
        newWar.attacker = msg.sender;
        newWar.defender = _defender;
        newWar.round = 1;
        newWar.warPool = _amount + defenderPool;

        wars[newWarId] = newWar;
        //transfer attacking amount to contract
        transferFrom(msg.sender, address(this), _amount);

        warId.increment();

        emit Attacked(newWarId, startTime, msg.sender, _defender);
    }

    function retaliate(
        uint256 _warId,
        uint256 _retaliationAmount
    ) public returns (uint256) {
        // #TODO calculate retaliation amount according to round number and last amount
        //check that amount is greater than or equal to the require power and that user has available balance
    }

    function calculateAttack(
        uint256 _currentAmount,
        uint256 roundNumber
    ) public pure returns (uint256 requiredPower) {
        requiredPower = _currentAmount + ((_currentAmount * roundNumber) / 10);
    }

    /**
    @dev this sets the amount to defend an address with.  in order to attack an attacker will 
    have to stake more than this amount and will begin the battle at this amount
     */

    function setDefenses(uint256 _amount) public {
        if (balanceOf[msg.sender] <= _amount) {
            revert InvalidBalance();
        }
        if (underAttack[msg.sender]) {
            revert UnderAttack(msg.sender);
        }

        uint256 timestamp = block.timestamp;
        Defense memory newDefense;
        newDefense.amount = _amount;
        newDefense.startDefenseTime = timestamp;
        defenses[msg.sender] = newDefense;
        transferFrom(msg.sender, address(this), _amount);
        emit DefensesSet(msg.sender, _amount, timestamp);
    }

    /** 
    @dev this will allow someone with defenses staked to unstake their defenses and collect their staking rewards
     */
    function unsetDefenses() public {
        uint256 amount = defenses[msg.sender].amount;
        if (amount == 0 || underAttack[msg.sender]) {
            revert InvalidDefender();
        }
        uint256 endTimestamp = block.timestamp;
        // calculate and mint staking rewards
        uint256 reward = calculateReward(
            amount,
            defenses[msg.sender].startDefenseTime,
            endTimestamp
        );

        // transfer original stake
        require(transfer(msg.sender, amount), "unable to unstake");
        // mint reward
        _mint(msg.sender, (reward - amount));
        // delete defense mapping.
        delete defenses[msg.sender];
        emit DefensesUnset(msg.sender, reward, endTimestamp);
    }

    function getWarById(uint256 _warId) public view returns (War memory war) {
        if (warId.current() <= _warId) {
            revert InvalidId();
        }
        war = wars[_warId];
    }

    function calculateReward(
        uint256 _amount,
        uint256 _startTimestamp,
        uint256 _endTimestamp
    ) internal view returns (uint256 reward) {
        // uint256 dailyInterestRate = ANNUAL_INTEREST_RATE / 365;
        uint256 daysStaked = (_endTimestamp - _startTimestamp) / 60 / 60 / 24;
        // Divide by 10,000 to account for the percentage
        reward =
            (_amount * (ANNUAL_INTEREST_RATE ** daysStaked)) /
            (100 ** daysStaked) /
            10000;
    }

    function transfer(
        address to,
        uint256 amount
    ) public override returns (bool) {
        if (underAttack[msg.sender] == true) {
            revert UnderAttack(msg.sender);
        }
        return super.transfer(to, amount);
    }

    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) public override returns (bool) {
        if (underAttack[from] == true) {
            revert UnderAttack(from);
        }
        return super.transferFrom(from, to, amount);
    }

    /** @dev OnlyOwner functions */
    function setImmunityTimer(
        address _immunized,
        uint256 _endTimeStamp
    ) external onlyOwner {
        immunityTimer[_immunized] = _endTimeStamp;
    }

    function setInterestRate(uint256 _newRate) external onlyOwner {
        ANNUAL_INTEREST_RATE = _newRate;
    }
}
