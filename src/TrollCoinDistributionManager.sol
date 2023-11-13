// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;
pragma experimental ABIEncoderV2;

import {Errors} from "./lib/Errors.sol";

import "forge-std/console2.sol";

/**
 * @title TrollCoinDistributionManager
 * @notice Accounting contract to manage staking distributions
 * @author MrDeadCe11
 **/

abstract contract TrollCoinDistributionManager is Errors {
    /// @notice The constant that represents percentage points for calculations.
    uint256 public constant PERC_POINTS = 1e6;

    /// @notice The emissions per second, set at 20% (20,000 out of a million).
    uint256 public apy = 20_000;

    uint256 public constant PRECISION = 1e18;
    // (seconds per year / percentage points) * APY
    uint256 public emissionsPerSecond = (31536000 / PERC_POINTS) * apy;

    event APYAdjusted(uint256);

    struct Defense {
        uint256 totalDefense;
        uint256 startDefenseTimestamp;
        uint256 totalSupplyAtTimeOfDefense;
    }

    function _calculateCurrentReward(
        Defense memory _defense
    ) internal view returns (uint256 reward) {
        uint256 timeDelta = (block.timestamp - _defense.startDefenseTimestamp);

        reward = (_defense.totalDefense *
            ((timeDelta * emissionsPerSecond * PRECISION) /
                _defense.totalSupplyAtTimeOfDefense));
    }

    function _adjustAPY(uint256 _newApy) internal {
        apy = _newApy;
        emit APYAdjusted(_newApy);
    }
}
