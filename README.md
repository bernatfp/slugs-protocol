# Slugs

## About

### Summary

The Slugs protocol is an onchain URL shortener.

### Description

The Slugs protocol operates through a smart contract that supports the registration and management of slugs. *A slug is a short alias that maps to an arbitrary URL*, respresented by an NFT. The protocol can be integrated by any frontend, supporting the registration, management and/or resolution of slug requests for redirection. 

Registration referral fees (50% of the mint fee at time of deployment) are baked into the protocol in order to incentivize frontend operators to integrate the protocol and build additional services atop. Frontend operators might want to differentiate and create additional value through traffic analytics, slug leasing, marketplaces, alternative shareable formats (e.g. QR codes), safer "preview & confirm" redirection models (perhaps supported by ads), browser extensions to register and redirect, etc.

The goal of the protocol is to establish an **open, composable, permanent, credibly neutral and censorship resistant URL shortener alternative** enabled by an immutable smart contract on Ethereum.

### Registering slugs

There are two kinds of slugs which can be registered:
1. **Random.** Supply a URL, and the protocol generates a random slug, at no cost (other than gas fees).
2. **Custom.** Choose your own vanity slug, subject to availability, for a fee inversely proportional to its length. Slugs of 8 characters or longer cost 0.01 ETH.

Slugs can be registered by calling `mintSlug(string memory url, string memory slug, address referrer)`. More details in the `/src` README.

### The slug NFT

Each slug is represented by an NFT with the following characteristics:
- **Transferrable.** Send it to anyone, or trade it on any NFT marketplace.
- **Perpetual.** No rent seeking. Once minted it's yours forever.
- **No royalties.** If you want to trade a slug, you keep 100% of the proceeds.
- **Generative.** Each slug is represented by an SVG generated onchain.

## But, why?

By leaning on the open, composable and immutable nature of blockchains we can build a new kind of URL shortening service with these unique properties:
- **Ownership.** Once you mint a slug, it's truly yours, forever.
- **NFTs.** Every slug is an NFT, and thus transferable, tradeable, and overall composable with other protocols.
- **User Experience.** No need for emails, social logins or CAPTCHAs. Just connect your wallet and mint.
- **Skin in the game.** Get transparently rewarded for helping the protocol grow through referral revenue sharing.

##  Developers 

Dive into the `/src` directory for comprehensive contract documentation and source code.

### Deployments 

- **Optimism Goerli**: [0x22Bc6b70f99bfB92104f0B83dCd436A0B5676666](https://goerli-optimism.etherscan.io/address/0x22Bc6b70f99bfB92104f0B83dCd436A0B5676666)
- **Optimism Mainnet**: TBD

### Disclaimers & caveats

- This contract is unaudited and could have bugs
- There is no URL validation at the contract level
- Safe URL redirection requires honest frontends to cooperate

### License

MIT License.