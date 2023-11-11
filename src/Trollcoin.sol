// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "../lib/solmate/src/tokens/ERC20.sol";
import "../lib/openzeppelin-contracts/contracts/access/Ownable.sol";

import {TrollCoinDistributionManager} from "./TrollCoinDistributionManager.sol";

import "../lib/forge-std/src/console.sol";

error InvalidAttackAmount(uint256 amount);
error InvalidBalance();
error CannotAttackThisAddress(address defender);
error InvalidId();
error InvalidDefender();
error UnderAttack(address trolled);
error InvalidTimestamp();

contract Troll is ERC20, Ownable, TrollCoinDistributionManager {
    // initialize war counter
    uint256 public warId;

    uint8 public constant PRECISION = 18;

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

    // mapping of defense amounts for each user
    mapping(address => Defense) public defenses;
    //mapping of war structs by war id
    mapping(uint256 => War) public wars;
    // mapping of wars being defended by eoa per address
    mapping(address => uint256[]) public defending;
    // mapping of wars eoa is attacker in.
    mapping(address => uint256[]) public attacking;
    // immunity timer: if you lose a round you are immune from attack for 24 hours.
    mapping(address => uint256) public immunityTimer;

    //solhint-disable-next-line
    uint256 internal ANNUAL_INTEREST_RATE;

    event Attacked(
        uint256 warId,
        uint256 time,
        address attacker,
        address defender
    );

    event Surrendered(
        uint256 warId,
        address loser,
        uint256 warPool,
        uint256 timestamp
    );

    modifier peaceTime(address defender) {
        if (
            defending[defender].length != 0 && attacking[defender].length != 0
        ) {
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
        warId++;
        _mint(msg.sender, _initialSupply);
        ANNUAL_INTEREST_RATE = _stakingReward;
    }

    function startWar(
        address _defender,
        uint256 _amount
    ) public peaceTime(_defender) {
        uint256 startTime = block.timestamp;
        // check for immunities
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

        // check defender defense amount
        if (_amount < defenses[_defender].amount) {
            revert InvalidAttackAmount(_amount);
        }

        for (uint256 i = 0; i < attacking[msg.sender].length; i++) {
            // you cannot attack someone who is attacking you, you must defend.
            if (getWarById(attacking[_defender][i]).defender == msg.sender)
                revert CannotAttackThisAddress(_defender);
        }

        uint256 newWarId = warId;

        // get defense amount

        uint256 defenderPool = _calculateReward(
            defenses[_defender].amount,
            defenses[_defender].startDefenseTime,
            startTime
        );

        // reset defenses
        delete defenses[_defender];
        defending[_defender].push(newWarId);
        attacking[msg.sender].push(newWarId);

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

        warId++;

        emit Attacked(newWarId, startTime, msg.sender, _defender);
    }

    function battle(
        uint256 _warId,
        uint256 _attackPower
    ) public returns (uint256) {
        // #TODO calculate retaliation amount according to round number and last amount make sure that it's
        // msg.senders' turn (even numbers = defeneder, odd numbers = attacker);
        //check that amount is greater than or equal to the require power and that user has available balance
    }

    function _calculateAttack(
        uint256 _poolAmount,
        uint256 _roundNumber
    ) internal pure returns (uint256 requiredPower) {
        requiredPower = (_poolAmount * _roundNumber) / 10;
    }

    /**
    @dev this sets the amount to defend an address with.  in order to attack an attacker will 
    have to stake more than this amount and will begin the battle at this amount
     */

    function setDefenses(uint256 _amount) public peaceTime(msg.sender) {
        if (
            balanceOf[msg.sender] < _amount &&
            allowance[msg.sender][address(this)] < _amount
        ) {
            revert InvalidBalance();
        }

        uint256 timestamp = block.timestamp;

        Defense memory newDefense;

        newDefense.amount = _amount;
        newDefense.startDefenseTime = timestamp;

        this.transferFrom(msg.sender, address(this), _amount);

        defenses[msg.sender] = newDefense;

        emit DefensesSet(msg.sender, _amount, timestamp);
    }

    /** 
    @dev this will allow someone with defenses staked to unstake their defenses and collect their staking rewards
     */
    function unsetDefenses() public peaceTime(msg.sender) returns (bool) {
        uint256 amount = defenses[msg.sender].amount;
        if (amount == 0) {
            revert InvalidDefender();
        }
        uint256 endTimestamp = block.timestamp;
        // calculate and mint staking rewards
        uint256 reward = _calculateReward(
            amount,
            defenses[msg.sender].startDefenseTime,
            endTimestamp
        );

        // _mint(address(this), (reward - amount));
        // // transfer original stake
        // require(this.transfer(msg.sender, reward), "unable to unstake");

        // // delete defense mapping.
        // delete defenses[msg.sender];

        // emit DefensesUnset(msg.sender, reward, endTimestamp);
        return true;
    }

    function getWarById(uint256 _warId) public view returns (War memory war) {
        if (warId <= _warId) {
            revert InvalidId();
        }
        war = wars[_warId];
    }

    function transfer(
        address to,
        uint256 amount
    ) public override peaceTime(msg.sender) returns (bool) {
        return super.transfer(to, amount);
    }

    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) public override peaceTime(from) returns (bool) {
        return super.transferFrom(from, to, amount);
    }

    ////////////////////////////// OnlyOwner functions ///////////////////////

    function setImmunityTimer(
        address _immunized,
        uint256 _endTimeStamp
    ) external onlyOwner {
        immunityTimer[_immunized] = _endTimeStamp;
    }

    function setInterestRate(uint256 _newRate) external onlyOwner {
        ANNUAL_INTEREST_RATE = _newRate;
    }

    function mint(address to, uint256 _amount) public {
        _mint(to, _amount);
    }
}
