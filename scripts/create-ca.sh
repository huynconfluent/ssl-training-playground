#!/bin/bash
# OPENSSL_BIN=openssl GEN_DIR=root_ca ./create-ca.sh <conf> <subject>
# OPENSSL_BIN=openssl GEN_DIR=root_ca ./create-ca.sh ./configs/root_ca.cnf "/C=US/ST=CA/O=Confluent Demo/CN=Root X1"

if [ -z "$OPENSSL_BIN" ]; then
    OPENSSL_BIN=openssl
fi

if [ -z "$(which $OPENSSL_BIN)" ]; then
    echo "Missing openssl, please install"
    exit 1
fi

#OPENSSL_VERSION=$($OPENSSL_BIN version | awk '{print $2}' | tr -d '.')
echo "$OPENSSL_VERSION"
if [[ $OPENSSL_VERSION -gt 309 ]]; then
    echo "OpenSSL version is greater than or equal to 3.1.0, please use 3.0 versions only"
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
$OPENSSL_BIN req -new -noenc -x509 -keyout $PRIVATE_CA_KEY -out $PUBLIC_CA_CERT -config $CONF -subj "${SUBJECT}" -days $DAYS_EXPIRE -sha256 -extensions v3_ca -pkeyopt rsa_keygen_bits:4096 > /dev/null 2>&1
