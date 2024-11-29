use core::num::traits::One;
use starknet::{
    ContractAddress, get_caller_address, get_contract_address, syscalls::call_contract_syscall,
    SyscallResultTrait
};
use dojo::{world::WorldStorage, model::{ModelStorage, Model}};
use betsy::{utils::Cast,};
use openzeppelin_token::erc20::{ERC20ABIDispatcher, ERC20ABIDispatcherTrait};

#[derive(Drop, Copy)]
struct Fee {
    per_mille: u16,
    owner: ContractAddress,
}

#[derive(Drop, Copy, Serde, Introspect)]
struct Wager {
    contract_address: ContractAddress,
    amount: u256,
}

#[derive(Drop, Copy, Serde, Introspect)]
struct Call {
    selector: felt252,
    calldata: Span<felt252>,
}


#[derive(Drop, Serde, Copy, PartialEq, Introspect)]
enum Status {
    #[default]
    None,
    Created,
    Accepted,
    Revoked,
    Claimed,
}

#[dojo::model]
#[derive(Drop, Copy, Serde)]
struct Bet {
    #[key]
    id: felt252,
    maker: ContractAddress,
    taker: ContractAddress,
    wager: Wager,
    contract: ContractAddress,
    init_call: Call,
    claim_selector: felt252,
    expiry: u64,
    game_id: felt252,
    status: Status,
}

#[generate_trait]
impl BetImpl of BetTrait {
    fn new(
        id: felt252,
        maker: ContractAddress,
        taker: ContractAddress,
        wager: Wager,
        contract: ContractAddress,
        init_call: Call,
        claim_selector: felt252,
        expiry: u64,
    ) -> Bet {
        Bet {
            id,
            maker,
            taker,
            wager,
            contract,
            init_call,
            claim_selector,
            expiry,
            game_id: 0,
            status: Status::Created,
        }
    }

    fn accept(ref self: Bet) {
        assert!(self.status == Status::Created);
        self.status = Status::Accepted;
    }

    fn revoke(ref self: Bet) {
        assert!(self.status == Status::Created);
        self.status = Status::Revoked;
    }

    fn collect(ref self: Bet) {
        let address = get_contract_address();
        let dispatcher = ERC20ABIDispatcher { contract_address: self.wager.contract_address };

        dispatcher.transfer_from(self.maker, address, self.wager.amount);
        dispatcher.transfer_from(self.taker, address, self.wager.amount);
    }

    fn init_call(ref self: Bet) {
        let span = call_contract_syscall(
            self.contract, self.init_call.selector, self.init_call.calldata
        )
            .unwrap_syscall();
        assert(span.len().is_one(), 'Return mut be a single felt');
        self.game_id = *span[0];
    }


    fn payout(ref self: Bet, fee_per_mille: u16) {
        let total = self.wager.amount * 2;
        let payout = total * (1000 - fee_per_mille).into() / 1000;
        

    }
}
