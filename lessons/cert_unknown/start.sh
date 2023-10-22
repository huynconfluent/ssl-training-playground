#!/bin/bash

CERT_CHAIN=2
BASE_SUBJECT="/C=US/ST=CA/O=Confluent Demo"
ORG_UNIT="OU=Global Technical Support"
GENERATED_DIR="../../generated"

# delete generated directory
echo "Cleaning up $GENERATED_DIR first..."
rm -rf "$GENERATED_DIR"

echo "Creating necessary SSL Certificates..."
export GEN_DIR=$GENERATED_DIR/root_ca
source ../../scripts/create-ca.sh ../../scripts/configs/root_ca.cnf "$BASE_SUBJECT/CN=Root X1"

export GEN_DIR=$GENERATED_DIR/intermediate_ca
source ../../scripts/create-intermediate-ca.sh $CERT_CHAIN "$BASE_SUBJECT/$ORG_UNIT/CN=Intermediate" ../../scripts/configs/intermediate_ca.cnf $GENERATED_DIR/root_ca/private/ca.key $GENERATED_DIR/root_ca/certs/ca.pem

# creating component certs and truststore
export GEN_DIR=$GENERATED_DIR/component
source ../../scripts/create-user-cert.sh zookeeper "$BASE_SUBJECT/$ORG_UNIT" ../../scripts/configs/component.cnf \
    "$GENERATED_DIR/intermediate_ca/private/intermediate_$CERT_CHAIN.key" "$GENERATED_DIR/intermediate_ca/certs/intermediate-signed_$CERT_CHAIN.pem" \
    "$GENERATED_DIR/intermediate_ca/certs/fullchain.pem" "DNS:localhost,DNS:zookeeper.confluentdemo.io"
source ../../scripts/create-truststore.sh zookeeper "$GENERATED_DIR/root_ca/certs/ca.pem" "topsecret"

source ../../scripts/create-user-cert.sh kafka "$BASE_SUBJECT/$ORG_UNIT" ../../scripts/configs/component.cnf \
    "$GENERATED_DIR/intermediate_ca/private/intermediate_$CERT_CHAIN.key" "$GENERATED_DIR/intermediate_ca/certs/intermediate-signed_$CERT_CHAIN.pem" \
    "$GENERATED_DIR/intermediate_ca/certs/fullchain.pem" "DNS:localhost,DNS:kafka.confluentdemo.io"

# bad root ca
export GEN_DIR=$GENERATED_DIR/wrong_root_ca
source ../../scripts/create-ca.sh ../../scripts/configs/root_ca.cnf "/C=US/ST=CA/O=Confluent Demo/CN=Super Real Root"

source ../../scripts/create-truststore.sh kafka "$GENERATED_DIR/wrong_root_ca/certs/ca.pem" "topsecret"

echo "SSL Certificate Generation complete!"