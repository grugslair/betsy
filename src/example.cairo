use starknet::ContractAddress;

#[starknet::interface]
trait IExample<T> {
    fn create(ref self: T, initiator: ContractAddress) -> felt252;
    fn start(ref self: T, id: felt252);
    fn set_winner(ref self: T, id: felt252, winner: ContractAddress);
    fn get_winner(self: @T, id: felt252) -> ContractAddress;
}

#[dojo::contract]
mod betsy_example_actions {
    use starknet::{ContractAddress, get_caller_address};
    use core::poseidon::poseidon_hash_span;
    use dojo::{event::EventStorage, model::{ModelStorage, Model}};
    use super::IExample;
    use betsy::utils::get_transaction_hash;

    #[dojo::model]
    #[derive(Drop, Serde)]
    struct BetsyExampleGame {
        #[key]
        id: felt252,
        owner: ContractAddress,
        initiator: ContractAddress,
        initiated: bool,
        winner: ContractAddress
    }


    #[abi(embed_v0)]
    impl IExampleImpl of IExample<ContractState> {
        fn create(ref self: ContractState, initiator: ContractAddress,) -> felt252 {
            let id = poseidon_hash_span(['example', get_transaction_hash()].span());
            let mut world = self.world(@"betsy");
            world
                .write_model(
                    @BetsyExampleGame {
                        id,
                        owner: get_caller_address(),
                        initiator,
                        initiated: false,
                        winner: Zeroable::zero()
                    }
                );
            id
        }

        fn start(ref self: ContractState, id: felt252) {
            let mut world = self.world(@"betsy");
            let game: BetsyExampleGame = world.read_model(id);
            assert(!game.initiated, 'The game has already started');
            assert(get_caller_address() == game.initiator, 'Initiator  start the game');
            world
                .write_member(
                    Model::<BetsyExampleGame>::ptr_from_keys(id), selector!("initiated"), true
                );
        }

        fn set_winner(ref self: ContractState, id: felt252, winner: ContractAddress) {
            let mut world = self.world(@"betsy");
            assert(
                get_caller_address() == world
                    .read_member(Model::<BetsyExampleGame>::ptr_from_keys(id), selector!("owner")),
                'The owner must set the winner'
            );
            world
                .write_member(
                    Model::<BetsyExampleGame>::ptr_from_keys(id), selector!("winner"), winner
                );
        }

        fn get_winner(self: @ContractState, id: felt252) -> ContractAddress {
            self
                .world(@"betsy")
                .read_member(Model::<BetsyExampleGame>::ptr_from_keys(id), selector!("winner"))
        }
    }
}
