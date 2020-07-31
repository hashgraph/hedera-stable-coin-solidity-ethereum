const { scripts, ConfigManager, network } = require("@openzeppelin/cli");
const { add, push, create } = scripts;

async function deploy(options) {
    add({ contractsData: [{ name: "Hbar", alias: "Hbar" }]});
    await push(options);
    await create(Object.assign({ contractAlias: "Hbar" }, options));
}

module.exports = function(deployer, networkName, accounts) {
    deployer.then(async() => {
        const { network, txParams } = await ConfigManager.initNetworkConfiguration({
            network: networkName, 
            from: accounts[0]
        });
        await deploy({ network, txParams });
    })
}