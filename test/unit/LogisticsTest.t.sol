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

        // verify recipientReached is false initially
        RealWorldItemNFT.ItemDetails memory details = realWorldItem.getItemDetailsByRealId(REAL_ID);
        assertEq(details.s_recipientReached, false);
        assertEq(details.s_originAddress, USER, "Origin address should be set to the initial recipient");
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

        // verify recipientReached is true
        RealWorldItemNFT.ItemDetails memory details = realWorldItem.getItemDetailsByRealId(REAL_ID);
        assertEq(details.s_recipientReached, true, "Should be marked as reached when transferred to final recipient");
        assertEq(details.s_originAddress, USER, "Origin address should remain unchanged after transfer");

        // try to transfer away from final recipient - should revert
        vm.prank(RECIPIENT);
        vm.expectRevert(RealWorldItemNFT.ItemAlreadyReachedFinalRecipient.selector);
        realWorldItem.transferItem(REAL_ID, USER);

        // verify recipientReached is still true
        details = realWorldItem.getItemDetailsByRealId(REAL_ID);
        assertEq(details.s_recipientReached, true, "Should remain marked as reached after attempted transfer");
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
        assertEq(details.s_recipientReached, false);
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

        // verify recipientReached is true after transfer to final recipient
        RealWorldItemNFT.ItemDetails memory details = realWorldItem.getItemDetailsByRealId(REAL_ID);
        assertEq(details.s_recipientReached, true);
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

        // verify recipientReached is true
        RealWorldItemNFT.ItemDetails memory details = realWorldItem.getItemDetailsByRealId(REAL_ID);
        assertEq(details.s_recipientReached, true);
    }

    function test_RevertWhen_OwnerOfByNonexistentRealId() public {
        // act & assert
        vm.expectRevert(RealWorldItemNFT.ItemNotFound.selector);
        realWorldItem.ownerOfByRealId("NONEXISTENT_ID");
    }

    function test_GetAllRealIdsByAddress() public {
        // arrange - mint multiple items for USER
        string memory realId1 = "TEST123";
        string memory realId2 = "TEST456";
        
        RealWorldItemNFT.MintParams memory params1 = RealWorldItemNFT.MintParams({
            realId: realId1,
            to: USER,
            itemName: ITEM_NAME,
            locationOrigin: locationOrigin,
            finalRecipient: RECIPIENT
        });

        RealWorldItemNFT.MintParams memory params2 = RealWorldItemNFT.MintParams({
            realId: realId2,
            to: USER,
            itemName: ITEM_NAME,
            locationOrigin: locationOrigin,
            finalRecipient: RECIPIENT
        });

        realWorldItem.mint(params1);
        realWorldItem.mint(params2);

        // act
        string[] memory userRealIds = realWorldItem.getAllRealIdsByAddress(USER);

        // assert
        assertEq(userRealIds.length, 2);
        assertEq(userRealIds[0], realId1);
        assertEq(userRealIds[1], realId2);
    }

    function test_GetAllRealIdsByAddress_EmptyForNewAddress() public {
        // act
        string[] memory realIds = realWorldItem.getAllRealIdsByAddress(makeAddr("newUser"));

        // assert
        assertEq(realIds.length, 0);
    }

    function test_GetAllRealIdsByAddress_AfterTransfer() public {
        // arrange - mint an item for USER
        string memory realId = "TEST123";
        RealWorldItemNFT.MintParams memory params = RealWorldItemNFT.MintParams({
            realId: realId,
            to: USER,
            itemName: ITEM_NAME,
            locationOrigin: locationOrigin,
            finalRecipient: RECIPIENT
        });
        realWorldItem.mint(params);

        // act - transfer the item to RECIPIENT
        vm.prank(USER);
        realWorldItem.transferItem(realId, RECIPIENT);

        // assert - check both addresses
        string[] memory userRealIds = realWorldItem.getAllRealIdsByAddress(USER);
        string[] memory recipientRealIds = realWorldItem.getAllRealIdsByAddress(RECIPIENT);

        assertEq(userRealIds.length, 0, "Original owner should have no items");
        assertEq(recipientRealIds.length, 1, "Recipient should have one item");
        assertEq(recipientRealIds[0], realId, "Recipient should have the transferred item");
    }

    function test_GetAllAddressesWithDetails() public {
        // arrange - mint multiple items with different parameters
        address recipient2 = makeAddr("recipient2");
        
        RealWorldItemNFT.MintParams memory params1 = RealWorldItemNFT.MintParams({
            realId: "TEST123",
            to: USER,
            itemName: "Item 1",
            locationOrigin: "Location 1",
            finalRecipient: RECIPIENT
        });

        RealWorldItemNFT.MintParams memory params2 = RealWorldItemNFT.MintParams({
            realId: "TEST456",
            to: RECIPIENT,
            itemName: "Item 2",
            locationOrigin: "Location 2",
            finalRecipient: recipient2
        });

        // mint the items
        realWorldItem.mint(params1);
        realWorldItem.mint(params2);

        // transfer first item to create some history
        vm.prank(USER);
        realWorldItem.transferItem("TEST123", RECIPIENT);

        // act
        RealWorldItemNFT.MintParams[] memory allDetails = realWorldItem.getAllAddressesWithDetails();
        RealWorldItemNFT.ItemDetails memory item1Details = realWorldItem.getItemDetailsByRealId("TEST123");
        RealWorldItemNFT.ItemDetails memory item2Details = realWorldItem.getItemDetailsByRealId("TEST456");

        // assert
        assertEq(allDetails.length, 2, "Should return details for 2 items");

        // verify first item details
        assertEq(allDetails[0].realId, "TEST123", "First item realId should match");
        assertEq(allDetails[0].to, RECIPIENT, "First item current owner should be RECIPIENT after transfer");
        assertEq(allDetails[0].itemName, "Item 1", "First item name should match");
        assertEq(allDetails[0].locationOrigin, "Location 1", "First item location should match");
        assertEq(allDetails[0].finalRecipient, RECIPIENT, "First item final recipient should match");
        assertEq(item1Details.s_recipientReached, true, "First item should be marked as reached");

        // verify second item details
        assertEq(allDetails[1].realId, "TEST456", "Second item realId should match");
        assertEq(allDetails[1].to, RECIPIENT, "Second item owner should match");
        assertEq(allDetails[1].itemName, "Item 2", "Second item name should match");
        assertEq(allDetails[1].locationOrigin, "Location 2", "Second item location should match");
        assertEq(allDetails[1].finalRecipient, recipient2, "Second item final recipient should match");
        assertEq(item2Details.s_recipientReached, false, "Second item should not be marked as reached");
    }

    // Update test_RecipientReachedStatus to reflect one-way flag behavior
    function test_RecipientReachedStatus() public {
        // arrange - first mint an item
        RealWorldItemNFT.MintParams memory params = RealWorldItemNFT.MintParams({
            realId: REAL_ID,
            to: USER,
            itemName: ITEM_NAME,
            locationOrigin: locationOrigin,
            finalRecipient: RECIPIENT
        });
        realWorldItem.mint(params);

        // verify initial state
        RealWorldItemNFT.ItemDetails memory details = realWorldItem.getItemDetailsByRealId(REAL_ID);
        assertEq(details.s_recipientReached, false, "Should start as not reached");

        // transfer to non-final recipient
        address intermediary = makeAddr("intermediary");
        vm.prank(USER);
        realWorldItem.transferItem(REAL_ID, intermediary);

        // verify still not reached
        details = realWorldItem.getItemDetailsByRealId(REAL_ID);
        assertEq(details.s_recipientReached, false, "Should still be not reached after transfer to intermediary");

        // transfer to final recipient
        vm.prank(intermediary);
        realWorldItem.transferItem(REAL_ID, RECIPIENT);

        // verify reached status is true
        details = realWorldItem.getItemDetailsByRealId(REAL_ID);
        assertEq(details.s_recipientReached, true, "Should be marked as reached when transferred to final recipient");

        // attempt to transfer away from final recipient - should revert
        vm.prank(RECIPIENT);
        vm.expectRevert(RealWorldItemNFT.ItemAlreadyReachedFinalRecipient.selector);
        realWorldItem.transferItem(REAL_ID, USER);

        // verify reached status is still true
        details = realWorldItem.getItemDetailsByRealId(REAL_ID);
        assertEq(details.s_recipientReached, true, "Should remain marked as reached after attempted transfer");
    }

    // Add new test for attempting multiple transfers after reaching final recipient
    function test_RevertWhen_TransferAfterReachingFinalRecipient() public {
        // arrange - first mint an item
        RealWorldItemNFT.MintParams memory params = RealWorldItemNFT.MintParams({
            realId: REAL_ID,
            to: USER,
            itemName: ITEM_NAME,
            locationOrigin: locationOrigin,
            finalRecipient: RECIPIENT
        });
        realWorldItem.mint(params);

        // transfer to final recipient
        vm.prank(USER);
        realWorldItem.transferItem(REAL_ID, RECIPIENT);

        // verify item reached final recipient
        RealWorldItemNFT.ItemDetails memory details = realWorldItem.getItemDetailsByRealId(REAL_ID);
        assertEq(details.s_recipientReached, true, "Should be marked as reached");
        assertEq(realWorldItem.ownerOf(0), RECIPIENT, "Final recipient should own the item");

        // attempt multiple transfers - all should fail
        address[] memory attemptedRecipients = new address[](3);
        attemptedRecipients[0] = USER;
        attemptedRecipients[1] = makeAddr("newUser1");
        attemptedRecipients[2] = makeAddr("newUser2");

        for(uint i = 0; i < attemptedRecipients.length; i++) {
            vm.prank(RECIPIENT);
            vm.expectRevert(RealWorldItemNFT.ItemAlreadyReachedFinalRecipient.selector);
            realWorldItem.transferItem(REAL_ID, attemptedRecipients[i]);

            // verify ownership and status haven't changed
            assertEq(realWorldItem.ownerOf(0), RECIPIENT, "Ownership should not change after failed transfer");
            details = realWorldItem.getItemDetailsByRealId(REAL_ID);
            assertEq(details.s_recipientReached, true, "Should remain marked as reached after failed transfer");
        }
    }

    function test_GetItemDetailsByAddress() public {
        // arrange - mint multiple items with different parameters
        RealWorldItemNFT.MintParams memory params1 = RealWorldItemNFT.MintParams({
            realId: "TEST123",
            to: USER,
            itemName: "Item 1",
            locationOrigin: "Location 1",
            finalRecipient: RECIPIENT
        });

        RealWorldItemNFT.MintParams memory params2 = RealWorldItemNFT.MintParams({
            realId: "TEST456",
            to: USER,
            itemName: "Item 2",
            locationOrigin: "Location 2",
            finalRecipient: RECIPIENT
        });

        // mint the items
        realWorldItem.mint(params1);
        realWorldItem.mint(params2);

        // act - get details for USER who owns both items
        RealWorldItemNFT.ItemDetails[] memory userDetails = realWorldItem.getItemDetailsByAddress(USER);

        // assert
        assertEq(userDetails.length, 2, "Should return details for 2 items");

        // verify first item details
        assertEq(userDetails[0].s_itemName, "Item 1", "First item name should match");
        assertEq(userDetails[0].s_locationOrigin, "Location 1", "First item location should match");
        assertEq(userDetails[0].s_finalRecipient, RECIPIENT, "First item final recipient should match");
        assertEq(userDetails[0].s_itemIdentifier, "TEST123", "First item realId should match");
        assertEq(userDetails[0].s_recipientReached, false, "First item should not be marked as reached");

        // verify second item details
        assertEq(userDetails[1].s_itemName, "Item 2", "Second item name should match");
        assertEq(userDetails[1].s_locationOrigin, "Location 2", "Second item location should match");
        assertEq(userDetails[1].s_finalRecipient, RECIPIENT, "Second item final recipient should match");
        assertEq(userDetails[1].s_itemIdentifier, "TEST456", "Second item realId should match");
        assertEq(userDetails[1].s_recipientReached, false, "Second item should not be marked as reached");

        // test empty address
        RealWorldItemNFT.ItemDetails[] memory emptyDetails = realWorldItem.getItemDetailsByAddress(makeAddr("emptyAddress"));
        assertEq(emptyDetails.length, 0, "Should return empty array for address with no items");

        // test after transfer
        vm.prank(USER);
        realWorldItem.transferItem("TEST123", RECIPIENT);

        // check USER's details after transfer
        RealWorldItemNFT.ItemDetails[] memory userDetailsAfterTransfer = realWorldItem.getItemDetailsByAddress(USER);
        assertEq(userDetailsAfterTransfer.length, 1, "Should now have only 1 item");
        assertEq(userDetailsAfterTransfer[0].s_itemIdentifier, "TEST456", "Remaining item should be TEST456");

        // check RECIPIENT's details after transfer
        RealWorldItemNFT.ItemDetails[] memory recipientDetails = realWorldItem.getItemDetailsByAddress(RECIPIENT);
        assertEq(recipientDetails.length, 1, "Should have 1 item");
        assertEq(recipientDetails[0].s_itemIdentifier, "TEST123", "Should have received TEST123");
        assertEq(recipientDetails[0].s_recipientReached, true, "Item should be marked as reached for final recipient");
    }

    function test_GetItemDetailsByOriginAddress() public {
        // arrange - mint multiple items with different origin addresses
        address originUser1 = makeAddr("originUser1");
        address originUser2 = makeAddr("originUser2");

        RealWorldItemNFT.MintParams memory params1 = RealWorldItemNFT.MintParams({
            realId: "TEST123",
            to: originUser1,
            itemName: "Item 1",
            locationOrigin: "Location 1",
            finalRecipient: RECIPIENT
        });

        RealWorldItemNFT.MintParams memory params2 = RealWorldItemNFT.MintParams({
            realId: "TEST456",
            to: originUser1,
            itemName: "Item 2",
            locationOrigin: "Location 2",
            finalRecipient: RECIPIENT
        });

        RealWorldItemNFT.MintParams memory params3 = RealWorldItemNFT.MintParams({
            realId: "TEST789",
            to: originUser2,
            itemName: "Item 3",
            locationOrigin: "Location 3",
            finalRecipient: RECIPIENT
        });

        // mint the items
        realWorldItem.mint(params1);
        realWorldItem.mint(params2);
        realWorldItem.mint(params3);

        // transfer some items to create history (shouldn't affect origin address)
        vm.prank(originUser1);
        realWorldItem.transferItem("TEST123", USER);
        vm.prank(originUser2);
        realWorldItem.transferItem("TEST789", USER);

        // act - get details for originUser1 who originated two items
        RealWorldItemNFT.ItemDetails[] memory originUser1Details = realWorldItem.getItemDetailsByOriginAddress(originUser1);

        // assert
        assertEq(originUser1Details.length, 2, "Should return details for 2 items");

        // verify first item details
        assertEq(originUser1Details[0].s_itemName, "Item 1", "First item name should match");
        assertEq(originUser1Details[0].s_locationOrigin, "Location 1", "First item location should match");
        assertEq(originUser1Details[0].s_finalRecipient, RECIPIENT, "First item final recipient should match");
        assertEq(originUser1Details[0].s_itemIdentifier, "TEST123", "First item realId should match");
        assertEq(originUser1Details[0].s_originAddress, originUser1, "First item origin address should match");

        // verify second item details
        assertEq(originUser1Details[1].s_itemName, "Item 2", "Second item name should match");
        assertEq(originUser1Details[1].s_locationOrigin, "Location 2", "Second item location should match");
        assertEq(originUser1Details[1].s_finalRecipient, RECIPIENT, "Second item final recipient should match");
        assertEq(originUser1Details[1].s_itemIdentifier, "TEST456", "Second item realId should match");
        assertEq(originUser1Details[1].s_originAddress, originUser1, "Second item origin address should match");

        // test originUser2 who originated one item
        RealWorldItemNFT.ItemDetails[] memory originUser2Details = realWorldItem.getItemDetailsByOriginAddress(originUser2);
        assertEq(originUser2Details.length, 1, "Should return details for 1 item");
        assertEq(originUser2Details[0].s_itemIdentifier, "TEST789", "Should have correct realId");
        assertEq(originUser2Details[0].s_originAddress, originUser2, "Should have correct origin address");

        // test address that hasn't originated any items
        RealWorldItemNFT.ItemDetails[] memory emptyDetails = realWorldItem.getItemDetailsByOriginAddress(makeAddr("emptyAddress"));
        assertEq(emptyDetails.length, 0, "Should return empty array for address with no originated items");
    }
}
