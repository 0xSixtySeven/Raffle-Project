// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

import {Script} from "forge-std/Script.sol";
import {VRFCoordinatorV2Mock} from "@chainlink/contracts/src/v0.8/mocks/VRFCoordinatorV2Mock.sol";
import {LinkToken} from "../test/mocks/LinkToken.t.sol";

contract HelperConfig is Script {
    struct NetworkConfig {
        // here we put the variables that we want to pass to the constructor
        uint256 entranceFee;
        uint256 interval;
        address vrfCoordinator;
        uint64 subscriptionId;
        uint32 callbackGasLimit;
        bytes32 gasLane;
        address link;
        uint256 deployerKey;
    }

    uint256 public constant ANVIL_PRIVATE_KEY =
        0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;
    NetworkConfig public activeNetworkConfig; // this is a state variable that we can access from other contracts.

    constructor() {
        if (block.chainid == 11155111) {
            activeNetworkConfig = getSepoliaEthConfig();
        } else {
            activeNetworkConfig = getOrCreateAnvilEthConfig();
        }
    }

    function getSepoliaEthConfig() public view returns (NetworkConfig memory) {
        return
            NetworkConfig({
                entranceFee: 0.1 ether,
                interval: 30,
                vrfCoordinator: 0x8103B0A8A00be2DDC778e6e7eaa21791Cd364625,
                subscriptionId: 0, // : add subscription ID, with our subId
                callbackGasLimit: 500000,
                gasLane: 0x474e34a077df58807dbe9c96d3c009b23b3c6d0cce433e59bbf5b34f823bc56c,
                link: 0x779877A7B0D9E8603169DdbD7836e478b4624789,
                deployerKey: vm.envUint("PRIVATE_KEY") // vm.envUint is a function that we can use to access the private key that we set in the .env file
            });
    }

    function getOrCreateAnvilEthConfig() public returns (NetworkConfig memory) {
        // as this need to make a transaction in mock, we need to make it public. We cant use pure or view here
        if (activeNetworkConfig.vrfCoordinator != address(0)) {
            return activeNetworkConfig;
        }

        uint96 baseFee = 0.25 ether; // 0.25 Link
        uint96 gasPriceLink = 1e9; // 1 Gwei

        vm.startBroadcast();

        VRFCoordinatorV2Mock vrfCoordinatorMock = new VRFCoordinatorV2Mock(
            baseFee,
            gasPriceLink
        );
        LinkToken linkToken = new LinkToken();
        vm.stopBroadcast();

        return
            NetworkConfig({
                entranceFee: 0.1 ether,
                interval: 30,
                vrfCoordinator: address(vrfCoordinatorMock),
                subscriptionId: 0, // our script will add this later
                callbackGasLimit: 500000,
                gasLane: 0x474e34a077df58807dbe9c96d3c009b23b3c6d0cce433e59bbf5b34f823bc56c,
                link: address(linkToken),
                deployerKey: ANVIL_PRIVATE_KEY
            });
    }
}
