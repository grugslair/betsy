use starknet::ContractAddress;

#[starknet::interface]
trait IExample<T> {
    fn create(
        ref self: T,
        collection_address_a: ContractAddress,
        collection_address_b: ContractAddress,
        player_a: ContractAddress,
        player_b: ContractAddress,
        token_a_id: u256,
        token_b_id: u256,
        attacks_a: Span<(felt252, felt252)>,
        attacks_b: Span<(felt252, felt252)>
    ) -> felt252;
    fn set_winner(ref self: T, id: felt252, winner: ContractAddress);
    fn winner(self: @T, id: felt252) -> ContractAddress;
}

#[dojo::contract]
mod example {
    use starknet::{ContractAddress, get_caller_address};
    use core::poseidon::poseidon_hash_span;
    use dojo::{event::EventStorage, model::{ModelStorage, Model}};
    use super::IExample;
    use betsy::{utils::get_transaction_hash, owner::{read_owner, write_owner}};

    #[dojo::event]
    #[derive(Drop, Serde)]
    struct Game {
        #[key]
        game_id: felt252,
        collection_address_a: ContractAddress,
        collection_address_b: ContractAddress,
        player_a: ContractAddress,
        player_b: ContractAddress,
        token_a_id: u256,
        token_b_id: u256,
        attacks_a: Span<(felt252, felt252)>,
        attacks_b: Span<(felt252, felt252)>
    }

    #[dojo::model]
    #[derive(Drop, Serde)]
    struct Winner {
        #[key]
        game_id: felt252,
        winner: ContractAddress
    }

    fn dojo_init(ref self: ContractState, owner: ContractAddress) {
        write_owner(owner);
    }

    #[abi(embed_v0)]
    impl IExampleImpl of IExample<ContractState> {
        fn create(
            ref self: ContractState,
            collection_address_a: ContractAddress,
            collection_address_b: ContractAddress,
            player_a: ContractAddress,
            player_b: ContractAddress,
            token_a_id: u256,
            token_b_id: u256,
            attacks_a: Span<(felt252, felt252)>,
            attacks_b: Span<(felt252, felt252)>
        ) -> felt252 {
            let game_id = poseidon_hash_span(['example', get_transaction_hash()].span());
            let mut world = self.world(@"betsy");
            world
                .emit_event(
                    @Game {
                        game_id: poseidon_hash_span(['example', get_transaction_hash()].span()),
                        collection_address_a,
                        collection_address_b,
                        player_a,
                        player_b,
                        token_a_id,
                        token_b_id,
                        attacks_a,
                        attacks_b
                    }
                );
            game_id
        }

        fn set_winner(ref self: ContractState, id: felt252, winner: ContractAddress) {
            assert(get_caller_address() == read_owner(), 'The owner must set the winner');
            let mut world = self.world(@"betsy");
            world.write_model(@Winner { game_id: id, winner });
        }

        fn winner(self: @ContractState, id: felt252) -> ContractAddress {
            self
                .world(@"betsy")
                .read_member(Model::<Winner>::ptr_from_keys(id), selector!("winner"))
        }
    }
}
