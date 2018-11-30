/**
 * @author: xiao.chen
 * @date: 2018.11.24
 * @description: 基于以太坊ERC20发行代币合约
 */
pragma solidity ^0.4.22;

contract IMigrationContract {
    function migrate(address addr, uint256 nas) public returns (bool success);
}
/* use SafeMath */
contract SafeMath {
    function safeAdd(uint256 x, uint256 y) pure internal returns(uint256) {
        uint256 z = x + y;
        require((z >= x) && (z >= y));
        return z;
    }
 
    function safeSubtract(uint256 x, uint256 y) pure internal returns(uint256) {
        require(x >= y);
        uint256 z = x - y;
        return z;
    }
 
    function safeMult(uint256 x, uint256 y) pure internal returns(uint256) {
        uint256 z = x * y;
        require((x == 0)||(z/x == y));
        return z;
    }
    function safeDiv(uint256 x, uint256 y) internal pure returns (uint256) {
        require(y > 0);
        uint256 z = x / y;
        return z;
  }
 
}
 
contract Token {
    uint256 public totalSupply;//总供应量
    function balanceOf(address _owner) internal returns (uint256 balance);
    function transfer(address _to, uint256 _value) external returns (bool success);
    function transferFrom(address _from, address _to, uint256 _value) external returns (bool success);
    function approve(address _spender, uint256 _value) external returns (bool success);
    function allowance(address _owner, address _spender) external returns (uint256 remaining);
    event Transfer(address indexed _from, address indexed _to, uint256 _value);
    event Approval(address indexed _owner, address indexed _spender, uint256 _value);
}
 
 
/*  ERC 20 token */
contract StandardToken is Token {
    function transfer(address _to, uint256 _value) external returns (bool success) {
        if (balances[msg.sender] >= _value && _value > 0) {
            balances[msg.sender] -= _value;
            balances[_to] += _value;
            // emit event
            emit Transfer(msg.sender, _to, _value);
            return true;
        } else {
            return false;
        }
    }
 
    function transferFrom(address _from, address _to, uint256 _value) external returns (bool success) {
        if (balances[_from] >= _value && allowed[_from][msg.sender] >= _value && _value > 0) {
            balances[_to] += _value;
            balances[_from] -= _value;
            allowed[_from][msg.sender] -= _value;
            emit Transfer(_from, _to, _value);
            return true;
        } else {
            return false;
        }
    }
 
    function balanceOf(address _owner) internal returns (uint256 balance) {
        return balances[_owner];
    }
 
    function approve(address _spender, uint256 _value) external returns (bool success) {
        allowed[msg.sender][_spender] = _value;
        // emit event when commit
        emit Approval(msg.sender, _spender, _value);
        return true;
    }
 
    function allowance(address _owner, address _spender) external returns (uint256 remaining) {
        return allowed[_owner][_spender];
    }
 
    mapping (address => uint256) balances;
    mapping (address => mapping (address => uint256)) allowed;
}
 
contract MyToken is StandardToken, SafeMath {
    // metadata
    string  public name;//代币名称
    string  public symbol;//代币符号
    uint256 public decimals;//小数点后位数
    uint256 public constant total = 1024000000;//总供应量,eg. 1024W,10亿2千4百万
    string  public version = "1.0";
 
    // contracts
    address public ethFundDeposit = 0xA1F139FD82DCAbe490352F69802fB8A2Cc8Ae37D;       // ETH存放地址
    address public newContractAddr;         // token更新地址
 
    // crowdsale parameters
    bool    public isFunding;                // 状态切换到true
    uint256 public fundingStartBlock;
    uint256 public fundingStopBlock;
 
    uint256 public currentSupply;           // 正在售卖中的tokens数量
    uint256 public tokenRaised = 0;         // 总的售卖数量token
    uint256 public tokenMigrated = 0;     // 总的已经交易的 token
    uint256 public tokenExchangeRate = 10000;             // 1 ETH = （n）个代币,兑换率
    // events
    event AllocateToken(address indexed _to, uint256 _value);   // 分配的私有交易token;
    event IssueToken(address indexed _to, uint256 _value);      // 公开发行售卖的token;
    event IncreaseSupply(uint256 _value);
    event DecreaseSupply(uint256 _value);
    event Migrate(address indexed _to, uint256 _value);
 
    // 转换
    function formatDecimals(uint256 _value)  internal view returns (uint256 ) {
        return _value * 10 ** decimals;
    }
    /* Initializes contract with initial supply tokens to the creator of the contract */
    constructor (uint256 _supply, string _name, string _symbol, uint8 _decimals) public {
        /* if supply not given then generate 1 million of the smallest unit of the token */
        require (_supply > 0);
        require (_decimals > 0 && _decimals <= 18);
 
        isFunding = false;
        fundingStartBlock = 0;
        fundingStopBlock = 0;

        name = _name;
        symbol = _symbol;
        decimals = _decimals;
//        ethFundDeposit = _ethFundDeposit;

        currentSupply = formatDecimals(_supply);
        totalSupply = formatDecimals(total);
        //balanceOf[msg.sender] = _supply;

        balances[msg.sender] = totalSupply;
        assert(currentSupply <= totalSupply);
    }
    modifier isOwner()  { require(msg.sender == ethFundDeposit); _; }
 
    ///  设置token汇率
    function setTokenExchangeRate(uint256 _tokenExchangeRate) isOwner external {
        require (_tokenExchangeRate > 0);
        require (_tokenExchangeRate != tokenExchangeRate);
 
        tokenExchangeRate = _tokenExchangeRate;
    }
 
    /// @dev 超发token处理
    function increaseSupply (uint256 _value) isOwner external {
        uint256 value = formatDecimals(_value);
        require (value + currentSupply <= totalSupply);
        currentSupply = safeAdd(currentSupply, value);
        /// emit event log
        emit IncreaseSupply(value);
    }
 
    /// @dev 被盗token处理
    function decreaseSupply (uint256 _value) isOwner external {
        uint256 value = formatDecimals(_value);
        require (value + tokenRaised <= currentSupply);
 
        currentSupply = safeSubtract(currentSupply, value);
        emit DecreaseSupply(value);
    }
 
    ///  启动区块检测 异常的处理
    function startFunding (uint256 _fundingStartBlock, uint256 _fundingStopBlock) isOwner external {
        require (!isFunding);
        require (_fundingStartBlock < _fundingStopBlock);
        require (block.number < _fundingStartBlock);
 
        fundingStartBlock = _fundingStartBlock;
        fundingStopBlock = _fundingStopBlock;
        isFunding = true;
    }
 
    ///  关闭区块异常处理
    function stopFunding() isOwner external {
        require (isFunding);
        isFunding = false;
    }
 
    /// 开发了一个新的合同来接收token（或者更新token）
    function setMigrateContract(address _newContractAddr) isOwner external {
        require (_newContractAddr != newContractAddr);
        newContractAddr = _newContractAddr;
    }
 
    /// 设置新的所有者地址
    function changeOwner(address _newFundDeposit) isOwner() external {
        require (_newFundDeposit != address(0x0));
        ethFundDeposit = _newFundDeposit;
    }
 
    ///转移token到新的合约
    function migrate() external {
        require(!isFunding);
        require(newContractAddr != address(0x0));
 
        uint256 tokens = balances[msg.sender];
        require (tokens > 0);
 
        balances[msg.sender] = 0;
        tokenMigrated = safeAdd(tokenMigrated, tokens);
 
        IMigrationContract newContract = IMigrationContract(newContractAddr);
        require (newContract.migrate(msg.sender, tokens));
 
        emit Migrate(msg.sender, tokens);               // log it
    }
 
    /// 转账ETH
    function transferETH() isOwner external{
        require (address(this).balance > 0);
        require (ethFundDeposit.send(address(this).balance));
    }
    ///  将token分配到预处理地址。
    function allocateToken (address _addr, uint256 _eth) isOwner external {
        require (_eth > 0);
        require (_addr != address(0x0));
 
        uint256 tokens = safeMult(formatDecimals(_eth), tokenExchangeRate);
        require (tokens + tokenRaised <= currentSupply);
 
        tokenRaised = safeAdd(tokenRaised, tokens);
        balances[_addr] += tokens;
 
        emit AllocateToken(_addr, tokens);  // 记录token日志
    }
    function getBalance() public view returns (uint256){
        return address(this).balance;
    }
    function findBalance(address _address) public view returns(uint256){
        return balances[_address];
    }
    /// 购买token
    function () external payable {
        require (isFunding);
        require (msg.value > 0);
        require (block.number >= fundingStartBlock);
        require (block.number <= fundingStopBlock);
        uint256 tokens = safeDiv(formatDecimals(safeMult(msg.value, tokenExchangeRate)),10**18);
        require (tokens + tokenRaised <= currentSupply);
 
        tokenRaised = safeAdd(tokenRaised, tokens);
        balances[msg.sender] += tokens;
 
        emit IssueToken(msg.sender, tokens);  //记录日志
    }
}