pub fn serialize_inline<T, +Serde<T>>(value: @T) -> Array<felt252> {
    let mut serialized = ArrayTrait::new();
    Serde::serialize(value, ref serialized);
    serialized
}

pub fn deserialize_unwrap<T, +Serde<T>>(mut span: Span<felt252>) -> T {
    match Serde::deserialize(ref span) {
        Option::Some(value) => value,
        Option::None => core::panic_with_felt252('Could not deserialize')
    }
}

