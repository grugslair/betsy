use starknet::ContractAddress;
use betsy::bet::{Bet, Wager, Status, Call};

#[starknet::interface]
trait IBet<T> {
    fn create(
        ref self: T,
        owner: ContractAddress,
        maker: ContractAddress,
        taker: ContractAddress,
        erc20_contract_address: ContractAddress,
        erc20_amount: u256,
        expiry: u64
    ) -> felt252;
    fn accept(ref self: T, id: felt252); 
    fn revoke(ref self: T, id: felt252); 
    fn claim(
        ref self: T, id: felt252
    ); 

    fn get_wager(self: @T, id: felt252) -> Wager;
    fn get_owner(self: @T, id: felt252) -> ContractAddress;
    fn get_maker(self: @T, id: felt252) -> ContractAddress;
    fn get_taker(self: @T, id: felt252) -> ContractAddress;
    fn get_betters(self: @T, id: felt252) -> (ContractAddress, ContractAddress);
    fn get_expiry(self: @T, id: felt252) -> u64;
    fn get_status(self: @T, id: felt252) -> Status;
    fn get_call_data(self: @T, id: felt252) -> Call;
    fn get_claim_selector(self: @T, id: felt252) -> felt252;
    fn get_game_id(self: @T, id: felt252) -> felt252;
}

#[starknet::interface]
trait IBetAdmin<T> {
    fn transfer_ownership(ref self: T, new_owner: ContractAddress);
    fn set_fee(ref self: T, fee: u16);
}


#[dojo::contract]
mod bet_contract {
    use starknet::{ContractAddress, get_caller_address, get_block_timestamp};
    use dojo::{world::WorldStorage, model::{ModelStorage, Model}};
    use betsy::{bet::{Bet, BetTrait, Wager, Status, Call}, utils::get_transaction_hash};
    use super::{IBet, IBetAdmin};

    #[storage]
    struct Storage {
        owner: ContractAddress,
        fee: u16,
    }

    #[abi(embed_v0)]
    impl IBetAdminImpl of IBetAdmin<ContractState> {
        fn transfer_ownership(ref self: ContractState, new_owner: ContractAddress) {
            assert(get_caller_address() == self.owner, 'Not owner');
            self.owner.write(new_owner);
        }

        fn set_fee(ref self: ContractState, fee: u16) {
            assert(get_caller_address() == self.owner, 'Not owner');
            self.fee.write(fee);
        }
    }

    #[abi(embed_v0)]
    impl IBetImpl of IBet<ContractState> {
        fn create(
            ref self: ContractState,
            taker: ContractAddress,
            erc20_contract_address: ContractAddress,
            erc20_amount: u256,
            init_call_selector: felt252,
            init_call_data: Span<felt252>, 
            expiry: u64,
            claim_selector: felt252,
        ) -> felt252 {
            let world = self.world();
            let id = get_transaction_hash();

            world.write_model(id, @BetTrait::new(
                id,
                get_caller_address(),
                taker,
                erc20_contract_address,
                erc20_amount,
                expiry
            ));
            id
        }

        fn accept(ref self: ContractState, id: felt252) {
            let world = self.world();
            let mut bet: Bet = world.read_model(id);

            assert!(bet.status == Status::Created);
            get_block_timestamp()
            bet.status = Status::Accepted;
        }

        fn revoke(ref self: ContractState, id: felt252) {
            let bet = self.bets.get_mut(id).unwrap();
            assert!(bet.status == Status::Created);
            bet.status = Status::Revoked;
        }

        fn claim(ref self: ContractState, id: felt252) {
            let bet = self.bets.get_mut(id).unwrap();
            assert!(bet.status == Status::Accepted);
            bet.status = Status::Claimed;
        }

        fn get_wager(self: @ContractState, id: felt252) -> Wager {
            self.bets.get(id).unwrap().wager
        }

        fn get_owner(self: @ContractState, id: felt252) -> ContractAddress {
            self.bets.get(id).unwrap().owner
        }

        fn get_maker(self: @ContractState, id: felt252) -> ContractAddress {
            self.bets.get(id).unwrap().maker
        }

        fn get_taker(self: @ContractState, id: felt252) -> ContractAddress {
            self.bets.get(id).unwrap().taker
        }

        fn get_betters(self: @ContractState, id: felt252) -> (ContractAddress, ContractAddress) {
            let bet = self.bets.get(id).unwrap();
            (bet.maker, bet.taker)
        }

        fn get_expiry(self: @ContractState, id: felt252) -> u64 {
            self.bets.get(id).unwrap().expiry
        }

        fn get_status(self: @ContractState, id: felt252) -> Status
    }
}
