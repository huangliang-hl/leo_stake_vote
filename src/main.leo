// import token.leo;
// 1、消耗aleo币生成代币
// 2、其他合约是否可以交易代币
// The 'pledge_vote' program.
program pledge_vote.aleo {

    struct ProposalInfo {
        title: field,
        proposer: address,
    }

    record ProposalInfoRecord {
        owner: address,
        gates: u64,
        content:ProposalInfo
    }

    record Ticket {
        owner: address,
        gates: u64,
        pid: field,
    }
    
    record Token {
        owner: address,
        gates: u64,
        amount: u64,
        is_staked: bool,
    }

    mapping stake_amounts: field => u64;
    
    mapping accounts: field => u64;

    mapping proposals: field => ProposalInfo;

    mapping join_all_campagin_record: field => u64;

    mapping agree_votes: field => u64;

    mapping is_votes: field => u8;

    mapping disagree_votes: field => u64;

    transition issue(owner: address, amount: u64) -> Token {
        assert_eq(self.caller, aleo1jht08tf8gr52zhv93k7r0hxh30zjyv4ku4y5h4gz2dfjyksmvy8qtwydvd);
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

    finalize stake(hash: field, amount: u64) {
        let balance: u64 = Mapping::get_or_init(stake_amounts, hash, 0u64);
        Mapping::set(stake_amounts, hash, amount + balance);
    }

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
        let sender_hash: field = BHP256::hash(sender);
        let receiver_hash: field = BHP256::hash(receiver);

        let sender_amount: u64 = Mapping::get_or_init(accounts, sender_hash, 0u64);
        Mapping::set(accounts, sender_hash, sender_amount - amount);
        
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


    transition start_voting_campaign (public owner: address,pid:field) -> ProposalInfo {
        is_onwer(owner);
        let owner_amount:field = BHP256::hash(owner);
        let vote_campaign:ProposalInfo = ProposalInfo{
            title : pid,
            proposer : owner,
        };
        let vote_campaign_record:ProposalInfoRecord = ProposalInfoRecord{
            owner : owner,
            gates : 0u64,
            content : vote_campaign,
        };
        return vote_campaign then finalize(owner,pid,vote_campaign.title,vote_campaign.proposer);
    }
    finalize start_voting_campaign (public owner: address,pid:field,title:field,campaigner:address) {
        let owner_vote:field = BHP256::hash(owner);
        Mapping::set(proposals,owner_vote,ProposalInfo{
            title : title,
            proposer : campaigner,
        });
    }


    inline is_onwer (owner:address) -> bool {
        assert_eq(owner, aleo1jht08tf8gr52zhv93k7r0hxh30zjyv4ku4y5h4gz2dfjyksmvy8qtwydvd);
        return true;
    }


    
    transition agree(ticket: Ticket) {
        // Finalize this vote.
        return then finalize(ticket.pid,ticket.owner);
    }
    finalize agree(public pid: field,ticket_owner:address) {
        let owner:field = BHP256::hash(ticket_owner);
        let participation_times:u64 = Mapping::get_or_init(join_all_campagin_record,owner,0u64);
        // Publicly increment the number of agree votes.
        let is_join:u8 = Mapping::get_or_init(is_votes,BHP256::hash(owner),0u8);
        assert_eq(is_join,0u8);
        let agree_vote: u64 = Mapping::get_or_init(agree_votes, pid, 0u64);
        let stake_amount: u64 = Mapping::get_or_init(stake_amounts,owner,0u64);
        let votes: u64 = agree_vote + participation_times * stake_amount;
        Mapping::set(agree_votes, pid, votes);
        Mapping::set(is_votes, BHP256::hash(owner), 1u8);

    }

    // Vote privately to disagree with a proposal.
    transition disagree(ticket: Ticket) {
        // Finalize this vote.
        return then finalize(ticket.pid,ticket.owner); 
    }
    finalize disagree(public pid: field, ticket_owner:address) {
        let owner:field = BHP256::hash(ticket_owner);
        let participation_times:u64 = Mapping::get_or_init(join_all_campagin_record,owner,0u64);
        // Publicly increment the number of agree votes.
        let is_join:u8 = Mapping::get_or_init(is_votes,BHP256::hash(owner),0u8);
        assert_eq(is_join,0u8);
        let disagree_vote: u64 = Mapping::get_or_init(agree_votes, pid, 0u64);
        let stake_amount: u64 = Mapping::get_or_init(stake_amounts,owner,0u64);
        let votes: u64 = disagree_vote + (participation_times * stake_amount);
        Mapping::set(disagree_votes, pid, votes);
        Mapping::set(is_votes, BHP256::hash(owner), 1u8);
    }

}
