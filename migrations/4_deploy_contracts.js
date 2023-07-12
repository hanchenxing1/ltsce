//var DeedRepository = artifacts.require("DeedRepository");
var AuctionRepository = artifacts.require("AuctionRepository");

module.exports = function(deployer) {
  //deployer.deploy(DeedRepository, "Smart Act", "SMAUT");
  deployer.deploy(AuctionRepository,"Smart Act", "SMAUT");
};
