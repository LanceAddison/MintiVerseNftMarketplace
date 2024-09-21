// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {Test, console} from "forge-std/Test.sol";
import {DeployMintiVerseMarket} from "../../script/DeployMintiVerseMarket.s.sol";
import {MintiVerseMarket} from "../../src/MintiVerseMarket.sol";
import {ArtShift} from "../../src/ArtShift.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";

contract MintiVerseMarketTest is Test {
    DeployMintiVerseMarket deployer;
    ArtShift artShift;
    MintiVerseMarket mintiVerse;
    HelperConfig helper;

    address public BOB = makeAddr("bob");
    address public ALICE = makeAddr("alice");
    address public DAVE = makeAddr("dave");

    uint256 constant DEFAULT_TOKEN_ID = 0;
    uint256 constant NFT_LISTING_PRICE = 0.1 ether;
    uint256 public constant STARTING_USER_BALANCE = 10 ether;
    uint256 constant DEFAULT_AUCTION_DURATION = 10; // 10 minutes
    uint256 constant DEFAULT_AUCTION_DURATION_IN_SEC = DEFAULT_AUCTION_DURATION * 60; // * 60 seconds
    uint256 constant DEFAULT_AUCTION_BID_AMOUNT = 0.15 ether;

    function setUp() external {
        deployer = new DeployMintiVerseMarket();
        (artShift, mintiVerse, helper) = deployer.run();

        vm.deal(BOB, STARTING_USER_BALANCE);
        vm.deal(ALICE, STARTING_USER_BALANCE);
        vm.deal(DAVE, STARTING_USER_BALANCE);
    }

    modifier mintNft() {
        vm.prank(BOB);
        artShift.mint();
        _;
    }

    modifier listItem(uint256 tokenId) {
        vm.startPrank(BOB);
        artShift.approve(address(mintiVerse), tokenId);
        mintiVerse.listItem(tokenId, NFT_LISTING_PRICE);
        vm.stopPrank();
        _;
    }

    modifier listItemWithAuction(uint256 tokenId) {
        vm.startPrank(BOB);
        artShift.approve(address(mintiVerse), DEFAULT_TOKEN_ID);
        mintiVerse.listItemWithAuction(DEFAULT_TOKEN_ID, NFT_LISTING_PRICE, DEFAULT_AUCTION_DURATION);
        vm.stopPrank();
        _;
    }

    modifier bidOnItem(uint256 tokenId) {
        vm.prank(ALICE);
        mintiVerse.bidOnItem{value: DEFAULT_AUCTION_BID_AMOUNT}(tokenId);
        _;
    }

    modifier unlistItem(uint256 tokenId) {
        vm.prank(BOB);
        mintiVerse.unlistItem(tokenId);
        _;
    }

    /*//////////////////////////////////////////////////////////////
                            LIST_ITEM TESTS
    //////////////////////////////////////////////////////////////*/
    function testCanListItem() public mintNft {
        vm.startPrank(BOB);
        artShift.approve(address(mintiVerse), DEFAULT_TOKEN_ID);
        mintiVerse.listItem(DEFAULT_TOKEN_ID, NFT_LISTING_PRICE);
        vm.stopPrank();

        (,,,,, bool listed) = mintiVerse.getItemDetails(DEFAULT_TOKEN_ID);

        uint256 expectedCount = 1;
        bool expectIsListed = true;
        uint256 expectedBalanceMarket = 1;

        assertEq(expectedCount, mintiVerse.getItemCount());
        assertEq(expectIsListed, listed);
        assertEq(expectedBalanceMarket, artShift.balanceOf(address(mintiVerse)));
    }

    function testItemCorrectlyListedAgain() public mintNft listItem(DEFAULT_TOKEN_ID) unlistItem(DEFAULT_TOKEN_ID) {
        vm.startPrank(BOB);
        artShift.approve(address(mintiVerse), DEFAULT_TOKEN_ID);
        mintiVerse.listItem(DEFAULT_TOKEN_ID, NFT_LISTING_PRICE);
        vm.stopPrank();

        (,, uint256 price,,, bool listed) = mintiVerse.getItemDetails(DEFAULT_TOKEN_ID);

        bool expectedIsListed = true;
        uint256 expectedPrice = NFT_LISTING_PRICE;
        uint256 expectedBalanceMarket = 1;

        assertEq(expectedIsListed, listed);
        assertEq(expectedPrice, price);
        assertEq(expectedBalanceMarket, artShift.balanceOf(address(mintiVerse)));
    }

    /*//////////////////////////////////////////////////////////////
                           UNLIST_ITEM TESTS
    //////////////////////////////////////////////////////////////*/
    function testCanUnlistItem() public mintNft listItem(DEFAULT_TOKEN_ID) {
        vm.prank(BOB);
        mintiVerse.unlistItem(DEFAULT_TOKEN_ID);

        (,, uint256 price,,, bool listed) = mintiVerse.getItemDetails(DEFAULT_TOKEN_ID);

        address expectedOwner = BOB;
        uint256 expectedPrice = 0;
        bool expectedIsListed = false;
        uint256 expectedBalanceBob = 1;

        assertEq(expectedOwner, artShift.ownerOf(DEFAULT_TOKEN_ID));
        assertEq(expectedPrice, price);
        assertEq(expectedIsListed, listed);
        assertEq(expectedBalanceBob, artShift.balanceOf(BOB));
    }

    function testCantUnlistIfNotApproved() public mintNft listItem(DEFAULT_TOKEN_ID) {
        vm.prank(ALICE);
        vm.expectRevert(MintiVerseMarket.MintiVerseMarket__OnlyOwnerCanUnlistItem.selector);
        mintiVerse.unlistItem(DEFAULT_TOKEN_ID);
    }

    function testCanUnlistItemWithAuction() public mintNft listItemWithAuction(DEFAULT_TOKEN_ID) {
        vm.prank(BOB);
        mintiVerse.unlistItem(DEFAULT_TOKEN_ID);

        (, address currentOwner, uint256 price, uint256 startAt, uint256 endAt, bool listed) =
            mintiVerse.getItemDetails(DEFAULT_TOKEN_ID);

        address expectedCurrentOwner = artShift.ownerOf(DEFAULT_TOKEN_ID);
        uint256 expectedPrice = 0;
        uint256 expectedStartAt = 0;
        uint256 expectedEndAt = 0;
        bool expectedIsListed = false;

        assertEq(expectedCurrentOwner, currentOwner);
        assertEq(expectedPrice, price);
        assertEq(expectedStartAt, startAt);
        assertEq(expectedEndAt, endAt);
        assertEq(expectedIsListed, listed);
    }

    /*//////////////////////////////////////////////////////////////
                             BUY_ITEM TESTS
    //////////////////////////////////////////////////////////////*/
    function testCanBuyItem() public mintNft listItem(DEFAULT_TOKEN_ID) {
        uint256 bobBalanceEthBefore = BOB.balance;

        vm.prank(ALICE);
        mintiVerse.buyItem{value: NFT_LISTING_PRICE}(DEFAULT_TOKEN_ID);

        (, address currentOwner, uint256 price,,,) = mintiVerse.getItemDetails(DEFAULT_TOKEN_ID);

        uint256 bobBalanceEthAfter = BOB.balance;
        uint256 aliceExpectedBalance = 1;
        uint256 expectedPrice = 0;

        assertEq(bobBalanceEthAfter, bobBalanceEthBefore + NFT_LISTING_PRICE);
        assertEq(aliceExpectedBalance, artShift.balanceOf(ALICE));
        assertEq(address(ALICE), currentOwner);
        assertEq(expectedPrice, price);
    }

    function testCantBuyTokenThatDoesntExist() public {
        vm.prank(BOB);
        vm.expectRevert();
        mintiVerse.buyItem(DEFAULT_TOKEN_ID);
    }

    function testCantBuyItemNowIfAuctioned() public mintNft listItemWithAuction(DEFAULT_TOKEN_ID) {
        vm.prank(ALICE);
        vm.expectRevert(MintiVerseMarket.MintiVerseMarket__CantBuyNowIfItemIsAuctioned.selector);
        mintiVerse.buyItem{value: NFT_LISTING_PRICE}(DEFAULT_TOKEN_ID);
    }

    /*//////////////////////////////////////////////////////////////
                      UPDATE_OR_ADD_ITEM_DETAILS TESTS
    //////////////////////////////////////////////////////////////*/
    function testTransferingNftUpdatesDetails() public mintNft listItem(DEFAULT_TOKEN_ID) {
        vm.startPrank(ALICE);
        mintiVerse.buyItem{value: NFT_LISTING_PRICE}(DEFAULT_TOKEN_ID);
        artShift.transferFrom(ALICE, BOB, DEFAULT_TOKEN_ID);
        vm.stopPrank();

        vm.prank(BOB);
        mintiVerse.updateOrAddItemDetails(DEFAULT_TOKEN_ID);

        (, address currentOwner,,,,) = mintiVerse.getItemDetails(DEFAULT_TOKEN_ID);

        address expectedCurrentOwner = address(BOB);

        assertEq(expectedCurrentOwner, currentOwner);
    }

    function testAddsDetailsIfNotAlreadyInMapping() public mintNft {
        vm.prank(BOB);
        mintiVerse.updateOrAddItemDetails(DEFAULT_TOKEN_ID);

        (string memory tokenUri, address currentOwner, uint256 price, uint256 startAt, uint256 endAt, bool listed) =
            mintiVerse.getItemDetails(DEFAULT_TOKEN_ID);

        string memory expectedTokenUri = artShift.tokenURI(DEFAULT_TOKEN_ID);
        address expectedCurrentOwner = artShift.ownerOf(DEFAULT_TOKEN_ID);
        uint256 expectedPrice = 0;
        uint256 expectedStartAt = 0;
        uint256 expectedEndAt = 0;
        bool expectedIsListed = false;

        assertEq(keccak256(abi.encodePacked(expectedTokenUri)), keccak256(abi.encodePacked(tokenUri)));
        assertEq(expectedCurrentOwner, currentOwner);
        assertEq(expectedPrice, price);
        assertEq(expectedStartAt, startAt);
        assertEq(expectedEndAt, endAt);
        assertEq(expectedIsListed, listed);
    }

    function testAddDetailsFailIfTokenIdDoesntExist() public {
        vm.prank(BOB);
        vm.expectRevert();
        mintiVerse.updateOrAddItemDetails(DEFAULT_TOKEN_ID);
    }

    /*//////////////////////////////////////////////////////////////
                      LIST_ITEM_WITH_AUCTION TESTS
    //////////////////////////////////////////////////////////////*/
    function testCanListItemWithAuction() public mintNft {
        vm.startPrank(BOB);
        artShift.approve(address(mintiVerse), DEFAULT_TOKEN_ID);
        mintiVerse.listItemWithAuction(DEFAULT_TOKEN_ID, NFT_LISTING_PRICE, DEFAULT_AUCTION_DURATION);
        vm.stopPrank();

        (,, uint256 price, uint256 startAt, uint256 endAt, bool listed) = mintiVerse.getItemDetails(DEFAULT_TOKEN_ID);
        uint256 expectedPrice = NFT_LISTING_PRICE;
        uint256 expectedStartAt = block.timestamp;
        uint256 expectedEndAt = block.timestamp + DEFAULT_AUCTION_DURATION_IN_SEC;
        bool expectedIsListed = true;

        assertEq(expectedPrice, price);
        assertEq(expectedStartAt, startAt);
        assertEq(expectedEndAt, endAt);
        assertEq(expectedIsListed, listed);
    }

    function testRevertIfListItemWithAuctionDurationIsZero() public mintNft {
        uint256 auctionDuration = 0;

        vm.prank(BOB);
        vm.expectRevert(MintiVerseMarket.MintiVerseMarket__AuctionDurationMustBeMoreThanZero.selector);
        mintiVerse.listItemWithAuction(DEFAULT_TOKEN_ID, NFT_LISTING_PRICE, auctionDuration);
    }

    function testItemCorrectlyListedWithAuctionAgain()
        public
        mintNft
        listItemWithAuction(DEFAULT_TOKEN_ID)
        unlistItem(DEFAULT_TOKEN_ID)
    {
        vm.startPrank(BOB);
        artShift.approve(address(mintiVerse), DEFAULT_TOKEN_ID);
        mintiVerse.listItemWithAuction(DEFAULT_TOKEN_ID, NFT_LISTING_PRICE, DEFAULT_AUCTION_DURATION);
        vm.stopPrank();

        (,, uint256 price, uint256 startAt, uint256 endAt, bool listed) = mintiVerse.getItemDetails(DEFAULT_TOKEN_ID);
        uint256 expectedPrice = NFT_LISTING_PRICE;
        uint256 expectedStartAt = block.timestamp;
        uint256 expectedEndAt = block.timestamp + DEFAULT_AUCTION_DURATION_IN_SEC;
        bool expectedIsListed = true;

        assertEq(expectedPrice, price);
        assertEq(expectedStartAt, startAt);
        assertEq(expectedEndAt, endAt);
        assertEq(expectedIsListed, listed);
    }

    /*//////////////////////////////////////////////////////////////
                           BID_ON_ITEM TESTS
    //////////////////////////////////////////////////////////////*/
    function testCanBidOnItem() public mintNft listItemWithAuction(DEFAULT_TOKEN_ID) {
        uint256 mintiVerseBalanceEthBefore = address(mintiVerse).balance;
        uint256 aliceBalanceEthBefore = ALICE.balance;

        vm.prank(ALICE);
        mintiVerse.bidOnItem{value: DEFAULT_AUCTION_BID_AMOUNT}(DEFAULT_TOKEN_ID);

        uint256 mintiVerseBalanceEthAfter = address(mintiVerse).balance;
        uint256 aliceBalanceEthAfter = ALICE.balance;

        assertEq(mintiVerseBalanceEthAfter, mintiVerseBalanceEthBefore + DEFAULT_AUCTION_BID_AMOUNT);
        assertEq(aliceBalanceEthAfter, aliceBalanceEthBefore - DEFAULT_AUCTION_BID_AMOUNT);
    }

    function testNewBidIsGreaterThanOldBid()
        public
        mintNft
        listItemWithAuction(DEFAULT_TOKEN_ID)
        bidOnItem(DEFAULT_TOKEN_ID)
    {
        uint256 newBidAmount = 0.165 ether;

        vm.prank(ALICE);
        mintiVerse.bidOnItem{value: newBidAmount}(DEFAULT_TOKEN_ID);

        (,, uint256 price,,,) = mintiVerse.getItemDetails(DEFAULT_TOKEN_ID);

        uint256 mintiVerseEthBalanceAfter = address(mintiVerse).balance;
        uint256 aliceBalanceEthAfter = ALICE.balance;
        uint256 aliceNewBidAmount = mintiVerse.getAddressBidAmount(DEFAULT_TOKEN_ID, ALICE);

        uint256 expectedMintiVerseBalanceEthAfter = newBidAmount;
        uint256 expectedAliceBalanceEthAfter = STARTING_USER_BALANCE - newBidAmount;
        uint256 expectedNewPrice = newBidAmount + (newBidAmount / mintiVerse.getAuctionPriceIncrement());

        assertEq(expectedMintiVerseBalanceEthAfter, mintiVerseEthBalanceAfter);
        assertEq(expectedAliceBalanceEthAfter, aliceBalanceEthAfter);
        assertEq(newBidAmount, aliceNewBidAmount);
        assertEq(expectedNewPrice, price);
    }

    function testSellerCantBidOnItem() public mintNft listItemWithAuction(DEFAULT_TOKEN_ID) {
        vm.prank(BOB);
        vm.expectRevert(MintiVerseMarket.MintiVerseMarket__CantBidOnWhatYouOwn.selector);
        mintiVerse.bidOnItem{value: DEFAULT_AUCTION_BID_AMOUNT}(DEFAULT_TOKEN_ID);
    }

    function testCantBidLessThanMostRecentPrice()
        public
        mintNft
        listItemWithAuction(DEFAULT_TOKEN_ID)
        bidOnItem(DEFAULT_TOKEN_ID)
    {
        uint256 newBidAmount = 0.16 ether;

        (,, uint256 price,,,) = mintiVerse.getItemDetails(DEFAULT_TOKEN_ID);

        vm.prank(ALICE);
        vm.expectRevert(
            abi.encodeWithSelector(
                MintiVerseMarket.MintiVerseMarket__CantBidBelowTheLatestBiddingPrice.selector, uint256(price)
            )
        );
        mintiVerse.bidOnItem{value: newBidAmount}(DEFAULT_TOKEN_ID);
    }

    function testCantBidLessThanPreviousBid()
        public
        mintNft
        listItemWithAuction(DEFAULT_TOKEN_ID)
        bidOnItem(DEFAULT_TOKEN_ID)
    {
        uint256 newBidAmount = 0.14 ether;

        vm.prank(ALICE);
        vm.expectRevert(MintiVerseMarket.MintiVerseMarket__NewBidMustBeGreaterThanYourPreviousBid.selector);
        mintiVerse.bidOnItem{value: newBidAmount}(DEFAULT_TOKEN_ID);
    }

    /*//////////////////////////////////////////////////////////////
                            CANCEL_BID TEST
    //////////////////////////////////////////////////////////////*/
    function testCanCancelBid() public mintNft listItemWithAuction(DEFAULT_TOKEN_ID) bidOnItem(DEFAULT_TOKEN_ID) {
        uint256 newBid = 0.2 ether;

        uint256 aliceBalanceEthBefore = ALICE.balance;
        uint256 mintiVerseBalanceEthBefore = address(mintiVerse).balance;
        uint256 aliceBidAmountBefore = mintiVerse.getAddressBidAmount(DEFAULT_TOKEN_ID, ALICE);

        vm.prank(DAVE);
        mintiVerse.bidOnItem{value: newBid}(DEFAULT_TOKEN_ID);

        vm.prank(ALICE);
        mintiVerse.cancelBid(DEFAULT_TOKEN_ID);

        uint256 aliceBalanceEthAfter = ALICE.balance;
        uint256 mintiVerseBalanceEthAfter = address(mintiVerse).balance;
        uint256 aliceBidAmountAfter = mintiVerse.getAddressBidAmount(DEFAULT_TOKEN_ID, ALICE);

        assertEq(aliceBalanceEthAfter, aliceBalanceEthBefore + DEFAULT_AUCTION_BID_AMOUNT);
        assertEq(mintiVerseBalanceEthAfter, (mintiVerseBalanceEthBefore + newBid) - DEFAULT_AUCTION_BID_AMOUNT);
        assertEq(aliceBidAmountAfter, aliceBidAmountBefore - DEFAULT_AUCTION_BID_AMOUNT);
    }

    function testWinnerCantCancelBid()
        public
        mintNft
        listItemWithAuction(DEFAULT_TOKEN_ID)
        bidOnItem(DEFAULT_TOKEN_ID)
    {
        vm.prank(ALICE);
        vm.expectRevert(MintiVerseMarket.MintiVerseMarket__WinnerCantCancelBid.selector);
        mintiVerse.cancelBid(DEFAULT_TOKEN_ID);
    }

    /*//////////////////////////////////////////////////////////////
                         COMPLETE_AUCTION TESTS
    //////////////////////////////////////////////////////////////*/
    function testHighestBidderCanCompleteAuction()
        public
        mintNft
        listItemWithAuction(DEFAULT_TOKEN_ID)
        bidOnItem(DEFAULT_TOKEN_ID)
    {
        uint256 endTimestamp = 601;
        uint256 bobBalanceEthBefore = BOB.balance;

        vm.warp(endTimestamp);

        address winner = mintiVerse.getAuctionWinner(DEFAULT_TOKEN_ID);
        uint256 winningBid = mintiVerse.getAddressBidAmount(DEFAULT_TOKEN_ID, winner);

        vm.prank(ALICE);
        mintiVerse.completeAuction(DEFAULT_TOKEN_ID);

        (, address currentOwner, uint256 price, uint256 startAt,, bool listed) =
            mintiVerse.getItemDetails(DEFAULT_TOKEN_ID);

        uint256 bobBalanceEthAfter = BOB.balance;
        address expectedNewOwner = ALICE;
        uint256 expectedPrice = 0;
        uint256 expectedStartAt = 0;
        bool expectedIsListed = false;

        assertEq(bobBalanceEthAfter, bobBalanceEthBefore + winningBid);
        assertEq(expectedNewOwner, currentOwner);
        assertEq(expectedPrice, price);
        assertEq(expectedStartAt, startAt);
        assertEq(expectedIsListed, listed);
    }

    function testOwnerCanCompleteAuction()
        public
        mintNft
        listItemWithAuction(DEFAULT_TOKEN_ID)
        bidOnItem(DEFAULT_TOKEN_ID)
    {
        uint256 endTimestamp = 601;

        vm.warp(endTimestamp);

        vm.prank(BOB);
        vm.expectEmit();
        emit MintiVerseMarket.AuctionCompleted(DEFAULT_TOKEN_ID, BOB, ALICE, DEFAULT_AUCTION_BID_AMOUNT);
        mintiVerse.completeAuction(DEFAULT_TOKEN_ID);

        (,,,,, bool listed) = mintiVerse.getItemDetails(DEFAULT_TOKEN_ID);

        address expectedNewOwner = ALICE;
        bool expectedIsListed = false;

        assertEq(expectedNewOwner, artShift.ownerOf(DEFAULT_TOKEN_ID));
        assertEq(expectedIsListed, listed);
    }

    function testReturnsNftToSellerIfNoBids() public mintNft listItemWithAuction(DEFAULT_TOKEN_ID) {
        uint256 endTimestamp = 601;

        vm.warp(endTimestamp);

        vm.prank(BOB);
        mintiVerse.completeAuction(DEFAULT_TOKEN_ID);

        address ownerOfNft = artShift.ownerOf(DEFAULT_TOKEN_ID);
        uint256 balanceOfBob = artShift.balanceOf(BOB);

        address expectedOwnerOfNft = BOB;
        uint256 expectedBalanceOfBob = 1;

        assertEq(expectedOwnerOfNft, ownerOfNft);
        assertEq(expectedBalanceOfBob, balanceOfBob);
    }

    /*//////////////////////////////////////////////////////////////
                          VIEW FUNCTION TESTS
    //////////////////////////////////////////////////////////////*/
    function testCanGetListedItemDetails() public mintNft listItem(DEFAULT_TOKEN_ID) {
        (string memory tokenUri, address currentOwner, uint256 price,,, bool listed) =
            mintiVerse.getItemDetails(DEFAULT_TOKEN_ID);

        string memory expectedTokenUri = artShift.tokenURI(DEFAULT_TOKEN_ID);
        address expectedCurrentOwner = BOB;
        uint256 expectedPrice = NFT_LISTING_PRICE;
        bool expectIsListed = true;

        assertEq(keccak256(abi.encodePacked(expectedTokenUri)), keccak256(abi.encodePacked(tokenUri)));
        assertEq(expectedCurrentOwner, currentOwner);
        assertEq(expectedPrice, price);
        assertEq(expectIsListed, listed);
    }
}
