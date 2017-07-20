/**
 * Overflow aware uint math functions.
 *
 * Inspired by https://github.com/MakerDAO/maker-otc/blob/master/contracts/simple_market.sol
 * Inspired by https://github.com/Firstbloodio/token/blob/master/smart_contract/FirstBloodToken.sol
 */
pragma solidity ^0.4.11;
contract SafeMath {
    //internals

    function safeMul(uint a, uint b) internal returns (uint) {
        uint c = a * b;
        assert(a == 0 || c / a == b);
        return c;
    }

    function safeSub(uint a, uint b) internal returns (uint) {
        assert(b <= a);
        return a - b;
    }

    function safeAdd(uint a, uint b) internal returns (uint) {
        uint c = a + b;
        assert(c >= a && c >= b);
        return c;
    }

    function assert(bool assertion) internal {
        if (!assertion) throw;
    }
}


/**
 * ERC 20 token
 *
 * https://github.com/ethereum/EIPs/issues/20
 */
contract Token {

    /// @return total amount of tokens
    function totalSupply() constant returns (uint256 supply) {}

    /// @param _owner The address from which the balance will be retrieved
    /// @return The balance
    function balanceOf(address _owner) constant returns (uint256 balance) {}

    /// @notice send `_value` token to `_to` from `msg.sender`
    /// @param _to The address of the recipient
    /// @param _value The amount of token to be transferred
    /// @return Whether the transfer was successful or not
    function transfer(address _to, uint256 _value) returns (bool success) {}

    /// @notice send `_value` token to `_to` from `_from` on the condition it is approved by `_from`
    /// @param _from The address of the sender
    /// @param _to The address of the recipient
    /// @param _value The amount of token to be transferred
    /// @return Whether the transfer was successful or not
    function transferFrom(address _from, address _to, uint256 _value) returns (bool success) {}

    /// @notice `msg.sender` approves `_addr` to spend `_value` tokens
    /// @param _spender The address of the account able to transfer the tokens
    /// @param _value The amount of wei to be approved for transfer
    /// @return Whether the approval was successful or not
    function approve(address _spender, uint256 _value) returns (bool success) {}

    /// @param _owner The address of the account owning tokens
    /// @param _spender The address of the account able to transfer the tokens
    /// @return Amount of remaining tokens allowed to spent
    function allowance(address _owner, address _spender) constant returns (uint256 remaining) {}

    event Transfer(address indexed _from, address indexed _to, uint256 _value);

    event Approval(address indexed _owner, address indexed _spender, uint256 _value);

}


/**
 * ERC 20 token
 *
 * https://github.com/ethereum/EIPs/issues/20
 */
contract StandardToken is Token {

    /**
     * Reviewed:
     * - Interger overflow = OK, checked
     */
    function transfer(address _to, uint256 _value) returns (bool success) {
        //Default assumes totalSupply can't be over max (2^256 - 1).
        //If your token leaves out totalSupply and can issue more tokens as time goes on, you need to check if it doesn't wrap.
        //Replace the if with this one instead.
        if (balances[msg.sender] >= _value && balances[_to] + _value > balances[_to]) {
            //if (balances[msg.sender] >= _value && _value > 0) {
            balances[msg.sender] -= _value;
            balances[_to] += _value;
            Transfer(msg.sender, _to, _value);
            return true;
        }
        else {return false;}
    }

    function transferFrom(address _from, address _to, uint256 _value) returns (bool success) {
        //same as above. Replace this line with the following if you want to protect against wrapping uints.
        if (balances[_from] >= _value && allowed[_from][msg.sender] >= _value && balances[_to] + _value > balances[_to]) {
            //if (balances[_from] >= _value && allowed[_from][msg.sender] >= _value && _value > 0) {
            balances[_to] += _value;
            balances[_from] -= _value;
            allowed[_from][msg.sender] -= _value;
            Transfer(_from, _to, _value);
            return true;
        }
        else {return false;}
    }

    function balanceOf(address _owner) constant returns (uint256 balance) {
        return balances[_owner];
    }

    function approve(address _spender, uint256 _value) returns (bool success) {
        allowed[msg.sender][_spender] = _value;
        Approval(msg.sender, _spender, _value);
        return true;
    }

    function allowance(address _owner, address _spender) constant returns (uint256 remaining) {
        return allowed[_owner][_spender];
    }

    mapping (address => uint256) balances;

    mapping (address => mapping (address => uint256)) allowed;

    uint256 public totalSupply;

}


/**
 * DropDeck crowdsale ICO contract.
 *
 * Security criteria evaluated against http://ethereum.stackexchange.com/questions/8551/methodological-security-review-of-a-smart-contract
 *
 *
 */
contract DropDeckToken is StandardToken, SafeMath {

    string public name = "DropDeck Token";

    string public symbol = "DDT";

    uint public decimals = 18;

    uint public startBlock; //crowdsale start block (set in constructor)
    uint public endBlock; //crowdsale end block (set in constructor)

    // Initial founder address (set in constructor)
    // All deposited ETH will be instantly forwarded to this address.
    // Address is a multisig wallet.
    address public founder = 0x0;

    uint public etherCap = 50000 * 10 ** 18; //max amount raised during crowdsale
    uint public transferLockup = 185142; //transfers are locked for this many blocks after endBlock (assuming 14 second blocks, this is 1 months)
    uint public founderLockup = 2252571; //founder allocation cannot be created until this many blocks after endBlock (assuming 14 second blocks, this is 1 year)

    uint public ddteamAllocation = 20 * 10 ** 16; //20% of token supply allocated post-crowdsale for the Founders, Team, Advisors, Early Contributors
    uint public partnershipsAllocation = 10 * 10 ** 16; //10% of token supply allocated post-crowdsale for the Partnerships, Bug, Bounties, Referral Rewards
    uint public reserveAllocation = 10 * 10 ** 16; //10% of token supply allocated post-crowdsale for the Reserve fund
    uint public ddfundAllocation = 10 * 10 ** 16; //10% of token supply allocated post-crowdsale for the DropDeck fund for investments, lending, promotions and rewards

    bool public ddteamAllocated = false; //this will change to true when the team fund is allocated
    bool public partnershipsAllocated = false; //this will change to true when the partnerships fund is allocated
    bool public reserveAllocated = false; //this will change to true when the reserve fund is allocated
    bool public ddfundAllocated = false; //this will change to true when the DropDeck fund is allocated

    uint public presaleTokenSupply = 0; //this will keep track of the token supply created during the crowdsale
    uint public presaleEtherRaised = 0; //this will keep track of the Ether raised during the crowdsale
    bool public halted = false; //the founder address can set this to true to halt the crowdsale due to emergency

    event Buy(address indexed sender, uint eth, uint fbt);

    event Withdraw(address indexed sender, address to, uint eth);

    event AllocateDDTeamTokens(address indexed sender);

    event AllocatePartnershipsTokens(address indexed sender);

    event AllocateReserveAndDDfundTokens(address indexed sender);

    function DropDeckToken(address founderInput, uint startBlockInput, uint endBlockInput) {
        founder = founderInput;
        startBlock = startBlockInput;
        endBlock = endBlockInput;
    }

    /**
     * Security review
     *
     * - Integer overflow: does not apply, blocknumber can't grow that high
     * - Division is the last operation and constant, should not cause issues
     * - Price function plotted https://github.com/Firstbloodio/token/issues/2
     */
    function price() constant returns (uint) {
        if (block.number >= startBlock && block.number < startBlock + 257) return 5500;
        //first power hour 1 ETH = 5500 DDT
        if (block.number >= startBlock && block.number >= startBlock + 257 && block.number < startBlock + 514) return 5000;
        //next power hour 1 ETH = 5000 DDT
        if (block.number >= startBlock && block.number >= startBlock + 514 && block.number < startBlock + 771) return 4500;
        //3rd power hour 1 ETH = 4500 DDT
        if (block.number >= startBlock && block.number >= startBlock + 771 && block.number < startBlock + 1028) return 4000;
        //4rd power hour 1 ETH = 4000 DDT
        if (block.number < startBlock || block.number > endBlock) return 3500;
        //default price
        return 3500;
        //crowdsale price
    }

    // price() exposed for unit tests
    function testPrice(uint blockNumber) constant returns (uint) {
        if (block.number >= startBlock && block.number < startBlock + 257) return 5500;
        //first power hour 1 ETH = 5500 DDT
        if (block.number >= startBlock && block.number >= startBlock + 257 && block.number < startBlock + 514) return 5000;
        //next power hour 1 ETH = 5000 DDT
        if (block.number >= startBlock && block.number >= startBlock + 514 && block.number < startBlock + 771) return 4500;
        //3rd power hour 1 ETH = 4500 DDT
        if (block.number >= startBlock && block.number >= startBlock + 771 && block.number < startBlock + 1028) return 4000;
        //4rd power hour 1 ETH = 4000 DDT
        if (block.number < startBlock || block.number > endBlock) return 3500;
        //default price
        return 3500;
        //crowdsale price
    }

    // Buy entry point
    function buy() {
        buyRecipient(msg.sender);
    }

    /**
     * Main token buy function.
     *
     * Buy for the sender itself or buy on the behalf of somebody else (third party address).
     *
     * Security review
     *
     * - Integer math: ok - using SafeMath
     *
     * - halt flag added - ok
     *
     * Applicable tests:
     *
     * - Test halting, buying, and failing
     * - Test buying on behalf of a recipient
     * - Test buy
     * - Test unhalting, buying, and succeeding
     * - Test buying after the sale ends
     *
     */
    function buyRecipient(address recipient) {
        bytes32 hash = sha256(msg.sender);
        if (block.number < startBlock || block.number > endBlock || safeAdd(presaleEtherRaised, msg.value) > etherCap || halted) throw;
        uint tokens = safeMul(msg.value, price());
        balances[recipient] = safeAdd(balances[recipient], tokens);
        totalSupply = safeAdd(totalSupply, tokens);
        presaleEtherRaised = safeAdd(presaleEtherRaised, msg.value);

        // TODO: Is there a pitfall of forwarding message value like this
        // TODO: Different address for founder deposits and founder operations (halt, unhalt)
        // as founder opeations might be easier to perform from normal geth account
        if (!founder.call.value(msg.value)()) throw;
        //immediately send Ether to founder address

        Buy(recipient, msg.value, tokens);
    }

    /**
     * Set up founder address token balance.
     *
     * AllocatePartnershipsTokens() must be calld first.
     *
     * Security review
     *
     * - Integer math: ok - only called once with fixed parameters
     *
     * Applicable tests:
     *
     * - Test AllocateReserveAndDDfundTokens
     *
     */
    function allocateDDTeamTokens() {
        if (msg.sender != founder) throw;
        if (block.number <= endBlock + founderLockup) throw;
        if (ddteamAllocated) throw;
        if (!partnershipsAllocated) throw;
        balances[founder] = safeAdd(balances[founder], presaleTokenSupply * ddteamAllocation / (1 ether));
        totalSupply = safeAdd(totalSupply, presaleTokenSupply * ddteamAllocation / (1 ether));
        ddteamAllocated = true;
        AllocateDDTeamTokens(msg.sender);
    }

    /**
     * Set up founder address token balance.
     *
     * Set up bounty pool.
     *
     * Security review
     *
     * - Integer math: ok - only called once with fixed parameters
     *
     * Applicable tests:
     *
     * - Test founder token allocation too early
     * - Test founder token allocation on time
     * - Test founder token allocation twice
     *
     */

    function allocatePartnershipsTokens() {
        if (msg.sender != founder) throw;
        if (ddteamAllocated) throw;
        if (!partnershipsAllocated) throw;
        balances[founder] = safeAdd(balances[founder], presaleTokenSupply * partnershipsAllocation / (1 ether));
        totalSupply = safeAdd(totalSupply, presaleTokenSupply * partnershipsAllocation / (1 ether));
        partnershipsAllocated = true;
        AllocatePartnershipsTokens(msg.sender);
    }

    function allocateReserveAndDDfundTokens() {
        if (msg.sender != founder) throw;
        if (block.number <= endBlock) throw;
        if (reserveAllocated || ddfundAllocated) throw;
        presaleTokenSupply = totalSupply;
        balances[founder] = safeAdd(balances[founder], presaleTokenSupply * reserveAllocation / (1 ether));
        totalSupply = safeAdd(totalSupply, presaleTokenSupply * reserveAllocation / (1 ether));
        balances[founder] = safeAdd(balances[founder], ddfundAllocation);
        totalSupply = safeAdd(totalSupply, ddfundAllocation);
        reserveAllocated = true;
        ddfundAllocated = true;
        AllocateReserveAndDDfundTokens(msg.sender);
    }

    /**
     * Emergency Stop ICO.
     *
     *  Applicable tests:
     *
     * - Test unhalting, buying, and succeeding
     */
    function halt() {
        if (msg.sender != founder) throw;
        halted = true;
    }

    function unhalt() {
        if (msg.sender != founder) throw;
        halted = false;
    }

    /**
     * Change founder address (where ICO ETH is being forwarded).
     *
     * Applicable tests:
     *
     * - Test founder change by hacker
     * - Test founder change
     * - Test founder token allocation twice
     */
    function changeFounder(address newFounder) {
        if (msg.sender!=founder) throw;
        founder = newFounder;
    }

    /**
     * ERC 20 Standard Token interface transfer function
     *
     * Prevent transfers until freeze period is over.
     *
     * Applicable tests:
     *
     * - Test restricted early transfer
     * - Test transfer after restricted period
     */
    function transfer(address _to, uint256 _value) returns (bool success) {
        if (block.number <= endBlock + transferLockup && msg.sender != founder) throw;
        return super.transfer(_to, _value);
    }
    /**
     * ERC 20 Standard Token interface transfer function
     *
     * Prevent transfers until freeze period is over.
     */
    function transferFrom(address _from, address _to, uint256 _value) returns (bool success) {
        if (block.number <= endBlock + transferLockup && msg.sender != founder) throw;
        return super.transferFrom(_from, _to, _value);
    }
}