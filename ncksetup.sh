#!/bin/bash
#

echo ""
echo "  _   _  _____ _  __      _   _ ______ _________          ______  _____  _  __  "
echo " | \ | |/ ____| |/ /     | \ | |  ____|__   __\ \        / / __ \|  __ \| |/ /  "
echo " |  \| | |    | ' /      |  \| | |__     | |   \ \  /\  / / |  | | |__) | ' /   "
echo " | .   | |    |  <       | .   |  __|    | |    \ \/  \/ /| |  | |  _  /|  <    "
echo " | |\  | |____| . \      | |\  | |____   | |     \  /\  / | |__| | | \ \| . \   "
echo " |_| \_|\_____|_|\_|     |_| \_|______|  |_|      \/  \/   \____/|_|  \_\_|\_\  "
echo ""

#wait till the function completes the action
readiness_probe(){
  sleep 3
}

cd nck-network
chmod +x cryptogen
chmod +x configtxgen

export SYS_CHANNEL=byfn-sys-channel
export COMPOSE_PROJECT_NAME=nck
export CHANNEL_NAME=nckchannel


#---------------------------------------------------------------------------------------------------------
#                                       Network creation
#---------------------------------------------------------------------------------------------------------

#==================================================
#       crypto generation
#==================================================

echo "Generate necessary crypto files"
./cryptogen generate --config=./crypto-config.yaml
readiness_probe

#==================================================
#       artifacts creation
#==================================================

mkdir channel-artifacts

echo "Generate genesis block"
./configtxgen -profile TwoOrgsOrdererGenesis -channelID $SYS_CHANNEL -outputBlock ./channel-artifacts/genesis.block
readiness_probe

echo "Generate channel artifacts"
./configtxgen -profile TwoOrgsChannel -outputCreateChannelTx ./channel-artifacts/channel.tx -channelID $CHANNEL_NAME
readiness_probe

echo "Create anchor peers of the organizations"
./configtxgen -profile TwoOrgsChannel -outputAnchorPeersUpdate ./channel-artifacts/WarehouseMSPanchors.tx -channelID nckchannel -asOrg WarehouseMSP

./configtxgen -profile TwoOrgsChannel -outputAnchorPeersUpdate ./channel-artifacts/IssuerMSPanchors.tx -channelID nckchannel -asOrg IssuerMSP

./configtxgen -profile TwoOrgsChannel -outputAnchorPeersUpdate ./channel-artifacts/SupplierMSPanchors.tx -channelID nckchannel -asOrg SupplierMSP
readiness_probe

#==================================================
#       Docker environment setup
#==================================================

export IMAGE_TAG=1.4.3
export SYS_CHANNEL=byfn-sys-channel
export COMPOSE_PROJECT_NAME=nck
export CHANNEL_NAME=nckchannel

echo "pull latest images for the cli"
docker-compose -f docker-compose-cli.yaml up -d
readiness_probe

export WAREHOUSE_MSPCONFIGPATH=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/warehouse.nck.com/users/Admin@warehouse.nck.com/msp
export WAREHOUSE_TLS_ROOTCERT_FILE=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/warehouse.nck.com/peers/peer0.warehouse.nck.com/tls/ca.crt

export SUPPLIER_MSPCONFIGPATH=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/supplier.nck.com/users/Admin@supplier.nck.com/msp 
export SUPPLIER_TLS_ROOTCERT_FILE=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/supplier.nck.com/peers/peer0.supplier.nck.com/tls/ca.crt

export ISSUER_MSPCONFIGPATH=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/issuer.nck.com/users/Admin@issuer.nck.com/msp 
export ISSUER_TLS_ROOTCERT_FILE=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/issuer.nck.com/peers/peer0.issuer.nck.com/tls/ca.crt

export ORDERER_TLS_ROOTCERT_FILE=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/ordererOrganizations/nck.com/orderers/orderer.nck.com/msp/tlscacerts/tlsca.nck.com-cert.pem

#==================================================
#       Channel installation
#==================================================

echo "install channel"
docker exec \
  -e CHANNEL_NAME=nckchannel \
  -e CORE_PEER_LOCALMSPID="WarehouseMSP" \
  -e CORE_PEER_ADDRESS=peer0.warehouse.nck.com:7051 \
  -e CORE_PEER_MSPCONFIGPATH=$WAREHOUSE_MSPCONFIGPATH \
  -e CORE_PEER_TLS_ROOTCERT_FILE=${WAREHOUSE_TLS_ROOTCERT_FILE} \
  cli \
  peer channel create \
    -o orderer.nck.com:7050 \
    -c $CHANNEL_NAME \
    -f ./channel-artifacts/channel.tx \
    --tls --cafile $ORDERER_TLS_ROOTCERT_FILE
readiness_probe

echo "install in the warehouse organization"
docker exec \
  -e CHANNEL_NAME=nckchannel \
  -e CORE_PEER_LOCALMSPID="WarehouseMSP" \
  -e CORE_PEER_ADDRESS=peer0.warehouse.nck.com:7051 \
  -e CORE_PEER_MSPCONFIGPATH=${WAREHOUSE_MSPCONFIGPATH} \
  -e CORE_PEER_TLS_ROOTCERT_FILE=${WAREHOUSE_TLS_ROOTCERT_FILE} \
  cli \
  peer channel join \
    -b nckchannel.block 
readiness_probe

echo "install in the supplier organization"
docker exec \
  -e CHANNEL_NAME=nckchannel \
  -e CORE_PEER_LOCALMSPID="SupplierMSP" \
  -e CORE_PEER_ADDRESS=peer0.supplier.nck.com:9051  \
  -e CORE_PEER_MSPCONFIGPATH=${SUPPLIER_MSPCONFIGPATH} \
  -e CORE_PEER_TLS_ROOTCERT_FILE=${SUPPLIER_TLS_ROOTCERT_FILE} \
  cli \
  peer channel join \
  -b nckchannel.block 
readiness_probe

echo "install in the issuer organization"
docker exec \
  -e CHANNEL_NAME=nckchannel \
  -e CORE_PEER_LOCALMSPID="IssuerMSP"  \
  -e CORE_PEER_ADDRESS=peer0.issuer.nck.com:10151  \
  -e CORE_PEER_MSPCONFIGPATH=${ISSUER_MSPCONFIGPATH} \
  -e CORE_PEER_TLS_ROOTCERT_FILE=${ISSUER_TLS_ROOTCERT_FILE} \
  cli \
  peer channel join \
  -b nckchannel.block 
readiness_probe

#==================================================
#       Definition of anchor peers
#==================================================

echo "Definition of warehouse anchor peer"
docker exec \
  -e CHANNEL_NAME=nckchannel \
  -e CORE_PEER_LOCALMSPID="WarehouseMSP" \
  -e CORE_PEER_ADDRESS=peer0.warehouse.nck.com:7051 \
  -e CORE_PEER_MSPCONFIGPATH=${WAREHOUSE_MSPCONFIGPATH} \
  -e CORE_PEER_TLS_ROOTCERT_FILE=${WAREHOUSE_TLS_ROOTCERT_FILE} \
  cli \
  peer channel update \
    -o orderer.nck.com:7050 \
    -c $CHANNEL_NAME \
    -f ./channel-artifacts/WarehouseMSPanchors.tx \
    --tls --cafile $ORDERER_TLS_ROOTCERT_FILE 
readiness_probe

echo "Definition of supplier anchor peer"
docker exec \
  -e CHANNEL_NAME=nckchannel \
  -e CORE_PEER_LOCALMSPID="SupplierMSP" \
  -e CORE_PEER_ADDRESS=peer0.supplier.nck.com:9051  \
  -e CORE_PEER_MSPCONFIGPATH=${SUPPLIER_MSPCONFIGPATH} \
  -e CORE_PEER_TLS_ROOTCERT_FILE=${SUPPLIER_TLS_ROOTCERT_FILE} \
  cli \
  peer channel update \
    -o orderer.nck.com:7050 \
    -c $CHANNEL_NAME \
    -f ./channel-artifacts/SupplierMSPanchors.tx \
    --tls --cafile $ORDERER_TLS_ROOTCERT_FILE 
readiness_probe

echo "Definition of issuer anchor peer"
docker exec \
  -e CHANNEL_NAME=nckchannel \
  -e CORE_PEER_LOCALMSPID="IssuerMSP"  \
  -e CORE_PEER_ADDRESS=peer0.issuer.nck.com:10151  \
  -e CORE_PEER_MSPCONFIGPATH=${ISSUER_MSPCONFIGPATH} \
  -e CORE_PEER_TLS_ROOTCERT_FILE=${ISSUER_TLS_ROOTCERT_FILE} \
  cli \
  peer channel update \
  -o orderer.nck.com:7050 \
  -c $CHANNEL_NAME \
  -f ./channel-artifacts/IssuerMSPanchors.tx \
  --tls --cafile ${ORDERER_TLS_ROOTCERT_FILE} 
readiness_probe

#---------------------------------------------------------------------------------------------------------
#                                       Chaincode creation
#---------------------------------------------------------------------------------------------------------

#==================================================
#       Install chaincode
#==================================================

echo "install chaincode in the warehouse peers"
docker exec \
  -e CHANNEL_NAME=nckchannel \
  -e CORE_PEER_LOCALMSPID="WarehouseMSP" \
  -e CORE_PEER_ADDRESS=peer0.warehouse.nck.com:7051 \
  -e CORE_PEER_MSPCONFIGPATH=${WAREHOUSE_MSPCONFIGPATH} \
  -e CORE_PEER_TLS_ROOTCERT_FILE=${WAREHOUSE_TLS_ROOTCERT_FILE} \
  cli \
  peer chaincode install \
  -n nckcc \
  -v 1.0 \
  -l node \
  -p /opt/gopath/src/github.com/contract
readiness_probe

echo "install chaincode in the supplier peers"
docker exec \
  -e CHANNEL_NAME=nckchannel \
  -e CORE_PEER_LOCALMSPID="SupplierMSP" \
  -e CORE_PEER_ADDRESS=peer0.supplier.nck.com:9051  \
  -e CORE_PEER_MSPCONFIGPATH=${SUPPLIER_MSPCONFIGPATH} \
  -e CORE_PEER_TLS_ROOTCERT_FILE=${SUPPLIER_TLS_ROOTCERT_FILE} \
  cli \
  peer chaincode install \
   -n nckcc \
   -v 1.0 \
   -l node \
   -p /opt/gopath/src/github.com/contract
readiness_probe

echo "install chaincode in the issuer peers"
docker exec \
  -e CHANNEL_NAME=nckchannel \
  -e CORE_PEER_LOCALMSPID="IssuerMSP"  \
  -e CORE_PEER_ADDRESS=peer0.issuer.nck.com:10151  \
  -e CORE_PEER_MSPCONFIGPATH=${ISSUER_MSPCONFIGPATH} \
  -e CORE_PEER_TLS_ROOTCERT_FILE=${ISSUER_TLS_ROOTCERT_FILE} \
  cli \
  peer chaincode install \
   -n nckcc \
   -v 1.0 \
   -l node \
   -p /opt/gopath/src/github.com/contract
readiness_probe

#==================================================
#       Instantiate chaincode
#==================================================

echo "instantiate chaincode"
docker exec \
  -e CHANNEL_NAME=nckchannel \
  -e CORE_PEER_LOCALMSPID="WarehouseMSP" \
  -e CORE_PEER_MSPCONFIGPATH=${WAREHOUSE_MSPCONFIGPATH} \
  cli \
  peer chaincode instantiate \
    -o orderer.nck.com:7050 \
    -C nckchannel \
    -n nckcc \
    -l node \
    -v 1.0 \
    -c '{"Args":[]}' \
    -P "OR ('WarehouseMSP.peer','SupplierMSP.peer','WarehouseMSP.peer')" \
    --tls \
    --cafile ${ORDERER_TLS_ROOTCERT_FILE} \
    --peerAddresses peer0.warehouse.nck.com:7051 \
    --tlsRootCertFiles ${WAREHOUSE_TLS_ROOTCERT_FILE} 
readiness_probe

#==================================================
#       invoke chaincode
#==================================================
echo "invoke chaincode"
docker exec \
  -e CHANNEL_NAME=nckchannel \
  -e CORE_PEER_LOCALMSPID="WarehouseMSP" \
  -e CORE_PEER_ADDRESS=peer0.warehouse.nck.com:7051 \
  -e CORE_PEER_MSPCONFIGPATH=${WAREHOUSE_MSPCONFIGPATH} \
  -e CORE_PEER_TLS_ROOTCERT_FILE=${WAREHOUSE_TLS_ROOTCERT_FILE} \
  -e CORE_PEER_GOSSIP_USELEADERELECTION=true \
  cli \
  peer chaincode invoke \
    -o orderer.nck.com:7050 \
    -C nckchannel \
    -n nckcc \
    -c '{"function":"initLedger","Args":[]}' \
    --waitForEvent \
    --tls \
    --cafile ${ORDERER_TLS_ROOTCERT_FILE} \
    --peerAddresses peer0.warehouse.nck.com:7051 \
    --peerAddresses peer0.supplier.nck.com:9051 \
    --peerAddresses peer0.issuer.nck.com:10151 \
    --tlsRootCertFiles ${WAREHOUSE_TLS_ROOTCERT_FILE} \
    --tlsRootCertFiles ${SUPPLIER_TLS_ROOTCERT_FILE} \
    --tlsRootCertFiles ${ISSUER_TLS_ROOTCERT_FILE}
readiness_probe

#---------------------------------------------------------------------------------------------------------
#                                       Application creation
#---------------------------------------------------------------------------------------------------------
#
#cd ..
#cd application/supplier

#echo "This is an example of an instance of a batch transported through a supply chain."
#echo "install necessary packages for supplier"
#npm install

#sleep 5
#echo "create the wallet of Adam from Aurora suppliers"
#node addToWallet.js

#sleep 5
#echo "To create a batch invoke createBatch.js "
#node createBatch.js
