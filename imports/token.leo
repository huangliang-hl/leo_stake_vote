// The `program` scope defines the data types, functions, and state associated with the `token` program.
program token.aleo {

    // An on-chain mapping, storing the amount of tokens owned by each account
    // The account is stored as a to preserve user privacy.
    mapping stake_amounts: field => u64;
    
    mapping accounts: field => u64;

    // On-chain storage of an `account` map, with `address` as the key,
    // and `u64` as the value.
    record Token {
        owner: address,
        gates: u64,
        amount: u64,
        is_staked: bool,
    }
 
    // Returns a new Token.
    // - `owner` : The address of the account to issue the token to.
    // - `amount`: The amount of tokens to issue.
    // Requires that the function caller is the platform.
    // The platform's address is aleo1x6mzndlel6ren4stve49zqdqes54aqmshee7c563t2etkxdjyyrsg7rv9t.
    transition issue(owner: address, amount: u64) -> Token {
        assert_eq(self.caller, aleo1x6mzndlel6ren4stve49zqdqes54aqmshee7c563t2etkxdjyyrsg7rv9t);
        return Token {
            owner: owner,
            gates: 0u64,
            amount: amount,
            is_staked: false,
        } then finalize (owner, amount);
    }

    finalize issue(owner: address, amount: u64) {
        let hash: field = BHP256::hash(owner);
        let account: u64 = Mapping::get_or_init(accounts, hash, 0u64);
        Mapping::set(accounts, hash, amount + account);
    }

    // Deposits some amount of money.
    // Returns a new Token with the remaining amount of money.
    // - `token` : A record containing tokens to stake.
    // - `amount`: The amount of tokens to stake.
    transition stake(token: Token, amount: u64) -> (Token, Token) {
        is_available(token);
        let difference: u64 = token.amount - amount;

        let remaining: Token = Token {
            owner: token.owner,
            gates: token.gates,
            amount: difference,
            is_staked: false,
        };

        let staked: Token = Token {
            owner: token.owner,
            gates: token.gates,
            amount: amount,
            is_staked: true,
        };

        // Compute the hash of the token owner.
        let hash: field = BHP256::hash(token.owner);

        return (remaining, staked) then finalize (hash, amount);
    }

    // Updates on-chain state by the amount of tokens staked.
    // - `hash`  : The hash of the token owner.
    // - `amount`: The amount of tokens that were staked.
    finalize stake(hash: field, amount: u64) {
        let balance: u64 = Mapping::get_or_init(stake_amounts, hash, 0u64);
        Mapping::set(stake_amounts, hash, amount + balance);
    }

    // Returns a new Token containing the amount of money unstake.
    // - `token` : A record containing tokens to unstake.
    // - `amount`   : The amount of tokens to unstake.
    // Requires that the function caller is the platform.
    transition unstake(deposited_token: Token, amount: u64) -> Token {
        let hash: field = BHP256::hash(deposited_token.owner);

        let token: Token = Token {
            owner: deposited_token.owner,
            gates: deposited_token.gates,
            amount: amount,
            is_staked: false,
        };

        return token then finalize(hash, amount);
    }

    // Updates on-chain state by the amount of tokens unstake.
    // - `hash`  : The hash of the token owner.
    // - `amount`: The amount of tokens that were unstake.
    finalize unstake(hash: field, amount: u64) {
        let balance: u64 = Mapping::get_or_init(stake_amounts, hash, 0u64);
        Mapping::set(stake_amounts, hash, balance - amount);
    }

    /* Transfer */
    transition transfer(token: Token, receiver: address, amount: u64) -> (Token, Token) {
        // Transfer the tokens publicly, by invoking the computation on-chain.
        is_available(token);
        let difference: u64 = token.amount - amount;

        let remaining: Token = Token {
            owner: token.owner,
            gates: token.gates,
            amount: difference,
            is_staked: false,
        };
        let receiver_token: Token = Token {
            owner: receiver,
            gates: token.gates,
            amount: amount,
            is_staked: false,
        };
        return (remaining, receiver_token) then finalize(self.caller, receiver, amount);
    }

    finalize transfer(public sender: address, public receiver: address, public amount: u64) {
        // Decrements `account[sender]` by `amount`.
        // If `account[sender]` does not exist, it will be created.
        // If `account[sender] - amount` underflows, `transfer_public` is reverted.        
        let sender_hash: field = BHP256::hash(sender);
        let receiver_hash: field = BHP256::hash(receiver);

        let sender_amount: u64 = Mapping::get_or_init(accounts, sender_hash, 0u64);
        Mapping::set(accounts, sender_hash, sender_amount - amount);
        
        // Increments `account[receiver]` by `amount`.
        // If `account[receiver]` does not exist, it will be created.
        // If `account[receiver] + amount` overflows, `transfer_public` is reverted.
        let receiver_amount: u64 = Mapping::get_or_init(accounts, receiver_hash, 0u64);
        Mapping::set(accounts, receiver_hash, receiver_amount + amount);
    }


    transition join(t0: Token, t1: Token) -> Token {
        is_available(t0);
        let sum: u64 = t0.amount + t1.amount;
        let t3: Token = Token {
            owner: t0.owner,
            gates: t0.gates,
            amount: sum,
            is_staked: false,
        };
        return t3;
    }

    transition split(t0: Token, amount: u64) -> (Token, Token) {
        is_available(t0);
        let difference: u64 = t0.amount - amount;

        let t1: Token = Token {
            owner: t0.owner,
            gates: t0.gates,
            amount: difference,
            is_staked: false,
        };
        let t2: Token = Token {
            owner: t0.owner,
            gates: t0.gates,
            amount: amount,
            is_staked: false,
        };
        return (t1, t2);
    }

    transition fee(t0: Token, amount: u64) -> Token {
        is_available(t0);
        let difference: u64 = t0.amount - amount;

        let t1: Token = Token {
            owner: t0.owner,
            gates: t0.gates,
            amount: difference,
            is_staked: false,
        };
        return t1 then finalize(t0.owner, amount);
    }

    finalize fee(owner: address, amount: u64) {
        let hash: field = BHP256::hash(owner);
        let account: u64 = Mapping::get_or_init(accounts, hash, 0u64);
        Mapping::set(accounts, hash, account - amount);
    }

    inline is_available(token: Token) {
        // assert_eq(self.caller, token.owner);
        assert_eq(token.is_staked, false);
    }
}
