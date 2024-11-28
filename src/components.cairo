use starknet::{ContractAddress};
use betsy::{
    utils::Cast,
    storage::{
        read_felt252, write_felt252, read_object, read_value, write_value, read_values, write_values
    }
};
use starknet::storage_access::{storage_base_address_from_felt252};

#[derive(Drop, Copy, Serde, Introspect)]
struct Wager {
    contract_address: ContractAddress,
    amount: u256,
}

impl Felt252IntoBool of Into<felt252, bool> {
    fn into(self: felt252) -> bool {
        match self {
            0 => false,
            1 => true,
            _ => panic!("Not a boolean"),
        }
    }
}


mod event {
    use super::{ContractAddress, Wager};
    #[dojo::event]
    #[derive(Drop, Copy, Serde)]
    struct Bet {
        #[key]
        id: felt252,
        owner: felt252,
        taker: ContractAddress,
        maker: ContractAddress,
        fee: u256,
        wager: Wager,
        paid: bool,
    }
}

#[derive(Drop, Copy, Serde)]
struct Bet {
    id: felt252,
    owner: ContractAddress, // 0
    taker: ContractAddress, // 1
    maker: ContractAddress, // 2
    fee: u256, // 3, 4
    wager: Wager, // 5, 6, 7
    paid: bool, // 8
}


fn read_bet(id: felt252) -> Bet {
    let base = storage_base_address_from_felt252(id);
    let mut array = array![id];
    for n in 0..9_u8 {
        array.append(read_felt252(base, n));
    };
    array.cast()
}

#[generate_trait]
impl BetImpl of BetTrait {
    fn read_bet(self: @felt252) -> Bet {
        read_object(storage_base_address_from_felt252(*self), [*self].span(), 9)
    }

    fn read_owner(self: @felt252) -> ContractAddress {
        read_value(storage_base_address_from_felt252(*self), 0)
    }

    fn read_taker(self: @felt252) -> ContractAddress {
        read_value(storage_base_address_from_felt252(*self), 1)
    }

    fn read_maker(self: @felt252) -> ContractAddress {
        read_value(storage_base_address_from_felt252(*self), 2)
    }

    fn read_fee(self: @felt252) -> u256 {
        read_values(storage_base_address_from_felt252(*self), 3, 1)
    }

    fn read_wager(self: @felt252) -> Wager {
        read_values(storage_base_address_from_felt252(*self), 5, 3)
    }

    fn is_paid(self: @felt252) -> bool {
        read_value(storage_base_address_from_felt252(*self), 8)
    }

    fn write_owner(self: @felt252, value: ContractAddress) {
        write_value(storage_base_address_from_felt252(*self), 0, value)
    }

    fn write_taker(self: @felt252, value: ContractAddress) {
        write_value(storage_base_address_from_felt252(*self), 1, value)
    }

    fn write_maker(self: @felt252, value: ContractAddress) {
        write_value(storage_base_address_from_felt252(*self), 2, value)
    }

    fn write_fee(self: @felt252, value: @u256) {
        write_values(storage_base_address_from_felt252(*self), 3, value)
    }

    fn write_wager(self: @felt252, value: @Wager) {
        write_values(storage_base_address_from_felt252(*self), 5, value)
    }

    fn set_paid(self: @felt252, value: bool) {
        write_value(storage_base_address_from_felt252(*self), 8, value)
    }
}

fn read_wager(id: felt252) -> Wager {
    let base = storage_base_address_from_felt252(id);
    let mut array = array![id];
    for n in 5..8_u8 {
        array.append(read_felt252(base, n));
    };
    array.cast()
}

