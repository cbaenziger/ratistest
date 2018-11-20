#!/bin/bash

# Trivial script to call the Ratis example server from GNU Screen

storage=$1
id=$2
peers=$3

java -jar `find /home/vagrant/incubator-ratis/ -name 'ratis-examples*-SNAPSHOT.jar'` server --storage $1 --id $2 --peers $3
