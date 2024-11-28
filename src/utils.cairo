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
