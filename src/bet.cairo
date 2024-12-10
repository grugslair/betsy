use core::num::traits::{One};
use starknet::{
    ContractAddress, get_caller_address, get_contract_address, syscalls::call_contract_syscall,
    SyscallResultTrait, get_block_timestamp,
};
use dojo::{world::WorldStorage, model::{ModelStorage, Model}};
use betsy::{utils::Cast, owner::{read_fee, read_owner}};
use openzeppelin_token::erc20::{ERC20ABIDispatcher, ERC20ABIDispatcherTrait};

const ASSERT_APPROVAL_STRING: felt252 = 'Both parties approval needed';

#[derive(Drop, Copy, Serde, Introspect)]
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
    Canceled,
    Released,
    Claimed: ContractAddress,
}

#[derive(Drop, Serde, Copy, PartialEq, Introspect)]
enum ReleaseStatus {
    #[default]
    None,
    MakerApproved,
    TakerApproved,
}

#[dojo::model]
#[derive(Drop, Copy, Serde)]
struct Bet {
    #[key]
    id: felt252,
    maker: ContractAddress,
    taker: ContractAddress,
    wager: Wager,
    fee: Fee,
    expiry: u64,
    contract: ContractAddress,
    game_id: felt252,
    init_selector: felt252,
    claim_selector: felt252,
    status: Status,
    release_status: ReleaseStatus,
}

fn get_fee_amount(fee: u16, wager: u256) -> u256 {
    (wager * fee.into() / 1000) * 2 // do not simplify to / 500 as the result need to be even
}

#[generate_trait]
impl BetImpl of BetTrait {
    fn new(
        id: felt252,
        taker: ContractAddress,
        erc20_contract_address: ContractAddress,
        erc20_amount: u256,
        expiry: u64,
        contract: ContractAddress,
        init_selector: felt252,
        claim_selector: felt252,
        game_id: felt252,
    ) -> Bet {
        let maker = get_caller_address();
        assert(maker != taker, 'Cannot bet against self');
        Bet {
            id,
            maker: get_caller_address(),
            taker,
            wager: Wager { contract_address: erc20_contract_address, amount: erc20_amount, },
            fee: Fee { per_mille: read_fee(), owner: read_owner(), },
            expiry,
            contract,
            init_selector: init_selector,
            claim_selector,
            game_id,
            status: Status::Created,
            release_status: ReleaseStatus::None,
        }
    }
    fn respond(ref self: Bet, status: Status) {
        match self.status {
            Status::None => { panic!("Bet not created"); },
            Status::Created => { self.status = status; },
            Status::Accepted | Status::Canceled | Status::Claimed |
            Status::Released => { panic!("Response already recorded"); }
        };
        assert(self.expiry.is_zero() || self.expiry < get_block_timestamp(), 'Bet expired');
    }
    fn call_game(self: @Bet, selector: felt252) -> Span<felt252> {
        call_contract_syscall(*self.contract, selector, [*self.game_id].span()).unwrap_syscall()
    }
    fn get_winner(self: @Bet) -> ContractAddress {
        let span = self.call_game(*self.claim_selector);
        assert(span.len().is_one(), 'Return mut be a single felt');
        let winner: ContractAddress = (*span[0]).try_into().unwrap();
        assert(winner == *self.maker || winner == *self.taker, 'Invalid winner');
        winner
    }

    fn init_game(ref self: Bet) {
        assert(get_caller_address() == self.taker, 'Only taker can respond');
        self.respond(Status::Accepted);
        self.call_game(self.init_selector);
    }

    fn revoke(ref self: Bet) {
        assert(get_caller_address() == self.maker, 'Only maker can revoke');
        self.respond(Status::Canceled);
    }

    fn reject(ref self: Bet) {
        assert(get_caller_address() == self.taker, 'Only taker can reject');
        self.respond(Status::None);
    }

    fn collect(self: @Bet) {
        let address = get_contract_address();
        let dispatcher = ERC20ABIDispatcher { contract_address: *self.wager.contract_address };

        dispatcher.transfer_from(*self.maker, address, *self.wager.amount);
        dispatcher.transfer_from(*self.taker, address, *self.wager.amount);
        dispatcher
            .transfer(*self.fee.owner, get_fee_amount(*self.fee.per_mille, *self.wager.amount));
    }
    fn claim_win(ref self: Bet) {
        let winner = self.get_winner();

        self.status = match self.status {
            Status::Claimed | Status::Released => { panic!("Bet already payed out") },
            Status::None | Status::Created | Status::Canceled => { panic!("Bet not running") },
            Status::Accepted => { Status::Claimed(winner) }
        };

        ERC20ABIDispatcher { contract_address: self.wager.contract_address }
            .transfer(
                winner,
                self.wager.amount * 2 - get_fee_amount(self.fee.per_mille, self.wager.amount)
            );
    }

    fn assert_release(ref self: Bet) {
        match self.status {
            Status::None => { panic!("Bet not created"); },
            Status::Created | Status::Canceled => { panic!("Bet not accepted"); },
            Status::Claimed | Status::Released => { panic!("Response already recorded"); },
            Status::Accepted => {}
        };
    }

    fn approve_release(ref self: Bet) {
        self.assert_release();
        let caller = get_caller_address();
        assert(self.release_status == ReleaseStatus::None, 'Release already approved');
        self
            .release_status =
                if caller == self.maker {
                    ReleaseStatus::MakerApproved
                } else if caller == self.taker {
                    ReleaseStatus::TakerApproved
                } else {
                    panic!("Only maker or taker can approve release")
                };
    }

    fn revoke_release(ref self: Bet) {
        self.assert_release();
        match self.release_status {
            ReleaseStatus::None => { panic!("Release not approved"); },
            ReleaseStatus::MakerApproved => {
                assert(get_caller_address() == self.maker, ASSERT_APPROVAL_STRING);
            },
            ReleaseStatus::TakerApproved => {
                assert(get_caller_address() == self.taker, ASSERT_APPROVAL_STRING);
            }
        };
        self.release_status = ReleaseStatus::None;
    }

    fn release_funds(ref self: Bet) {
        self.assert_release();
        match self.release_status {
            ReleaseStatus::None => { panic!("Release not approved"); },
            ReleaseStatus::MakerApproved => {
                assert(get_caller_address() == self.taker, ASSERT_APPROVAL_STRING);
            },
            ReleaseStatus::TakerApproved => {
                assert(get_caller_address() == self.maker, ASSERT_APPROVAL_STRING);
            }
        };

        self.status = Status::Released;
        let payout = self.wager.amount - (self.wager.amount * self.fee.per_mille.into() / 1000);
        let dispatcher = ERC20ABIDispatcher { contract_address: self.wager.contract_address };

        dispatcher.transfer(self.maker, payout);
        dispatcher.transfer(self.taker, payout);
    }
}
