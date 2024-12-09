# Starknet Wagering Contract

This Cairo interface provides a framework for managing decentralized wagering system on Starknet. It includes methods for creating, managing, and settling bets as well as overcoming errors in contracts bet on.

---

## **Interface Overview**

### **Key Methods**

#### **Bet Lifecycle**

1. **`create`**

   - Initiates a new bet with specified terms, participants, and conditions.
   - Parameters:
     - `taker`: Address of the other party to the bet.
     - `erc20_contract_address`: Address of the ERC20 token used as the wager.
     - `erc20_amount`: Amount of token to be wagered by each party.
     - `contract`: Address of the contract managing the bet.
     - `init_call_selector` & `init_call_data`: Function selector and data to initiate the bet.
     - `claim_selector`: Selector for claiming the bet.
     - `expiry`: Optional expiration timestamp (0 for none).
   - Returns: Bet identifier (`felt252`).

2. **`accept`**

   - Accepts a bet by the specified `id`. Only callable by the `taker`.

3. **`reject`**

   - Rejects a bet by the specified `id`. Only callable by the `taker`.

4. **`revoke`**
   - Cancels a bet by the specified `id`. Only callable by the `maker`.

---

#### **Claiming and Dispute Resolution**

1. **`claim_win`**

   - Claims winnings for a specific bet. Only callable by the winner.

2. **`approve_release`**

   - Approves fund release for a specific bet in case of errors or disputes.

3. **`revoke_release`**

   - Revokes a prior release approval for a specific bet.

4. **`release_funds`**
   - Releases funds back to both parties after mutual approval.

---

#### **Querying Bet Details**

1. **General Bet Information**

   - `get_bet`: Fetches the full bet struct.
   - `get_bet_status`: Returns the current status of the bet.
   - `get_bet_winner`: Fetches the winner's address.

2. **Participant Information**

   - `get_bet_maker`: Fetches the maker's address.
   - `get_bet_taker`: Fetches the taker's address.
   - `get_bet_betters`: Fetches both participants' addresses.

3. **Wager Details**

   - `get_bet_wager`: Returns the wager details (ERC20 contract and amount).
   - `get_bet_fee`: Fetches the fee associated with the bet.

4. **Bet Contract Details**

   - `get_bet_contract`: Fetches the address of the associated contract.
   - `get_bet_init_call`: Fetches the initialization call details.
   - `get_bet_init_call_selector` & `get_bet_init_calldata`: Fetch initialization function and data.
   - `get_bet_claim_selector`: Fetches the claim function

5. **Miscellaneous**
   - `get_bet_expiry`: Fetches the bet's expiration timestamp.
   - `get_bet_game_id`: Fetches the unique game ID.
   - `get_bet_release_status`: Fetches the release status of the funds.

---

### **Supporting Structures**

#### **`Bet`**

A structure encapsulating the full details of a bet, including participants, wager, contract references, and status.

#### **`Wager`**

Details the ERC20 contract address and the amount of tokens wagered.

#### **`Status`**

An enum representing the current state of the bet (e.g., `Pending`, `Accepted`, `Completed`, etc.).

#### **`ReleaseStatus`**

An enum indicating the state of funds release:

- `None`: (Default)
- `Created`
- `Accepted`
- `Canceled`: When revoked or rejected.
- `Released`: A bet that has been split.
- `Claimed: ContractAddress`: The winner has claimed the pot (Contract address is the winner).

---

## Caller Contract Interface

The interface required by the contract that is being bet needs two methods, an init function and a function to return the winner

### Init function

The `init_function` takes in the is called at the `contract` on the `init_call_selector` defined in the create method with the `init_call_data` passed to the function. The function should return a single felt252 with an id for the game.

### Winner function

A read method is also required on the `contract` that takes a single felt252 of the `game_id` returned from the init function and returns a single value of the `ContractAddress` of the winner who should either be the maker or the taker (if not funds can be claimed with the release system).

---

### **Usage Considerations**

- **Permissions**:
  - The `taker` and `maker` are required to call specific methods based on their roles.
  - Secure handling of funds and approvals ensures fairness and prevents unauthorized access.
- **Expiry**:
  - Optional expiration timestamps allow for time-bound offers.
- **Error Handling**:
  - Mechanisms for mutual fund release ensure amicable resolution in case of errors.

---

This interface provides a robust foundation for decentralized betting applications, ensuring fairness, transparency, and efficiency.
