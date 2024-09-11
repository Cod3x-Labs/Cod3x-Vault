# Description

Submodules for Cod3x vaults and strategies, to be consumed by deployer repositories of specific vaults and strategies.

## ReaperVaultV2
Multi-strategy vault base class

## ReaperVaultERC4626
Multi-strategy vault ERC4626 wrapper

## ReaperFeeController
Controls the management fee across a set of vaults

## ReaperSwapper
A configurable swapper smart contract for reaper strategies that interfaces with several decentralized exchanges. Deployed once per chain alongside strategies.

## ReaperBaseStrategyv4
Multi-strategy strategy base classe, to be inherited by every strategy.

# Development

This project uses [Foundry](https://github.com/gakonst/foundry) as the development framework.

## Dependencies

```
forge install
```

## Compilation

```
forge build
```

## Testing

```
forge test
```

