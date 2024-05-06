## Test for setting up ELTK sablier vesting contracts

### Commands

#### Test

```bash
forge test -vvv

# deploy token contract
forge script script/DeployToken_Sepolia.s.sol:TokenDeployScript --rpc-url $SEPOLIA_RPC_URL --verify --broadcast
```
