contract DGXConfig {
    function getConfigEntryAddr(bytes32 key) returns (address);
    function getConfigEntryInt(bytes32 key) returns (uint);
    function isAdmin(address who) returns (bool);
}

contract AddressRegistry {
    function contains(address who) returns (bool);
}

contract GoldRegistry {
    function getFee(address _gold) returns (uint);
    function regFeePayment(address _gold) returns (bool);
}

contract GoldTokenLedger {
    function () {}

    struct Account {
        bool initialized;
        uint balance;
        uint lastPaid;
        mapping(address => uint) allowance;
    }

    address public config;
    address public owner;
    uint public totalSupply;
    mapping(address => Account) users;

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

    function setOwner(address _owner) {
        if (msg.sender == owner) {
            owner = _owner;
        }
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
        return users[who].initialized;
    }

    function addUser(address who) internal {
        users[who].initialized = true;
        users[who].lastPaid = now;
        NewAccount(who);
    }

    function allowance(address _owner, address _spender) constant returns (uint) {
        return users[_owner].allowance[_spender];
    }

    function balanceOf(address who) returns (uint) {
        if (who == 0) return 0;
        uint bal = users[who].balance;
        uint due = calculateDemurrage(who);
        if (due >= bal) return 0;
        return bal - due;
    }

    function actualBalanceOf(address who) returns (uint) {
        return users[who].balance;
    }

    function getFeeDays(address who) returns (uint) {
        return (now - users[who].lastPaid) / billingPeriod();
    }

    function demurrageCalc(uint _balance, uint _days) returns (uint) {
        return (_days * _balance * storageRate()) / getBase();
    }

    function calculateDemurrage(address who) returns (uint) {
        if (users[who].lastPaid == 0) return 0;
        return demurrageCalc(users[who].balance, getFeeDays(who));
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
        users[msg.sender].allowance[_addr] = _val;
        Approval(msg.sender, _addr, _val);
        return true;
    }

    function deductFees(address who) returns (bool) {
        if (who == accountingWallet()) return true;
        if (who == txFeeWallet()) return true;
        uint balance = users[who].balance;
        if (balance == 0) {
            users[who].lastPaid = now;
            return true;
        }
        uint fee = calculateDemurrage(who);
        if (fee == 0) {
            users[who].lastPaid = now;
            return true;
        }
        if (fee > balance) fee = balance;
        users[who].balance -= fee;
        users[accountingWallet()].balance += fee;
        Transfer(who, accountingWallet(), fee);
        users[who].lastPaid = now;
        return true;
    }

    function payStorageFee(address _gold) {
        uint256 _sfee = GoldRegistry(goldRegistry()).getFee(_gold);
        if (!userExists(tx.origin)) addUser(tx.origin);
        if (!deductFees(tx.origin)) throw;
        if (balanceOf(tx.origin) < _sfee) throw;
        if (!GoldRegistry(goldRegistry()).regFeePayment(_gold)) throw;
        users[tx.origin].balance -= _sfee;
        users[accountingWallet()].balance += _sfee;
        Transfer(tx.origin, accountingWallet(), _sfee);
    }

    function transfer(address _to, uint _value) returns (bool) {
        if (_to == 0) throw;
        if (!userExists(_to)) addUser(_to);
        uint fee = calculateTxFee(_value, msg.sender);
        if (msg.sender == accountingWallet()) fee = 0;
        if (msg.sender == txFeeWallet()) fee = 0;
        uint total = _value + fee;
        if (users[msg.sender].balance < total) return false;
        if (!deductFees(msg.sender)) return false;
        if (!deductFees(_to)) return false;
        users[msg.sender].balance -= total;
        users[_to].balance += _value;
        users[txFeeWallet()].balance += fee;
        Transfer(msg.sender, txFeeWallet(), fee);
        Transfer(msg.sender, _to, _value);
        return true;
    }

    function transferFrom(address _from, address _to, uint _value) returns (bool) {
        if (_to == 0) throw;
        if (!userExists(_to)) addUser(_to);
        uint fee = calculateTxFee(_value, _from);
        if (_from == accountingWallet()) fee = 0;
        if (_from == txFeeWallet()) fee = 0;
        uint total = _value + fee;
        if (users[_from].allowance[msg.sender] < total) return false;
        if (users[_from].balance < total) return false;
        if (!deductFees(_from)) return false;
        if (!deductFees(_to)) return false;
        users[_from].allowance[msg.sender] -= total;
        users[_from].balance -= total;
        users[_to].balance += _value;
        users[txFeeWallet()].balance += fee;
        Transfer(_from, txFeeWallet(), fee);
        Transfer(_from, _to, _value);
        return true;
    }

    function auditRelease() returns (bool) {
        if (msg.sender != txFeeWallet()) return false;
        uint bal = users[txFeeWallet()].balance;
        users[txFeeWallet()].balance = 0;
        users[accountingWallet()].balance += bal;
        Transfer(msg.sender, accountingWallet(), bal);
        return true;
    }

    function ledgerMint(address _bar, address _to, uint256 _value, uint256 _fee) returns (bool) {
        if (msg.sender != goldRegistry()) return false;
        if (!userExists(_to)) addUser(_to);
        if (!userExists(_to)) return false;
        users[accountingWallet()].balance += _fee;
        Transfer(tx.origin, accountingWallet(), _fee);
        users[_to].balance += _value - _fee;
        totalSupply += _value;
        Transfer(tx.origin, _to, _value - _fee);
        return true;
    }

    function recastCall(address _from, address _to, uint256 _value, uint256 _fee) returns (bool) {
        if (msg.sender != recastContract()) return false;
        if (!userExists(_to)) addUser(_to);
        deductFees(_from);
        if (users[_from].balance < (_value + _fee)) return false;
        if (!userExists(_to)) return false;
        users[_from].balance -= (_value + _fee);
        users[_to].balance += _value;
        users[accountingWallet()].balance += _fee;
        Transfer(_from, accountingWallet(), _fee);
        Transfer(_from, _to, _value);
        return true;
    }
}
