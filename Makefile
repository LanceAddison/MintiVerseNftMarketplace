-include .env

.PHONY: all test clean deploy help install snapshot format anvil

help:
	@echo "Usage:"
	@echo " make deploy [ARGS=...]\n	example: make deploy ARGS=\"--network sepolia\""

all: clean remove install update build

clean:; forge clean

remove:; rm -rf .gitmodules && rm -rf .git/modules/* && rm -rf lib && touch .gitmodules && git add . && git commit -m "modules"

install:; forge install https://github.com/OpenZeppelin/openzeppelin-contracts.git --no-commit && forge install https://github.com/smartcontractkit/chainlink.git --no-commit && forge install https://github.com/Cyfrin/foundry-devops.git --no-commit && forge install https://github.com/transmissions11/solmate.git --no-commit && https://github.com/foundry-rs/forge-std.git --no-commit

