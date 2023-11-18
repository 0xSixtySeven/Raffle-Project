// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

import {VRFCoordinatorV2Interface} from "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import {VRFConsumerBaseV2} from "@chainlink/contracts/src/v0.8/vrf/VRFConsumerBaseV2.sol";

/**
 * @title A Sample Raffle Contract
 * @author Miguel de los Rios
 * @notice This contract if for creating a sample raffle
 * @dev Implementing Chainlink VRFv2 for random number generation
 */

contract Raffle is VRFConsumerBaseV2 {
    error Raffle__NotEnoughETHSent();
    error Raffle__TrasferFailed();
    error Raffle__TrasferNotOpen();
    error Raffle__upkeepNotNeeded(
        uint256 currentBalance,
        uint256 numPlayers,
        uint256 raffleState
    ); // this is how we can pass variables to the error message

    /** Type Declarations */
    enum RaffleState {
        // this is a custom data type that we are creating to keep track of the state of the raffle (this is a good practice)
        ENTRANCE_OPEN, // 0
        RAFFLE_IN_PROGRESS // 1
    }

    /**State Variables */
    uint16 private constant REQUEST_CONFIRMATIONS = 3; // @dev How many nodes we want to verify the random number, the higher the number, the safer it is but the more expensive it is
    uint32 private constant NUM_WORDS = 1; // @dev How many random numbers we want to generate

    uint256 private immutable i_entranceFee; // state variable (immutable)  - cheaper than local variable
    uint256 private immutable i_interval; // @dev How long the raffle will last
    uint64 private immutable i_subscriptionId; // @dev Chainlink VRF Subscription ID
    VRFCoordinatorV2Interface private immutable i_vrfCoordinator; // @dev Chainlink VRF Coordinator address
    bytes32 private immutable i_gasLane; // @dev Chainlink VRF Gas Lane address. KeyHash = Gas Lane
    uint32 private immutable i_callbackGasLimit; // @dev Chainlink VRF Callback Gas Limit, the maximum of gas we want to pay when we call the function to pay the winner

    uint256 private s_lastTimeStamp;
    address payable[] private s_players;
    address payable private s_recentWinner;
    RaffleState private s_raffleState;

    event EnteredRaffle(address indexed players);
    event PickedWinner(address indexed winner);
    event RequestedRaffleWinner(uint256 indexed requestId);

    constructor(
        uint256 entranceFee,
        uint256 interval,
        address vrfCoordinator,
        uint64 subscriptionId,
        uint32 callbackGasLimit,
        bytes32 gasLane
    ) VRFConsumerBaseV2(vrfCoordinator) {
        i_entranceFee = entranceFee;
        i_interval = interval;
        i_vrfCoordinator = VRFCoordinatorV2Interface(vrfCoordinator);
        i_gasLane = gasLane;
        i_subscriptionId = subscriptionId;
        i_callbackGasLimit = callbackGasLimit;
        s_lastTimeStamp = block.timestamp; // block.timeStamp is a global variable that gives you the time stamp of the block
        s_raffleState = RaffleState.ENTRANCE_OPEN;
    }

    // external vs public (external is cheaper)
    function enterRaffle() external payable {
        // require(msg.value >= i_entranceFee, "Not enough ETH sent")   // this is how it used to be done but is more gas expensive
        if (msg.value < i_entranceFee) {
            revert Raffle__NotEnoughETHSent(); // revert is cheaper than require
        }
        if (s_raffleState != RaffleState.ENTRANCE_OPEN) {
            revert Raffle__TrasferNotOpen();
        }

        s_players.push(payable(msg.sender)); // we need to put payable here because msg.sender is not payable by default, so for us to be able to push it into the array, we need to make it payable
        emit EnteredRaffle(msg.sender); // this will emit the event of the player entering the raffle (this is a good practice)
    }

    /**
     * @dev This function is called by the Chainlink VRF node to fulfill the randomness request
     * to see if its time to perform the upKeep
     * the following should be true for this to return true:
     * 1. The time interval has passed since the last time the winner was picked
     * 2. the raffle is in ENTRANCE_OPEN state
     * 3. The contract has players in the array (s_players). ETH has been sent to the contract
     * 4. The subscription is funded with LINK
     */
    function checkUpKeep(
        //checkData is an input parameter that we can use to pass data to the function, we are not going to use it in this case
        bytes memory /*checkData*/
    ) public view returns (bool upKeepNeeded, bytes memory /*performData*/) {
        // we can name our variables in the return statement, in this case we are not going to use the performData variable
        bool timeHasPassed = (block.timestamp - s_lastTimeStamp) >= i_interval; // this will return true if the time interval has passed
        bool isOpen = RaffleState.ENTRANCE_OPEN == s_raffleState; // this will return true if the raffle is in ENTRANCE_OPEN state
        bool hasBalance = address(this).balance > 0; // this will return true if the contract has ETH
        bool hasPlayers = s_players.length > 0; // this will return true if the contract has players
        upKeepNeeded = (timeHasPassed && isOpen && hasBalance && hasPlayers); // this will return true if all the conditions are true. && is the AND operator that means that if and of the variables are false it will invalidate everything.
        return (upKeepNeeded, ""); // this is the return of the function, if there is no data to return, we can just return an empty string
    }

    // checkUpKeep is a view function so it will not cost any gas because it is simulating if the conditions are true, so we can call the performUpKeep function.

    function performUpKeep(bytes calldata /* performData */) external {
        (bool upKeepNeeded, ) = checkUpKeep(""); // we are calling the checkUpKeep function to see if the conditions are true
        if (!upKeepNeeded) {
            revert Raffle__upkeepNotNeeded(
                address(this).balance,
                s_players.length,
                uint256(s_raffleState)
            );
        }
        s_raffleState = RaffleState.RAFFLE_IN_PROGRESS;

        uint256 requestId = i_vrfCoordinator.requestRandomWords(
            i_gasLane, // with this we can specify the amount of gas we want to use // KeyHash = Gas Lane
            i_subscriptionId,
            REQUEST_CONFIRMATIONS,
            i_callbackGasLimit,
            NUM_WORDS
        );

        emit RequestedRaffleWinner(requestId); // events are not read from inside the contract so we need to emit them to be able to read them
    }

    // CEI = Check-Effects-Interactions (this is a good practice to follow) its a safer way to avoid some kind of attacks.
    function fulfillRandomWords(
        // Checks (Conditions) - Check if the request is valid and if the random number is valid
        // Effects (State Changes) - Change the state of the contract (who is the winner, who is the players, etc)
        uint256 /*requestId*/,
        uint256[] memory randomWords
    ) internal override {
        uint256 indexOfWinner = randomWords[0] % s_players.length; // this will give us the index of the winner
        address payable winner = s_players[indexOfWinner];
        s_recentWinner = winner;
        s_raffleState = RaffleState.ENTRANCE_OPEN;
        s_players = new address payable[](0); // this will create a new array with 0 elements
        s_lastTimeStamp = block.timestamp; // we need to update the lastTimeStamp so we can start a new raffle
        emit PickedWinner(winner); // this will emit the event of the winner, its better to put this before the interaction because if the interaction fails, the event will not be emitted
        // Interactions(with other contracts)
        (bool success, ) = winner.call{value: address(this).balance}(""); // this is how we can send ETH to the winner
        if (!success) {
            revert Raffle__TrasferFailed();
        }
    }

    /** Getter Function */

    function getEntranceFee() external view returns (uint256) {
        // difference of view vs pure is that view can read state variables and pure cannot - so if you need to read state variables, use view
        // view is cheaper than pure
        return i_entranceFee;
    }

    function getRaffleState() external view returns (RaffleState) {
        return s_raffleState;
    }

    function getPlayer(uint256 indexOfPlayer) external view returns (address) {
        return s_players[indexOfPlayer];
    }

    function getRaffleWinner() external view returns (address) {
        return s_recentWinner;
    }

    function getResetPlayers() external view returns (uint256) {
        return s_players.length;
    }

    function getLastTimeStamp() external view returns (uint256) {
        return s_lastTimeStamp;
    }
}
