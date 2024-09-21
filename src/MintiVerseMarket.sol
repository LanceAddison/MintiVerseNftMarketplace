// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {ArtShift} from "./ArtShift.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {console} from "forge-std/console.sol";

/**
 * @title MintiVerse Market
 * @author Lance Addison
 */
contract MintiVerseMarket is Ownable, ReentrancyGuard {
    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/
    error MintiVerseMarket__NotTokenOwner();
    error MintiVerseMarket__NotEnoughFundsToPurchase(uint256 provided, uint256 required);
    error MintiVerseMarket__ItemNotForSale();
    error MintiVerseMarket__OnlyOwnerCanUnlistItem();
    error MintiVerseMarket__ItemIsntListed();
    error MintiVerseMarket__AuctionDurationMustBeMoreThanZero();
    error MintiVerseMarket__CantBidOnWhatYouOwn();
    error MintiVerseMarket__CantBidBelowTheLatestBiddingPrice(uint256 latestBidPrice);
    error MintiVerseMarket__NewBidMustBeGreaterThanYourPreviousBid();
    error MintiVerseMarket__AuctionHasEnded();
    error MintiVerseMarket__AuctionStillOpen();
    error MintiVerseMarket__CantBuyNowIfItemIsAuctioned();
    error MintiVerseMarket__OnlySellerOrWinnerCanCompleteAuction();
    error MintiVerseMarket__WinnerCantCancelBid();
    error MintiVerseMarket__TransferFailed();

    /*//////////////////////////////////////////////////////////////
                                 TYPES
    //////////////////////////////////////////////////////////////*/
    struct NFTDetails {
        uint256 tokenId;
        string tokenUri;
        address currentOwner;
        uint256 price;
        uint256 startAt;
        uint256 endAt;
        bool listed;
    }

    /*//////////////////////////////////////////////////////////////
                            STATE VARIABLES
    //////////////////////////////////////////////////////////////*/
    ArtShift immutable i_artShift;
    uint256 private s_itemIdCounter;
    uint256 private s_auctionIncrement = 10; // 10%

    mapping(uint256 => NFTDetails) private s_itemIdToDetails;
    mapping(uint256 => uint256) private s_tokenIdToItemId;
    mapping(uint256 => mapping(address => uint256)) public s_itemIdToAddressBidAmount;
    mapping(uint256 => address) public s_itemIdToHighestBidder;

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/
    event ItemListed(uint256 indexed tokenId, address indexed owner, uint256 price);
    event ItemUnlisted(uint256 indexed tokenId, address indexed owner);
    event ItemSold(uint256 indexed tokenId, address indexed buyer, uint256 price);
    event UpdatedItemDetails(
        uint256 indexed tokenId, string tokenUri, address indexed newOwner, uint256 newPrice, bool isListed
    );
    event AddedItemDetails(
        uint256 indexed tokenId,
        string tokenUri,
        address indexed newOwner,
        uint256 newPrice,
        uint256 startAt,
        uint256 endAt,
        bool isListed
    );
    event ItemListedForAuction(
        uint256 indexed tokenId, address indexed owner, uint256 price, uint256 startAt, uint256 endAt
    );
    event BidCreated(uint256 indexed tokenId, address indexed bidder, uint256 latestBid);
    event BidCanceled(uint256 indexed tokenId, address indexed bidder, uint256 originalBid);
    event AuctionCompleted(
        uint256 indexed tokenId, address indexed previousOwner, address indexed newOwner, uint256 winningBid
    );

    /*//////////////////////////////////////////////////////////////
                               MODIFIERS
    //////////////////////////////////////////////////////////////*/
    modifier onlyTokenOwner(uint256 tokenId) {
        if (i_artShift.ownerOf(tokenId) != msg.sender) revert MintiVerseMarket__NotTokenOwner();
        _;
    }

    modifier hasEnoughFundsAndItemIsForSale(uint256 tokenId, uint256 price) {
        if (!s_itemIdToDetails[s_tokenIdToItemId[tokenId]].listed) revert MintiVerseMarket__ItemNotForSale();
        if (msg.value < price) revert MintiVerseMarket__NotEnoughFundsToPurchase(msg.value, price);
        _;
    }

    /*//////////////////////////////////////////////////////////////
                               FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    constructor(address artShift) Ownable(msg.sender) {
        i_artShift = ArtShift(artShift);
    }

    /*//////////////////////////////////////////////////////////////
                           EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    function listItem(uint256 tokenId, uint256 price) external onlyTokenOwner(tokenId) {
        _transferTokenAndList(tokenId, price, 0, 0);
        emit ItemListed(tokenId, msg.sender, price);
    }

    function listItemWithAuction(uint256 tokenId, uint256 price, uint256 durationInMinutes)
        external
        onlyTokenOwner(tokenId)
    {
        if (durationInMinutes == 0) revert MintiVerseMarket__AuctionDurationMustBeMoreThanZero();

        uint256 startAt = block.timestamp;
        uint256 endAt = startAt + (durationInMinutes * 60);

        _transferTokenAndList(tokenId, price, startAt, endAt);
        emit ItemListedForAuction(tokenId, msg.sender, price, startAt, endAt);
    }

    function unlistItem(uint256 tokenId) external {
        uint256 itemId = s_tokenIdToItemId[tokenId];
        NFTDetails storage item = s_itemIdToDetails[itemId];

        if (msg.sender != item.currentOwner) revert MintiVerseMarket__OnlyOwnerCanUnlistItem();
        if (!item.listed) revert MintiVerseMarket__ItemIsntListed();

        _unlistItem(tokenId);
        emit ItemUnlisted(tokenId, msg.sender);
    }

    function buyItem(uint256 tokenId)
        external
        payable
        nonReentrant
        hasEnoughFundsAndItemIsForSale(tokenId, getItemPrice(tokenId))
    {
        uint256 itemId = s_tokenIdToItemId[tokenId];
        NFTDetails storage item = s_itemIdToDetails[itemId];
        if (item.startAt != 0 && item.endAt != 0) revert MintiVerseMarket__CantBuyNowIfItemIsAuctioned();

        address seller = item.currentOwner;
        uint256 price = item.price;

        _transferFunds(seller, price);
        _completePurchase(tokenId, msg.sender);
        emit ItemSold(tokenId, msg.sender, price);
    }

    function completeAuction(uint256 tokenId) external payable nonReentrant {
        uint256 itemId = s_tokenIdToItemId[tokenId];
        NFTDetails storage item = s_itemIdToDetails[itemId];

        if (!item.listed) revert MintiVerseMarket__ItemNotForSale();
        if (isAuctionOpen(tokenId)) revert MintiVerseMarket__AuctionStillOpen();

        address winner = s_itemIdToHighestBidder[itemId];
        if (msg.sender != item.currentOwner && msg.sender != winner) {
            revert MintiVerseMarket__OnlySellerOrWinnerCanCompleteAuction();
        }
        address seller = item.currentOwner;
        uint256 finalBid = s_itemIdToAddressBidAmount[itemId][winner];
        s_itemIdToAddressBidAmount[itemId][winner] = 0;

        _finalizeAuction(tokenId, winner, finalBid);
        emit AuctionCompleted(tokenId, seller, winner, finalBid);
    }

    /**
     * @notice If the user previously bidded their previous bid will be returned to them
     * @notice After each bid the price of the item increases by 10% to incentivize higher bids
     */
    function bidOnItem(uint256 tokenId) external payable nonReentrant {
        uint256 itemId = s_tokenIdToItemId[tokenId];
        NFTDetails storage item = s_itemIdToDetails[itemId];

        if (!item.listed) revert MintiVerseMarket__ItemNotForSale();
        if (!isAuctionOpen(tokenId)) revert MintiVerseMarket__AuctionHasEnded();
        if (msg.sender == item.currentOwner) revert MintiVerseMarket__CantBidOnWhatYouOwn();

        uint256 previousBid = s_itemIdToAddressBidAmount[itemId][msg.sender];
        if (msg.value <= previousBid) revert MintiVerseMarket__NewBidMustBeGreaterThanYourPreviousBid();
        if (msg.value < item.price) revert MintiVerseMarket__CantBidBelowTheLatestBiddingPrice(item.price);

        s_itemIdToAddressBidAmount[itemId][msg.sender] = msg.value;
        s_itemIdToHighestBidder[itemId] = msg.sender;

        uint256 incentive = msg.value / s_auctionIncrement;
        item.price = msg.value + incentive;

        _refundPreviousBid(msg.sender, previousBid);
        emit BidCreated(itemId, msg.sender, msg.value);
    }

    /**
     * @notice The highest bidder cannot cancel their bid
     */
    function cancelBid(uint256 tokenId) external payable nonReentrant {
        uint256 itemId = s_tokenIdToItemId[tokenId];
        if (msg.sender == s_itemIdToHighestBidder[itemId]) revert MintiVerseMarket__WinnerCantCancelBid();

        uint256 bidAmount = s_itemIdToAddressBidAmount[itemId][msg.sender];
        s_itemIdToAddressBidAmount[itemId][msg.sender] = 0;

        _refundPreviousBid(msg.sender, bidAmount);
        emit BidCanceled(tokenId, msg.sender, bidAmount);
    }

    /**
     * @notice This allows anyone to add an nft to the s_itemIdToDetails mapping if it isnt already added
     * @notice If the nft already exists in the mapping the details will be updated
     * This is specifically used to update the NFTDetails if the tokenUri was updated after the Nft was already added to the s_itemIdToDetails mapping
     * This is also used to update the currentOwner if the nft was transfered to another wallet after being added to the s_itemIdToDetails mapping
     */
    function updateOrAddItemDetails(uint256 tokenId) external {
        uint256 itemId = s_tokenIdToItemId[tokenId];

        if (itemId == 0) {
            itemId = ++s_itemIdCounter;
            s_tokenIdToItemId[tokenId] = itemId;
            s_itemIdToDetails[itemId] =
                NFTDetails(tokenId, i_artShift.tokenURI(tokenId), i_artShift.ownerOf(tokenId), 0, 0, 0, false);
            NFTDetails memory newItem = s_itemIdToDetails[itemId];

            emit AddedItemDetails(
                tokenId,
                newItem.tokenUri,
                newItem.currentOwner,
                newItem.price,
                newItem.startAt,
                newItem.endAt,
                newItem.listed
            );
            return;
        }

        NFTDetails storage item = s_itemIdToDetails[itemId];

        item.tokenUri = i_artShift.tokenURI(tokenId);
        if (!item.listed) {
            item.currentOwner = i_artShift.ownerOf(tokenId);
        }

        emit UpdatedItemDetails(itemId, item.tokenUri, item.currentOwner, item.price, item.listed);
    }

    /*//////////////////////////////////////////////////////////////
                           INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    function _transferTokenAndList(uint256 _tokenId, uint256 _price, uint256 _startAt, uint256 _endAt) internal {
        uint256 itemId = s_tokenIdToItemId[_tokenId];
        if (itemId == 0) {
            itemId = ++s_itemIdCounter;
            s_tokenIdToItemId[_tokenId] = itemId;
        }
        s_itemIdToDetails[itemId] =
            NFTDetails(_tokenId, i_artShift.tokenURI(_tokenId), msg.sender, _price, _startAt, _endAt, true);
        i_artShift.transferFrom(msg.sender, address(this), _tokenId);
    }

    function _unlistItem(uint256 _tokenId) internal {
        uint256 itemId = s_tokenIdToItemId[_tokenId];
        NFTDetails storage item = s_itemIdToDetails[itemId];
        item.price = 0;
        item.startAt = 0;
        item.endAt = 0;
        item.listed = false;
        i_artShift.transferFrom(address(this), msg.sender, _tokenId);
    }

    function _transferFunds(address _to, uint256 _amount) internal {
        (bool success,) = _to.call{value: _amount}("");
        if (!success) revert MintiVerseMarket__TransferFailed();
    }

    function _completePurchase(uint256 _tokenId, address _buyer) internal {
        uint256 itemId = s_tokenIdToItemId[_tokenId];
        NFTDetails storage item = s_itemIdToDetails[itemId];
        item.currentOwner = _buyer;
        item.price = 0;
        item.startAt = 0;
        item.endAt = 0;
        item.listed = false;
        i_artShift.safeTransferFrom(address(this), _buyer, _tokenId);
    }

    function _finalizeAuction(uint256 _tokenId, address _winner, uint256 _winningBid) internal {
        uint256 itemId = s_tokenIdToItemId[_tokenId];
        NFTDetails storage item = s_itemIdToDetails[itemId];

        if (_winner != address(0) && _winningBid != 0) {
            _transferFunds(item.currentOwner, _winningBid);
            _completePurchase(_tokenId, _winner);
        } else {
            _completePurchase(_tokenId, item.currentOwner);
        }
    }

    function _refundPreviousBid(address _bidder, uint256 _amount) internal {
        if (_amount > 0) {
            (bool success,) = _bidder.call{value: _amount}("");
            if (!success) revert MintiVerseMarket__TransferFailed();
        }
    }

    /*//////////////////////////////////////////////////////////////
                         PUBLIC VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    function isAuctionOpen(uint256 tokenId) public view returns (bool) {
        NFTDetails memory item = s_itemIdToDetails[s_tokenIdToItemId[tokenId]];
        return item.endAt > block.timestamp;
    }

    function getItemDetails(uint256 tokenId)
        public
        view
        returns (
            string memory tokenUri,
            address currentOwner,
            uint256 price,
            uint256 startAt,
            uint256 endAt,
            bool listed
        )
    {
        NFTDetails memory item = s_itemIdToDetails[s_tokenIdToItemId[tokenId]];
        return (item.tokenUri, item.currentOwner, item.price, item.startAt, item.endAt, item.listed);
    }

    function getAddressBidAmount(uint256 tokenId, address bidder) public view returns (uint256) {
        return s_itemIdToAddressBidAmount[s_tokenIdToItemId[tokenId]][bidder];
    }

    function getAuctionWinner(uint256 tokenId) public view returns (address) {
        return s_itemIdToHighestBidder[s_tokenIdToItemId[tokenId]];
    }

    function getItemPrice(uint256 tokenId) public view returns (uint256) {
        return s_itemIdToDetails[s_tokenIdToItemId[tokenId]].price;
    }

    function getAuctionPriceIncrement() public view returns (uint256) {
        return s_auctionIncrement;
    }

    function getItemIdFromTokenId(uint256 tokenId) public view returns (uint256) {
        return s_tokenIdToItemId[tokenId];
    }

    function getItemCount() public view returns (uint256) {
        return s_itemIdCounter;
    }
}
