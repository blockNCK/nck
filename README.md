# Blockchain based IoT platform
This project is the use case implementation of the final year project of our group. This is an implementation of blockchain based IoT 
platform. 

### Importance of using blockchain for pharmaceutical supply chain

The availability of best quality, high standard medicine is a essential element in a hospital. Normally in pharmaceutial inventory, the management 
is usually conducted manually. There is a high chance of missing the essential medicine at critical instances due to human error. 
There are many types of medicine which need to be maintained at a specific temperature range to maintain the quality of the drug. Eventhough 
the pharmacy maintains the medicine the drug at a specific temperature range, it cannot assure that the medicine was at the standard 
temperature range during transportation and warehouse storage. And also counterfeiting of the medicine during 3rd party transportation and
warehouse storage is high due to the high costs associated with the prescription and life saving medications. 

A blockchain based pharmaceutical supply chain with IoT devices could provide a solution for this problem. By using RFID tags the inventory management
could be done very easily. And also tamper proof technology of blockchain technology could address the counterfeiting of medicine. The temperature 
maintainance could be montiored with IoT devices. The blockchain and IoT technlogy usage will makesure that the authenticity of the 
drugs by making sure that the drugs are from the said pharmaceutical company without counterfaiting and assuring the quality of the drugs by
making sure the drugs are maintained in the standard temperature range during transportation and storage.

## BLockNCK blockchain based supply chain

![alt text](https://github.com/blockNCK/nck/blob/master/documents/images/supchain.png)

The diagram shows the basic scenario of the BlockNCk supply chain. The production companies produce different medicine and the aurora supplier
transport the drugs to the warehouse where the medicine is stored. Different pharmacies obtain drugs from the warehouse and issue the drugs. 
the production companies include a simple embedded system which consist of RFID tags and temperature sensors and seal the batch of drugs.
The supplier obtain the batch of drugs and read the RFID tag and using a smart contract transaction is processed. Then the supplier 
transport the batch to the warehouse and using another smart contract the transaction between the warehouse and the supplier is processed.
The warehouse could makesure that the batch is authentic and maintained the quality by reading the batch data through the blockchain.
Then the batch is taken to a pharmacy and again using another smart contract the transaction is processed. At the pharmacy the issuer can 
observe how the batch was obtained from the production to the pharmacy making sure the authencity and quality of the batch.

## Network configuration
![alt text](https://github.com/blockNCK/nck/blob/master/documents/images/network%20configuration.png)
 
 The basic configuration of the network is shown above. Each organization as 2 peers. The smart contracts are installed at each organization and
 ledger is maintained by each peer. A single chaincode, nck chaincode is installed in the nck channel. The network configuration is maintained
 by the Network configuration with the orderer of the channel. The channel configuration includes the configuration of channel with organizations
 warehouse, issuer and supplier. The applications to execute smart contracts between the different organizations are installed through the chaincode.
 Different actors of the companies communicate with the blockchains using the wallets which has the access configurations to specific organization.
 
 ### History and transactions of a batch
 ![alt text](https://github.com/blockNCK/nck/blob/master/documents/images/history.png)
 At the end of issuing a batch, the issuer can see how the batch was transported and whether the quality of the batch was maintained.

 peer chaincode query -C nckchannel -n nck -c '{"Args":["querygetQueryResultForQueryString", "{\"selector\":{\"docType\":\"batch\",\"block\":\"0\"}, \"use_index\":[\"_design/indexOwnerDoc\", \"indexOwner\"]}"]}'

/usr/bin/time -p docker exec \
  cli \
  peer chaincode invoke \
    -o orderer.nck.com:7050 \
    -C nckchannel \
    -n nckcc \
    -c '{"Args":["createBatch","76367543","Neugdsn","652", "quigsg","2019-08-15","2020-01-12","12","17","0"]}'

docker exec \
  cli \
  peer chaincode query \
    -o orderer.nck.com:7050 \
    -C nckchannel \
    -n nckcc \
    -c '{"Args":["createBatch", "{\"selector\":{\"docType\":\"batch\",\"block\":\"0\"}, \"use_index\":[\"_design/blockDoc\", \"blockindex\"]}"]}'
