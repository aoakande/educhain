# EduChainConnect

A decentralized education platform built on Stacks blockchain that connects institutions, learners, and educators through verifiable credentials and token incentives.

## Features

- Institution registration and verification
- Course creation and management
- Student enrollment system
- Verifiable digital credentials
- Token-based incentive system (EduToken)
- Smart contract-powered transactions

## Prerequisites

- Stacks CLI
- Clarinet
- Node.js (v14+)

## Smart Contract Components

- `edutoken`: Platform's native token for incentives
- `institutions`: Management of registered educational institutions
- `courses`: Course creation and pricing
- `enrollments`: Student course participation tracking
- `credentials`: Verifiable academic achievements

## Key Functions

### For Institutions
```clarity
(register-institution (name (string-ascii 50)))
(create-course (name (string-ascii 100)) (price uint))
(issue-credential (student principal) (course-id uint))
```

### For Students
```clarity
(enroll-in-course (course-id uint))
(complete-course (course-id uint))
```

### Token Operations
```clarity
(distribute-tokens (recipient principal) (amount uint))
```

## Setup

1. Clone the repository
```bash
git clone https://github.com/aoakande/educhain-connect
cd educhain-connect
```

2. Install dependencies
```bash
clarinet install
```

3. Test the smart contract
```bash
clarinet test
```

4. Deploy to testnet
```bash
clarinet deploy --testnet
```

## Security Considerations

- Owner-only functions protected by principal checks
- Input validation for all public functions
- Enrollment status verification before credential issuance
- Token distribution restricted to contract owner
- Course completion verification before certification

## Contributing

Pull requests welcome. For major changes, open an issue first.
