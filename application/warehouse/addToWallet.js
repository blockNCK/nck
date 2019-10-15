/*
 *  SPDX-License-Identifier: Apache-2.0
 */

'use strict';

// Bring key classes into scope, most importantly Fabric SDK network class
const fs = require('fs');
const { FileSystemWallet, X509WalletMixin } = require('fabric-network');
const path = require('path');

const fixtures = path.resolve(__dirname, '../../nck-network');

// A wallet stores a collection of identities
const wallet = new FileSystemWallet('../identity/user/nick/wallet');

async function main() {

    // Main try/catch block
    try {

        // Identity to credentials to be stored in the wallet
        const credPath = path.join(fixtures, '/crypto-config/peerOrganizations/warehouse.nck.com/users/Admin@warehouse.nck.com');
        const cert = fs.readFileSync(path.join(credPath, '/msp/signcerts/Admin@warehouse.nck.com-cert.pem')).toString();
        const key = fs.readFileSync(path.join(credPath, '/msp/keystore/dd0eddbde5d6c997b84abcbdb73ba334ca10b780109c1fd112215c563022c711_sk')).toString();

        // Load credentials into wallet
        const identityLabel = 'Admin@warehouse.nck.com';
        const identity = X509WalletMixin.createIdentity('WarehouseMSP', cert, key);

        await wallet.import(identityLabel, identity);

    } catch (error) {
        console.log(`Error adding to wallet. ${error}`);
        console.log(error.stack);
    }
}

main().then(() => {
    console.log('done');
}).catch((e) => {
    console.log(e);
    console.log(e.stack);
    process.exit(-1);
});