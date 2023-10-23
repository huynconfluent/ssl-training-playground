# Control Center LDAPS

## Start
Generate the necessary SSL files for this  lesson
```
./start.sh
```

## Run Docker
Start Openldap and Zookeeper
```
docker-compose up -d openldap zookeeper
```

Next let's start up Kafka
```
docker-compose up -d kafka
```

Next let's start up Control Center

Alright, let's try and login via the web browser

```
username: controlcenter
password: controlcenter-secret
```
Okay that fails, let's check the jaas conf.

We see that we're connecting on ldaps based on the configuration, let's just quickly test a non ldaps port

Please make the following modifications to the jaas conf located at `../../generated/ssl/c3-ldap-jaas.conf`

```
  useLdaps="false"
  port="389"
```

Alright, let's shutdown and start control center again so that we can apply our changes.
```
docker-compose down controlcenter
docker-compose up -d controlcenter
```
Alright let's attempt to authenticate again. Woah, it works! So that the configuration itself is mostly fine, we just seem to fail when communicating with LDAPS.

Let's add some SSL debugging to the JVM to see what's up.

First, let's revert back the jaas conf changes to use ldaps again
```
  useLdaps="true"
  port="636"
```
Then let's add the following to the `CONTROL_CENTER_OPTS` for additional SSL debugging
```
CONTROL_CENTER_OPTS: "-Djava.security.auth.login.config=/mnt/ssl/c3-ldaps-jaas.conf -Djavax.net.debug=ssl,handshake,keymanager,trustmanager"
```
Alright, let's apply our changes
```
docker-compose down controlcenter
docker-compose up -d controlcenter
```

Okay, let's make another authentication attempt again, that fails, now let's check the logs, be warned there will be a ton of new logged data, so best to save this to a temp file for viewing in an editor/grepping.

From here we want to search for our `javax.net.ssl|ERROR` level logging and from this we can see the following `cert_unknown` ERROR encountered
```
javax.net.ssl|DEBUG|56|qtp126142286-86|2023-10-23 11:10:15.306 GMT|Alert.java:238|Received alert message (
"Alert": {
  "level"      : "fatal",
  "description": "certificate_unknown"
}
)
javax.net.ssl|ERROR|56|qtp126142286-86|2023-10-23 11:10:15.308 GMT|TransportContext.java:345|Fatal (CERTIFICATE_UNKNOWN): Received fatal alert: certificate_unknown (
"throwable" : {
  javax.net.ssl.SSLHandshakeException: Received fatal alert: certificate_unknown
```
and
```
javax.net.ssl|ERROR|52|qtp126142286-82|2023-10-23 11:10:28.522 GMT|TransportContext.java:345|Fatal (CERTIFICATE_UNKNOWN): PKIX path building failed: sun.security.provider.certpath.SunCertPathBuilderException: unable to find valid certification path to requested target (
"throwable" : {
  sun.security.validator.ValidatorException: PKIX path building failed: sun.security.provider.certpath.SunCertPathBuilderException: unable to find valid certification path to requested target
```
Prior to this ERROR we should see our SSL Handshake (Client Hello -> Server Hello), the important keywords to note are the `Consuming server Certificate handshake message` this is us as a client receiving the SSL certificate from the Server

```
javax.net.ssl|DEBUG|5A|qtp126142286-90|2023-10-23 11:10:28.503 GMT|CertificateMessage.java:366|Consuming server Certificate handshake message (
"Certificates": [
  "certificate" : {
    "version"            : "v3",
    "serial number"      : "10 00",
    "signature algorithm": "SHA256withRSA",
    "issuer"             : "CN=Intermediate X1, OU=Global Technical Support, O=Confluent Demo, ST=CA, C=US",
    "not before"         : "2023-10-23 10:55:54.000 GMT",
    "not  after"         : "2023-11-22 10:55:54.000 GMT",
    "subject"            : "CN=openldap, OU=Global Technical Support, O=Confluent Demo, ST=CA, C=US",
    "subject public key" : "RSA",
    "extensions"         : [
      {
        ObjectId: 2.5.29.35 Criticality=false
        AuthorityKeyIdentifier [
        KeyIdentifier [
        0000: D5 CF F4 A6 AE B7 83 87   5B CB 50 E8 86 AE 5A 6B  ........[.P...Zk
        0010: DA E4 E3 F2                                        ....
        ]
        ]
      },
      {
        ObjectId: 2.5.29.19 Criticality=true
        BasicConstraints:[
          CA:false
          PathLen: undefined
        ]
      },
      {
        ObjectId: 2.5.29.37 Criticality=true
        ExtendedKeyUsages [
          serverAuth
          clientAuth
        ]
      },
      {
        ObjectId: 2.5.29.15 Criticality=true
        KeyUsage [
          DigitalSignature
          Non_repudiation
        ]
      },
      {
        ObjectId: 2.5.29.17 Criticality=false
        SubjectAlternativeName [
          DNSName: localhost
          DNSName: openldap
          DNSName: openldap.confluentdemo.io
        ]
      },
      {
        ObjectId: 2.5.29.14 Criticality=false
        SubjectKeyIdentifier [
        KeyIdentifier [
        0000: A1 A0 2D BF 58 2D 57 D3   52 AE 24 46 CE F0 6C AA  ..-.X-W.R.$F..l.
        0010: CB 92 CD 47                                        ...G
        ]
        ]
      }
    ]},
  "certificate" : {
    "version"            : "v3",
    "serial number"      : "10 00",
    "signature algorithm": "SHA256withRSA",
    "issuer"             : "CN=Root X1, O=Confluent Demo, ST=CA, C=US",
    "not before"         : "2023-10-23 10:55:54.000 GMT",
    "not  after"         : "2023-11-22 10:55:54.000 GMT",
    "subject"            : "CN=Intermediate X1, OU=Global Technical Support, O=Confluent Demo, ST=CA, C=US",
    "subject public key" : "RSA",
    "extensions"         : [
      {
        ObjectId: 2.5.29.35 Criticality=false
        AuthorityKeyIdentifier [
        KeyIdentifier [
        0000: 73 9E B0 8F 62 C1 4C B5   B1 5B 5F 2B 12 7A 91 6E  s...b.L..[_+.z.n
        0010: EE 77 B0 CF                                        .w..
        ]
        ]
      },
      {
        ObjectId: 2.5.29.19 Criticality=true
        BasicConstraints:[
          CA:true
          PathLen:1
        ]
      },
      {
        ObjectId: 2.5.29.15 Criticality=true
        KeyUsage [
          DigitalSignature
          Key_CertSign
          Crl_Sign
        ]
      },
      {
        ObjectId: 2.5.29.14 Criticality=false
        SubjectKeyIdentifier [
        KeyIdentifier [
        0000: D5 CF F4 A6 AE B7 83 87   5B CB 50 E8 86 AE 5A 6B  ........[.P...Zk
        0010: DA E4 E3 F2                                        ....
        ]
        ]
      }
    ]},
  "certificate" : {
    "version"            : "v3",
    "serial number"      : "1E A5 70 DB 3B D6 EA 58 A9 36 61 5C FD 92 64 3A 0E 99 B4",
    "signature algorithm": "SHA256withRSA",
    "issuer"             : "CN=Root X1, O=Confluent Demo, ST=CA, C=US",
    "not before"         : "2023-10-23 10:55:54.000 GMT",
    "not  after"         : "2023-11-22 10:55:54.000 GMT",
    "subject"            : "CN=Root X1, O=Confluent Demo, ST=CA, C=US",
    "subject public key" : "RSA",
    "extensions"         : [
      {
        ObjectId: 2.5.29.35 Criticality=false
        AuthorityKeyIdentifier [
        KeyIdentifier [
        0000: 73 9E B0 8F 62 C1 4C B5   B1 5B 5F 2B 12 7A 91 6E  s...b.L..[_+.z.n
        0010: EE 77 B0 CF                                        .w..
        ]
        ]
      },
      {
        ObjectId: 2.5.29.19 Criticality=true
        BasicConstraints:[
          CA:true
          PathLen:2147483647
        ]
      },
      {
        ObjectId: 2.5.29.15 Criticality=true
        KeyUsage [
          DigitalSignature
          Key_CertSign
          Crl_Sign
        ]
      },
      {
        ObjectId: 2.5.29.14 Criticality=false
        SubjectKeyIdentifier [
        KeyIdentifier [
        0000: 73 9E B0 8F 62 C1 4C B5   B1 5B 5F 2B 12 7A 91 6E  s...b.L..[_+.z.n
        0010: EE 77 B0 CF                                        .w..
        ]
        ]
      }
    ]}
]
)
```
This will contain the full chain for this server cert in this example. We can obtain the same output via openssl
```
docker exec -ti controlcenter openssl s_client -connect openldap.confluentdemo.io:636
```

Now in this situation, we never specifid a Truststore for use by the Ldap Client as we cannot specify one in the jaas configuration nor can we specify one in the control center properties file for this authentication method. This means that the Ldap client will default to the system truststore.

We can see that because of the SSL logging we added.
```
javax.net.ssl|DEBUG|4F|qtp126142286-79|2023-10-23 11:10:28.360 GMT|TrustStoreManager.java:161|Inaccessible trust store: /usr/lib/jvm/zulu11-ca/lib/security/jssecacerts
javax.net.ssl|DEBUG|4F|qtp126142286-79|2023-10-23 11:10:28.361 GMT|TrustStoreManager.java:112|trustStore is: /usr/lib/jvm/zulu11-ca/lib/security/cacerts
trustStore type is: pkcs12
trustStore provider is: 
```
We should also see that the system's default truststore doesn't contain our Self Signed Root CA. Meaning that we either need add or specify a truststore to be used for Ldap client.

Since this configuration type is Control Center with Ldap Authentication, we can only specify truststore via JVM options. So let's add that.
```
-Djavax.net.ssl.trustStore=/mnt/ssl/controlcenter.truststore.jks -Djavax.net.ssl.trustStorePassword=topsecret
```
and let's restart control center
```
docker-compose up -d controlcenter
```
Alright now that it's back up, let's re-test the login... Success!


## Cleanup
```
docker-compose down
./stop.sh
```