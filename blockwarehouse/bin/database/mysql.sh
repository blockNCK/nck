#!/bin/bash
#

mysql -u username -p

query_values = $1
CREATE DATABASE blockAnalytics;
use blockAnalytics;

CREATE TABLE drugs(drugName varchar(200), amount int, dateSupplied date, dateIssued date);

INSERT INTO drugs(query_values);

