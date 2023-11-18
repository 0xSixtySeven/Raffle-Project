// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

import {DeployRaffle} from "../../script/DeployRaffle.s.sol";
import {Raffle} from "../../src/Raffle.sol";
import {Test, console} from "forge-std/Test.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {Vm} from "forge-std/Vm.sol";
import {VRFCoordinatorV2Mock} from "@chainlink/contracts/src/v0.8/mocks/VRFCoordinatorV2Mock.sol";

contract RaffleTest is Test {
    /// EVENTS
    event EnteredRaffle(address indexed player);

    Raffle raffle; // this is a state variable that we can access from other contracts.
    HelperConfig helperConfig;

    // STATE VARIABLES
    uint256 entranceFee;
    uint256 interval;
    address vrfCoordinator;
    uint64 subscriptionId;
    uint32 callbackGasLimit;
    bytes32 gasLane;
    address link;

    address public PLAYER = makeAddr("player"); // makeAddr is a function that we can use to create a new address
    uint256 public constant STARTING_USER_BALANCE = 10 ether;

    function setUp() external {
        DeployRaffle deployer = new DeployRaffle();
        (raffle, helperConfig) = deployer.run(); // this is how we can access the return values from the script
        vm.deal(PLAYER, STARTING_USER_BALANCE); // with vm.deal we can give ether to an address (in this case PLAYER). STARTING_USER_BALANCE is defined in the state variables
        (
            entranceFee,
            interval,
            vrfCoordinator,
            subscriptionId,
            callbackGasLimit,
            gasLane,
            link,

        ) = helperConfig.activeNetworkConfig();
    }

    function testRaffleInitilizesInOpenState() public view {
        assert(raffle.getRaffleState() == Raffle.RaffleState.ENTRANCE_OPEN);
    }

    ///////////////////////////////
    //////// enter_Raffle /////////
    ///////////////////////////////

    function testRaffleRevertsWhenYouDontPayEnough() public {
        // ARANGE
        vm.prank(PLAYER);
        // ACT // ASSERT
        vm.expectRevert(Raffle.Raffle__NotEnoughETHSent.selector); // selector is the function signature of the error message that we want to expect to revert
        raffle.enterRaffle();
    }

    function testRaffleStoresPlayersWhenTheyEnter() public {
        // ARANGE
        vm.prank(PLAYER);
        // ACT // ASSERT
        raffle.enterRaffle{value: entranceFee}();
        address playerRecorded = raffle.getPlayer(0);
        if (playerRecorded != PLAYER) {
            revert();
        }
    }

    function testEmitsEventsOnEntrance() public {
        vm.prank(PLAYER);
        // expectEmit is a function that we can use to check if an event was emitted: with this structure:
        // function expectEmit(
        //     bool checkTopic1, // in checkTopic we only put the indexed variables of the event
        //     bool checkTopic2,
        //     bool checkTopic3,
        //     bool checkData,
        //     address emitter
        // ) external;
        /// we cant import events from other contracts, so we need to create a mock event here(redifine it)
        vm.expectEmit(true, false, false, false, address(raffle)); // the 4th (checkData) will be false aswell because we are not passing any data.
        emit EnteredRaffle(PLAYER); // after vm.expectEmit we need to emit the event, this emit will be run in the transaction.
        raffle.enterRaffle{value: entranceFee}(); // after the emit we run the transaction where the event is emitted
    }

    function testCantEnterWhenRaffleIsCalculating() public {
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
        vm.warp(block.timestamp + interval + 1); // vm.warp function (it is a function that we can use to move the block.timestamp forward)
        vm.roll(block.number + 1); // vm.roll this is a function that we can use to move the block.number forward
        raffle.performUpKeep(""); // this will change the state of the contract to RAFFLE_IN_PROGRESS

        vm.expectRevert(Raffle.Raffle__TrasferNotOpen.selector); // selector is the function signature of the error message that we want to expect to revert
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
    }

    ///////////////////////////////
    ///////checkUpKeep/////////////
    ///////////////////////////////

    function testCheckUpKeepReturnsFalseIfItHasNoBalance() public {
        vm.warp(block.timestamp + interval + 1); // vm.warp function (it is a function that we can use to move the block.timestamp forward)
        vm.roll(block.number + 1); // vm.roll this is a function that we can use to move the block.number forward

        (bool upKeepNeeded, ) = raffle.checkUpKeep("");
        assert(!upKeepNeeded);
    }

    // function testCheckUpKeepReturnsFalseIfRaffleIsNotOpen() public {
    //     vm.prank(PLAYER);
    //     raffle.enterRaffle{value: entranceFee}();
    //     vm.roll(block.number + 1); // vm.roll this is a function that we can use to move the block.number forward
    //     vm.warp(block.timestamp + interval - 1);
    //     (bool upkeepNeeded, ) = raffle.checkUpKeep("");
    //     assert(!upkeepNeeded);

    function testCheckUpKeepReturnsFalseIfRaffleIsNotOpen() public {
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
        vm.warp(block.timestamp + interval + 1); // vm.warp function (it is a function that we can use to move the block.timestamp forward)
        vm.roll(block.number + 1); // vm.roll this is a function that we can use to move the block.number forward
        raffle.performUpKeep(""); // this will change the state of the contract to RAFFLE_IN_PROGRESS

        (bool upKeepNeeded, ) = raffle.checkUpKeep("");
        assert(upKeepNeeded == false);
    }

    // CHALLENGE to do this tests, the code is in the repo.
    // function testCheckUpKeepReturnsFalseIfEnoughTimeHasntPassed() public {}
    // function testCheckUpkeepReturnsTrueWhenParametersAreGood() public{}

    ///////////////////////////////
    ///////performUpKeep///////////
    ///////////////////////////////

    function testPerformUpkeepCanOnlyRunIfCheckUpkeepIsTrue() public {
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
        vm.warp(block.timestamp + interval + 1); // vm.warp function (it is a function that we can use to move the block.timestamp forward)
        vm.roll(block.number + 1); // vm.roll this is a function that we can use to move the block.number forward

        raffle.performUpKeep(""); // this will change the state of the contract to RAFFLE_IN_PROGRESS
    }

    function testPerformUpkeepRevertsIfCheckUpkeepIsFalse() public {
        //ARANGE
        uint256 currentBalance = 0; //!!!!!!!! RECHECK LATER WHY I HAD TO CHANGE THIS VALUE TO 4e16 WHICH IS THE ACTUALL BALANCE OF THE CONTRACT, INSTEAD OF 0. THIS IS BECAUSE THE CHECKUPKEEP FUNCTION IS CHECKING IF THE CONTRACT HAS BALANCE, AND IF IT DOESNT, IT WILL REVERT
        uint256 numPlayers = 0;
        uint256 raffleState = 0;

        //ACT //ASSERT
        vm.expectRevert( // this is how we can expect a revert from a function, in this case we are expecting to fail raffle.performUpKeep(""); and we are expecting the error message to be Raffle__upkeepNotNeeded, considering all the paramenters inside the expectRevert function
            abi.encodeWithSelector(
                Raffle.Raffle__upkeepNotNeeded.selector,
                currentBalance,
                numPlayers,
                raffleState
            )
        ); // selector is the function signature of the error message that we want to expect to revert
        raffle.performUpKeep(""); // this will change the state of the contract to RAFFLE_IN_PROGRESS
    }

    modifier raffleEnteredAndTimePassed() {
        // we place the modifer after the function name and before the curly brackets, in this case after public
        // we have used this variables in various tests, so we are going to create a modifier to reuse them and minimize lines of code
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
        vm.warp(block.timestamp + interval + 1); // vm.warp function (it is a function that we can use to move the block.timestamp forward)
        vm.roll(block.number + 1);
        _;
    }

    function testPerformUpkeepUpdatesRaffleStateAndEmitsRequest()
        public
        raffleEnteredAndTimePassed
    {
        //ACT //ASSERT
        vm.recordLogs();
        raffle.performUpKeep("");
        Vm.Log[] memory entries = vm.getRecordedLogs(); // all logs are recorded as bytes32 in foundry, so we need to convert them to Vm.Log
        bytes32 requestId = entries[1].topics[1];

        Raffle.RaffleState rState = raffle.getRaffleState(); // we are getting the raffle state after the performUpKeep function has been called

        assert(uint256(requestId) > 0); // this is how we can check if the requestId is greater than 0
        assert(uint256(rState) == 1);
    }

    modifier skipFork() {
        if (block.chainid != 31337) {
            return;
        }
        _;
    }

    function testFullfulRandomWordsCanOnlyBeCalledAfterPerformUpkeep(
        // Fuzz testing, this tests are used to check for all random possibilities that can happen in a function. This is really important for security reasons
        // instead of making a lot of tests functions, we can use this function to check for all the possibilities in only 1 function. In this case we change the number of the requested Id for the Fuzz testing(randomRequestId)
        uint256 randomRequestId
    ) public raffleEnteredAndTimePassed skipFork {
        // @remind skipFork is not the best way to fix the two errors that forge test with $SEPOLIA_RPC_URL
        vm.expectRevert("nonexistent request");
        VRFCoordinatorV2Mock(vrfCoordinator).fulfillRandomWords(
            randomRequestId,
            address(raffle)
        );
    }

    function testFulfillWordsPicksAWinnerResetsAndPays()
        public
        raffleEnteredAndTimePassed
        skipFork // @remind SkipFork-Not the best way
    {
        // ARANGE
        uint256 additionalEntrants = 5;
        uint256 startingIndex = 1;
        for (
            uint256 i = startingIndex;
            i < startingIndex + additionalEntrants;
            i++ // i++ is the same as i = i + 1
        ) {
            address player = address(uint160(i)); // we are converting the uint256 to an address payable (uint160) and then to an address. This is because the array is an array of addresses payable
            hoax(player, STARTING_USER_BALANCE); // hoax is vm.prank + vm.deal. creats a new address and gives it ether
            raffle.enterRaffle{value: entranceFee}();
        }

        uint256 prize = entranceFee * (additionalEntrants);

        vm.recordLogs();
        raffle.performUpKeep(""); // emit requestId
        Vm.Log[] memory entries = vm.getRecordedLogs(); // Vm.log always counts in bytes32
        bytes32 requestId = entries[1].topics[1];

        uint256 previousTimeStamp = raffle.getLastTimeStamp();

        // now we need to pretend to be chainlink vrf to get a random number and pick a winner.
        VRFCoordinatorV2Mock(vrfCoordinator).fulfillRandomWords(
            uint256(requestId),
            address(raffle)
        );

        assert(uint256(raffle.getRaffleState()) == 0); // this is how we can check if the raffle state is 0 (ENTRANCE_OPEN)
        assert(raffle.getRaffleWinner() != address(0));
        assert(raffle.getResetPlayers() == 0);
        assert(raffle.getLastTimeStamp() > previousTimeStamp); // this is how we can check if the lastTimeStamp is less than the current block.timestamp )
        assert(
            raffle.getRaffleWinner().balance == prize + STARTING_USER_BALANCE
        );
    }
}
