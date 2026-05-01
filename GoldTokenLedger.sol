// Submitted by EthereumHistory (ethereumhistory.com)
// Source reconstructed via bytecode reverse engineering.
// All 44 function selectors identified. One function name is a placeholder:
// recordStorageFeePayment (selector 0x65afd0ed) — true name unknown.

contract DGXConfig {
    function getConfigEntryAddr(bytes32 key) returns (address);
    function getConfigEntryInt(bytes32 key) returns (uint);
    function isAdmin(address who) returns (bool);
}

contract AddressRegistry {
    function contains(address who) returns (bool);
}

contract GoldRegistry {
    function getFee(address who) returns (uint);
    function recordStorageFeePayment(address who) returns (bool); // selector 0x65afd0ed — placeholder name
}

contract GoldTokenLedger {
    struct Account {
        bool initialized;
        uint balance;
        uint lastPaid;
        mapping(address => uint) allowance;
    }

    address public config;
    address public owner;
    uint public totalSupply;
    mapping(address => Account) accounts;

    event Transfer(address indexed _from, address indexed _to, uint256 indexed _value);
    event Approval(address indexed _owner, address indexed _spender, uint256 _value);
    event NewAccount(address indexed _account);

    function GoldTokenLedger(address _conf) {
        config = _conf;
        owner = msg.sender;
    }

    function getOwner() returns (address) {
        return owner;
    }

    function setOwner(address _owner) returns (bool) {
        if (msg.sender != owner) throw;
        owner = _owner;
        return true;
    }

    function getConfigAddress() returns (address) {
        return config;
    }

    function isAdmin(address who) returns (bool) {
        return DGXConfig(config).isAdmin(who);
    }

    function vendorRegistry() returns (address) { return DGXConfig(config).getConfigEntryAddr("registry/vendor"); }
    function custodianRegistry() returns (address) { return DGXConfig(config).getConfigEntryAddr("registry/custodian"); }
    function goldRegistry() returns (address) { return DGXConfig(config).getConfigEntryAddr("registry/gold"); }
    function auditorRegistry() returns (address) { return DGXConfig(config).getConfigEntryAddr("registry/auditor"); }
    function accountingWallet() returns (address) { return DGXConfig(config).getConfigEntryAddr("wallet/accounting"); }
    function txFeeWallet() returns (address) { return DGXConfig(config).getConfigEntryAddr("wallet/txfee"); }
    function minterContract() returns (address) { return DGXConfig(config).getConfigEntryAddr("contract/minter"); }
    function recastContract() returns (address) { return DGXConfig(config).getConfigEntryAddr("contract/recast"); }
    function goldTokenLedger() returns (address) { return DGXConfig(config).getConfigEntryAddr("ledger/token"); }

    function storageRate() returns (uint) { return DGXConfig(config).getConfigEntryInt("settings/rate"); }
    function getBase() returns (uint) { return DGXConfig(config).getConfigEntryInt("settings/base"); }
    function requiredConfirmations() returns (uint) { return DGXConfig(config).getConfigEntryInt("settings/confirmations"); }
    function billingPeriod() returns (uint) { return DGXConfig(config).getConfigEntryInt("settings/billingperiod"); }
    function recastFee() returns (uint) { return DGXConfig(config).getConfigEntryInt("settings/recastfee"); }
    function redemptionFee() returns (uint) { return DGXConfig(config).getConfigEntryInt("settings/redemptionfee"); }
    function txFee() returns (uint) { return DGXConfig(config).getConfigEntryInt("settings/txfee"); }
    function txFeeMax() returns (uint) { return DGXConfig(config).getConfigEntryInt("settings/txfeemax"); }

    function userExists(address who) returns (bool) {
        return accounts[who].initialized;
    }

    function allowance(address _owner, address _spender) constant returns (uint) {
        return accounts[_owner].allowance[_spender];
    }

    function balanceOf(address who) returns (uint) {
        uint bal = accounts[who].balance;
        uint due = calculateDemurrage(who);
        if (due >= bal) return 0;
        return bal - due;
    }

    function actualBalanceOf(address who) returns (uint) {
        return accounts[who].balance;
    }

    function getFeeDays(address who) returns (uint) {
        if (accounts[who].lastPaid == 0) return 0;
        return (now - accounts[who].lastPaid) / billingPeriod();
    }

    function demurrageCalc(uint _balance, uint _days) returns (uint) {
        return (_days * _balance * storageRate()) / getBase();
    }

    function calculateDemurrage(address who) returns (uint) {
        return demurrageCalc(accounts[who].balance, getFeeDays(who));
    }

    function calculateTxFee(uint _value, address _user) returns (uint) {
        if (_user == accountingWallet()) return 0;
        if (_user == txFeeWallet()) return 0;
        uint fee = (_value * txFee()) / getBase();
        if (fee > txFeeMax()) fee = txFeeMax();
        return fee;
    }

    function isVendor(address who) returns (bool) {
        return AddressRegistry(vendorRegistry()).contains(who);
    }

    function isCustodian(address who) returns (bool) {
        return AddressRegistry(custodianRegistry()).contains(who);
    }

    function isAuditor(address who) returns (bool) {
        return AddressRegistry(auditorRegistry()).contains(who);
    }

    function isGoldRegistry(address who) returns (bool) {
        return who == goldRegistry();
    }

    function approve(address _addr, uint _val) returns (bool) {
        accounts[msg.sender].allowance[_addr] = _val;
        Approval(msg.sender, _addr, _val);
        return true;
    }

    function settle(address who) internal returns (bool) {
        if (who == accountingWallet()) return true;
        if (who == txFeeWallet()) return true;
        uint balance = accounts[who].balance;
        if (balance == 0) {
            accounts[who].lastPaid = now;
            return true;
        }
        uint fee = calculateDemurrage(who);
        if (fee == 0) {
            accounts[who].lastPaid = now;
            return true;
        }
        if (fee > balance) fee = balance;
        accounts[who].balance -= fee;
        accounts[accountingWallet()].balance += fee;
        Transfer(who, accountingWallet(), fee);
        accounts[who].lastPaid = now;
        return true;
    }

    function deductFees(address who) returns (bool) {
        return settle(who);
    }

    function payStorageFee(address who) returns (bool) {
        uint fee = GoldRegistry(goldRegistry()).getFee(who);
        if (!accounts[tx.origin].initialized) {
            accounts[tx.origin].initialized = true;
            accounts[tx.origin].lastPaid = now;
            NewAccount(tx.origin);
        }
        if (!settle(tx.origin)) throw;
        if (accounts[tx.origin].balance < fee) throw;
        if (!GoldRegistry(goldRegistry()).recordStorageFeePayment(who)) throw;
        accounts[tx.origin].balance -= fee;
        accounts[accountingWallet()].balance += fee;
        Transfer(tx.origin, accountingWallet(), fee);
        return true;
    }

    function transfer(address _to, uint _value) returns (bool) {
        if (_to == 0) throw;
        if (!accounts[_to].initialized) {
            accounts[_to].initialized = true;
            accounts[_to].lastPaid = now;
            NewAccount(_to);
        }
        uint fee = calculateTxFee(_value, msg.sender);
        if (msg.sender == accountingWallet()) fee = 0;
        if (msg.sender == txFeeWallet()) fee = 0;
        uint total = _value + fee;
        if (accounts[msg.sender].balance < total) return false;
        if (!settle(msg.sender)) return false;
        if (!settle(_to)) return false;
        accounts[msg.sender].balance -= total;
        accounts[_to].balance += _value;
        accounts[txFeeWallet()].balance += fee;
        Transfer(msg.sender, txFeeWallet(), fee);
        Transfer(msg.sender, _to, _value);
        return true;
    }

    function transferFrom(address _from, address _to, uint _value) returns (bool) {
        if (_to == 0) throw;
        if (!accounts[_to].initialized) {
            accounts[_to].initialized = true;
            accounts[_to].lastPaid = now;
            NewAccount(_to);
        }
        uint fee = calculateTxFee(_value, _from);
        if (_from == accountingWallet()) fee = 0;
        if (_from == txFeeWallet()) fee = 0;
        uint total = _value + fee;
        if (accounts[_from].allowance[msg.sender] < total) return false;
        if (accounts[_from].balance < total) return false;
        if (!settle(_from)) return false;
        if (!settle(_to)) return false;
        accounts[_from].allowance[msg.sender] -= total;
        accounts[_from].balance -= total;
        accounts[_to].balance += _value;
        accounts[txFeeWallet()].balance += fee;
        Transfer(_from, txFeeWallet(), fee);
        Transfer(_from, _to, _value);
        return true;
    }

    function auditRelease() returns (bool) {
        if (msg.sender != txFeeWallet()) return false;
        uint bal = accounts[txFeeWallet()].balance;
        accounts[txFeeWallet()].balance = 0;
        accounts[accountingWallet()].balance += bal;
        Transfer(msg.sender, accountingWallet(), bal);
        return true;
    }

    function ledgerMint(address _bar, address _to, uint256 _value, uint256 _fee) returns (bool) {
        if (msg.sender != goldRegistry()) return false;
        if (!accounts[_to].initialized) {
            accounts[_to].initialized = true;
            accounts[_to].lastPaid = now;
            NewAccount(_to);
        }
        if (!userExists(_to)) return false;
        accounts[accountingWallet()].balance += _fee;
        Transfer(tx.origin, accountingWallet(), _fee);
        accounts[_to].balance += _value - _fee;
        totalSupply += _value;
        Transfer(tx.origin, _to, _value - _fee);
        return true;
    }

    function recastCall(address _from, address _to, uint256 _value, uint256 _fee) returns (bool) {
        if (msg.sender != recastContract()) return false;
        if (!accounts[_to].initialized) {
            accounts[_to].initialized = true;
            accounts[_to].lastPaid = now;
            NewAccount(_to);
        }
        settle(_from);
        if (accounts[_from].balance < (_value + _fee)) return false;
        if (!userExists(_to)) return false;
        accounts[_from].balance -= (_value + _fee);
        accounts[_to].balance += _value;
        accounts[accountingWallet()].balance += _fee;
        Transfer(_from, accountingWallet(), _fee);
        Transfer(_from, _to, _value);
        return true;
    }
}
