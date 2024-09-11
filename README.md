# Description

## vault-v2
Multi-strategy vault base classes, meant to be ingested as a submodule in other repositories, not to be used directly.

## ReaperSwapper
A configurable swapper smart contract for reaper strategies that interfaces with several decentralized exchanges. Deployed once per chain alongside strategies.

# Installation

## Local development

This project uses [Foundry](https://github.com/gakonst/foundry) as the development framework.

### Dependencies

```
forge install
```

### Compilation

```
forge build
```

# Testing

## Dynamic

```
forge test
```

`--report lcov` - coverage which can be turned on in code using "Coverage Gutters"

![Architecture diagram](docs/architecture.png)
