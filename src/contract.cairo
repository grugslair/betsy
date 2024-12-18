use starknet::ContractAddress;
use betsy::bet::{Bet, Wager, Status, ReleaseStatus};

#[starknet::interface]
trait IBet<T> {
    // Create a new bet
    fn create(
        ref self: T,
        taker: ContractAddress, // The address of the taker
        erc20_contract_address: ContractAddress, // The address of the ERC20 payment token
        erc20_amount: u256, // The amount of the ERC20 payment token for each person
        contract: ContractAddress, // The address of the contract to be called for the bet
        init_selector: felt252, // The selector of the function to be called to start the bet on the contract zero if no call. 
        claim_selector: felt252, // The selector of the function to be called to claim the bet
        game_id: felt252, // The id of the game
        expiry: u64, // The time when the bet offer expires 0 for None
    ) -> felt252;
    fn accept(ref self: T, id: felt252); // Accept the bet, must be called by the taker
    fn reject(ref self: T, id: felt252); // Reject the bet, must be called by the taker
    fn revoke(ref self: T, id: felt252); // Revoke the bet, must be called by the maker
    fn claim_win(ref self: T, id: felt252); // Claim the win, can be called by anyone

    // In the case of an error both parties can agree to revoke the bet and split the wager minus
    // the fee
    fn approve_release(ref self: T, id: felt252); // Approve the release of the funds
    fn revoke_release(ref self: T, id: felt252); // Revoke Approval the release of the funds
    fn release_funds(
        ref self: T, id: felt252
    ); // Release the funds back to betters, need approval from other party before call
    fn get_bet(self: @T, id: felt252) -> Bet; // Get the bet struct of the bet
    fn get_bet_wager(
        self: @T, id: felt252
    ) -> Wager; // Get the wager of the bet (contract address and amount)
    fn get_bet_maker(self: @T, id: felt252) -> ContractAddress; // Get the maker of the bet
    fn get_bet_taker(self: @T, id: felt252) -> ContractAddress; // Get the taker of the bet
    fn get_bet_betters(
        self: @T, id: felt252
    ) -> (ContractAddress, ContractAddress); // Get the maker and taker of the bet
    fn get_bet_fee(self: @T, id: felt252) -> u16; // Get the fee of the bet
    fn get_bet_expiry(self: @T, id: felt252) -> u64;
    fn get_bet_contract(
        self: @T, id: felt252
    ) -> ContractAddress; // Get the contract address that the bet points to
    fn get_bet_init_selector(
        self: @T, id: felt252
    ) -> felt252; // Get the selector of the call to start the bet
    fn get_bet_claim_selector(
        self: @T, id: felt252
    ) -> felt252; // Get the selector of the call to claim the bet
    fn get_bet_game_id(self: @T, id: felt252) -> felt252; // Get the game id of the bet
    fn get_bet_status(self: @T, id: felt252) -> Status; // Get the status of the bet
    fn get_bet_winner(self: @T, id: felt252) -> ContractAddress; // Get the winner of the bet
    fn get_bet_release_status(
        self: @T, id: felt252
    ) -> ReleaseStatus; // Get the release status of the bet
}

#[starknet::interface]
trait IBetAdmin<T> {
    fn transfer_ownership(ref self: T, new_owner: ContractAddress);
    fn set_owners_fee(ref self: T, fee: u16);

    fn get_owners_fee(self: @T) -> u16;
    fn get_owner(self: @T) -> ContractAddress;
}


#[dojo::contract]
mod bet {
    use starknet::{ContractAddress, get_caller_address, get_block_timestamp};
    use dojo::{world::WorldStorage, model::{ModelStorage, Model}};
    use betsy::{
        bet::{Bet, BetTrait, Wager, Status, ReleaseStatus},
        owner::{read_fee, read_owner, write_fee, write_owner},
        utils::{get_transaction_hash, default_namespace, uuid, uuid_init}
    };
    use super::{IBet, IBetAdmin};

    fn dojo_init(ref self: ContractState, owner: ContractAddress, fee_per_mille: u16) {
        write_owner(owner);
        write_fee(fee_per_mille);
        uuid_init();
    }

    #[generate_trait]
    impl PrivateImpl of PrivateTrait {
        fn assert_owner(self: @ContractState) {
            assert(get_caller_address() == read_owner(), 'Not owner');
        }

        fn read_bet_member<T, +Serde<T>>(
            self: @ContractState, id: felt252, selector: felt252
        ) -> T {
            self.world(default_namespace()).read_member(Model::<Bet>::ptr_from_keys(id), selector)
        }
    }

    #[abi(embed_v0)]
    impl IBetAdminImpl of IBetAdmin<ContractState> {
        fn transfer_ownership(ref self: ContractState, new_owner: ContractAddress) {
            assert(get_caller_address() == read_owner(), 'Not owner');
            write_owner(new_owner);
        }

        fn set_owners_fee(ref self: ContractState, fee: u16) {
            assert(get_caller_address() == read_owner(), 'Not owner');
            write_fee(fee);
        }

        fn get_owners_fee(self: @ContractState) -> u16 {
            read_fee()
        }

        fn get_owner(self: @ContractState) -> ContractAddress {
            read_owner()
        }
    }

    #[abi(embed_v0)]
    impl IBetImpl of IBet<ContractState> {
        fn create(
            ref self: ContractState,
            taker: ContractAddress,
            erc20_contract_address: ContractAddress,
            erc20_amount: u256,
            contract: ContractAddress,
            init_selector: felt252,
            claim_selector: felt252,
            game_id: felt252,
            expiry: u64,
        ) -> felt252 {
            let mut world = self.world(default_namespace());
            let id = uuid();

            world
                .write_model(
                    @BetTrait::new(
                        id,
                        taker,
                        erc20_contract_address,
                        erc20_amount,
                        expiry,
                        contract,
                        init_selector,
                        claim_selector,
                        game_id,
                    )
                );
            id
        }

        fn accept(ref self: ContractState, id: felt252) {
            let mut world = self.world(default_namespace());
            let mut bet: Bet = world.read_model(id);
            bet.init_game();
            bet.collect();
            world.write_model(@bet);
        }

        fn revoke(ref self: ContractState, id: felt252) {
            let mut world = self.world(default_namespace());
            let mut bet: Bet = world.read_model(id);
            bet.revoke();
            world.write_model(@bet);
        }

        fn reject(ref self: ContractState, id: felt252) {
            let mut world = self.world(default_namespace());
            let mut bet: Bet = world.read_model(id);
            bet.reject();
            world.write_model(@bet);
        }

        fn claim_win(ref self: ContractState, id: felt252) {
            let mut world = self.world(default_namespace());
            let mut bet: Bet = world.read_model(id);

            bet.claim_win();

            world.write_model(@bet);
        }

        fn approve_release(ref self: ContractState, id: felt252) {
            let mut world = self.world(default_namespace());
            let mut bet: Bet = world.read_model(id);
            bet.approve_release();
            world.write_model(@bet);
        }

        fn revoke_release(ref self: ContractState, id: felt252) {
            let mut world = self.world(default_namespace());
            let mut bet: Bet = world.read_model(id);
            bet.revoke_release();
            world.write_model(@bet);
        }

        fn release_funds(ref self: ContractState, id: felt252) {
            let mut world = self.world(default_namespace());
            let mut bet: Bet = world.read_model(id);
            bet.release_funds();
            world.write_model(@bet);
        }

        fn get_bet(self: @ContractState, id: felt252) -> Bet {
            self.world(default_namespace()).read_model(id)
        }

        fn get_bet_maker(self: @ContractState, id: felt252) -> ContractAddress {
            self.read_bet_member(id, selector!("maker"))
        }

        fn get_bet_taker(self: @ContractState, id: felt252) -> ContractAddress {
            self.read_bet_member(id, selector!("taker"))
        }

        fn get_bet_betters(
            self: @ContractState, id: felt252
        ) -> (ContractAddress, ContractAddress) {
            let bet: Bet = self.world(default_namespace()).read_model(id);
            (bet.maker, bet.taker)
        }


        fn get_bet_wager(self: @ContractState, id: felt252) -> Wager {
            self.read_bet_member(id, selector!("wager"))
        }

        fn get_bet_fee(self: @ContractState, id: felt252) -> u16 {
            self.read_bet_member(id, selector!("fee"))
        }

        fn get_bet_expiry(self: @ContractState, id: felt252) -> u64 {
            self.read_bet_member(id, selector!("expiry"))
        }

        fn get_bet_contract(self: @ContractState, id: felt252) -> ContractAddress {
            self.read_bet_member(id, selector!("contract"))
        }

        fn get_bet_init_selector(self: @ContractState, id: felt252) -> felt252 {
            self.read_bet_member(id, selector!("init_selector"))
        }

        fn get_bet_claim_selector(self: @ContractState, id: felt252) -> felt252 {
            self.read_bet_member(id, selector!("claim_selector"))
        }

        fn get_bet_game_id(self: @ContractState, id: felt252) -> felt252 {
            self.read_bet_member(id, selector!("game_id"))
        }

        fn get_bet_status(self: @ContractState, id: felt252) -> Status {
            self.read_bet_member(id, selector!("status"))
        }

        fn get_bet_winner(self: @ContractState, id: felt252) -> ContractAddress {
            let status: Status = self.read_bet_member(id, selector!("status"));
            match status {
                Status::Claimed(winner) => winner,
                _ => panic!("Bet not claimed")
            }
        }

        fn get_bet_release_status(self: @ContractState, id: felt252) -> ReleaseStatus {
            self.read_bet_member(id, selector!("release_status"))
        }
    }
}

