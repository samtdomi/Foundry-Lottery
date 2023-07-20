// SPDX-License-Identifier: MIT

pragma solidity ^0.8.17;

/**   Imports   */
import {VRFCoordinatorV2Interface} from "lib/chainlink-brownie-contracts/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import {VRFConsumerBaseV2} from "lib/chainlink-brownie-contracts/contracts/src/v0.8/VRFConsumerBaseV2.sol";

/**   Errors   */
error Raffle__NotEnoughETH();
error Raffle__TransferFailed();
error Raffle__RaffleNotOpen();
error Raffle__UpkeepNotNeeded(
    uint256 _raffleState,
    uint256 currentBalance,
    uint256 numPlayers
);

/**
 * @title Verifiably Random Lottery Contract
 * @author Samuel Troy Dominguez
 * @notice This contract is for creating a lottery
 * @dev Implements Chainlink VRFv2
 */
contract Raffle is VRFConsumerBaseV2 {
    /**   Type Declarations   */
    enum RaffleState {
        Open, // 0
        Calculating // 1
    }
    RaffleState private s_raffleState;

    /**   State Variables   */
    uint256 private immutable i_entranceFee;
    address payable[] private s_players; // array of payable addresses
    // @dev duration of time until next lottery selection in seconds
    uint256 private immutable i_interval;
    uint256 private s_lastTimeStamp;
    address private s_recentWinner;
    // Chainlink VRF Variables
    VRFCoordinatorV2Interface private immutable i_vrfCoordinator;
    bytes32 private immutable i_keyHash; // gas lane
    uint64 private immutable i_subId;
    uint16 private constant REQUEST_CONFIRMATIONS = 3;
    uint32 private immutable i_callbackGasLimit;
    uint32 private constant NUM_WORDS = 1;

    /**   Events   */
    event RaffleEntered(address indexed player);
    event WinnerPicked(address indexed winner);
    event RequestedRaffleWinner(uint256 indexed requestId);

    /**   Modifiers   */

    /**   Functions   */
    constructor(
        address _vrfCoordinator,
        uint256 _entranceFee,
        uint256 _interval,
        bytes32 _keyHash,
        uint64 _subId,
        uint32 _callbackGasLimit
    ) VRFConsumerBaseV2(_vrfCoordinator) {
        i_entranceFee = _entranceFee;
        i_interval = _interval;
        s_lastTimeStamp = block.timestamp;
        i_vrfCoordinator = VRFCoordinatorV2Interface(_vrfCoordinator);
        i_keyHash = _keyHash;
        i_subId = _subId;
        i_callbackGasLimit = _callbackGasLimit;
        s_raffleState = RaffleState.Open;
    }

    function enterRaffle() public payable {
        if (msg.value < i_entranceFee) {
            revert Raffle__NotEnoughETH();
        }
        if (s_raffleState != RaffleState.Open) {
            revert Raffle__RaffleNotOpen();
        }
        s_players.push(payable(msg.sender));
        emit RaffleEntered(msg.sender);
    }

    /**
     * @dev This is the function that the Chainlink Automation nodes call
     * to see if its time to perform an upkeep
     * @dev The following must ALL be true for this function to return "true" (true it needs an upkeep)
     * 1. The time interval between raffle runs Has Passed
     * 2. The raffle is in the OPEN state
     * 3. This raffle contract has ETH (aka Players)
     * 4. (Implicit) The subscription is funded with LINK Tokens
     * @return upkeepNeeded = true if all the above is true. (upkeepNeeded = false if any are not true)
     */
    function checkUpkeep(
        bytes memory /* checkData */
    ) public view returns (bool upkeepNeeded, bytes memory /* performData */) {
        bool timePassed = (block.timestamp - s_lastTimeStamp) > i_interval;
        bool raffleOpen = s_raffleState == RaffleState.Open;
        bool hasBalance = address(this).balance > 0;
        bool hasPlayers = s_players.length > 0;
        upkeepNeeded = (timePassed && raffleOpen && hasBalance && hasPlayers);
        return (upkeepNeeded, "0x0");
    }

    // ChainlinkVRF requestRandomWords() is called here
    // This is the function to get ChainlinkVRF to get us a random number
    // Runs if checkUpkeep() is true
    // 1. Get a random number
    // 2. Use the random number to pick a player
    // 3. Be automatically called
    function performUpkeep(
        bytes memory /* performData */
    ) public returns (uint256 requestId) {
        (bool upkeepNeeded, ) = checkUpkeep("");
        if (!upkeepNeeded) {
            revert Raffle__UpkeepNotNeeded(
                uint256(s_raffleState),
                address(this).balance,
                s_players.length
            );
        }
        s_raffleState = RaffleState.Calculating; // close entries for raffle
        requestId = i_vrfCoordinator.requestRandomWords(
            i_keyHash,
            i_subId,
            REQUEST_CONFIRMATIONS,
            i_callbackGasLimit,
            NUM_WORDS
        );

        emit RequestedRaffleWinner(requestId);

        return requestId;
    }

    // vrfCoordinator will call this function after running pickWinner() and pass in random words
    // 1. Choose a number between 0 and the amount of players in the lottery, suing the random word and modulo
    // 2. Reveal the winner of the lottery
    // 3. Pay the winner the entire balance of the lottery (this smart contract balance)
    function fulfillRandomWords(
        uint256 /* requestId */,
        uint256[] memory _randomWords
    ) internal override {
        uint256 winningNumber = _randomWords[0] % s_players.length;
        address payable winner = s_players[winningNumber];
        s_recentWinner = winner;
        s_raffleState = RaffleState.Open; // open up the raffle again for new players
        s_players = new address payable[](0);
        s_lastTimeStamp = block.timestamp;

        // Pay the winner of the lottery
        (bool success, ) = s_recentWinner.call{value: address(this).balance}(
            ""
        );
        if (!success) {
            revert Raffle__TransferFailed();
        }

        emit WinnerPicked(winner);
    }

    //
    //
    //
    //
    //
    /**   Getter Functions   */
    function getEntrancFee() external view returns (uint256) {
        return i_entranceFee;
    }

    function getPlayer(uint256 index) external view returns (address) {
        return s_players[index];
    }

    function getPlayersArray()
        external
        view
        returns (address payable[] memory)
    {
        return s_players;
    }

    function getPlayersArrayLength() external view returns (uint256) {
        return s_players.length;
    }

    function getRecentWinner() external view returns (address) {
        return s_recentWinner;
    }

    function getRaffleState() external view returns (RaffleState) {
        return s_raffleState;
    }

    function getLastTimeStamp() external view returns (uint256) {
        return s_lastTimeStamp;
    }
}
