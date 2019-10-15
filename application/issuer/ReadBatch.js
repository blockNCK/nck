/*
SPDX-License-Identifier: Apache-2.0
*/


'use strict';

// Bring key classes into scope, most importantly Fabric SDK network class
const fs = require('fs');
const yaml = require('js-yaml');
const { FileSystemWallet, Gateway } = require('fabric-network');

// A wallet stores a collection of identities for use
const wallet = new FileSystemWallet('../identity/user/susan/wallet');

// Main program function
async function main () {

    // A gateway defines the peers used to access Fabric networks
    const gateway = new Gateway();

    // Main try/catch block
    try {

        // Specify userName for network access
        const userName = 'Admin@issuer.nck.com';

        // Load connection profile; will be used to locate a gateway
        let connectionProfile = yaml.safeLoad(fs.readFileSync('./gateway/networkConnection.yaml', 'utf8'));

        // Set connection options; identity and wallet
        let connectionOptions = {
            identity: userName,
            wallet: wallet,
            discovery: { enabled: false, asLocalhost: true }

        };


        await gateway.connect(connectionProfile, connectionOptions);
        const network = await gateway.getNetwork('nckchannel');
        const contract = await network.getContract('nckcc');
        const result = await contract.evaluateTransaction('getHistoryForBatch','8746296537');
        console.log(`Transaction has been evaluated, result is: ${result.toString()}`);

    } catch (error) {

        console.log(`Error processing transaction. ${error}`);
        console.log(error.stack);

    } finally {

        // Disconnect from the gateway
        console.log('smart contract completeda');
        gateway.disconnect();

    }
}
main().then(() => {

    console.log('Reading a batch is complete.');

}).catch((e) => {

    console.log('Read batch program exception.');
    console.log(e);
    console.log(e.stack);
    process.exit(-1);

});