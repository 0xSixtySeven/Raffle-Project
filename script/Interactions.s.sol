// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

import {Script, console} from "forge-std/Script.sol";
import {HelperConfig} from "./HelperConfig.s.sol";
import {VRFCoordinatorV2Mock} from "@chainlink/contracts/src/v0.8/mocks/VRFCoordinatorV2Mock.sol";
import {LinkToken} from "../test/mocks/LinkToken.t.sol";
import {DevOpsTools} from "lib/foundry-devops/src/DevOpsTools.sol";
import {Raffle} from "../src/Raffle.sol";

contract CreateSubscription is Script {
    function createSubscriptionUsingConfig() public returns (uint64) {
        // WHEN WE MAKE A TRANSACTION TO METAMASK, IN THE "HEX DATA" WE CAN SEE THE FUNCTION THAT IS CALLING. IF WE KNOW WHAT FUNCTION IS CALLING, WE CAN USE cast sig "funtion name()" AND IT WILL RETURN THE HEX
        // IF WE DONT KNOW WHAT FUNCTION ITS CALLING, WE CAN DECRYPT THE HEX TO KNOW IN: https://openchain.xyz/signatures
        // as this need to make a transaction in mock, we need to make it public. We cant use pure or view here
        HelperConfig helperConfig = new HelperConfig();
        (, , address vrfCoordinator, , , , , uint256 deployerKey) = helperConfig
            .activeNetworkConfig();
        return createSubscription(vrfCoordinator, deployerKey);
    }

    function createSubscription(
        address vrfCoordinator,
        uint256 deployerKey
    ) public returns (uint64) {
        console.log("Creatingsubscription on Chainid: ", block.chainid);
        vm.startBroadcast(deployerKey);
        uint64 subscriptionId = VRFCoordinatorV2Mock(vrfCoordinator)
            .createSubscription();
        vm.stopBroadcast();
        console.log("Your sub Id is: ", subscriptionId);
        console.log("Please update subscriptionId in HelperConfig.s.sol");
        return subscriptionId;
    }

    function run() external returns (uint64) {
        return createSubscriptionUsingConfig();
    }
}

contract FundSubscription is Script {
    uint96 public constant FUND_AMOUNT = 3 ether;

    function fundSubscriptionUsingConfig() public {
        HelperConfig helperConfig = new HelperConfig();
        (
            ,
            ,
            address vrfCoordinator,
            uint64 subscriptionId, // we need to pass the subscription ID to the function
            ,
            ,
            address link,
            uint256 deployerKey
        ) = helperConfig.activeNetworkConfig();
        fundSubscription(vrfCoordinator, subscriptionId, link, deployerKey);
    }

    function fundSubscription(
        address vrfCoordinator,
        uint64 subscriptionId,
        address link,
        uint256 deployerKey
    ) public {
        console.log("Funding subscription: ", subscriptionId);
        console.log("Using vrfCoodinator", vrfCoordinator);
        console.log("On ChainID: ", block.chainid);
        if (block.chainid == 31337) {
            vm.startBroadcast(deployerKey);
            VRFCoordinatorV2Mock(vrfCoordinator).fundSubscription(
                subscriptionId,
                FUND_AMOUNT
            );
            vm.stopBroadcast();
        } else {
            vm.startBroadcast(deployerKey);
            LinkToken(link).transferAndCall(
                vrfCoordinator,
                FUND_AMOUNT,
                abi.encode(subscriptionId)
            );
            vm.stopBroadcast();
        }
    }

    function run() external {
        fundSubscriptionUsingConfig();
    }
}

contract AddConsumer is Script {
    function addConsumer(
        address raffle,
        address vrfCoordinator,
        uint64 subscriptionId,
        uint256 deployerKey
    ) public {
        console.log("Adding consumer to raffle: ", raffle);
        console.log("Using vrfCoodinator", vrfCoordinator);
        console.log("On ChainID: ", block.chainid);

        vm.startBroadcast(deployerKey); // whe we start the broadcast, we need to pass the private key of the deployer, so that we can sign the transaction to add the consumer(add.Consumer)
        VRFCoordinatorV2Mock(vrfCoordinator).addConsumer(
            subscriptionId,
            raffle
        );
        vm.stopBroadcast();
    }

    function addConsumerUsingConfig(address raffle) public {
        HelperConfig helperConfig = new HelperConfig();
        (
            ,
            ,
            address vrfCoordinator,
            uint64 subscriptionId,
            ,
            ,
            ,
            uint256 deployerKey
        ) = helperConfig.activeNetworkConfig();
        addConsumer(raffle, vrfCoordinator, subscriptionId, deployerKey);
    }

    function run() external {
        address raffle = DevOpsTools.get_most_recent_deployment(
            "raffle",
            block.chainid
        );
        addConsumerUsingConfig(raffle);
    }
}
