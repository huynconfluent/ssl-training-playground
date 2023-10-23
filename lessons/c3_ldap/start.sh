#!/bin/bash

CERT_CHAIN=1
BASE_SUBJECT="/C=US/ST=CA/O=Confluent Demo"
ORG_UNIT="OU=Global Technical Support"
GENERATED_DIR="../../generated"

# delete generated directory
rm -rf "$GENERATED_DIR"

export GEN_DIR=$GENERATED_DIR/root_ca
source ../../scripts/create-ca.sh ../../scripts/configs/root_ca.cnf "$BASE_SUBJECT/CN=Root X1"

export GEN_DIR=$GENERATED_DIR/intermediate_ca
source ../../scripts/create-intermediate-ca.sh $CERT_CHAIN "$BASE_SUBJECT/$ORG_UNIT/CN=Intermediate" ../../scripts/configs/intermediate_ca.cnf $GENERATED_DIR/root_ca/private/ca.key $GENERATED_DIR/root_ca/certs/ca.pem

# creating component certs and truststore
export GEN_DIR=$GENERATED_DIR/component
source ../../scripts/create-user-cert.sh openldap "$BASE_SUBJECT/$ORG_UNIT" ../../scripts/configs/component.cnf \
    "$GENERATED_DIR/intermediate_ca/private/intermediate_$CERT_CHAIN.key" "$GENERATED_DIR/intermediate_ca/certs/intermediate-signed_$CERT_CHAIN.pem" \
    "$GENERATED_DIR/intermediate_ca/certs/fullchain.pem" "DNS:localhost,DNS:openldap,DNS:openldap.confluentdemo.io"
source ../../scripts/create-truststore.sh openldap "$GENERATED_DIR/root_ca/certs/ca.pem" "topsecret"

cp $GENERATED_DIR/component/certs/openldap-fullchain.pem $GENERATED_DIR/ssl/openldap-fullchain.pem
cp $GENERATED_DIR/component/private/openldap.key $GENERATED_DIR/ssl/openldap.key
cp $GENERATED_DIR/root_ca/certs/ca.pem $GENERATED_DIR/ssl/ca.pem

source ../../scripts/create-user-cert.sh zookeeper "$BASE_SUBJECT/$ORG_UNIT" ../../scripts/configs/component.cnf \
    "$GENERATED_DIR/intermediate_ca/private/intermediate_$CERT_CHAIN.key" "$GENERATED_DIR/intermediate_ca/certs/intermediate-signed_$CERT_CHAIN.pem" \
    "$GENERATED_DIR/intermediate_ca/certs/fullchain.pem" "DNS:localhost,DNS:zookeeper,DNS:zookeeper.confluentdemo.io"
source ../../scripts/create-truststore.sh zookeeper "$GENERATED_DIR/root_ca/certs/ca.pem" "topsecret"

source ../../scripts/create-user-cert.sh kafka "$BASE_SUBJECT/$ORG_UNIT" ../../scripts/configs/component.cnf \
    "$GENERATED_DIR/intermediate_ca/private/intermediate_$CERT_CHAIN.key" "$GENERATED_DIR/intermediate_ca/certs/intermediate-signed_$CERT_CHAIN.pem" \
    "$GENERATED_DIR/intermediate_ca/certs/fullchain.pem" "DNS:localhost,DNS:kafka,DNS:kafka.confluentdemo.io,DNS:mds,DNS:mds.confluentdemo.io"
source ../../scripts/create-truststore.sh kafka "$GENERATED_DIR/root_ca/certs/ca.pem" "topsecret"

source ../../scripts/create-user-cert.sh controlcenter "$BASE_SUBJECT/$ORG_UNIT" ../../scripts/configs/component.cnf \
    "$GENERATED_DIR/intermediate_ca/private/intermediate_$CERT_CHAIN.key" "$GENERATED_DIR/intermediate_ca/certs/intermediate-signed_$CERT_CHAIN.pem" \
    "$GENERATED_DIR/intermediate_ca/certs/fullchain.pem" "DNS:localhost,DNS:controlcenter,DNS:controlcenter.confluentdemo.io"
source ../../scripts/create-truststore.sh controlcenter "$GENERATED_DIR/root_ca/certs/ca.pem" "topsecret"

# create ldap-jaas
cat > ../../generated/ssl/c3-ldap-jaas.conf <<EOL
c3 {
  org.eclipse.jetty.jaas.spi.LdapLoginModule required

  useLdaps="true"
  debug="true"
  contextFactory="com.sun.jndi.ldap.LdapCtxFactory"
  hostname="openldap.confluentdemo.io"
  port="636"
  bindDn="cn=admin,dc=confluentdemo,dc=io"
  bindPassword="admin"
  authenticationMethod="simple"
  forceBindingLogin="false"
  userBaseDn="ou=users,dc=confluentdemo,dc=io"
  userRdnAttribute="uid"
  userIdAttribute="cn"
  userPasswordAttribute="userPassword"
  userObjectClass="inetOrgPerson"
  roleBaseDn="ou=groups,dc=confluentdemo,dc=io"
  roleNameAttribute="cn"
  roleMemberAttribute="memberuid"
  roleObjectClass="posixGroup";
};
EOL