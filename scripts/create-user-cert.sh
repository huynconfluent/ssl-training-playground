#!/bin/bash

# GEN_DIR=component ./create-user-cert.sh <component_name> <base_subject> <conf> <issuer_key> <issuer_cert> <fullchain_ca_cert> <subject_alt_entries>
# GEN_DIR=component ./create-user-cert.sh kafka "/C=US/ST=CA/O=Confluent Demo/OU=Global Technical Support" ./configs/component.cnf ../generated/intermediateca/private/intermediate_3.key ../generated/intermediateca/certs/intermediate-signed_3.pem "../generated/intermediateca/certs/fullchain.pem" "DNS:localhost,DNS:kafka-1.confluentdemo.io"

if [ -z "$(which openssl)" ]; then
    echo "Missing openssl, please install"
    exit 1
fi

DIR=$GEN_DIR
COMPONENT_NAME=$1
DAYS_EXPIRE="30"
CONF=$3
ROOT_SUBJECT=$2
SUBJECT="$ROOT_SUBJECT/CN=$COMPONENT_NAME"
PRIVATE_COMPONENT_KEY_PATH=$DIR/private
COMPONENT_CSR_PATH=$DIR/csr
PUBLIC_COMPONENT_CERT_PATH=$DIR/certs
ISSUER_KEY=$4
ISSUER_CERT=$5
CA_CHAIN=$6
if [ ! -z $7 ]; then
    SUBJECT_ALT_DNS="$7"
fi

# create generated directories if missing
mkdir -p $DIR/{certs,crl,newcerts,private,csr}
mkdir -p "../../generated/ssl"
touch $DIR/index.txt
if [ ! -f "$DIR/serial" ]; then
    echo 1000 > $DIR/serial
fi

#echo "Creating Private Key and CSR for $COMPONENT_NAME"
# create private key and CSR
if [ -z "$7" ]; then
    # no subjectAltName
    openssl req -newkey rsa:2048 -keyout $PRIVATE_COMPONENT_KEY_PATH/$COMPONENT_NAME.key -out $COMPONENT_CSR_PATH/$COMPONENT_NAME.csr -noenc -subj "${SUBJECT}" -config $CONF -extensions v3_component > /dev/null 2>&1
else
    openssl req -newkey rsa:2048 -keyout $PRIVATE_COMPONENT_KEY_PATH/$COMPONENT_NAME.key -out $COMPONENT_CSR_PATH/$COMPONENT_NAME.csr -noenc -subj "${SUBJECT}" -addext "subjectAltName = ${SUBJECT_ALT_DNS}" -config $CONF -extensions v3_component > /dev/null 2>&1
fi

#echo "Signing $COMPONENT_NAME CSR"
openssl ca -config $CONF -extensions v3_component -days $DAYS_EXPIRE -notext -md sha256 -in $COMPONENT_CSR_PATH/$COMPONENT_NAME.csr -out $PUBLIC_COMPONENT_CERT_PATH/$COMPONENT_NAME-signed.pem -keyfile $ISSUER_KEY -cert $ISSUER_CERT -batch > /dev/null 2>&1
#echo "Cert signed for $COMPONENT_NAME"

# create fullchain
cat "$PUBLIC_COMPONENT_CERT_PATH/$COMPONENT_NAME-signed.pem" > $PUBLIC_COMPONENT_CERT_PATH/$COMPONENT_NAME-fullchain.pem
cat "$CA_CHAIN" >> $PUBLIC_COMPONENT_CERT_PATH/$COMPONENT_NAME-fullchain.pem

# create keystore file
$(dirname "${BASH_SOURCE[0]}")/create-keystore.sh $COMPONENT_NAME $PRIVATE_COMPONENT_KEY_PATH/$COMPONENT_NAME.key $PUBLIC_COMPONENT_CERT_PATH/$COMPONENT_NAME-fullchain.pem topsecret "../../generated/ssl"