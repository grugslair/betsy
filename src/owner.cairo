use starknet::{ContractAddress, storage_access::{StorageAddress}};
use betsy::storage::{read_value_from_felt252, write_value_from_felt252};

const FEE_ADDRESS_FELT252: felt252 = 'fee';
const OWNER_ADDRESS_FELT252: felt252 = 'owner';


fn read_fee() -> u16 {
    read_value_from_felt252(FEE_ADDRESS_FELT252)
}

fn read_owner() -> ContractAddress {
    read_value_from_felt252(OWNER_ADDRESS_FELT252)
}

fn write_fee(fee: u16) {
    write_value_from_felt252(FEE_ADDRESS_FELT252, fee)
}

fn write_owner(owner: ContractAddress) {
    write_value_from_felt252(OWNER_ADDRESS_FELT252, owner)
}
