// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {Script, console} from "forge-std/Script.sol";
import {HelperConfig} from "./HelperConfig.s.sol";
import {VRFCoordinatorV2_5Mock} from "@chainlink/contracts/vrf/mocks/VRFCoordinatorV2_5Mock.sol";
import {LinkToken} from "../test/mocks/LinkToken.sol";
import {DevOpsTools} from "foundry-devops/src/DevOpsTools.sol";

contract CreateSubscription is Script {
    function createSubscriptionUsingConfig() public returns (address, uint256) {
        HelperConfig helper = new HelperConfig();
        (, address vrfCoordinator,,,, uint256 deployerKey) = helper.activeNetworkConfig();
        return createSubscription(vrfCoordinator, deployerKey);
    }

    function createSubscription(address vrfCoordinator, uint256 deployerKey) public returns (address, uint256) {
        console.log("Creating subscription on ChainId: ", block.chainid);
        vm.startBroadcast(deployerKey);
        uint256 subscriptionId = VRFCoordinatorV2_5Mock(vrfCoordinator).createSubscription();
        vm.stopBroadcast();
        console.log("Your subscriptionId is: ", subscriptionId);
        console.log("Please update subscriptionId in HelperConfig.s.sol");
        return (vrfCoordinator, subscriptionId);
    }

    function run() external returns (address, uint256) {
        return createSubscriptionUsingConfig();
    }
}

contract FundSubscription is Script {
    uint96 public constant FUND_AMOUNT = 100 ether; // 100 LINK

    function fundSubscriptionUsingConfig() public {
        HelperConfig helper = new HelperConfig();
        (uint256 subscriptionId, address vrfCoordinator,,, address link, uint256 deployerKey) =
            helper.activeNetworkConfig();

        if (subscriptionId == 0) {
            CreateSubscription createSub = new CreateSubscription();
            (address updatedVRFv2_5, uint256 updatedSubId) = createSub.run();
            vrfCoordinator = updatedVRFv2_5;
            subscriptionId = updatedSubId;
            console.log("New subscriptionId created! ", subscriptionId, "VRF address: ", vrfCoordinator);
        }

        fundSubscription(vrfCoordinator, subscriptionId, link, deployerKey);
    }

    function fundSubscription(address vrfCoordinator, uint256 subscriptionId, address link, uint256 deployerKey)
        public
    {
        console.log("Funding subscription: ", subscriptionId);
        console.log("Using vrfCoordinator: ", vrfCoordinator);
        console.log("On ChainId: ", block.chainid);
        if (block.chainid == 31337) {
            vm.startBroadcast(deployerKey);
            VRFCoordinatorV2_5Mock(vrfCoordinator).fundSubscription(subscriptionId, FUND_AMOUNT);
            vm.stopBroadcast();
        } else {
            vm.startBroadcast(deployerKey);
            LinkToken(link).transferAndCall(vrfCoordinator, FUND_AMOUNT, abi.encode(subscriptionId));
            vm.stopBroadcast();
        }
    }

    function run() external {
        fundSubscriptionUsingConfig();
    }
}

contract AddConsumer is Script {
    function addConsumer(address artShift, address vrfCoordinator, uint256 subscriptionId, uint256 deployerKey)
        public
    {
        console.log("Adding consumer contract: ", artShift);
        console.log("Using vrfCoordinator: ", vrfCoordinator);
        console.log("On ChainId: ", block.chainid);
        vm.startBroadcast(deployerKey);
        VRFCoordinatorV2_5Mock(vrfCoordinator).addConsumer(subscriptionId, artShift);
        vm.stopBroadcast();
    }

    function addConsumerUsingConfig(address artShift) public {
        HelperConfig helper = new HelperConfig();
        (uint256 subscriptionId, address vrfCoordinator,,,, uint256 deployerKey) = helper.activeNetworkConfig();
        addConsumer(artShift, vrfCoordinator, subscriptionId, deployerKey);
    }

    function run() external {
        address artShift = DevOpsTools.get_most_recent_deployment("ArtShift", block.chainid);
        addConsumerUsingConfig(artShift);
    }
}
