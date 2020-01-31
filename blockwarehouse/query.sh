
#!/bin/bash
#

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

