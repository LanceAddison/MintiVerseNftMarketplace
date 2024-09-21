// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {Script} from "forge-std/Script.sol";
import {VRFCoordinatorV2_5Mock} from "@chainlink/contracts/vrf/mocks/VRFCoordinatorV2_5Mock.sol";
import {LinkToken} from "../test/mocks/LinkToken.sol";

contract HelperConfig is Script {
    struct NetworkConfig {
        uint256 subscriptionId;
        address vrfCoordinator;
        uint32 callbackGasLimit;
        bytes32 keyHash;
        address link;
        uint256 deployerKey;
    }

    NetworkConfig public activeNetworkConfig;
    VRFCoordinatorV2_5Mock public vrfCoordinatorMock;

    constructor() {
        if (block.chainid == 11155111) {
            activeNetworkConfig = getSepoliaEthConfig();
        } else {
            activeNetworkConfig = getOrCreateAnvilEthConfig();
        }
    }

    function getSepoliaEthConfig() public view returns (NetworkConfig memory) {
        return NetworkConfig({
            subscriptionId: 98413950849193634705921691051523939907023850956356862350586104453608289414966,
            vrfCoordinator: 0x9DdfaCa8183c41ad55329BdeeD9F6A8d53168B1B,
            callbackGasLimit: 500000,
            keyHash: 0x787d74caea10b2b357790d5b5247c2f63d1d91572a9846f780606e4d953677ae,
            link: 0x779877A7B0D9E8603169DdbD7836e478b4624789,
            deployerKey: vm.envUint("PRIVATE_KEY")
        });
    }

    function getOrCreateAnvilEthConfig() public returns (NetworkConfig memory) {
        if (activeNetworkConfig.vrfCoordinator != address(0)) {
            return activeNetworkConfig;
        }

        int256 weiPerUnitLink = 4289527751874512;
        uint96 baseFee = uint96((0.25 ether * uint256(weiPerUnitLink)) / 1e18); // 0.25 LINK
        // uint96 baseFee = 0.25 ether;
        uint96 gasPriceLink = 1e9;

        vm.startBroadcast();
        vrfCoordinatorMock = new VRFCoordinatorV2_5Mock(baseFee, gasPriceLink, weiPerUnitLink);
        LinkToken link = new LinkToken();
        vm.stopBroadcast();

        return NetworkConfig({
            subscriptionId: 0,
            vrfCoordinator: address(vrfCoordinatorMock),
            callbackGasLimit: 100000,
            keyHash: 0x474e34a077df58807dbe9c96d3c009b23b3c6d0cce433e59bbf5b34f823bc56c,
            link: address(link),
            deployerKey: vm.envUint("ANVIL_DEFAULT_KEY")
        });
    }
}
