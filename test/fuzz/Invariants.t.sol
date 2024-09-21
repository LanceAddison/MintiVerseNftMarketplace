// SPDX-license-Identifier: MIT
pragma solidity ^0.8.25;

import {Test, console} from "forge-std/Test.sol";
import {StdInvariant} from "forge-std/StdInvariant.sol";
import {ArtShift} from "../../src/ArtShift.sol";
import {DeployArtShift} from "../../script/DeployArtShift.s.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {Handler} from "./Handler.t.sol";

contract Invaritants is StdInvariant, Test {
    ArtShift artShift;
    HelperConfig helper;
    Handler handler;

    function setUp() external {
        DeployArtShift deployer = new DeployArtShift();
        (artShift, helper) = deployer.run();

        handler = new Handler(artShift, helper);
        targetContract(address(handler));
    }

    function invariant_randomizeArtMustAlwaysHaveDifferentTokenUriAfterwards() public view {
        assert(
            keccak256(abi.encodePacked(handler.tokenUriBefore)) != keccak256(abi.encodePacked(handler.tokenUriAfter))
        );
    }
}
