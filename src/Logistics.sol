// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "lib/openzeppelin/contracts/token/ERC721/ERC721.sol";
import "lib/openzeppelin/contracts/access/Ownable.sol";

/**
 * @title NFT Padala
 * @author Selwyn John G. Guiruela
 * @notice This contract is for tracking real world items using an NFT representation
 * @dev Implements OpenZeppelin's ERC721 and Ownable contracts
 */

contract RealWorldItemNFT is ERC721, Ownable {
    using Strings for uint256;

    /*//////////////////////////////////////////////////////////////
                                ERRORS
    //////////////////////////////////////////////////////////////*/

    error NotCurrentOwner();
    error InvalidAddress();
    error EmptyString();
    error ItemNotFound();
    error DuplicateRealId();


    /*//////////////////////////////////////////////////////////////
                            TYPE DECLARATIONS
    //////////////////////////////////////////////////////////////*/

    struct TransferRecord {
        address from;
        address to;
        uint timestamp;
    }

    struct ItemDetails {
        string s_itemName;
        string s_locationOrigin;
        address s_finalRecipient;
        string s_itemIdentifier; 
    }

    /// @notice Parameters for minting a new item
    struct MintParams {
        string realId;
        address to;
        string itemName;
        string locationOrigin;
        address finalRecipient;
    }

    /// @dev stores all details about an item for each token ID
    mapping(uint256 => ItemDetails) private s_itemDetails;

    /// @dev a chronological list of all transfers for a given tokenId
    mapping(uint256 => TransferRecord[]) private s_history;

    /// @dev mapping from realId to tokenId for reverse lookups
    mapping(string => uint256) private s_realIdToTokenId;

    /// @dev array to store all realIds
    string[] private s_allRealIds;

    /// @dev incremental token IDs
    uint256 public nextTokenId;

    /// @dev Base URI for computing {tokenURI}. Can be updated by owner.
    string private s_baseURI;

    /*//////////////////////////////////////////////////////////////
                                EVENTS
    //////////////////////////////////////////////////////////////*/

    /// @notice emitted when a new item is minted
    event ItemMinted(
        uint256 tokenId,
        address from,
        address to,
        string indexed itemName,
        string indexed locationOrigin,
        address indexed finalRecipient,
        string itemIdentifier
    );

    /// @notice emitted when an item is transferred
    event ItemTransferred(
        uint256 tokenId,
        address indexed from,
        address indexed to,
        uint indexed timestamp
    );

    /*//////////////////////////////////////////////////////////////
                            CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor(address initialOwner) ERC721("Real World Items", "RWI") Ownable(initialOwner) {
        s_baseURI = ""; // Initialize with empty string, can be updated later
    }

    /*//////////////////////////////////////////////////////////////
                        EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @dev anyone can mint (no whitelist yet)
    /// @notice generate a new NFT representing the real world item.
    /// @notice can add a function on the app where registered accounts are only addresses that in the whitelist
    /// @param params struct containing all parameters for minting
    function mint(MintParams calldata params) external {
        if (params.finalRecipient == address(0)) {
            revert InvalidAddress();
        }
        if (bytes(params.itemName).length == 0) {
            revert EmptyString();
        }
        if (bytes(params.locationOrigin).length == 0) {
            revert EmptyString();
        }
        if (bytes(params.realId).length == 0) {
            revert EmptyString();
        }
        // check if realId already exists
        uint256 existingTokenId = s_realIdToTokenId[params.realId];
        if (existingTokenId != 0) {
            revert DuplicateRealId();
        }

        uint256 tokenId = nextTokenId++;
        
        // store all item details
        s_itemDetails[tokenId] = ItemDetails({
            s_itemName: params.itemName,
            s_locationOrigin: params.locationOrigin,
            s_finalRecipient: params.finalRecipient,
            s_itemIdentifier: params.realId
        });

        // store the reverse mapping
        s_realIdToTokenId[params.realId] = tokenId;
        
        // add realId to the array of all realIds
        s_allRealIds.push(params.realId);

        _safeMint(params.to, tokenId);
        
        // record the "genesis" or the first ownership of the item as a transfer from address(0)
        s_history[tokenId].push(TransferRecord({
            from: address(0),
            to: params.to,
            timestamp: block.timestamp
        }));

        // emit the mint event
        emit ItemMinted(
            tokenId,
            address(0),
            params.to,
            params.itemName,
            params.locationOrigin,
            params.finalRecipient,
            params.realId
        );
    }

    /// @notice transfer the NFT to the next handler using the real world identifier
    /// @dev only the current token owner can invoke
    function transferItem(string calldata realId, address to) external {
        uint256 tokenId = s_realIdToTokenId[realId];
        if (tokenId == 0 && bytes(s_itemDetails[0].s_itemIdentifier).length == 0) {
            revert ItemNotFound();
        }
        if (ownerOf(tokenId) != msg.sender) {
            revert NotCurrentOwner();
        }
        if (to == address(0)) {
            revert InvalidAddress();
        }
        // append this leg to the on-chain history
        s_history[tokenId].push(TransferRecord({
            from: msg.sender,
            to: to,
            timestamp: block.timestamp
        }));
        // move the NFT
        _safeTransfer(msg.sender, to, tokenId, "");

        // emit the transfer event
        emit ItemTransferred(
            tokenId,
            msg.sender,
            to,
            block.timestamp
        );
    }

    /// @notice get the full transfer history of `tokenId`
    function getHistory(uint256 tokenId) external view returns (TransferRecord[] memory) {
        return s_history[tokenId];
    }

    /// @notice get all details of a specific NFT token using its realId
    /// @param realId the real world identifier of the item
    /// @return ItemDetails struct containing all item information
    function getItemDetailsByRealId(string calldata realId) external view returns (ItemDetails memory) {
        uint256 tokenId = s_realIdToTokenId[realId];
        if (tokenId == 0 && bytes(s_itemDetails[0].s_itemIdentifier).length == 0) {
            revert ItemNotFound();
        }
        return s_itemDetails[tokenId];
    }

    /// @notice Get the owner of an item using its real world identifier
    /// @param realId the real world identifier of the item
    /// @return address of the current owner
    function ownerOfByRealId(string calldata realId) external view returns (address) {
        uint256 tokenId = s_realIdToTokenId[realId];
        if (tokenId == 0 && bytes(s_itemDetails[0].s_itemIdentifier).length == 0) {
            revert ItemNotFound();
        }
        return super.ownerOf(tokenId);
    }

    /// @notice Get all real world identifiers that have been minted
    /// @return array of all realIds
    function getAllRealIds() external view returns (string[] memory) {
        return s_allRealIds;
    }

    // /// @notice Set the base URI for token metadata
    // /// @dev Only callable by contract owner
    // /// @param baseURI_ The new base URI to set
    // function setBaseURI(string memory baseURI_) external onlyOwner {
    //     s_baseURI = baseURI_;
    // }

    // /// @notice Returns the Uniform Resource Identifier (URI) for `tokenId` token.
    // /// @dev Overrides the OpenZeppelin implementation
    // /// @param tokenId The token ID to get URI for
    // function tokenURI(uint256 tokenId) public view virtual override returns (string memory) {
    //     _requireOwned(tokenId);

    //     string memory baseURI = _baseURI();
    //     return bytes(baseURI).length > 0 ? string.concat(baseURI, tokenId.toString()) : "";
    // }

    // /// @dev Returns the base URI for computing {tokenURI}
    // /// @return The base URI string
    // function _baseURI() internal view virtual override returns (string memory) {
    //     return s_baseURI;
    // }
}