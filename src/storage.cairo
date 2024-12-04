use starknet::SyscallResultTrait;
use starknet::storage_access::{
    storage_base_address_from_felt252, storage_address_from_base,
    storage_address_from_base_and_offset, StorageBaseAddress, storage_write_syscall,
    storage_read_syscall
};

use betsy::{utils::Cast, serde::{serialize_inline, deserialize_unwrap}};

fn read_value_from_felt252<T, +TryInto<felt252, T>>(address: felt252) -> T {
    storage_read_syscall(0, address.try_into().unwrap()).unwrap_syscall().try_into().unwrap()
}

fn write_value_from_felt252<T, +Into<T, felt252>, +Drop<T>>(address: felt252, value: T) {
    storage_write_syscall(0, address.try_into().unwrap(), value.into()).unwrap_syscall();
}

fn read_felt252(address: StorageBaseAddress, offset: u8) -> felt252 {
    let storage_address = storage_address_from_base_and_offset(address, offset);
    storage_read_syscall(0, storage_address).unwrap_syscall()
}

fn read_felt252s(address: StorageBaseAddress, start: u8, size: u8) -> Array<felt252> {
    let mut array = ArrayTrait::<felt252>::new();
    for n in start..(start + size) {
        array.append(read_felt252(address, n));
    };
    array
}


fn read_value<T, +TryInto<felt252, T>>(address: StorageBaseAddress, offset: u8) -> T {
    let storage_address = storage_address_from_base_and_offset(address, offset);
    storage_read_syscall(0, storage_address).unwrap_syscall().try_into().unwrap()
}

fn read_values<T, +Serde<T>>(address: StorageBaseAddress, start: u8, size: u8) -> T {
    deserialize_unwrap(read_felt252s(address, start, size).span())
}

fn read_object<T, +Serde<T>>(address: StorageBaseAddress, keys: Span<felt252>, size: u8) -> T {
    let mut array: Array<felt252> = keys.into();
    for n in 0..size {
        array.append(read_felt252(address, n));
    };
    deserialize_unwrap(array.span())
}


fn write_felt252(address: StorageBaseAddress, offset: u8, value: felt252) {
    let storage_address = storage_address_from_base_and_offset(address, offset);
    storage_write_syscall(0, storage_address, value.into()).unwrap_syscall();
}

fn write_felt252s(address: StorageBaseAddress, start: u8, values: Span<felt252>) {
    let mut n = 0;
    for value in values {
        write_felt252(address, start + n, *value);
        n += 1;
    };
}

fn write_value<T, +Into<T, felt252>>(address: StorageBaseAddress, offset: u8, value: T) {
    let storage_address = storage_address_from_base_and_offset(address, offset);
    storage_write_syscall(0, storage_address, value.into()).unwrap_syscall();
}

fn write_values<T, +Serde<T>>(address: StorageBaseAddress, start: u8, value: @T) {
    let array = serialize_inline(value);
    write_felt252s(address, start, array.span());
}

