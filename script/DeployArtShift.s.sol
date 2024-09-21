// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {Script} from "forge-std/Script.sol";
import {ArtShift} from "../src/ArtShift.sol";
import {HelperConfig} from "./HelperConfig.s.sol";
import {CreateSubscription, FundSubscription, AddConsumer} from "./Interactions.s.sol";

contract DeployArtShift is Script {
    string[] public artShiftUris = [
        "https://ipfs.io/ipfs/QmYaDcC1nCpNeQzoEF2tQz7gyu1WqpKKtZfZyK6cP3fcDR?filename=ArtShift-001.json",
        "https://ipfs.io/ipfs/QmXaY8u2csuYBD2dQMsKu5kHPJGK7zWoTnhfNtcGYRa6Xq?filename=ArtShift-002.json",
        "https://ipfs.io/ipfs/QmWh39jqJDR2gxwgYRbrJCev16scwmv1dcQE6cjrXkisDR?filename=ArtShift-003.json",
        "https://ipfs.io/ipfs/QmWvMoSHxnpjDewh7pYfu9rRCypnV4Q9cWYs5dgasmhvk5?filename=ArtShift-004.json",
        "https://ipfs.io/ipfs/QmZVHFbsPpe2hS8y3igNLqM4eV3mo4XvGe1JdHgHhDC92F?filename=ArtShift-005.json"
    ];

    function run() external returns (ArtShift, HelperConfig) {
        HelperConfig helper = new HelperConfig();
        AddConsumer addConsumer = new AddConsumer();
        (
            uint256 subscriptionId,
            address vrfCoordinator,
            uint32 callbackGasLimit,
            bytes32 keyHash,
            address link,
            uint256 deployerKey
        ) = helper.activeNetworkConfig();

        if (subscriptionId == 0) {
            // CreateSubscription
            CreateSubscription createSubscription = new CreateSubscription();
            (vrfCoordinator, subscriptionId) = createSubscription.createSubscription(vrfCoordinator, deployerKey);

            // Fund it
            FundSubscription fundSubscription = new FundSubscription();
            fundSubscription.fundSubscription(vrfCoordinator, subscriptionId, link, deployerKey);
        }

        vm.startBroadcast(deployerKey);
        ArtShift artShift = new ArtShift(artShiftUris, subscriptionId, vrfCoordinator, callbackGasLimit, keyHash);
        vm.stopBroadcast();

        // Add consumer
        addConsumer.addConsumer(address(artShift), vrfCoordinator, subscriptionId, deployerKey);

        return (artShift, helper);
    }
}
