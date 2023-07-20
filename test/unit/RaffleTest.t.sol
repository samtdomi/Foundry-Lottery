// SPDX-License-Identifier: MIT

pragma solidity ^0.8.17;

import {Test, console} from "lib/forge-std/src/Test.sol";
import {DeployRaffle} from "../../script/DeployRaffle.s.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {Raffle} from "../../src/Raffle.sol";
import {Vm} from "lib/forge-std/src/Vm.sol";
import {VRFCoordinatorV2Mock} from "lib/chainlink-brownie-contracts/contracts/src/v0.8/mocks/VRFCoordinatorV2Mock.sol";

contract RaffleTest is Test {
    /* Event */
    event RaffleEntered(address indexed player);

    /*   State Variables   */
    Raffle raffle;
    HelperConfig helperConfig;

    address public Player = makeAddr("player");
    uint256 public constant StartingPlayerBalance = 10 ether;

    address vrfCoordinator;
    uint256 entranceFee;
    uint256 interval;
    bytes32 keyHash;
    uint64 subId;
    uint32 callbackGasLimit;
    address linkToken;
    uint256 deployerKey;

    // this function runs before each new test function
    // deploy contracts so each test has a fresh contract to work with
    function setUp() external {
        // using the deploy script to deploy the Raffle contract and not only test
        // that the Raffle contract works properly, but also that the deploy
        // script works properly and deploys the Raffle contract as needed
        DeployRaffle deployRaffle = new DeployRaffle();
        (raffle, helperConfig) = deployRaffle.run();
        (
            vrfCoordinator,
            entranceFee,
            interval,
            keyHash,
            subId,
            callbackGasLimit,
            linkToken,
            deployerKey
        ) = helperConfig.activeConfig();

        vm.deal(Player, StartingPlayerBalance);
    }

    function testRaffleIntializesInOpenState() public view {
        assert(raffle.getRaffleState() == Raffle.RaffleState.Open);
    }

    ////////////////////////////////
    ////   enter raffle tests   ////
    ////////////////////////////////

    function testRaffleRevertsWhenYouDontPayEnough() public {
        vm.startPrank(Player);
        vm.expectRevert /* Raffle.Raffle__NotEnoughETH.selector */();
        raffle.enterRaffle(); // calling enterRaffle and sending 0 eth
        vm.stopPrank();
    }

    function testRaffleRecordsPlayerWhenTheyEnter() public {
        vm.startPrank(Player);
        raffle.enterRaffle{value: entranceFee}();
        vm.stopPrank();

        // address payable[] memory playersArray = raffle.getPlayersArray();
        // assertEq(playersArray.length, 1);
        assertEq(raffle.getPlayer(0), Player);
    }

    function testEmitsEventOnEntrance() public {
        vm.prank(Player);
        vm.expectEmit(true, false, false, false, address(raffle));
        emit RaffleEntered(Player);
        raffle.enterRaffle{value: entranceFee}();
    }

    function testCannotEnterWhenRaffleIsCalculating() public {
        vm.prank(Player);
        raffle.enterRaffle{value: entranceFee}();
        vm.warp(block.timestamp + interval + 1 seconds); // changes the block timestamp to whatever
        vm.roll(block.number + 1); // moves to the next block
        raffle.performUpkeep(""); // checkUpkeep is true, all conditions are true
        // running performUpkeep() changesthe RaffleState to calculating
        // contract should revert when anyone tries to enter when its in this state
        vm.expectRevert /*Raffle.Raffle__NotOpen.selector*/();
        vm.prank(Player);
        raffle.enterRaffle{value: entranceFee}();
    }

    ////////////////////////////////
    ////   checkUpkeep tests    ////
    ////////////////////////////////

    function testCheckUpkeepReturnsFalseIfItHasNoBalance() public {
        // make sure every other check except 'hasBalance' is TRUE
        // so we can specifically check if it returns false when there is no balance
        // if it has no balance, it also has no players. so testing both at once
        // Arrange
        vm.warp(block.timestamp + interval + 1 seconds);
        vm.roll(block.number + 1);
        // Act
        (bool upkeepNeeded, ) = raffle.checkUpkeep("");
        // Assert
        assert(!upkeepNeeded);
    }

    function testCheckUpkeepReturnsFalseIfRaffleNotOpen() public {
        // we have to get raffleState to "Calculating" - we have to run checkUpkeep()
        // and have it pass and run performUpkeep() to change the raffleState to "Calculating"
        vm.prank(Player);
        raffle.enterRaffle{value: entranceFee}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        // changes the raffleState to "Calculating"
        raffle.performUpkeep("");

        // Act
        (bool upkeepNeeded, ) = raffle.checkUpkeep("");
        // Assert
        assert(upkeepNeeded == false);
    }

    function testCheckUpkeepReturnsFalseIfEnoughTimeHasntPassed() public {
        // Arrange
        // raffle will have players and balance, and raffleState will be "Open"
        // Only the time will not have passed and is false
        vm.prank(Player);
        raffle.enterRaffle{value: entranceFee}();
        // Act
        (bool checkUpkeep, ) = raffle.checkUpkeep("");
        // Assert
        assert(!checkUpkeep);
    }

    function testCheckUpkeepReturnsTrueWhenParamatersAreGood() public {
        // Arrange
        vm.prank(Player);
        raffle.enterRaffle{value: entranceFee}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        // Act
        (bool checkUpkeep, ) = raffle.checkUpkeep("");
        // Assert
        assert(checkUpkeep == true);
    }

    ////////////////////////////////
    ////     Perform Upkeep     ////
    ////////////////////////////////

    modifier raffleEnterRaffleAndTimePassed() {
        vm.prank(Player);
        raffle.enterRaffle{value: entranceFee}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        _;
    }

    function testPerformUpkeepCanOnlyRunIfCheckUpkeepIsTrue() public {
        // Arrange
        // raffleEnterRaffleAndTimePassed() modifier equivalent
        vm.startPrank(Player);
        raffle.enterRaffle{value: entranceFee}();
        vm.stopPrank();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        // Act / Assert
        raffle.performUpkeep(""); // if it runs, it is considered to be successful test
    }

    function testPerformUpkeepRevertsIfCheckUpkeepIsFalse() public {
        // Arrange
        // Act
        // Assert
        vm.expectRevert();
        raffle.performUpkeep("");
    }

    // What if I need to test using the output of an event? How do I do that?
    function testPerformUpkeepUpdatesRaffleStateAndEmitsRequestId()
        public
        raffleEnterRaffleAndTimePassed
    {
        // Arrange
        // Uses modifier raffleEnterRaffleAndTimePassed();

        // Act
        vm.recordLogs();
        raffle.performUpkeep(""); // emit requestId
        Vm.Log[] memory entries = vm.getRecordedLogs();
        bytes32 requestId = entries[1].topics[1];

        Raffle.RaffleState rState = raffle.getRaffleState();

        // Assert
        assert(uint256(requestId) > 0);
        assert(uint256(rState) == 1);
    }

    ////////////////////////////////
    ////   Fulfill RandomWords  ////
    ////////////////////////////////

    modifier skipFork() {
        if (block.chainid != 31337) {
            return;
        }
        _;
    }

    function testFulfillRandomWordsCanOnlyBeCalledAfterPerformUpkeep(
        uint256 randomRequestId
    ) public raffleEnterRaffleAndTimePassed skipFork {
        // randomRequestId is "FUZZING" testing technique that will test several random numbers
        // as the value of randomRequestId
        // Arrange
        vm.expectRevert("nonexistent request");
        VRFCoordinatorV2Mock(vrfCoordinator).fulfillRandomWords(
            randomRequestId,
            address(raffle)
        );
    }

    function testFulfillRandomWordsPicksWinnerResetsAndSendsMoney()
        public
        skipFork
    {
        // Arrange
        uint256 additionalEntrants = 5;
        uint256 startingIndex = 1;
        for (
            uint256 i = startingIndex;
            i < additionalEntrants + startingIndex;
            i++
        ) {
            address player = makeAddr("player");
            hoax(player, StartingPlayerBalance); // equivalent to the following 2 lines, call prank and gives the prank account funds
            // vm.deal(player, 10 ether);
            // vm.prank(player);
            raffle.enterRaffle{value: entranceFee}();
        }

        // Make sure enoguh time has passed, more than the interval requirement
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);

        // gets the total amount of ETH the contract has from all of the players that entered
        uint256 prize = entranceFee * (additionalEntrants + 1);

        // gets the requestId from the emitted event after performUpkeep() calls Chainlink's requestRandomWords()
        vm.recordLogs();
        raffle.performUpkeep(""); // emits requestId
        Vm.Log[] memory entries = vm.getRecordedLogs();
        bytes32 requestId = entries[1].topics[1];

        uint256 previousTimeStamp = raffle.getLastTimeStamp();

        // Pretend to be Chainlink VRF to get random number & pick winner
        VRFCoordinatorV2Mock(vrfCoordinator).fulfillRandomWords(
            uint256(requestId),
            address(raffle)
        );

        console.log(StartingPlayerBalance);
        console.log(raffle.getRecentWinner().balance);
        console.log(prize);
        console.log(entranceFee);
        console.log(StartingPlayerBalance + prize - entranceFee - entranceFee);

        // Assert
        assert((uint256(raffle.getRaffleState()) == 0));
        assert(raffle.getRecentWinner() != address(0));
        assert(raffle.getPlayersArrayLength() == 0);
        assert(previousTimeStamp < raffle.getLastTimeStamp());
        assert(
            raffle.getRecentWinner().balance ==
                StartingPlayerBalance + prize - entranceFee - entranceFee
        );
    }

    /////////////////////////////////////////////////////////
    //////////           END OF TEST'S         /////////////
    ////////////////////////////////////////////////////////
}

//// God please help me today and tomorrow. I really need for this problem to be resolved. I need my mom to be willing to help me and send me the money.
//// God help me be stronger every single day. I need the strength to push forward - i need your strength to be passed in to me
//// God please let me get this rent paid, and the situation resolved and not be evicted. Please.
//// I need your stength God - I need your strength. I am weak. I am almost defeated.
