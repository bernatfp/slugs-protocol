# Slugs
**Inherits:**
ERC721Enumerable, Ownable, Pausable

**Author:**
bernat.eth

This contract implements the Slugs protocol, which allows for the creation and management of unique slug NFTs that map to URLs.
Each slug is associated with a unique URL.
Random slugs can be generated at no cost (other than gas fees), while custom slugs entail a mint fee.
The contract also includes functionality for referrers to earn a share of mint fees.


## State Variables
### idCounter

```solidity
uint256 public idCounter;
```


### referrerFeeBips

```solidity
uint256 public referrerFeeBips;
```


### urls

```solidity
mapping(string => string) public urls;
```


### slugToTokenId

```solidity
mapping(string => uint256) public slugToTokenId;
```


### tokenIdToSlugData

```solidity
mapping(uint256 => SlugData) public tokenIdToSlugData;
```


### balances

```solidity
mapping(address => uint256) public balances;
```


### CHARSET

```solidity
bytes constant CHARSET = "0123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz";
```


### MAX_FEE

```solidity
uint256 constant MAX_FEE = 10000;
```


## Functions
### constructor


```solidity
constructor() ERC721("Slugs", "SLUGS");
```

### mintSlug

Mint a new slug.

*Referrer is required but can be the zero address.
Requirements:
- `url` cannot be empty.
- `slug` must not already exist.
- `referrer` cannot be the sender.
Random slugs are generated when slug is an empty string, and can be created at no cost.
If a custom slug is provided, an ETH amount equal or greater to the mint fee needs to be provided. See getSlugCost for more details.
Emits a {NewSlug} event.*


```solidity
function mintSlug(string memory url, string memory slug, address referrer)
    public
    payable
    whenNotPaused
    returns (string memory);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`url`|`string`|The URL associated with the new slug.|
|`slug`|`string`|The custom slug to be created. If empty, a random slug is generated.|
|`referrer`|`address`|The address of the referrer. Can be the zero address.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`string`|Returns the slug that was created.|


### editUrl

*Edits the URL of a slug.
Requirements:
- `tokenId` must be owned by the caller.
- `newUrl` cannot be empty.*


```solidity
function editUrl(uint256 tokenId, string memory newUrl) public;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`tokenId`|`uint256`|The ID of the token (slug) to edit.|
|`newUrl`|`string`|The new URL to associate with the slug.|


### claimBalance

*Claims the ETH balance associated with the caller's address.
Requirements:
- The caller must have a non-zero balance.
Emits a {Transfer} event.*


```solidity
function claimBalance() public;
```

### receive


```solidity
receive() external payable;
```

### generateAvailableSlug


```solidity
function generateAvailableSlug() private view returns (string memory);
```

### generateSlug


```solidity
function generateSlug(uint256 seed) private pure returns (string memory);
```

### incrementSlug


```solidity
function incrementSlug(string memory slug) private pure returns (string memory);
```

### isValidSlug


```solidity
function isValidSlug(string memory slug) private pure returns (bool);
```

### handleCustomSlugPayment


```solidity
function handleCustomSlugPayment(string memory slug, address referrer) private;
```

### _mintSlug


```solidity
function _mintSlug(string memory slug, string memory url, bool isCustom) private;
```

### getTokenId

Fetches the token ID associated with a given slug.

*This function requires that the slug is not empty and exists.*


```solidity
function getTokenId(string memory slug) public view returns (uint256);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`slug`|`string`|The slug for which to fetch the token ID.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|Returns the token ID associated with the given slug.|


### getURL

Fetches the URL associated with a given slug.

*This function requires that the slug is not empty and exists.*


```solidity
function getURL(string memory slug) public view returns (string memory);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`slug`|`string`|The slug for which to fetch the URL.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`string`|Returns the URL associated with the given slug.|


### getSlugCost

Calculates the cost of a slug based on its length.

*The cost is determined by a set of predefined rules.*


```solidity
function getSlugCost(uint256 slugLength) public pure returns (uint256);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`slugLength`|`uint256`|The length of the slug.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|Returns the cost of the slug in ether.|


### tokenURI

Returns a URI for a given token ID

*Overrides ERC721's tokenURI() with metadata that includes the slug and its attributes*


```solidity
function tokenURI(uint256 tokenId) public view override returns (string memory);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`tokenId`|`uint256`|The ID of the token to query|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`string`|A string containing the URI of the given token ID|


### generateSVG


```solidity
function generateSVG(uint256 tokenId) internal view returns (bytes memory);
```

### rescueERC20


```solidity
function rescueERC20(address token) external onlyOwner;
```

### rescueERC721


```solidity
function rescueERC721(address token, uint256 tokenId) external onlyOwner;
```

### modifyReferrerFee


```solidity
function modifyReferrerFee(uint256 fee) external onlyOwner;
```

### pause


```solidity
function pause() external onlyOwner;
```

### unpause


```solidity
function unpause() external onlyOwner;
```

## Events
### NewSlug

```solidity
event NewSlug(address indexed sender, string url, string slug, uint256 tokenId, bool isCustom, address referrer);
```

## Structs
### SlugData

```solidity
struct SlugData {
    string slug;
    bool isCustom;
}
```

