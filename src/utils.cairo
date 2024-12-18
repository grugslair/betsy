use core::{hash::{HashStateTrait}, poseidon::HashState, poseidon::PoseidonTrait};

use starknet::{get_tx_info, storage_access::StorageAddress, get_contract_address};
use betsy::storage::{read_felt252_from_storage_address, write_felt252_from_storage_address};
trait Cast<T, S> {
    fn cast(self: @T) -> S;
}

const UUID_ADDRESS_SELECTOR: felt252 = 'uuid';

impl CastImpl<T, S, +Serde<T>, +Serde<S>, +Drop<T>,> of Cast<T, S> {
    fn cast(self: @T) -> S {
        let mut array = ArrayTrait::<felt252>::new();
        Serde::<T>::serialize(self, ref array);
        let mut span = array.span();
        Serde::<S>::deserialize(ref span).unwrap()
    }
}

fn uuid_init() {
    write_felt252_from_storage_address(
        UUID_ADDRESS_SELECTOR.try_into().unwrap(), get_contract_address().into()
    );
}

fn uuid() -> felt252 {
    let storage_address: StorageAddress = UUID_ADDRESS_SELECTOR.try_into().unwrap();
    let value = PoseidonTrait::new()
        .update(read_felt252_from_storage_address(storage_address))
        .finalize();
    write_felt252_from_storage_address(storage_address, value);
    value
}

fn get_transaction_hash() -> felt252 {
    get_tx_info().unbox().transaction_hash
}

fn default_namespace() -> @ByteArray {
    @"betsy"
}
