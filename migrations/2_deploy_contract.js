var MyToken = artifacts.require("MyToken");

module.exports = function(deployer) {
  deployer.deploy(MyToken,512000000,'墨蚁MoYi','MYI',8);
};