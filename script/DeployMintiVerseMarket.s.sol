// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {Script, console} from "forge-std/Script.sol";
import {HelperConfig} from "./HelperConfig.s.sol";
import {DeployArtShift} from "./DeployArtShift.s.sol";
import {ArtShift} from "../src/ArtShift.sol";
import {MintiVerseMarket} from "../src/MintiVerseMarket.sol";
// import {DevOpsTools} from "foundry-devops/src/DevOpsTools.sol";

contract DeployMintiVerseMarket is Script {
    ArtShift artShift;
    MintiVerseMarket mintiVerse;
    HelperConfig helper;

    function run() external returns (ArtShift, MintiVerseMarket, HelperConfig) {
        DeployArtShift deployer = new DeployArtShift();
        (artShift, helper) = deployer.run();

        (,,,,, uint256 deployerKey) = helper.activeNetworkConfig();

        vm.startBroadcast(deployerKey);
        mintiVerse = new MintiVerseMarket(address(artShift));
        vm.stopBroadcast();

        return (artShift, mintiVerse, helper);
    }
}
