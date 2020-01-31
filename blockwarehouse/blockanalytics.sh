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


chmod +x query.sh
queryResult = ./query.sh drugName inferon


#if database type is mysql
chmod +x bin/database/mysql.sh
./mysql.sh queryResult




