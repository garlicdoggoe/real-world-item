// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {Test, console} from "forge-std/Test.sol";
import {RealWorldItemNFT} from "../../src/Logistics.sol";

contract LogisticsTest is Test {
    RealWorldItemNFT realWorldItem;
    address public OWNER = makeAddr("owner");
    address public USER = makeAddr("user");
    address public RECIPIENT = makeAddr("recipient");

    // test item parameters
    string constant ITEM_NAME = "Test Item";
    string constant locationOrigin = "Test locationOrigin";
    string constant REAL_ID = "TEST123";

    function setUp() public {
        vm.startPrank(OWNER);
        realWorldItem = new RealWorldItemNFT(OWNER);
        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////
                            MINT TESTS
    //////////////////////////////////////////////////////////////*/

    function test_MintWithValidParams() public {
        // arrange
        RealWorldItemNFT.MintParams memory params = RealWorldItemNFT.MintParams({
            realId: REAL_ID,
            to: USER,
            itemName: ITEM_NAME,
            locationOrigin: locationOrigin,
            finalRecipient: RECIPIENT
        });

        // act
        realWorldItem.mint(params);

        // assert
        assertEq(realWorldItem.ownerOf(0), USER);

        RealWorldItemNFT.TransferRecord[] memory history = realWorldItem.getHistory(0);
        assertEq(history.length, 1);
        assertEq(history[0].from, address(0));
        assertEq(history[0].to, USER);
    }

    function test_RevertWhen_MintWithZeroAddressFinalRecipient() public {
        // arrange
        RealWorldItemNFT.MintParams memory params = RealWorldItemNFT.MintParams({
            realId: REAL_ID,
            to: USER,
            itemName: ITEM_NAME,
            locationOrigin: locationOrigin,
            finalRecipient: address(0)
        });

        // act & assert
        vm.expectRevert(RealWorldItemNFT.InvalidAddress.selector);
        realWorldItem.mint(params);
    }

    function test_RevertWhen_MintWithEmptyItemName() public {
        // arrange
        RealWorldItemNFT.MintParams memory params = RealWorldItemNFT.MintParams({
            realId: REAL_ID,
            to: USER,
            itemName: "",
            locationOrigin: locationOrigin,
            finalRecipient: RECIPIENT
        });

        // act & assert
        vm.expectRevert(RealWorldItemNFT.EmptyString.selector);
        realWorldItem.mint(params);
    }

    function test_RevertWhen_MintWithEmptylocationOrigin() public {
        // arrange
        RealWorldItemNFT.MintParams memory params = RealWorldItemNFT.MintParams({
            realId: REAL_ID,
            to: USER,
            itemName: ITEM_NAME,
            locationOrigin: "",
            finalRecipient: RECIPIENT
        });

        // act & assert
        vm.expectRevert(RealWorldItemNFT.EmptyString.selector);
        realWorldItem.mint(params);
    }

    /*//////////////////////////////////////////////////////////////
                        TRANSFER TESTS
    //////////////////////////////////////////////////////////////*/

    function test_TransferItem() public {
        // arrange - first mint an item
        RealWorldItemNFT.MintParams memory params = RealWorldItemNFT.MintParams({
            realId: REAL_ID,
            to: USER,
            itemName: ITEM_NAME,
            locationOrigin: locationOrigin,
            finalRecipient: RECIPIENT
        });
        realWorldItem.mint(params);

        // act - transfer the item using realId instead of tokenId
        vm.prank(USER);
        realWorldItem.transferItem(REAL_ID, RECIPIENT);

        // assert
        assertEq(realWorldItem.ownerOf(0), RECIPIENT);
        
        RealWorldItemNFT.TransferRecord[] memory history = realWorldItem.getHistory(0);
        assertEq(history.length, 2);
        assertEq(history[1].from, USER);
        assertEq(history[1].to, RECIPIENT);
    }

    function test_RevertWhen_TransferFromNonOwner() public {
        // arrange - first mint an item
        RealWorldItemNFT.MintParams memory params = RealWorldItemNFT.MintParams({
            realId: REAL_ID,
            to: USER,
            itemName: ITEM_NAME,
            locationOrigin: locationOrigin,
            finalRecipient: RECIPIENT
        });
        realWorldItem.mint(params);

        // act & assert
        vm.prank(OWNER); // try to transfer as non-owner
        vm.expectRevert(RealWorldItemNFT.NotCurrentOwner.selector);
        realWorldItem.transferItem(REAL_ID, RECIPIENT);
    }

    function test_RevertWhen_TransferToZeroAddress() public {
        // arrange - first mint an item
        RealWorldItemNFT.MintParams memory params = RealWorldItemNFT.MintParams({
            realId: REAL_ID,
            to: USER,
            itemName: ITEM_NAME,
            locationOrigin: locationOrigin,
            finalRecipient: RECIPIENT
        });
        realWorldItem.mint(params);

        // act & assert
        vm.prank(USER);
        vm.expectRevert(RealWorldItemNFT.InvalidAddress.selector);
        realWorldItem.transferItem(REAL_ID, address(0));
    }

    // Add new test for non-existent realId
    function test_RevertWhen_TransferNonExistentItem() public {
        vm.prank(USER);
        vm.expectRevert(RealWorldItemNFT.ItemNotFound.selector);
        realWorldItem.transferItem("NONEXISTENT_ID", RECIPIENT);
    }

    /*//////////////////////////////////////////////////////////////
                         GETTER TESTS
    //////////////////////////////////////////////////////////////*/

    function test_GetItemDetailsByRealId() public {
        // arrange - first mint an item
        RealWorldItemNFT.MintParams memory params = RealWorldItemNFT.MintParams({
            realId: REAL_ID,
            to: USER,
            itemName: ITEM_NAME,
            locationOrigin: locationOrigin,
            finalRecipient: RECIPIENT
        });
        realWorldItem.mint(params);

        // act
        RealWorldItemNFT.ItemDetails memory details = realWorldItem.getItemDetailsByRealId(REAL_ID);

        // assert
        assertEq(details.s_itemName, ITEM_NAME);
        assertEq(details.s_locationOrigin, locationOrigin);
        assertEq(details.s_finalRecipient, RECIPIENT);
        assertEq(details.s_itemIdentifier, REAL_ID);
    }

    function test_RevertWhen_GetItemDetailsByNonexistentRealId() public {
        // act & assert
        vm.expectRevert(RealWorldItemNFT.ItemNotFound.selector);
        realWorldItem.getItemDetailsByRealId("NONEXISTENT_ID");
    }

    function test_GetHistory() public {
        // arrange - first mint an item and make a transfer
        RealWorldItemNFT.MintParams memory params = RealWorldItemNFT.MintParams({
            realId: REAL_ID,
            to: USER,
            itemName: ITEM_NAME,
            locationOrigin: locationOrigin,
            finalRecipient: RECIPIENT
        });
        realWorldItem.mint(params);

        vm.prank(USER);
        realWorldItem.transferItem(REAL_ID, RECIPIENT);

        // act
        RealWorldItemNFT.TransferRecord[] memory history = realWorldItem.getHistory(0);

        // assert
        assertEq(history.length, 2);
        // check first transfer (mint)
        assertEq(history[0].from, address(0));
        assertEq(history[0].to, USER);
        // check second transfer
        assertEq(history[1].from, USER);
        assertEq(history[1].to, RECIPIENT);
    }

    function test_OwnerOfByRealId() public {
        // arrange - first mint an item
        RealWorldItemNFT.MintParams memory params = RealWorldItemNFT.MintParams({
            realId: REAL_ID,
            to: USER,
            itemName: ITEM_NAME,
            locationOrigin: locationOrigin,
            finalRecipient: RECIPIENT
        });
        realWorldItem.mint(params);

        // act
        address owner = realWorldItem.ownerOfByRealId(REAL_ID);

        // assert
        assertEq(owner, USER);

        // transfer the item and check new owner
        vm.prank(USER);
        realWorldItem.transferItem(REAL_ID, RECIPIENT);
        
        address newOwner = realWorldItem.ownerOfByRealId(REAL_ID);
        assertEq(newOwner, RECIPIENT);
    }

    function test_RevertWhen_OwnerOfByNonexistentRealId() public {
        // act & assert
        vm.expectRevert(RealWorldItemNFT.ItemNotFound.selector);
        realWorldItem.ownerOfByRealId("NONEXISTENT_ID");
    }
}
