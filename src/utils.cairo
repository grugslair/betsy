use starknet::get_tx_info;

trait Cast<T, S> {
    fn cast(self: @T) -> S;
}

impl CastImpl<T, S, +Serde<T>, +Serde<S>, +Drop<T>,> of Cast<T, S> {
    fn cast(self: @T) -> S {
        let mut array = ArrayTrait::<felt252>::new();
        Serde::<T>::serialize(self, ref array);
        let mut span = array.span();
        Serde::<S>::deserialize(ref span).unwrap()
    }
}

fn get_transaction_hash() -> felt252 {
    get_tx_info().unbox().transaction_hash
}

fn default_namespace() -> @ByteArray {
    @"betsy"
}
