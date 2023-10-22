#!/bin/bash
# GEN_DIR=root_ca ./create-ca.sh <conf> <subject>
# GEN_DIR=root_ca ./create-ca.sh ./configs/root_ca.cnf "/C=US/ST=CA/O=Confluent Demo/CN=Root X1"

if [ -z "$(which openssl)" ]; then
    echo "Missing openssl, please install"
    exit 1
fi

DIR=$GEN_DIR
DAYS_EXPIRE="30"
CONF=$1
SUBJECT=$2
PRIVATE_CA_KEY=$DIR/private/ca.key
PUBLIC_CA_CERT=$DIR/certs/ca.pem

# create generated directories if missing
mkdir -p $DIR/{certs,crl,newcerts,private}
touch $DIR/index.txt
echo 1000 > $DIR/serial

# create Root CA
openssl req -new -noenc -x509 -keyout $PRIVATE_CA_KEY -out $PUBLIC_CA_CERT -config $CONF -subj "${SUBJECT}" -days $DAYS_EXPIRE -sha256 -extensions v3_ca -pkeyopt rsa_keygen_bits:4096 > /dev/null 2>&1