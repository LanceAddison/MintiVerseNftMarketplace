// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {Test, console} from "forge-std/Test.sol";
import {ArtShift} from "../../src/ArtShift.sol";
import {DeployArtShift} from "../../script/DeployArtShift.s.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";

contract ArtShiftTest is Test {
    ArtShift artShift;
    HelperConfig helper;
    DeployArtShift deployer;

    address public BOB = makeAddr("bob");
    address public ALICE = makeAddr("alice");
    uint256 public constant STARTING_USER_BALANCE = 10 ether;

    uint256 subscriptionId;
    address vrfCoordinator;
    uint32 callbackGasLimit;
    bytes32 keyHash;
    address link;
    uint256 deployerKey;

    function setUp() external {
        deployer = new DeployArtShift();
        (artShift, helper) = deployer.run();
        (subscriptionId, vrfCoordinator, callbackGasLimit, keyHash, link, deployerKey) = helper.activeNetworkConfig();
        vm.deal(BOB, STARTING_USER_BALANCE);
    }

    /*//////////////////////////////////////////////////////////////
                             MINT_NFT TESTS
    //////////////////////////////////////////////////////////////*/
    modifier mintNft() {
        vm.prank(BOB);
        artShift.mint();
        _;
    }

    function testMintSuccess() public {
        uint256 expectedTokenCount = 1;
        string memory expectedArtShiftUri =
            "https://ipfs.io/ipfs/QmYaDcC1nCpNeQzoEF2tQz7gyu1WqpKKtZfZyK6cP3fcDR?filename=ArtShift-001.json";
        vm.prank(BOB);
        artShift.mint();
        assertEq(artShift.getTokenCount(), expectedTokenCount);
        assertEq(artShift.tokenURI(0), expectedArtShiftUri);
    }

    /*//////////////////////////////////////////////////////////////
                             BURN_NFT TESTS
    //////////////////////////////////////////////////////////////*/
    function testBurnSuccess() public mintNft {
        uint256 expectedBalanceBob = 0;
        vm.prank(BOB);
        artShift.burn(0);
        assertEq(artShift.balanceOf(BOB), expectedBalanceBob);
    }

    function testBurnFailsIfNotOwner() public mintNft {
        vm.prank(ALICE);
        vm.expectRevert(ArtShift.ArtShift__NotTokenOwner.selector);
        artShift.burn(0);
    }

    function testBurnFailsIfNotValidTokenId() public mintNft {
        vm.prank(BOB);
        vm.expectRevert();
        artShift.burn(1);
    }

    /*//////////////////////////////////////////////////////////////
                           TRANSFER_NFT TESTS
    //////////////////////////////////////////////////////////////*/
    function testCanTransferNft() public mintNft {
        uint256 expectedBalanceBob = 0;
        uint256 expectedBalanceAlice = 1;

        vm.prank(BOB);
        artShift.transferFrom(BOB, ALICE, 0);

        assertEq(artShift.balanceOf(BOB), expectedBalanceBob);
        assertEq(artShift.balanceOf(ALICE), expectedBalanceAlice);
    }

    function testCanApproveAndTransferNft() public mintNft {
        uint256 expectedBalanceBob = 0;
        uint256 expectedBalanceAlice = 1;

        vm.prank(BOB);
        artShift.approve(ALICE, 0);
        vm.prank(ALICE);
        artShift.transferFrom(BOB, ALICE, 0);

        assertEq(artShift.balanceOf(BOB), expectedBalanceBob);
        assertEq(artShift.balanceOf(ALICE), expectedBalanceAlice);
    }

    /*//////////////////////////////////////////////////////////////
                          RANDOMIZE_ART TESTS
    //////////////////////////////////////////////////////////////*/
    function testRandomizeArtSuccess() public mintNft {
        string memory beforeRandomizeTokenUri = artShift.tokenURI(0);
        vm.prank(BOB);
        artShift.randomizeArt(0);

        vm.prank(address(helper.vrfCoordinatorMock()));
        helper.vrfCoordinatorMock().fulfillRandomWords(artShift.requestId(), address(artShift));

        string memory afterRandomizeTokenUri = artShift.tokenURI(0);

        assert(
            keccak256(abi.encodePacked(beforeRandomizeTokenUri)) != keccak256(abi.encodePacked(afterRandomizeTokenUri))
        );
    }

    function testRandomizeArtMultipleTimes() public mintNft {
        for (uint256 i = 0; i < 10; i++) {
            string memory currentUri = artShift.tokenURI(0);
            vm.prank(BOB);
            artShift.randomizeArt(0);

            vm.prank(address(helper.vrfCoordinatorMock()));
            helper.vrfCoordinatorMock().fulfillRandomWords(artShift.requestId(), address(artShift));

            string memory newUri = artShift.tokenURI(0);
            assert(keccak256(abi.encodePacked(currentUri)) != keccak256(abi.encodePacked(newUri)));
        }
    }

    function testFuzzTokenUriIsAlwaysDifferentAfterRandomize(uint256 randomNumber) public mintNft {
        vm.assume(randomNumber < type(uint256).max);

        string memory initialUri = artShift.tokenURI(0);

        uint256[] memory randomWords = new uint256[](1);
        randomWords[0] = randomNumber;

        vm.prank(BOB);
        artShift.randomizeArt(0);

        vm.prank(address(helper.vrfCoordinatorMock()));
        helper.vrfCoordinatorMock().fulfillRandomWordsWithOverride(artShift.requestId(), address(artShift), randomWords);

        string memory newUri = artShift.tokenURI(0);

        assert(keccak256(abi.encodePacked(initialUri)) != keccak256(abi.encodePacked(newUri)));
    }
}
