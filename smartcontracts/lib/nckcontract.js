/*
 * SPDX-License-Identifier: Apache-2.0
 */

'use strict';

const { Contract } = require('fabric-contract-api');

class NCKContract extends Contract {

    async initLedger(ctx) {
        console.info('============= START : Initialize Ledger ===========');
        const batch = [
            {
               RFIDtag: '5432565466',
               drugName: 'inferon',
               amount: '50',
               organization: 'yekinto',
               dateManufactured: '2019-03-04',
               dateExpired: '2020-05-20',
               minTemp: '15',
               maxTemp: '20',
            },
            {
                RFIDtag: '4324987425',
                drugName: 'teriperatide',
                amount: '100',
                organization: 'tomorotz',
                dateManufactured: '2019-06-24',
                dateExpired: '2020-12-30',
                minTemp: '10',
                maxTemp: '20',
             },
             {
                RFIDtag: '4324947283',
                drugName: 'Erythromycin',
                amount: '150',
                organization: 'tomorotz',
                dateManufactured: '2019-07-20',
                dateExpired: '2019-12-05',
                minTemp: '15',
                maxTemp: '23',
             },
             {
                RFIDtag: '5543687575',
                drugName: 'inferon',
                amount: '50',
                organization: 'yekinto',
                dateManufactured: '2019-03-04',
                dateExpired: '2020-05-20',
                minTemp: '15',
                maxTemp: '20',
             },
             {
                RFIDtag: '76487865368',
                drugName: 'Alkeran',
                amount: '100',
                organization: 'weton',
                dateManufactured: '2019-08-20',
                dateExpired: '2019-12-10',
                minTemp: '25',
                maxTemp: '30',
             },
             {
                RFIDtag: '8447248953',
                drugName: 'Ritonavir',
                amount: '30',
                organization: 'borex',
                dateManufactured: '2019-03-15',
                dateExpired: '2019-10-12',
                minTemp: '14',
                maxTemp: '20',
             },
             {
                RFIDtag: '8535893582',
                drugName: 'VePesid',
                amount: '80',
                organization: 'gorongo',
                dateManufactured: '2019-07-05',
                dateExpired: '2020-02-20',
                minTemp: '23',
                maxTemp: '30',
             },
             {
                RFIDtag: '7434574523',
                drugName: 'Neupogen',
                amount: '100',
                organization: 'gorongo',
                dateManufactured: '2019-10-23',
                dateExpired: '2020-10-23',
                minTemp: '20',
                maxTemp: '25',
             },
             {
                RFIDtag: '8746296537',
                drugName: 'Procrit',
                amount: '50',
                organization: 'voeltoty',
                dateManufactured: '2019-10-20',
                dateExpired: '2020-12-05',
                minTemp: '17',
                maxTemp: '25',
             },
             {
                RFIDtag: '46793579024',
                drugName: 'Sandostatin',
                amount: '100',
                organization: 'quient',
                dateManufactured: '2019-04-05',
                dateExpired: '2020-05-10',
                minTemp: '19',
                maxTemp: '27',
             },
        ];

        for (let i = 0; i < batch.length; i++) {
            batch[i].docType = 'batch';
            await ctx.stub.putState(batch[i].RFIDtag, Buffer.from(JSON.stringify(batch[i])));
            let indexName = 'drugName ~ RFIDtag'
            let drugNameRFIDTagIndexKey = await ctx.stub.createCompositeKey(indexName, [batch[i].drugName, batch[i].RFIDtag]);
            await ctx.stub.putState(drugNameRFIDTagIndexKey, Buffer.from('\u0000'));
        
            console.info('Added <--> ', batch[i]);
        }
        console.info('============= END : Initialize Ledger ===========');
    }

  // ===============================================
  // readBatch - read a batch from chaincode state
  // ===============================================
    async queryBatch(ctx, RFIDtag) {
        const batchAsBytes = await ctx.stub.getState(RFIDtag); // get the batch from chaincode state
        if (!batchAsBytes || batchAsBytes.length === 0) {
            throw new Error(`${RFIDtag} does not exist`);
        }
        console.info('=======================================');
        console.log(batchAsBytes.toString());
        console.info('=======================================');
        return batchAsbytes;
    }

  // =====================================================
  // createBatch - create a batch and add to the chaincode
  // =====================================================
    async createBatch(ctx, RFIDtag, drugName, amount, organization,dateManufactured, dateExpired, minTemp, maxTemp ) {
      
        // ==== Check if batch already exists ====
        let drugbatchState = await ctx.stub.getState(RFIDtag);
        if (drugbatchState.toString()) {
        throw new Error('This batch already exists: ' + RFIDtag + 'of this type: ' +drugName);
        }

        drugName = drugName.toLowerCase();
        organization = organization.toLowerCase();
        console.info('============= START : Create Batch ===========');
        const batch = {
            docType: 'batch',
            RFIDtag,
            drugName,
            amount,
            organization,
            dateManufactured,
            dateExpired,
            minTemp,
            maxTemp,
        };
        await ctx.stub.putState(RFIDtag, Buffer.from(JSON.stringify(batch)));
        let indexName = 'drugName ~ RFIDtag'
        let drugNameRFIDTagIndexKey = await ctx.stub.createCompositeKey(indexName, [batch.drugName, batch.RFIDtag]);
        //  Save index entry to state. Only the key name is needed, no need to store a duplicate copy of the batch.
        //  Note - passing a 'nil' value will effectively delete the key from state, therefore we pass null character as value
        await ctx.stub.putState(drugNameRFIDTagIndexKey, Buffer.from('\u0000'));    
        console.info('============= END : Create Batch ===========');
    }

    async transferBatch(ctx, RFIDtag, newOrganization) {
        console.info('============= START : changeOrganization ===========');

        const batchAsBytes = await ctx.stub.getState(RFIDtag); // get the batch from chaincode state
        if (!batchAsBytes || batchAsBytes.length === 0) {
            throw new Error(`${RFIDtag} does not exist`);
        }
        let batchToTransfer = {};
        try {
          batchToTransfer = JSON.parse(batchAsBytes.toString()); //unmarshal
        } catch (err) {
          let jsonResp = {};
          jsonResp.error = 'Failed to decode JSON of: ' + RFIDtag;
          throw new Error(jsonResp);
        }
        batchToTransfer.organization = newOrganization; //change the organization
    
        let batchJSONasBytes = Buffer.from(JSON.stringify(batchToTransfer));
        await ctx.stub.putState(RFIDtag, batchJSONasBytes); //rewrite the batch
        console.info('============= END : changeOrganization ===========');
    }

    async getAllResults(iterator, isHistory) {
    let allResults = [];
    while (true) {
      let res = await iterator.next();

      if (res.value && res.value.value.toString()) {
        let jsonRes = {};
        console.log(res.value.value.toString('utf8'));

        if (isHistory && isHistory === true) {
          jsonRes.TxId = res.value.tx_id;
          jsonRes.Timestamp = res.value.timestamp;
          jsonRes.IsDelete = res.value.is_delete.toString();
          try {
            jsonRes.Value = JSON.parse(res.value.value.toString('utf8'));
          } catch (err) {
            console.log(err);
            jsonRes.Value = res.value.value.toString('utf8');
          }
        } else {
          jsonRes.Key = res.value.key;
          try {
            jsonRes.Record = JSON.parse(res.value.value.toString('utf8'));
          } catch (err) {
            console.log(err);
            jsonRes.Record = res.value.value.toString('utf8');
          }
        }
        allResults.push(jsonRes);
      }
      if (res.done) {
        console.log('end of data');
        await iterator.close();
        console.info(allResults);
        return allResults;
      }
    }
    }

    async getHistoryForBatch(ctx, RFIDtag) {

        console.info('- start getHistoryForBatch: %s\n', RFIDtag);  
        let resultsIterator = await ctx.stub.getHistoryForKey(RFIDtag);
        let results = await this.getAllResults(resultsIterator, true);   
        return Buffer.from(JSON.stringify(results));

    }    

}

module.exports = NCKContract;
