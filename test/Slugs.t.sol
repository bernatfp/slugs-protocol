pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/Slugs.sol";

contract SlugsTest is Test {
    Slugs slugs;
    string testUrl = "https://example.com";
    string vanitySlug = "vanity";
    string subSlug = "subslug";

    function setUp() public {
        slugs = new Slugs();
    }

    function test_owner() public {
        assertEq(slugs.owner(), address(this));
    }

    function test_mintSlug() public {
        string memory slug = slugs.mintSlug(testUrl, "", address(1));
        assertEq(slugs.urls(slug), testUrl);
    }

    function test_getURL() public {
        string memory slug = slugs.mintSlug(testUrl, "", address(1));
        string memory url = slugs.getURL(slug);
        assertEq(url, testUrl);
    }

    function testFail_shortenEmptyURL() public {
        slugs.mintSlug("", "", address(1));
    }

    function testFail_getEmptyURL() public view {
        slugs.getURL("");
    }

    function testFail_getNonexistentURL() public view {
        slugs.getURL("nonexistent");
    }

    function test_costs() public {
        assertEq(slugs.getSlugCost(bytes("a").length), 1 ether);
        assertEq(slugs.getSlugCost(bytes("abcd").length), 0.1 ether);
        assertEq(slugs.getSlugCost(bytes("abcdefgh").length), 0.01 ether);
        assertEq(slugs.getSlugCost(bytes("abcdefghjkl").length), 0.01 ether);
    }

    function test_registerVanitySlug() public {
        uint256 slugCost = slugs.getSlugCost(bytes(vanitySlug).length);
        slugs.mintSlug{value: slugCost}(testUrl, vanitySlug, address(1));
        assertEq(slugs.urls(vanitySlug), testUrl);
    }

    function testFail_registerExistentVanitySlug() public {
        uint256 slugCost = slugs.getSlugCost(bytes(vanitySlug).length);
        slugs.mintSlug{value: slugCost}(testUrl, vanitySlug, address(1));
        assertEq(slugs.urls(vanitySlug), testUrl);

        address alice = makeAddr("alice");
        vm.startPrank(alice);
        slugs.mintSlug{value: slugCost}(testUrl, "https://anothernewurl.com", address(1));
        vm.stopPrank();
    }

    function test_editVanitySlug() public {
        uint256 slugCost = slugs.getSlugCost(bytes(vanitySlug).length);
        slugs.mintSlug{value: slugCost}(testUrl, vanitySlug, address(1));
        slugs.editUrl(slugs.getTokenId(vanitySlug), "https://newurl.com");
        assertEq(slugs.urls(vanitySlug), "https://newurl.com");
    }

    function testFail_editNonOwnerVanitySlug() public {
        uint256 slugCost = slugs.getSlugCost(bytes(vanitySlug).length);
        slugs.mintSlug{value: slugCost}(vanitySlug, testUrl, address(1));

        address alice = makeAddr("alice");
        vm.startPrank(alice);
        slugs.editUrl(slugs.getTokenId(vanitySlug), "https://anothernewurl.com");
        vm.stopPrank();
    }

    function testFail_editDifferentAccountVanitySlug() public {
        slugs.editUrl(slugs.getTokenId(vanitySlug), "https://newurl.com");
    }

    function testFail_editInexistentVanitySlug() public {
        slugs.editUrl(slugs.getTokenId("inexistent"), "https://newurl.com");
    }

    function test_pauseFunctionality() public {
        assertFalse(slugs.paused());
        slugs.pause();
        assertTrue(slugs.paused());
        slugs.unpause();
        assertFalse(slugs.paused());
    }

    function testFail_mintSlugWhenPaused() public {
        slugs.pause();
        assertTrue(slugs.paused());
        slugs.mintSlug(testUrl, "", address(1));
    }

    function testFail_pauseByNonOwner() public {
        address alice = makeAddr("alice");
        vm.startPrank(alice);
        slugs.pause();
        vm.stopPrank();
    }

    function test_dealETH() public {
        uint256 initialBalance = address(slugs).balance;
        uint256 amount = 1 ether;
        vm.deal(address(slugs), amount);
        assertEq(address(slugs).balance, initialBalance + amount);
    }

    function test_withdrawETH() public {
        // Transfer ownership to avoid fallback issues with Test contract instance
        address alice = makeAddr("alice");
        slugs.transferOwnership(alice);

        uint256 initialBalance = address(alice).balance;
        uint256 amount = 1 ether;

        // Send owner's amount to the contract
        (bool success,) = address(slugs).call{value: amount}("");
        require(success, "ETH transfer failed");

        // Owner rescues funds
        vm.startPrank(alice);
        slugs.claimBalance();
        vm.stopPrank();

        // Check that the funds have been rescued
        assertEq(address(alice).balance, initialBalance + amount);
    }

    function test_claimBalanceNoReferral() public {
        // Transfer ownership to avoid fallback issues with Test contract instance
        address alice = makeAddr("alice");
        slugs.transferOwnership(alice);

        // Mint vanity to generate fees
        uint256 slugCost = slugs.getSlugCost(bytes(vanitySlug).length);
        slugs.mintSlug{value: slugCost}(testUrl, vanitySlug, address(0));

        // Owner balance
        uint256 initialBalance = address(alice).balance;

        // Owner claims all fees because no referral
        vm.startPrank(alice);
        slugs.claimBalance();
        vm.stopPrank();

        assertEq(initialBalance + slugCost, address(alice).balance);
    }

    function test_claimBalanceWithReferral() public {
        // Transfer ownership to avoid fallback issues with Test contract instance
        address alice = makeAddr("alice");
        slugs.transferOwnership(alice);

        // Mint vanity to generate fees
        uint256 slugCost = slugs.getSlugCost(bytes(vanitySlug).length);
        address referrer = makeAddr("bob");
        slugs.mintSlug{value: slugCost}(testUrl, vanitySlug, referrer);

        // Estimate fees
        uint256 referrerFees = slugCost * slugs.referrerFeeBips() / 10000; // cannot load Slugs.MAX_FEE
        uint256 protocolFees = slugCost - referrerFees;
        assertEq(slugCost, referrerFees + protocolFees);

        // Check balances add up
        assertEq(protocolFees, slugs.balances(alice));
        assertEq(referrerFees, slugs.balances(referrer));

        // Owner balance
        uint256 initialBalance = address(alice).balance;

        // Owner claims fees
        vm.startPrank(alice);
        slugs.claimBalance();
        vm.stopPrank();

        // Owner fees should match balance delta
        assertEq(protocolFees, address(alice).balance - initialBalance);

        // Referrer balance
        uint256 initialReferrerBalance = address(referrer).balance;

        // Referrer claims fees
        vm.startPrank(referrer);
        slugs.claimBalance();
        vm.stopPrank();

        // Referrer fees should match balance delta
        assertEq(referrerFees, address(referrer).balance - initialReferrerBalance);
    }

    function testFail_editWithEmptyURL() public {
        slugs.mintSlug(testUrl, vanitySlug, address(1));
        slugs.editUrl(slugs.getTokenId(vanitySlug), "");
    }

    function testFail_mintWithInsufficientAmount() public {
        slugs.mintSlug{value: 0.5 ether}(testUrl, "a", address(1));
    }

    function test_transferSlugOwnership() public {
        uint256 slugCost = slugs.getSlugCost(bytes(vanitySlug).length);
        slugs.mintSlug{value: slugCost}(testUrl, vanitySlug, address(1));
        address bob = makeAddr("bob");
        slugs.transferFrom(address(this), bob, slugs.getTokenId(vanitySlug));
        assertEq(slugs.ownerOf(slugs.getTokenId(vanitySlug)), bob);
    }

    function testFail_transferSlugNotOwned() public {
        address alice = makeAddr("alice");
        address bob = makeAddr("bob");
        vm.startPrank(alice);
        uint256 slugCost = slugs.getSlugCost(bytes(vanitySlug).length);
        slugs.mintSlug{value: slugCost}(testUrl, vanitySlug, address(1));
        vm.stopPrank();
        vm.startPrank(bob);
        slugs.transferFrom(bob, makeAddr("charlie"), slugs.getTokenId(vanitySlug));
        vm.stopPrank();
    }

}
