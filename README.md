# MintiVerse Nft Marketplace

# About

This project is meant to be an nft collection and a marketplace where users can mint nfts and then list their nfts or buy other listed nfts. Users can also choose to randomize the art of their nfts.

- [MintiVerse Nft Marketplace](#mintiverse-nft-marketplace)
- [About](#about)
- [Getting Started](#getting-started)
  - [Requirements](#requirements)
  - [Quickstart](#quickstart)
- [Usage](#usage)
  - [Start a local node](#start-a-local-node)
  - [Deploy](#deploy)
  - [Deploy - Other Network](#deploy---other-network)
  - [Testing](#testing)
    - [Test coverage](#test-coverage)
- [Deployment to a testnet or mainnet](#deployment-to-a-testnet-or-mainnet)
  - [Scripts](#scripts)
  - [Estimate gas](#estimate-gas)
- [Formatting](#formatting)
- [Additional Info:](#additional-info)
- [Acknowlegement](#acknowlegement)
- [Thank you!](#thank-you)

# Getting Started

## Requirements

- [git](https://git-scm.com/book/en/v2/Getting-Started-Installing-Git)
  - You'll know you did it right if you can run `git --version` and you see a response like `git version x.x.x`
- [foundry](https://getfoundry.sh/)
  - You'll know you did it right if you can run `forge --version` and you see a response like `forge 0.2.0 (816e00b 2023-03-16T00:05:26.396218Z)`

## Quickstart

```
git clone https://github.com/LanceAddison/MintiVerseNftMarketplace.git
cd mintiverse-nftmarketplace
forge build
```

# Usage

**NOTE** Make sure the required directories are installed in the `/lib` folder.

[See below](#additional-info)

## Start a local node

```
make anvil
```

## Deploy

This will default to your local node. You need to have it running in another terminal in order for it to deploy.

You'll want to set your `ANVIL_DEFAULT_KEY` and `ANVIL_RPC_URL` as environment variables in a .env file.

Additionally [see below](#additional-info) for an important change required to get the `ArtShift` contract to deploy correctly.

```
make deployMintiVerseMarketAndArtShift
```

## Deploy - Other Network

[See below](#deployment-to-a-testnet-or-mainnet)

## Testing

```
make test
```

### Test coverage

```
forge coverage
```

# Deployment to a testnet or mainnet

1. Setup environment variables

You'll want to set your `SEPOLIA_RPC_URL`, `PRIVATE_KEY`, and `SUBSCRIPTION_ID` as environment variables in a .env file.

- `SEPOLIA_RPC_URL`: This is the url of the sepolia testnet node you're working with. You can get one for free from [Alchemy](https://alchemy.com/?a=673c802981)
- `PRIVATE_KEY`: The private key of your account. **NOTE** FOR DEVELOPMENT, YOU SHOULD USE A KEY THAT DOESN'T HAVE ANY REAL FUNDS ASSOCIATED WITH IT.
- `SUBSCRIPTION_ID`: This represents the unique identifier of the vrf subscription. Read more below

Optionally, you can add your `ETHERSCAN_API_KEY` if you want to verify your contract on Etherscan.

1. Get testnet ETH and LINK

Get some testnet ETH and LINK at a faucet such as [faucets.chain.link](https://faucets.chain.link/). They should show up in your wallet.

2. Create a Chainlink VRF Subscription and fund it

[You can follow the instructions here.](https://docs.chain.link/vrf/v2-5/subscription/create-manage)

- **NOTE** You do not need to add a consumer to your subscription. When you go to deploy the `ArtShift` contract it will automatically do this for you.

- **NOTE** Fund the subscription with at least 10-20 LINK to ensure each randomness request is fulfilled. 

After you create the subscription add the subscriptionId to `SUBSCRIPTION_ID` in your .env file as mentioned above.

3. Deploy

```
make deployMintiVerseMarketAndArtShift ARGS="--network sepolia"
```

## Scripts

Instead of scripts, we can use the `cast` command to interact with the contract.

For example, on Sepolia:

- First load your .env variables into the terminal

```
source .env
```

1. Mint an NFT

```
cast send [ArtShift_Contract_Address] "mint()" --rpc-url $SEPOLIA_RPC_URL --private-key $PRIVATE_KEY
```

2. List the NFT

```
cast send [MintiVerseMarke_Contract_Address] "listItem(uint256,uint256)" [tokenIdToList] [priceToListAtInWei] --rpc-url $SEPOLIA_RPC_URL --private-key $PRIVATE_KEY
```

## Estimate gas

You can estimate how much gas things cost by running:

```
make snapshot
```

And you'll see an output file called `.gas-snapshot`

# Formatting

To format your code run:

```
make format
```

# Additional Info:

<h3>If the required directories need to be reinstalled:</h3>

1. Remove directories and Git submodules

```
make remove
```

2. Install the required directories

```
make install
```

<h3>When deploying to a local node such as anvil you must change a line in the `SubscriptionAPI` contract.</h3>

Do this if you specifically needed to reinstall the `chainlink` directory.

1. Navigate to the `SubscriptionAPI` contract

Follow this path in your file tree to find the contract `/lib/chainlink/contracts/src/v0.8/vrf/dev/SubscriptionAPI.sol`.

2. Find the `createSubscription` function

This is the line that must be changed:

```
subId = uint256(
    eccak256(abi.encodePacked(msg.sender, blockhash(block.number - 1), address(this), currentSubNonce))
);
```

Change `blockhash(block.number - 1)` to `blockhash(block.number)`

This is done because the anvil local node starts at block 0. This causes it to underflow when the code tries to subtract 1 from `block.number`.

# Acknowlegement

- The art used for the `ArtShift` nfts was created by [Steve Johnson](https://www.pexels.com/@steve/)

# Thank you!

If you appreciated this, feel free to follow me on X(formerly Twitter) [@LanceAddison17](https://x.com/LanceAddison17).

You can also contact me on there.
