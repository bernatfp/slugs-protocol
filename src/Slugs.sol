pragma solidity ^0.8.13;

import "openzeppelin-contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "openzeppelin-contracts/token/ERC721/IERC721.sol";
import "openzeppelin-contracts/token/ERC20/IERC20.sol";
import "openzeppelin-contracts/access/Ownable.sol";
import "openzeppelin-contracts/security/Pausable.sol";
import "openzeppelin-contracts/utils/Base64.sol";
import "openzeppelin-contracts/utils/Strings.sol";

/**
 * @title Slugs
 * @author bernat.eth
 * @notice This contract implements the Slugs protocol, which allows for the creation and management of unique slug NFTs that map to URLs.
 * Each slug is associated with a unique URL.
 * Random slugs can be generated at no cost (other than gas fees), while custom slugs entail a mint fee.
 * The contract also includes functionality for referrers to earn a share of mint fees.
 */

contract Slugs is ERC721Enumerable, Ownable, Pausable {
    struct SlugData {
        string slug;
        bool isCustom;
    }

    uint256 public idCounter;
    uint256 public referrerFeeBips;
    mapping(string => string) public urls;
    mapping(string => uint256) public slugToTokenId;
    mapping(uint256 => SlugData) public tokenIdToSlugData;
    mapping(address => uint256) public balances;

    event NewSlug(address indexed sender, string url, string slug, uint256 tokenId, bool isCustom, address referrer);

    bytes constant CHARSET = "0123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz"; // 58 chars
    uint256 constant MAX_FEE = 10000;

    uint256[9] private PRICES = [0 ether, 1 ether, 0.5 ether, 0.25 ether, 0.1 ether, 0.05 ether, 0.03 ether, 0.02 ether, 0.01 ether];

    constructor()
        ERC721(
            "Slugs", // Name of token
            "SLUGS" // Symbol of token
        )
    {
        idCounter = 0;
        referrerFeeBips = 50 * 100; // 50%
    }

    ///////////// Transactional methods /////////////

    /**
     * @notice Mint a new slug.
     * @dev Referrer is required but can be the zero address.
     *
     * Requirements:
     * - `url` cannot be empty.
     * - `slug` must not already exist.
     * - `referrer` cannot be the sender.
     *
     * Random slugs are generated when slug is an empty string, and can be created at no cost.
     * If a custom slug is provided, an ETH amount equal or greater to the mint fee needs to be provided. See getSlugCost for more details.
     *
     * Emits a {NewSlug} event.
     *
     * @param url The URL associated with the new slug.
     * @param slug The custom slug to be created. If empty, a random slug is generated.
     * @param referrer The address of the referrer. Can be the zero address.
     * @return Returns the slug that was created.
     */
    function mintSlug(string memory url, string memory slug, address referrer)
        public
        payable
        whenNotPaused
        returns (string memory)
    {
        require(bytes(url).length > 0, "URL cannot be empty");
        require(bytes(urls[slug]).length == 0, "Slug already exists");
        require(msg.sender != referrer, "Referrer cannot be sender");

        bool isCustom;

        // If no custom slug provided, generate an available random one
        if (bytes(slug).length == 0) {
            slug = generateAvailableSlug();
            isCustom = false;
        // Custom slug
        } else {
            isCustom = true;
            handleCustomSlugPayment(slug, referrer);
        }

        // Register slug -> url mapping
        _mintSlug(slug, url, isCustom);

        emit NewSlug(msg.sender, url, slug, idCounter, isCustom, referrer);

        return slug;
    }

    /**
     * @dev Edits the URL of a slug.
     *
     * Requirements:
     * - `tokenId` must be owned by the caller.
     * - `newUrl` cannot be empty.
     *
     * @param tokenId The ID of the token (slug) to edit.
     * @param newUrl The new URL to associate with the slug.
     */
    function editUrl(uint256 tokenId, string memory newUrl) public {
        require(ownerOf(tokenId) == msg.sender, "Caller is not owner nor approved");
        require(bytes(newUrl).length > 0, "URL cannot be empty");

        string memory slug = tokenIdToSlugData[tokenId].slug;
        urls[slug] = newUrl;
    }

    /**
     * @dev Claims the ETH balance associated with the caller's address.
     *
     * Requirements:
     * - The caller must have a non-zero balance.
     *
     * Emits a {Transfer} event.
     */
    function claimBalance() public {
        uint256 balance = balances[msg.sender];
        require(balance > 0, "No balance to claim");
        balances[msg.sender] = 0;
        payable(msg.sender).transfer(balance);
    }

    receive() external payable {
        balances[owner()] += msg.value;
    }

    ///////////// Private methods /////////////

    // Generate an available random slug
    function generateAvailableSlug() private view returns (string memory) {
        string memory slug = generateSlug(idCounter);

        // avoid collisions
        while (bytes(urls[slug]).length != 0) {
            slug = incrementSlug(slug);
        }

        return slug;
    }

    // Generate a random slug
    function generateSlug(uint256 seed) private pure returns (string memory) {
        uint256 hash = uint256(keccak256(abi.encodePacked(seed)));
        string memory slug = "";
        for (uint8 i = 0; i < 8; i++) {
            slug = string(abi.encodePacked(slug, CHARSET[hash % 58])); // charset is 58 chars long
            hash = hash >> 6; // 2 ** 6 > 58 > 2 ** 5
        }
        return slug;
    }

    // Given a slug, increment it by 1 character covering the entire combinatorial charset space
    function incrementSlug(string memory slug) private pure returns (string memory) {
        bytes memory b = bytes(slug);
        for (uint8 i = 7; i >= 0; i--) {
            if (b[i] != CHARSET[57]) {
                b[i] = getNextChar(b[i]);
                return string(b);
            } else {
                b[i] = CHARSET[0]; // Reset to the first character in the CHARSET
            }
        }
        return "00000000";  // This will only be hit if all characters in the slug are the last character in CHARSET.
    }

    function getNextChar(bytes1 char) private pure returns (bytes1) {
        for (uint8 i = 0; i < 57; i++) {
            if (CHARSET[i] == char) {
                return CHARSET[i + 1];
            }
        }
        // If provided with the last character in the CHARSET, just return it.
        return char;
    }

    function handleCustomSlugPayment(string memory slug, address referrer) private {
        uint256 slugLength = bytes(slug).length;
        uint256 cost = getSlugCost(slugLength);
        require(msg.value >= cost, "Insufficient payment");

        if (msg.value > cost) {
            payable(msg.sender).transfer(msg.value - cost);
        }

        if (referrer == address(0)) {
            referrer = owner();
        }

        uint256 referrerFees = cost * referrerFeeBips / MAX_FEE;
        balances[referrer] += referrerFees;
        balances[owner()] += cost - referrerFees;
    }

    function _mintSlug(string memory slug, string memory url, bool isCustom) private {
        urls[slug] = url;
        idCounter++;
        _mint(msg.sender, idCounter);
        slugToTokenId[slug] = idCounter;
        tokenIdToSlugData[idCounter] = SlugData(slug, isCustom);
    }

    ///////////// Public view methods /////////////

    /**
     * @notice Fetches the token ID associated with a given slug.
     * @dev This function requires that the slug is not empty and exists.
     * @param slug The slug for which to fetch the token ID.
     * @return Returns the token ID associated with the given slug.
     */
    function getTokenId(string memory slug) public view returns (uint256) {
        require(bytes(slug).length > 0, "Slug cannot be empty");
        require(bytes(urls[slug]).length > 0, "Slug does not exist");
        return slugToTokenId[slug];
    }

    /**
     * @notice Fetches the URL associated with a given slug.
     * @dev This function requires that the slug is not empty and exists.
     * @param slug The slug for which to fetch the URL.
     * @return Returns the URL associated with the given slug.
     */
    function getURL(string memory slug) public view returns (string memory) {
        require(bytes(slug).length > 0, "Slug cannot be empty");
        require(bytes(urls[slug]).length > 0, "Slug does not exist");
        return urls[slug];
    }

    /**
     * @notice Calculates the cost of a slug based on its length.
     * @dev The cost is determined by a set of predefined rules.
     * @param slugLength The length of the slug.
     * @return Returns the cost of the slug in ether.
     */
    function getSlugCost(uint256 slugLength) public view returns (uint256) {
        if (slugLength >= PRICES.length) {
            return PRICES[PRICES.length - 1];
        }
        return PRICES[slugLength];
    }

    /**
     * @notice Returns a URI for a given token ID
     * @dev Overrides ERC721's tokenURI() with metadata that includes the slug and its attributes
     * @param tokenId The ID of the token to query
     * @return A string containing the URI of the given token ID
     */
    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        bytes memory svg = generateSVG(tokenId);

        // Encode SVG to base64
        string memory base64Svg = Base64.encode(svg);

        // Generate JSON metadata
        string memory json = Base64.encode(
            bytes(
                string(
                    abi.encodePacked(
                        "{",
                        '"name": "/',
                        tokenIdToSlugData[tokenId].slug,
                        '",',
                        '"description": "A unique short slug for a long URL.",',
                        '"image": "data:image/svg+xml;base64,',
                        base64Svg,
                        '",',
                        '"attributes": [{"trait_type": "Custom", "value": "',
                        (tokenIdToSlugData[tokenId].isCustom ? "Yes" : "No"),
                        '"}, {"trait_type": "Slug Length", "display_type": "number", "value": ',
                        Strings.toString(bytes(tokenIdToSlugData[tokenId].slug).length),
                        "}]",
                        "}"
                    )
                )
            )
        );

        return string(abi.encodePacked("data:application/json;base64,", json));
    }

    function generateSVG(uint256 tokenId) internal view returns (bytes memory) {
        SlugData memory data = tokenIdToSlugData[tokenId];
        bytes memory slug = bytes(data.slug);

        uint256 fontSize = (slug.length <= 12) ? 96 : (slug.length >= 48) ? 1 : 96 - (2 * slug.length);
        uint256 color = uint256(keccak256(abi.encodePacked(tokenId))) % 361;

        string memory background = string(abi.encodePacked("hsl(", Strings.toString(color), ", 90%, 90%)"));
        string memory foreground = string(abi.encodePacked("hsl(", Strings.toString(color), ", 50%, 40%)"));

        bytes memory text = abi.encodePacked(
            '<text x="10%" y="40%" font-family="Helvetica" font-size="',
            Strings.toString(fontSize),
            '" font-weight="700" fill="',
            foreground,
            '">/',
            data.slug,
            "</text>"
        );

        bytes memory logo = abi.encodePacked(
            '<path d="M650 700 Q 700 750, 700 700 T 750 700" stroke="',
            foreground,
            '" fill="',
            background,
            '" stroke-width="20"/>'
        );

        bytes memory svg = abi.encodePacked(
            '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 800 800" height="100%" width="100%">',
            '<rect x="0" y="0" width="800" height="800" fill="',
            background,
            '" />',
            text,
            logo,
            "</svg>"
        );

        return svg;
    }

    ///////////// Owner methods /////////////

    function rescueERC20(address token) external onlyOwner {
        IERC20 erc20Token = IERC20(token);
        uint256 balance = erc20Token.balanceOf(address(this));
        require(balance > 0, "No token balance in the contract");
        erc20Token.transfer(owner(), balance);
    }

    function rescueERC721(address token, uint256 tokenId) external onlyOwner {
        IERC721 erc721Token = IERC721(token);
        require(erc721Token.ownerOf(tokenId) == address(this), "The token is not owned by the contract");
        erc721Token.safeTransferFrom(address(this), owner(), tokenId);
    }

    function modifyReferrerFee(uint256 fee) external onlyOwner {
        require(fee <= MAX_FEE, "Fee can't be more than MAX_FEE");
        referrerFeeBips = fee;
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }
}
