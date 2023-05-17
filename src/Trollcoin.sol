// SPDX-License-Identifier: MIT

pragma solidity ^0.8.14;

import "@solmate/tokens/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";


contract Trollcoin is ERC20, Ownable {

    constructor()ERC20("Trollcoin", "TROLOLOL", 18){}
}