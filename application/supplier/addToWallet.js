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
const wallet = new FileSystemWallet('../identity/user/adam/wallet');

async function main() {

    // Main try/catch block
    try {

        // Identity to credentials to be stored in the wallet
        const credPath = path.join(fixtures, '/crypto-config/peerOrganizations/supplier.nck.com/users/Admin@supplier.nck.com');
        const cert = fs.readFileSync(path.join(credPath, '/msp/signcerts/Admin@supplier.nck.com-cert.pem')).toString();
        const key = fs.readFileSync(path.join(credPath, '/msp/keystore/b7fd65ea2d894b6f4649f1f257789971dcbe382fc3017b0f3816c8cee8a781c3_sk')).toString();

        // Load credentials into wallet
        const identityLabel = 'Admin@supplier.nck.com';
        const identity = X509WalletMixin.createIdentity('SupplierMSP', cert, key);

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