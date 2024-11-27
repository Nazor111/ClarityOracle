# ClarityOracle

ClarityOracle is an advanced cross-chain prediction market platform built on Stacks blockchain using Clarity smart contracts. The platform enables users to participate in prediction markets across multiple blockchains while supporting multi-asset staking and NFT-based achievements.

## Features

### Core Functionality
- Create and participate in prediction markets across multiple blockchains
- Stake various supported tokens on predicted outcomes
- Oracle-based result verification system
- Automated reward distribution
- Achievement system with NFT rewards

### Cross-Chain Support
- Bridge integration for cross-chain market creation
- Multi-chain oracle verification system
- Standardized cross-chain event verification

### Multi-Asset Staking
- Support for multiple token types
- Dynamic token rate conversion system
- Minimum stake requirements
- Platform fees in basis points

### Achievement System
- NFT rewards for successful predictions
- Tracking of user statistics
  - Correct predictions count
  - Total stake amount
  - NFT collection

## Smart Contract Architecture

### Core Components

#### Events
- Unique event ID system
- Title and description
- Oracle assignment
- Multiple possible outcomes
- Cross-chain verification support
- Total stake tracking

#### Stakes
- Per-user stake tracking
- Multi-token support
- Original amount preservation
- Event-specific stake pools

#### Bridges
- Chain ID registration
- Bridge contract association
- Oracle assignment
- Enable/disable functionality

### Constants
- Minimum stake requirement
- Platform fee (basis points)
- Error codes for various scenarios
- Owner-specific functions

## Public Functions

### Event Management
```clarity
(create-cross-chain-event (title) (description) (oracle) (end-block) (possible-outcomes) (supported-tokens) (cross-chain-verification))
```
Creates a new prediction market event with cross-chain support.

### Staking
```clarity
(stake-with-token (event-id) (outcome) (amount) (token))
```
Stakes tokens on a specific outcome for an event.

### Rewards
```clarity
(claim-rewards (event-id))
```
Claims rewards for correct predictions and updates achievements.

### Asset Management
```clarity
(register-token (token) (rate))
```
Registers new tokens with their conversion rates.

### Bridge Operations
```clarity
(register-bridge (chain-id) (bridge-contract) (oracle))
```
Registers new blockchain bridges for cross-chain functionality.

## Read-Only Functions

- `get-stake`: Retrieves stake information
- `get-token-rate`: Queries token conversion rates
- `get-user-achievements`: Retrieves user achievement data
- `get-bridge-info`: Queries bridge configuration data

## Error Handling

The contract includes comprehensive error handling for various scenarios:
- Owner-only operations
- Event existence and validity
- Outcome validation
- Token and bridge operations
- Stake requirements
- Oracle authorization

## Security Features

- Principal-based access control
- Oracle verification system
- Minimum stake requirements
- Protected owner functions
- Safe token transfer handling
- Cross-chain verification mechanisms

## Development Setup

1. Ensure you have the [Clarinet](https://github.com/hirosystems/clarinet) development environment installed
2. Clone the repository
3. Initialize the Clarinet project
4. Deploy required token contracts
5. Configure bridge contracts for cross-chain functionality

## Testing

Run tests using Clarinet:
```bash
clarinet test
```

## Contributing

1. Fork the repository
2. Create a feature branch
3. Commit your changes
4. Push to the branch
5. Create a Pull Request
