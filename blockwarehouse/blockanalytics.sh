#!/bin/bash
#

#validate the user of the application through smart contracts
#The application is used by the warehouse. Hence the user must be validated by the warehouse
npm validate.js

# 1. provide the smart contract file
# 2. setup the database suited for the warehouse
# 3. query the blockchain 
# 4. provide the columns needed by user
# 4. process and clean the data

export WAREHOUSE_MSPCONFIGPATH=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/warehouse.nck.com/users/Admin@warehouse.nck.com/msp
export WAREHOUSE_TLS_ROOTCERT_FILE=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/warehouse.nck.com/peers/peer0.warehouse.nck.com/tls/ca.crt

query = docker exec \
  -e CHANNEL_NAME=nckchannel \
  -e CORE_PEER_LOCALMSPID="WarehouseMSP" \
  -e CORE_PEER_ADDRESS=peer0.warehouse.nck.com:7051 \
  -e CORE_PEER_MSPCONFIGPATH=${WAREHOUSE_MSPCONFIGPATH} \
  -e CORE_PEER_TLS_ROOTCERT_FILE=${WAREHOUSE_TLS_ROOTCERT_FILE} \
  -e CORE_PEER_GOSSIP_USELEADERELECTION=true \
  cli \
  peer chaincode query \
    -o orderer.nck.com:7050 \
    -C nckchannel \
    -n nckcc \
    -c '{"function":"queryBatchbyDrugName","Args":["inferon"]}' 

#if database type is mysql
chmod +x bin/database/mysql.sh
./mysql.sh query




