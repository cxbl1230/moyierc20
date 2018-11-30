App = {
    web3Provider: null,
    contractAddress:"0x9d846296eb789a70b4ff0253a06aeffb9beca544",
    contracts: {},
    init: function() {
        return App.initWeb3();
    },
    //初始化web3,数据驱动地址
    initWeb3: function() {
        if (typeof web3 !== 'undefined') {
            App.web3Provider = web3.currentProvider;
        } else {
            // If no injected web3 instance is detected, fall back to Ganache
            App.web3Provider = new Web3.providers.HttpProvider('http://localhost:8545');
        }
        web3 = new Web3(App.web3Provider);
        return App.initContract();
    },

    initContract: function() {
        $.getJSON('MyToken.json', function(data) {
            App.contracts.MyToken = TruffleContract(data);
            App.contracts.MyToken.setProvider(App.web3Provider);
            return App.done();
        });
        return App.ready();
    },
    done:function(){
        App.contracts.MyToken.deployed().then(function(instance){
            return instance.isFunding.call();
        }).then(function(result){
            if(result === true){
                $("#token-status").html("结束私募").addClass("btn-danger");
            }else{

            }
        });
        App.getBalance();
    },
    //绑定点事件
    ready: function() {
        $("#my-account").html(App.contractAddress);
        $(document).on('click',"#findaddress",App.find);
        $(document).on("click",".btn-buy",App.buy);
        $(document).on('click','#token-withdraw',App.widthdraw);
        $(document).on("click","#token-status",App.starting);
    },
    /*
      查询拥有的代币数量
     */
    find:function(){
        var addr = $("#myaddress").val();
        if(addr){
            App.contracts.MyToken.deployed().then(function(instance){
                return instance.findBalance(addr);
            }).then(function(result){
            	var myi = result.c[0];
            	myi = myi / 100000000;//代币小数后8位
            	$(".my-tokens label").html(myi);
                console.log(myi);
            }).then(function(err){
                console.log(err);
            });
        }
    },
    /*
     购买myi
     */
    buy:function(){
        var val = $(this).data("money");
        if(val>0){
            web3.eth.getAccounts(function(error, accounts) {
            if (error) {
                console.log(error);
                return;
            }
            var account = accounts[0];
            web3.eth.sendTransaction({from: account,to:App.contractAddress, value: web3.toWei(val, 'ether')}, (err, res) => {
                console.log(res);
                if(res !=undefined){
                    if($("#buy-tips").hasClass("hidden")){
                        $("#buy-tips").removeClass("hidden");
                    }
                }
                
            });
        });

        }
    },
    starting:function(){
        console.log('starting...');
        App.contracts.MyToken.deployed().then(function(instance) {
            return instance.startFunding(10,120);
        }).then(function(result) {
            console.log(result);
        }).catch(function(err) {
            console.log(err.message);
        });

    },
    getBalance:function(){
        App.contracts.MyToken.deployed().then(function(instance) {
            return instance.getBalance.call();
        }).then(function(result) {
            var ethNum = result.c[0] / 10000;
            $("#token-withdraw em").html(ethNum);
        }).catch(function(err) {
            console.log(err.message);
        });
    },
    setOwner:function(){
        var addr = "0xC3d6e439200ae8f28875208f0379D09bA3aBf40b";
        App.contracts.MyToken.deployed().then(function(instance) {
                adoptionInstance = instance;
                return adoptionInstance.setOwner(addr);
            }).then(function(result) {
                console.log(result);
            }).catch(function(err) {
                console.log(err.message);
            });

    },
    /**
     * 提现
     * @return {[type]} [description]
     */
    widthdraw:function(){
        App.contracts.MyToken.deployed().then(function(instance) {
            return instance.transferETH();
        }).then(function(result) {
            $("#token-withdraw em").html(0);
        }).catch(function(err) {
            console.log(err.message);
        });
        
    }
};

$(function() {
    $(window).load(function() {
        App.init();
    });
});
