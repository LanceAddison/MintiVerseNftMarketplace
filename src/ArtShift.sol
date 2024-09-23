//SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {VRFConsumerBaseV2Plus, IVRFCoordinatorV2Plus} from "@chainlink/contracts/vrf/dev/VRFConsumerBaseV2Plus.sol";
import {VRFV2PlusClient} from "@chainlink/contracts/vrf/dev/libraries/VRFV2PlusClient.sol";

/**
 * @title ArtShift
 * @author Lance Addison
 * @notice This is an nft contract that allows you to do basic functions including randomize the details of an nft
 */
contract ArtShift is ERC721, VRFConsumerBaseV2Plus {
    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/
    error ArtShift__NotTokenOwner();
    error ArtShift__FailedToFindDifferentTokenUri();

    /*//////////////////////////////////////////////////////////////
                            STATE VARIABLES
    //////////////////////////////////////////////////////////////*/
    uint32 private immutable i_callbackGasLimit;
    bytes32 private immutable i_keyHash;
    uint256 private immutable i_subscriptionId;

    uint16 constant REQUEST_CONFIRMATIONS = 3;
    uint32 constant NUM_WORDS = 1;

    uint256 private s_tokenCounter;
    mapping(uint256 => string) private s_tokenIdToImgUri;
    string[] private s_artShiftUris;
    mapping(uint256 => uint256) private requestIdToTokenId;

    uint256 public requestId;
    uint256 public randomNumber;

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/
    event RequestInitialized(uint256 requestId, uint256 tokenId);
    event RequestSent(uint256 requestId, uint32 numWords);
    event RequestFulfilled(uint256 requestId, uint256 randomWord);

    /*//////////////////////////////////////////////////////////////
                               MODIFIERS
    //////////////////////////////////////////////////////////////*/
    modifier onlyTokenOwner(uint256 tokenId) {
        // require(ownerOf(tokenId) == msg.sender, "Not the owner");
        if (ownerOf(tokenId) != msg.sender) revert ArtShift__NotTokenOwner();
        _;
    }

    /*//////////////////////////////////////////////////////////////
                               FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    constructor(
        string[] memory artShiftUris,
        uint256 subscriptionId,
        address vrfCoordinator,
        uint32 callbackGasLimit,
        bytes32 keyHash
    ) ERC721("ArtShift", "SHFT") VRFConsumerBaseV2Plus(vrfCoordinator) {
        s_artShiftUris = artShiftUris;
        i_subscriptionId = subscriptionId;
        s_vrfCoordinator = IVRFCoordinatorV2Plus(vrfCoordinator);
        i_callbackGasLimit = callbackGasLimit;
        i_keyHash = keyHash;
    }

    /*//////////////////////////////////////////////////////////////
                           EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    function mint() external {
        _safeMint(msg.sender, s_tokenCounter);
        s_tokenIdToImgUri[s_tokenCounter] = s_artShiftUris[s_tokenCounter % s_artShiftUris.length];
        s_tokenCounter++;
    }

    /*//////////////////////////////////////////////////////////////
                            PUBLIC FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    function burn(uint256 tokenId) public onlyTokenOwner(tokenId) {
        _burn(tokenId);
    }

    /**
     * @notice Randomizes the users nft tokenUri using Chainlink VRF
     * This will cause the nft to get new details including a new image.
     */
    function randomizeArt(uint256 tokenId) public onlyTokenOwner(tokenId) {
        requestId = requestRandomWords(false);
        requestIdToTokenId[requestId] = tokenId;
        emit RequestInitialized(requestId, tokenId);
    }

    /*//////////////////////////////////////////////////////////////
                           INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    function requestRandomWords(bool enableNativePayment) internal returns (uint256) {
        requestId = s_vrfCoordinator.requestRandomWords(
            VRFV2PlusClient.RandomWordsRequest({
                keyHash: i_keyHash,
                subId: i_subscriptionId,
                requestConfirmations: REQUEST_CONFIRMATIONS,
                callbackGasLimit: i_callbackGasLimit,
                numWords: NUM_WORDS,
                extraArgs: VRFV2PlusClient._argsToBytes(VRFV2PlusClient.ExtraArgsV1({nativePayment: enableNativePayment}))
            })
        );

        emit RequestSent(requestId, NUM_WORDS);
        return requestId;
    }

    function fulfillRandomWords(uint256 _requestId, uint256[] calldata _randomWords) internal override {
        uint256 tokenId = requestIdToTokenId[_requestId];
        string memory currentUri = s_tokenIdToImgUri[tokenId];

        randomNumber = _randomWords[0];
        string memory newUri = _getNewUri(randomNumber, currentUri);

        if (bytes(newUri).length > 0) {
            s_tokenIdToImgUri[tokenId] = newUri;
            emit RequestFulfilled(_requestId, randomNumber);
            return;
        }

        randomNumber += 1;
        newUri = _getNewUri(randomNumber, currentUri);

        if (bytes(newUri).length > 0) {
            s_tokenIdToImgUri[tokenId] = newUri;
            emit RequestFulfilled(_requestId, randomNumber);
        } else {
            revert ArtShift__FailedToFindDifferentTokenUri();
        }
    }

    /*//////////////////////////////////////////////////////////////
                         PUBLIC VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        return s_tokenIdToImgUri[tokenId];
    }

    function getTokenCount() public view returns (uint256) {
        return s_tokenCounter;
    }

    function getSubscriptionBalance() public view returns (uint96) {
        (uint96 balance,,,,) = s_vrfCoordinator.getSubscription(i_subscriptionId);
        return balance;
    }

    /*//////////////////////////////////////////////////////////////
                        INTERNAL VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    /**
     * @notice Returns a new token uri by using _randomNumber
     * @param _randomNumber The random number returned by the Chainlink VRF
     * @param _currentUri The current tokens uri
     */
    function _getNewUri(uint256 _randomNumber, string memory _currentUri) internal view returns (string memory) {
        uint256 newIndex = _randomNumber % s_artShiftUris.length;
        string memory newUri = s_artShiftUris[newIndex];

        if (keccak256(abi.encodePacked(newUri)) != keccak256(abi.encodePacked(_currentUri))) {
            return newUri;
        }

        return "";
    }
}
