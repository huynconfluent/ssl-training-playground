#!/bin/bash

# ./create-keystore.sh <component_name> <private_key> <fullchain_cert> <keystore_password> <keystore_path>

if [ -z "$(which openssl)" ]; then
    echo "Missing openssl, please install"
    exit 1
fi

if [ -z "$(which keytool)" ]; then
    echo "Missing keytool, please install"
    exit 1
fi

COMPONENT_NAME=$1
KEYFILE=$2
CERTFILE=$3
KEYSTORE_PASSWORD=$4
KEYSTORE_PATH=$5
KEYSTORE_FILE="$KEYSTORE_PATH/$COMPONENT_NAME.keystore.p12"
KEYSTORE_ALIAS="1"
KEYSTORE_JKS_FILE="$KEYSTORE_PATH/$COMPONENT_NAME.keystore.jks"

# generate p12 with private key and public fullchain, must use -legacy option for OpenSSL 3.x
#echo "Create p12 keystore"
openssl pkcs12 -export -in $CERTFILE -inkey $KEYFILE -out $KEYSTORE_FILE -password "pass:${KEYSTORE_PASSWORD}" -legacy > /dev/null 2>&1

# convert to jks
#echo "Create additional jks keystore from p12"
keytool -importkeystore -srcstorepass $KEYSTORE_PASSWORD -srckeystore $KEYSTORE_FILE -srcstoretype pkcs12 -srcalias $KEYSTORE_ALIAS -destkeystore $KEYSTORE_JKS_FILE -deststoretype jks -deststorepass $KEYSTORE_PASSWORD -destalias $KEYSTORE_ALIAS > /dev/null 2>&1