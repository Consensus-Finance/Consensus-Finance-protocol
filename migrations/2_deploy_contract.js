const TownToken = artifacts.require('TownToken');

module.exports = (deployer) => {
  deployer.deploy(TownToken);
};
