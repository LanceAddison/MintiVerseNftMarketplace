// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {Test, console} from "forge-std/Test.sol";
import {ArtShift} from "../../src/ArtShift.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";

contract Handler is Test {
    ArtShift artShift;
    HelperConfig helper;

    address public BOB = makeAddr("bob");
    uint256 public constant STARTING_USER_BALANCE = 10 ether;

    string public tokenUriBefore;
    string public tokenUriAfter;

    constructor(ArtShift _artShift, HelperConfig _helper) {
        artShift = _artShift;
        helper = _helper;

        vm.deal(BOB, STARTING_USER_BALANCE);

        vm.prank(BOB);
        artShift.mint();
    }

    function randomizeArt(uint256 randomNumber) public {
        vm.assume(randomNumber < type(uint256).max);

        tokenUriBefore = artShift.tokenURI(0);
        console.log("tokenUriBefore: ", tokenUriBefore);
        uint256[] memory randomWords = new uint256[](1);
        randomWords[0] = randomNumber;

        vm.prank(BOB);
        artShift.randomizeArt(0);

        vm.prank(address(helper.vrfCoordinatorMock()));
        helper.vrfCoordinatorMock().fulfillRandomWordsWithOverride(artShift.requestId(), address(artShift), randomWords);

        tokenUriAfter = artShift.tokenURI(0);
        console.log("tokenUriAfter: ", tokenUriAfter);
    }
}
