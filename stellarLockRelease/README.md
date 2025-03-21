# zkCross Lock and Release Contract

## Overview
This smart contract is part of zkCross DEX, a product by zkCrossNetwork on the Stellar blockchain. The contract implements a secure lock and release mechanism for cross-chain transactions.

## Contract Details
- **Network**: Stellar Mainnet
- **Contract Address**: CA4KMAVQYUCKGS6C74HWN4M2VOLZJUAPK3DTHB5XJSHYAWHGLKJZYKDH
- **Product**: zkCross DEX
- **Company**: zkCrossNetwork
- **Lines of Functional Code**: ~300 lines (excluding tests and comments)

## Code Metrics
- **Core Contract Logic**: ~200 lines
- **State Management**: ~50 lines
- **Error Handling**: ~30 lines
- **Event Emissions**: ~20 lines

## Features
- Secure asset locking mechanism for cross-chain transactions
- Automated release functionality with admin controls
- Owner-controlled admin management
- Multi-token support
- Cross-chain compatibility
- Secure initialization process

## Contract Functions

### Initialize
Initializes the contract with an owner address who has permission to manage admins.

```bash
stellar contract invoke \
    --id CONTRACT_ID \
    --source SOURCE_ACCOUNT \
    --network mainnet \
    -- initialize \
    --owner OWNER_ADDRESS
```

### Set Admin
Allows the owner to set an admin address for managing operations.

```bash
stellar contract invoke \
    --id CONTRACT_ID \
    --source SOURCE_ACCOUNT \
    --network mainnet \
    -- set_admin \
    --admin ADMIN_ADDRESS
```

### Lock
Locks assets for cross-chain transfer.

```bash
stellar contract invoke \
    --id CONTRACT_ID \
    --source SOURCE_ACCOUNT \
    --network mainnet \
    -- lock \
    --user_address USER_ADDRESS \
    --from_token SOURCE_TOKEN_ID \
    --dest_token DESTINATION_TOKEN_ID \
    --in_amount AMOUNT \
    --dest_chain CHAIN_ID \
    --recipient_address RECIPIENT_ADDRESS
```

### Release
Releases locked assets to the specified user.

```bash
stellar contract invoke \
    --id CONTRACT_ID \
    --source-account ADMIN_ACCOUNT \
    --network mainnet \
    -- release \
    --amount AMOUNT \
    --user USER_ADDRESS \
    --destination_token TOKEN_ID
```

## Deployment Guide

### Prerequisites
- Rust toolchain
- Stellar CLI
- Soroban CLI
- Valid Stellar account with funds

### Deployment Steps

1. **Clean and Build**
```bash
# Clean previous builds
cargo clean

# Build the contract
stellar contract build

# Build for WASM target
cargo build --target wasm32-unknown-unknown --release
```

2. **Install Contract**
```bash
stellar contract install \
--wasm target/wasm32-unknown-unknown/release/lock_release.wasm \
--source SOURCE_ACCOUNT \
--network mainnet
```

3. **Deploy Contract**
```bash
stellar contract deploy \
--source SOURCE_ACCOUNT \
--network mainnet \
--wasm-hash WASM_HASH_FROM_INSTALL_STEP
```

## Security Considerations
- Only authorized admins can release funds
- Owner controls admin management
- Secure cross-chain transaction handling
- Multi-signature support for critical operations

## Error Handling
Common errors and solutions:
- Unauthorized access attempts
- Insufficient balance errors
- Invalid token address errors
- Network connection issues

## Integration Guide
1. Deploy the contract following the deployment guide
2. Initialize with owner address
3. Set up admin addresses
4. Integrate lock and release functions with your application
5. Implement proper error handling

## Testing
The contract includes comprehensive testing capabilities:
- Unit tests
- Integration tests
- CLI-based testing for mainnet interactions

## License
[Specify your license type]

## Contact & Support
- **Website**: [Your website]
- **Email**: [Support email]
- **Documentation**: [Link to additional documentation]

## Contributing
Please read our contributing guidelines before submitting pull requests.
