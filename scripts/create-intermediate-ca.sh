#!/bin/bash

# GEN_DIR=intermediate_ca ./create-intermediate-ca.sh <chain_count> <base_subject> <conf> "<issuer_key>" "<issuer_cert>"
# GEN_DIR=intermediate_ca ./create-intermediate-ca.sh 1 "/C=US/ST=CA/O=Confluent Demo/OU=Global Technical Support/CN=Intermediate" ./configs/intermediate_ca.cnf ../generated/root_ca/private/ca.key ../generated/root_ca/certs/ca.pem

if [ -z "$(which openssl)" ]; then
    echo "Missing openssl, please install"
    exit 1
fi

DIR=$GEN_DIR
COUNT=$1
DAYS_EXPIRE="30"
CONF=$3
ROOT_SUBJECT=$2
PRIVATE_INTERMEDIATE_KEY_PATH=$DIR/private
INTERMEDIATE_CSR_PATH=$DIR/csr
PUBLIC_INTERMEDIATE_CERT_PATH=$DIR/certs
ISSUER_KEY=$4
ISSUER_CERT=$5

# create generated directories if missing
mkdir -p $DIR/{certs,crl,newcerts,private,csr}
touch $DIR/index.txt
if [ ! -f "$DIR/serial" ]; then
    echo 1000 > $DIR/serial
fi

for (( i=1; i<=$COUNT; ++i)); do
    #echo "Creating Intermediate Private Key and CSR X$i"
    # create private key and CSR
    openssl req -newkey rsa:2048 -keyout $PRIVATE_INTERMEDIATE_KEY_PATH/intermediate_$i.key -out $INTERMEDIATE_CSR_PATH/intermediate_$i.csr -noenc -subj "${ROOT_SUBJECT} X${i}" > /dev/null 2>&1

    # if count = 1, sign with root, if else sign with intermediate previous count
    #echo "Signing Intermediate CSR X$i..."
    if [ $i -eq 1 ]; then
        openssl ca -config $CONF -extensions v3_intermediate_ca -keyfile $ISSUER_KEY -cert $ISSUER_CERT -days $DAYS_EXPIRE -notext -md sha256 -in $INTERMEDIATE_CSR_PATH/intermediate_$i.csr -out $PUBLIC_INTERMEDIATE_CERT_PATH/intermediate-signed_$i.pem -batch > /dev/null 2>&1
    else
        k=$((i - 1))
        openssl ca -config $CONF -extensions v3_intermediate_ca -keyfile $PRIVATE_INTERMEDIATE_KEY_PATH/intermediate_$k.key -cert $PUBLIC_INTERMEDIATE_CERT_PATH/intermediate-signed_$k.pem -days $DAYS_EXPIRE -notext -md sha256 -in $INTERMEDIATE_CSR_PATH/intermediate_$i.csr -out $PUBLIC_INTERMEDIATE_CERT_PATH/intermediate-signed_$i.pem -batch > /dev/null 2>&1
    fi
done

#echo "Creating fullchain.pem..."
# clear fullchain
echo -n "" > $PUBLIC_INTERMEDIATE_CERT_PATH/fullchain.pem

# create intermediate cert chain
for ((j=$COUNT; j>=1; --j)); do
    cat $PUBLIC_INTERMEDIATE_CERT_PATH/intermediate-signed_$j.pem >> $PUBLIC_INTERMEDIATE_CERT_PATH/fullchain.pem
done
cat $ISSUER_CERT >> $PUBLIC_INTERMEDIATE_CERT_PATH/fullchain.pem