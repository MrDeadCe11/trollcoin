// SPDX-License-Identifier: MIT
pragma solidity ^0.8.14;

import "@solmate/tokens/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

error InvalidAttackAmount(uint256 amount);
error InvalidBalance();
error CannotAttackThisAddress(address defender);
error InvalidId();

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

    uint256 internal ANNUAL_INTEREST_RATE;

    event Attacked (uint256 warId, uint256 time, address attacker, address defender);
    event Surrender (uint256 warId, address attacker, address defender, uint256 warPool);

    constructor(uint256 _initialSupply, uint256 _stakingReward)ERC20("Troll", "TROLOLOL", 18){
        warId.increment();
        _mint(msg.sender, _initialSupply);
        ANNUAL_INTEREST_RATE = _stakingReward;
    }

    function attack(address _defender , uint256 _amount) public {

        if(msg.sender == _defender){
            revert CannotAttackThisAddress(_defender);
        }

        if(balanceOf[msg.sender] < _amount){
            revert InvalidBalance();
        }

        //check defender defense amount
        if(_amount < defenses[_defender].amount){
         revert InvalidAttackAmount(_amount);
          }

        for(uint256 i; i <  activeWars[_defender].length; i++){
            // you cannot attack someone who is attacking you, you must defend.
            if(getWarById(activeWars[_defender][i]).defender == msg.sender) revert CannotAttackThisAddress(_defender);
        }

          uint256 newWarId = warId.current();

          uint256 startTime = block.timestamp;
          // get defenses
    
          uint256 defenderPool = calculateReward(defenses[_defender]);
          //create new war
          War memory newWar;
          newWar.id = newWarId;
          newWar.startTime = startTime;
          newWar.attacker = msg.sender;
          newWar.defender = _defender;
          newWar.warPool = _amount + defenderPool;

          wars[newWarId] = newWar;
        //burn attacking amount
        _burn(msg.sender, _amount);

        warId.increment();

        emit Attacked(newWarId, startTime,msg.sender, _defender);
    }

    function getWarById(uint256 _warId) public view returns(War memory war){
        if(warId.current() <= _warId) { revert InvalidId(); }
        war = wars[_warId];
    }

    function calculateReward(Defense memory _defenses)internal view returns(uint256 reward){
        uint256 dailyInterestRate = ANNUAL_INTEREST_RATE / 365;
        uint256 daysStaked = (block.timestamp - _defenses.startDefenseTime) / 60 / 60 / 24;
        // Divide by 10,000 to account for the percentage
        reward = (_defenses.amount * dailyInterestRate * daysStaked) / 10000; 
    }
}