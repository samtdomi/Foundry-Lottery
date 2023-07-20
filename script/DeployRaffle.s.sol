// SPDX-License-Identifier: MIT

pragma solidity ^0.8.17;

import {Script} from "lib/forge-std/src/Script.sol";
import {Raffle} from "../src/Raffle.sol";
import {HelperConfig} from "./HelperConfig.s.sol";
import {CreateSubscription, FundSubscription, AddConsumer} from "./interactions.s.sol";

contract DeployRaffle is Script {
    Raffle raffle;
    HelperConfig helperConfig;

    /* Constructor Arguments (IN ORDER) //
    // we dont have to save these globally because deplo script is only using 1 function
    address vrfCoordinator;
    uint256 entranceFee;
    uint256 interval;
    bytes32 keyHash;
    uint64 subId;
    uint32 callbackGasLimit;
    address linkToken;
    */

    function run() external returns (Raffle, HelperConfig) {
        helperConfig = new HelperConfig();
        (
            address vrfCoordinator,
            uint256 entranceFee,
            uint256 interval,
            bytes32 keyHash,
            uint64 subId,
            uint32 callbackGasLimit,
            address linkToken,
            // non-constructor variable
            uint256 deployerKey
        ) = helperConfig.activeConfig();

        // Create a new subscription if deploying on local network and no susbcription is found
        // Fund the new subscription
        if (subId == 0) {
            // creates new subscription
            CreateSubscription createSubscription = new CreateSubscription();
            subId = createSubscription.createSubscription(vrfCoordinator);

            // Fund new subcription
            FundSubscription fundSubscription = new FundSubscription();
            fundSubscription.fundSubscription(vrfCoordinator, subId, linkToken);

            // Add Raffle contract as a Consumer to the new subscription
            // AFTER RAFFLE IS DEPLOYED!
        }

        vm.startBroadcast();

        // Deploy Raffle Contract
        // Pass in EVERY constructor() argument in order
        raffle = new Raffle(
            vrfCoordinator,
            entranceFee,
            interval,
            keyHash,
            subId,
            callbackGasLimit
        );

        vm.stopBroadcast();

        // Add newly deployed RAFFLE contract as a Consumer to the newly created subscription
        AddConsumer addConsumer = new AddConsumer();
        addConsumer.addConsumer(
            address(raffle),
            vrfCoordinator,
            subId,
            deployerKey
        );

        return (raffle, helperConfig);
    }
}
