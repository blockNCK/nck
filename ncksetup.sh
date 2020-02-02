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
./configtxgen -profile TwoOrgsChannel -outputCreateChannelTx ./channel-artifacts/channel.tx -channelID nckchannel
readiness_probe

echo "Create anchor peers of the organizations"
./configtxgen -profile TwoOrgsChannel -outputAnchorPeersUpdate ./channel-artifacts/WarehouseMSPanchors.tx -channelID nckchannel -asOrg WarehouseMSP

./configtxgen -profile TwoOrgsChannel -outputAnchorPeersUpdate ./channel-artifacts/IssuerMSPanchors.tx -channelID nckchannel -asOrg IssuerMSP

./configtxgen -profile TwoOrgsChannel -outputAnchorPeersUpdate ./channel-artifacts/SupplierMSPanchors.tx -channelID nckchannel -asOrg SupplierMSP
readiness_probe

#==================================================
#       Docker environment setup
#==================================================

export IMAGE_TAG=latest
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
  -e CORE_PEER_MSPCONFIGPATH=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/warehouse.nck.com/users/Admin@warehouse.nck.com/msp \
  -e CORE_PEER_TLS_ROOTCERT_FILE=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/warehouse.nck.com/peers/peer0.warehouse.nck.com/tls/ca.crt \
  cli \
  peer channel create \
    -o orderer.nck.com:7050 \
    -c nckchannel \
    -f ./channel-artifacts/channel.tx \
    --tls --cafile /opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/ordererOrganizations/nck.com/orderers/orderer.nck.com/msp/tlscacerts/tlsca.nck.com-cert.pem
readiness_probe

echo "install in the warehouse organization"
docker exec \
  -e CHANNEL_NAME=nckchannel \
  -e CORE_PEER_LOCALMSPID="WarehouseMSP" \
  -e CORE_PEER_ADDRESS=peer0.warehouse.nck.com:7051 \
  -e CORE_PEER_MSPCONFIGPATH=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/warehouse.nck.com/users/Admin@warehouse.nck.com/msp \
  -e CORE_PEER_TLS_ROOTCERT_FILE=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/warehouse.nck.com/peers/peer0.warehouse.nck.com/tls/ca.crt \
  cli \
  peer channel join \
    -b nckchannel.block 
readiness_probe

echo "install in the warehouse organization"
docker exec \
  -e CHANNEL_NAME=nckchannel \
  -e CORE_PEER_LOCALMSPID="WarehouseMSP" \
  -e CORE_PEER_ADDRESS=peer1.warehouse.nck.com:8051 \
  -e CORE_PEER_MSPCONFIGPATH=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/warehouse.nck.com/users/Admin@warehouse.nck.com/msp \
  -e CORE_PEER_TLS_ROOTCERT_FILE=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/warehouse.nck.com/peers/peer1.warehouse.nck.com/tls/ca.crt \
  cli \
  peer channel join \
    -b nckchannel.block 
readiness_probe

echo "install in the supplier organization"
docker exec \
  -e CHANNEL_NAME=nckchannel \
  -e CORE_PEER_LOCALMSPID="SupplierMSP" \
  -e CORE_PEER_ADDRESS=peer0.supplier.nck.com:9051  \
  -e CORE_PEER_MSPCONFIGPATH=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/supplier.nck.com/users/Admin@supplier.nck.com/msp  \
  -e CORE_PEER_TLS_ROOTCERT_FILE=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/supplier.nck.com/peers/peer0.supplier.nck.com/tls/ca.crt \
  cli \
  peer channel join \
  -b nckchannel.block 
readiness_probe

echo "install in the supplier organization"
docker exec \
  -e CHANNEL_NAME=nckchannel \
  -e CORE_PEER_LOCALMSPID="SupplierMSP" \
  -e CORE_PEER_ADDRESS=peer1.supplier.nck.com:10051  \
  -e CORE_PEER_MSPCONFIGPATH=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/supplier.nck.com/users/Admin@supplier.nck.com/msp  \
  -e CORE_PEER_TLS_ROOTCERT_FILE=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/supplier.nck.com/peers/peer1.supplier.nck.com/tls/ca.crt \
  cli \
  peer channel join \
  -b nckchannel.block 
readiness_probe

echo "install in the issuer organization"
docker exec \
  -e CHANNEL_NAME=nckchannel \
  -e CORE_PEER_LOCALMSPID="IssuerMSP"  \
  -e CORE_PEER_ADDRESS=peer0.issuer.nck.com:10151  \
  -e CORE_PEER_MSPCONFIGPATH=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/issuer.nck.com/users/Admin@issuer.nck.com/msp  \
  -e CORE_PEER_TLS_ROOTCERT_FILE=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/issuer.nck.com/peers/peer0.issuer.nck.com/tls/ca.crt \
  cli \
  peer channel join \
  -b nckchannel.block 
readiness_probe

echo "install in the issuer organization"
docker exec \
  -e CHANNEL_NAME=nckchannel \
  -e CORE_PEER_LOCALMSPID="IssuerMSP"  \
  -e CORE_PEER_ADDRESS=peer1.issuer.nck.com:10251  \
  -e CORE_PEER_MSPCONFIGPATH=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/issuer.nck.com/users/Admin@issuer.nck.com/msp  \
  -e CORE_PEER_TLS_ROOTCERT_FILE=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/issuer.nck.com/peers/peer1.issuer.nck.com/tls/ca.crt \
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
  -e CORE_PEER_MSPCONFIGPATH=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/warehouse.nck.com/users/Admin@warehouse.nck.com/msp \
  -e CORE_PEER_TLS_ROOTCERT_FILE=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/warehouse.nck.com/peers/peer0.warehouse.nck.com/tls/ca.crt \
  cli \
  peer channel update \
    -o orderer.nck.com:7050 \
    -c nckchannel \
    -f ./channel-artifacts/WarehouseMSPanchors.tx \
    --tls --cafile /opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/ordererOrganizations/nck.com/orderers/orderer.nck.com/msp/tlscacerts/tlsca.nck.com-cert.pem 
readiness_probe

echo "Definition of supplier anchor peer"
docker exec \
  -e CHANNEL_NAME=nckchannel \
  -e CORE_PEER_LOCALMSPID="SupplierMSP" \
  -e CORE_PEER_ADDRESS=peer0.supplier.nck.com:9051  \
  -e CORE_PEER_MSPCONFIGPATH=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/supplier.nck.com/users/Admin@supplier.nck.com/msp  \
  -e CORE_PEER_TLS_ROOTCERT_FILE=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/supplier.nck.com/peers/peer0.supplier.nck.com/tls/ca.crt \
  cli \
  peer channel update \
    -o orderer.nck.com:7050 \
    -c nckchannel \
    -f ./channel-artifacts/SupplierMSPanchors.tx \
    --tls --cafile /opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/ordererOrganizations/nck.com/orderers/orderer.nck.com/msp/tlscacerts/tlsca.nck.com-cert.pem 
readiness_probe

echo "Definition of issuer anchor peer"
docker exec \
  -e CHANNEL_NAME=nckchannel \
  -e CORE_PEER_LOCALMSPID="IssuerMSP"  \
  -e CORE_PEER_ADDRESS=peer0.issuer.nck.com:10151  \
  -e CORE_PEER_MSPCONFIGPATH=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/issuer.nck.com/users/Admin@issuer.nck.com/msp  \
  -e CORE_PEER_TLS_ROOTCERT_FILE=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/issuer.nck.com/peers/peer0.issuer.nck.com/tls/ca.crt \
  cli \
  peer channel update \
  -o orderer.nck.com:7050 \
  -c nckchannel \
  -f ./channel-artifacts/IssuerMSPanchors.tx \
  --tls --cafile /opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/ordererOrganizations/nck.com/orderers/orderer.nck.com/msp/tlscacerts/tlsca.nck.com-cert.pem
readiness_probe
