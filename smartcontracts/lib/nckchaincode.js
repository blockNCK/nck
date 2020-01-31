/*
# Copyright IBM Corp. All Rights Reserved.
#
# SPDX-License-Identifier: Apache-2.0
*/

'use strict';
const shim = require('fabric-shim');
const util = require('util');

let Chaincode = class {
  async Init(stub) {
    let ret = stub.getFunctionAndParameters();
    console.info(ret);
    console.info('=========== Instantiated NCK Chaincode ===========');
    return shim.success();
  }

  async Invoke(stub) {
    console.info('Transaction ID: ' + stub.getTxID());
    console.info(util.format('Args: %j', stub.getArgs()));

    let ret = stub.getFunctionAndParameters();
    console.info(ret);

    let method = this[ret.fcn];
    if (!method) {
      console.log('no function of name:' + ret.fcn + ' found');
      throw new Error('Received unknown function ' + ret.fcn + ' invocation');
    }
    try {
      let payload = await method(stub, ret.params, this);
      return shim.success(payload);
    } catch (err) {
      console.log(err);
      return shim.error(err);
    }
  }

  // ========================================================
  // initDrug - create a new drug batch for specific RFID tag
  // ========================================================
  async initDrug(stub, args, thisClass) {
    if (args.length != 8) {
      throw new Error('Incorrect number of arguments. Expecting 8');
    }
    // ==== Input sanitation ====
    console.info('--- start init drug batch ---')

    let RFIDtag = args[0];
    let drugName = args[1].toLowerCase();
    let organization = args[2].toLowerCase();
    let amount = parseInt(args[3]);
    if (typeof amount !== 'number') {
        throw new Error('4th argument must be a numeric string');
    }

    let dateManufactured = args[4];
    let dateExpired = args[5];
    let minTemp = parseInt(args[6]);
    if (typeof minTemp !== 'number') {
        throw new Error('6th argument must be a numeric string');
    }

    let maxTemp = parseInt(args[7]);
    if (typeof maxTemp !== 'number') {
        throw new Error('7th argument must be a numeric string');
    }

    // ==== Check if batch already exists ====
    let drugbatchState = await stub.getState(RFIDtag);
    if (drugbatchState.toString()) {
      throw new Error('This batch already exists: ' + RFIDtag + 'of this type: ' +drugName);
    }

    // ==== Create batch object and marshal to JSON ====
    let batch = {};
    batch.docType = 'drug';
    batch.RFIDtag = RFIDtag;
    batch.drugName = drugName;
    batch.amount = amount;
    batch.organization = organization;
    batch.dateManufactured = dateManufactured;
    batch.dateExpired = dateExpired;
    batch.minTemp = minTemp;
    batch.maxTemp = maxTemp;

    // === Save batch to state ===
    await stub.putState(RFIDtag, Buffer.from(JSON.stringify(batch)));
    let indexName = 'drugName ~ RFIDtag'
    let indexName2 = 'organization ~ drugName'
    let drugNameRFIDTagIndexKey = await stub.createCompositeKey(indexName, [batch.drugName, batch.RFIDtag]);
    let organizationDrugNameIndexKey = await stub.createCompositeKey(indexName2,[batch.organization, batch.drugName]);
    console.info(drugNameRFIDTagIndexKey);
    console.info(organizationDrugNameIndexKey);
    //  Save index entry to state. Only the key name is needed, no need to store a duplicate copy of the batch.
    //  Note - passing a 'nil' value will effectively delete the key from state, therefore we pass null character as value
    await stub.putState(drugNameRFIDTagIndexKey, Buffer.from('\u0000'));
    await stub.putState(organizationDrugNameIndexKey, Buffer.from('\u0000'));
    // ==== batch saved and indexed. Return success ====
    console.info('- end init batch');
  }

  // ===============================================
  // readBatch - read a batch from chaincode state
  // ===============================================
  async readBatch(stub, args, thisClass) {
    if (args.length != 1) {
      throw new Error('Incorrect number of arguments. Expecting RFID tag to query');
    }

    let batchTag = args[0];
    if (!batchTag) {
      throw new Error(' RFID batch tag must not be empty');
    }
    let batchAsbytes = await stub.getState(batchTag); //get the marble from chaincode state
    if (!batchAsbytes.toString()) {
      let jsonResp = {};
      jsonResp.Error = 'Batch does not exist: ' + batchTag;
      throw new Error(JSON.stringify(jsonResp));
    }
    console.info('=======================================');
    console.log(batchAsbytes.toString());
    console.info('=======================================');
    return batchAsbytes;
  }

  // ==================================================
  // delete - remove a batch key/value pair from state
  // ==================================================
  async delete(stub, args, thisClass) {
    if (args.length != 1) {
      throw new Error('Incorrect number of arguments. Expecting RFID tag to delete');
    }
    let RFIDbatchtag = args[0];
    if (!RFIDbatchtag) {
      throw new Error('RFID batch tag must not be empty');
    }
    // to maintain the color~name index, we need to read the marble first and get its color
    let RFIDBatchAsbytes = await stub.getState(RFIDbatchtag); //get the marble from chaincode state
    let jsonResp = {};
    if (!RFIDBatchAsbytes) {
      jsonResp.error = 'batch does not exist: ' + RFIDbatchtag;
      throw new Error(jsonResp);
    }
    let batchJSON = {};
    try {
      batchJSON = JSON.parse(RFIDbatchtag.toString());
    } catch (err) {
      jsonResp = {};
      jsonResp.error = 'Failed to decode JSON of: ' + RFIDbatchtag;
      throw new Error(jsonResp);
    }

    await stub.deleteState(RFIDbatchtag); //remove the marble from chaincode state

    // delete the index
    let indexName = 'drugName ~ RFIDtag';
    let nameTagIndexKey = stub.createCompositeKey(indexName, [batchJSON.drugName, batchJSON.RFIDtag]);
    if (!nameTagIndexKey) {
      throw new Error(' Failed to create the createCompositeKey');
    }
    let indexName2 = 'organization ~ drugName';
    let organizationNameIdexKey = stub.createCompositeKey(indexName2,[batchJSON.organization, batchJSON.drugName]);
    //  Delete index entry to state.
    await stub.deleteState(nameTagIndexKey);
    await stub.deleteState(organizationDrugNameIndexKey);
  }

  // ===========================================================
  // transfer a batch by setting a new organization name on the batch
  // ===========================================================
  async transferBatch(stub, args, thisClass) {

    if (args.length < 2) {
      throw new Error('Incorrect number of arguments. Expecting RFID tag and organization')
    }

    let RFIDtag = args[0];
    let newOrganization = args[1].toLowerCase();
    console.info('- start transferMarble ', RFIDtag, newOrganization);

    let batchAsBytes = await stub.getState(RFIDtag);
    if (!batchAsBytes || !batchAsBytes.toString()) {
      throw new Error('batch does not exist');
    }
    let batchToTransfer = {};
    try {
      batchToTransfer = JSON.parse(batchAsBytes.toString()); //unmarshal
    } catch (err) {
      let jsonResp = {};
      jsonResp.error = 'Failed to decode JSON of: ' + marbleName;
      throw new Error(jsonResp);
    }
    console.info(marbleToTransfer);
    batchToTransfer.organization = newOrganization; //change the owner

    let batchJSONasBytes = Buffer.from(JSON.stringify(batchToTransfer));
    await stub.putState(RFIDtag, batchJSONasBytes); //rewrite the marble

    console.info('- end transferBatch (success)');
  }

  // ===========================================================================================
  // getBatchByRange performs a range query based on the start and end keys provided.

  // Read-only function results are not typically submitted to ordering. If the read-only
  // results are submitted to ordering, or if the query is used in an update transaction
  // and submitted to ordering, then the committing peers will re-execute to guarantee that
  // result sets are stable between endorsement time and commit time. The transaction is
  // invalidated by the committing peers if the result set has changed between endorsement
  // time and commit time.
  // Therefore, range queries are a safe option for performing update transactions based on query results.
  // ===========================================================================================
  async getBatchByRange(stub, args, thisClass) {

    if (args.length < 2) {
      throw new Error('Incorrect number of arguments. Expecting 2');
    }

    let startKey = args[0];
    let endKey = args[1];

    let resultsIterator = await stub.getStateByRange(startKey, endKey);
    let method = thisClass['getAllResults'];
    let results = await method(resultsIterator, false);

    return Buffer.from(JSON.stringify(results));
  }

  // ==== Example: GetStateByPartialCompositeKey/RangeQuery =========================================
  // transferBatchBasedOnName will transfer batch of a given name to a certain new organization.
  // Uses a GetStateByPartialCompositeKey (range query) against  name ~ tags 'index'.
  // Committing peers will re-execute range queries to guarantee that result sets are stable
  // between endorsement time and commit time. The transaction is invalidated by the
  // committing peers if the result set has changed between endorsement time and commit time.
  // Therefore, range queries are a safe option for performing update transactions based on query results.
  // ===========================================================================================
  async transferBatchOnName(stub, args, thisClass) {

    if (args.length < 2) {
      throw new Error('Incorrect number of arguments. Expecting name of the drug and organization');
    }

    let name = args[0];
    let newOrganization = args[1].toLowerCase();
    console.info('- start transferBatchBasedOnName ', name, newOrganization);

    // Query the name ~ tag index by name
    // This will execute a key range query on all keys starting with 'drug name'
    let drugTagResultsIterator = await stub.getStateByPartialCompositeKey('drugName ~ RFIDtag', [name]);

    let method = thisClass['transferBatch'];
    // Iterate through result set and for each batch found, transfer to newOrganization
    while (true) {
      let responseRange = await drugTagResultsIterator.next();
      if (!responseRange || !responseRange.value || !responseRange.value.key) {
        return;
      }
      console.log(responseRange.value.key);

      // let value = res.value.value.toString('utf8');
      let objectType;
      let attributes;
      ({
        objectType,
        attributes
      } = await stub.splitCompositeKey(responseRange.value.key));

      let returnedDrugName = attributes[0];
      let returnedbatch = attributes[1];
      console.info(util.format('- found a batch from index:%s drug name:%s batch:%s\n', objectType, returnedbatch, returnedDrugName));

      // Now call the transfer function for the found batch.
      // Re-use the same function that is used to transfer individual batch
      let response = await method(stub, [returnedbatch, newOrganization]);
    }

    let responsePayload = util.format('Transferred %s batch to %s', name, newOrganization);
    console.info('- end transferBatchBasedOnName: ' + responsePayload);
  }


  async queryBatchByOrganization(stub, args, thisClass) {

    if (args.length < 1) {
      throw new Error('Incorrect number of arguments. Expecting organization.')
    }

    let organization = args[0].toLowerCase();
    let queryString = {};
    queryString.selector = {};
    queryString.selector.docType = 'batch';
    queryString.selector.organization = organization;
    let method = thisClass['getQueryResultForQueryString'];
    let queryResults = await method(stub, JSON.stringify(queryString), thisClass);
    return queryResults; //shim.success(queryResults);
  }


  async queryBatch(stub, args, thisClass) {

    if (args.length < 1) {
      throw new Error('Incorrect number of arguments. Expecting queryString');
    }
    let queryString = args[0];
    if (!queryString) {
      throw new Error('queryString must not be empty');
    }
    let method = thisClass['getQueryResultForQueryString'];
    let queryResults = await method(stub, queryString, thisClass);
    return queryResults;
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

  // =========================================================================================
  // getQueryResultForQueryString executes the passed in query string.
  // Result set is built and returned as a byte array containing the JSON results.
  // =========================================================================================
  async getQueryResultForQueryString(stub, queryString, thisClass) {

    console.info('- getQueryResultForQueryString queryString:\n' + queryString)
    let resultsIterator = await stub.getQueryResult(queryString);
    let method = thisClass['getAllResults'];

    let results = await method(resultsIterator, false);

    return Buffer.from(JSON.stringify(results));
  }

  async getHistoryForBatch(stub, args, thisClass) {

    if (args.length < 1) {
      throw new Error('Incorrect number of arguments. Expecting 1')
    }
    let RFIDtag = args[0];
    console.info('- start getHistoryForBatch: %s\n', RFIDtag);

    let resultsIterator = await stub.getHistoryForKey(RFIDtag);
    let method = thisClass['getAllResults'];
    let results = await method(resultsIterator, true);

    return Buffer.from(JSON.stringify(results));
  }


  async getBatchByRangeWithPagination(stub, args, thisClass) {
    if (args.length < 2) {
      throw new Error('Incorrect number of arguments. Expecting 2');
    }
    const startKey = args[0];
    const endKey = args[1];

    const pageSize = parseInt(args[2], 10);
    const bookmark = args[3];

    const { iterator, metadata } = await stub.getStateByRangeWithPagination(startKey, endKey, pageSize, bookmark);
    const getAllResults = thisClass['getAllResults'];
    const results = await getAllResults(iterator, false);
    // use RecordsCount and Bookmark to keep consistency with the go sample
    results.ResponseMetadata = {
      RecordsCount: metadata.fetched_records_count,
      Bookmark: metadata.bookmark,
    };
    return Buffer.from(JSON.stringify(results));
  }

  // =========================================================================================
  // getQueryResultForQueryStringWithPagination executes the passed in query string with
  // pagination info. Result set is built and returned as a byte array containing the JSON results.
  // =========================================================================================
  async queryBatchWithPagination(stub, args, thisClass) {

    if (args.length < 3) {
      return shim.Error("Incorrect number of arguments. Expecting 3")
    }

    const queryString = args[0];
    const pageSize = parseInt(args[1], 10);
    const bookmark = args[2];

    const { iterator, metadata } = await stub.getQueryResultWithPagination(queryString, pageSize, bookmark);
    const getAllResults = thisClass['getAllResults'];
    const results = await getAllResults(iterator, false);
    // use RecordsCount and Bookmark to keep consistency with the go sample
    results.ResponseMetadata = {
      RecordsCount: metadata.fetched_records_count,
      Bookmark: metadata.bookmark,
    };

    return Buffer.from(JSON.stringify(results));
  }
};

shim.start(new Chaincode());
