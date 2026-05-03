# DGX GoldTokenLedger - Source Reconstruction

**Contract:** [`0x55b9a11c2e8351b4ffc7b11561148bfac9977855`](https://etherscan.io/address/0x55b9a11c2e8351b4ffc7b11561148bfac9977855)
**Compiler:** solc 0.3.3-0.3.6 (exact version TBD)
**Runtime bytecode:** 6,770 bytes
**Verification status:** Source reconstructed. All 44 function names known.

## About

The DGX GoldTokenLedger is the core token contract of Digix Global's gold-backed token system, deployed on Ethereum mainnet in early 2016. Digix was one of the first projects to tokenize a real-world asset on Ethereum, representing physical gold bars stored in vaults in Singapore.

The contract implements an ERC20-like token with:
- **Demurrage fees** - storage costs that accrue over time based on token balance and holding period
- **Transaction fees** - percentage-based fees on transfers, capped at a maximum
- **Custodian/vendor/auditor roles** - verified through linked registry contracts
- **Minting** - controlled through a separate gold registry contract
- **Recasting** - converting tokens back to physical gold through a recast contract

All configuration (fee rates, wallet addresses, role registries) is read from an on-chain config contract, making the system modular.

## Source reconstruction

All 44 public function dispatch entries were identified by reverse-engineering the on-chain bytecode. The source in `GoldTokenLedger.sol` reproduces the full contract logic.

### Selector 0x65afd0ed = `regFeePayment`

The selector `0x65afd0ed` was the last unknown name on the contract — not present in 4byte.directory and over 17,000 brute-force name guesses returned no match. **Anthony Eufemio (Digix CTO) provided the original function name and the exact `payStorageFee` implementation**, confirming:

- Selector `0x65afd0ed` = `regFeePayment(address)` on the GoldRegistry
- The token-side `payStorageFee` implementation, including variable names (`_gold`, `_sfee`) and the use of `addUser`, `deductFees`, and `balanceOf` helpers

The reconstructed source now reflects these exact names and structure.

## All 44 function selectors

| Selector | Function |
|----------|----------|
| `0x012beac9` | `vendorRegistry()` |
| `0x0627f5a9` | `getFeeDays(address)` |
| `0x095ea7b3` | `approve(address,uint256)` |
| `0x0e666e49` | `userExists(address)` |
| `0x13af4035` | `setOwner(address)` |
| `0x17a950ac` | `actualBalanceOf(address)` |
| `0x18160ddd` | `totalSupply()` |
| `0x23b872dd` | `transferFrom(address,address,uint256)` |
| `0x24d7806c` | `isAdmin(address)` |
| `0x28b2362f` | `custodianRegistry()` |
| `0x35c80c8c` | `isCustodian(address)` |
| `0x377141d9` | `calculateDemurrage(address)` |
| `0x3ec27341` | `getConfigAddress()` |
| `0x458f5815` | `redemptionFee()` |
| `0x46396e18` | `goldTokenLedger()` |
| `0x49b90557` | `isAuditor(address)` |
| `0x4a619fa6` | `txFeeWallet()` |
| `0x4e03ab49` | `accountingWallet()` |
| `0x4e0fb2a4` | `auditRelease()` |
| `0x64e1721c` | `ledgerMint(address,address,uint256,uint256)` |
| `0x65448a76` | `storageRate()` |
| `0x694d98e5` | `recastContract()` |
| `0x6d786740` | `billingPeriod()` |
| `0x70a08231` | `balanceOf(address)` |
| `0x79502c55` | `config()` |
| `0x7d92f6be` | `goldRegistry()` |
| `0x82e717f7` | `requiredConfirmations()` |
| `0x893d20e8` | `getOwner()` |
| `0x8da5cb5b` | `owner()` |
| `0x8facfa01` | `deductFees(address)` |
| `0x92f00233` | `minterContract()` |
| `0x9dec628b` | `demurrageCalc(uint256,uint256)` |
| `0xa9059cbb` | `transfer(address,uint256)` |
| `0xc1a27089` | `recastFee()` |
| `0xc8028bee` | `auditorRegistry()` |
| `0xcf820461` | `txFee()` |
| `0xd104a136` | `getBase()` |
| `0xd3dd22da` | `txFeeMax()` |
| `0xd60f66de` | `recastCall(address,address,uint256,uint256)` |
| `0xdd62ed3e` | `allowance(address,address)` |
| `0xec1d9bf4` | `isGoldRegistry(address)` |
| `0xee54d54f` | `isVendor(address)` |
| `0xfae9d06d` | `calculateTxFee(uint256,address)` |
| `0xfd6e248e` | `payStorageFee(address)` |

## Linked contracts

| Contract | Address | Role |
|----------|---------|------|
| Config | `0x8568f930a560e4b84147d291342655a75d4f69a9` | Configuration registry |
| Config helper | `0x9988ffccd8620f49e355915fdbcc28d54b68cc98` | Config accessor |
| Gold Registry | `0x782059ecf4d5dc7fc2079c191917de44638c4d38` | Fee management, role verification |
| Recast contract | `0xb1d9062c1ebb025b62018b40af2f563599acf602` | Token recasting |
| Minter contract | `0xf58b008970f45b9de73a65c9f80307c20527a0f5` | Token minting |
| Payment history | `0x55dbd10c0e2ca1e86b2c5045d0c0a53059f3a816` | Stores fee payment timestamps |

## payStorageFee flow

```
payStorageFee(_gold)
  -> GoldRegistry.getFee(_gold)           // get fee amount (_sfee)
  -> addUser(tx.origin) if new            // create account if first interaction
  -> deductFees(tx.origin)                // settle accrued demurrage
  -> check balanceOf(tx.origin) >= _sfee  // revert if insufficient
  -> GoldRegistry.regFeePayment(_gold)    // 0x65afd0ed - record timestamp
  -> deduct _sfee from tx.origin
  -> credit _sfee to accounting wallet
  -> emit Transfer event
```

## Attribution

Source reconstructed by [EthereumHistory](https://ethereumhistory.com) via bytecode reverse engineering. The function name `regFeePayment` for selector `0x65afd0ed` and the exact `payStorageFee` implementation were provided by **Anthony Eufemio** (Digix CTO).
