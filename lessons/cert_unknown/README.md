# Certificate Unknown

# Start
Generate the necessary SSL files for this lesson
```
./start.sh
```

# Run Docker
Start Zookeeper
```
docker-compose up -d zookeeper
```

Then try and start kafka
```
docker-compose up kafka
```

We should start to see some ERRORs
```
[2023-10-19 19:09:48,527] ERROR Unexpected throwable (org.apache.zookeeper.ClientCnxnSocketNetty)
    io.netty.handler.codec.DecoderException: javax.net.ssl.SSLHandshakeException: PKIX path building failed: sun.security.provider.certpath.SunCertPathBuilderException: unable to find valid certification path to requested target
```

Based on the class here we know this failure is with regards to Zookeeper Connection from Kafka. The Messaging states that it's `unable to find valid certification path to requested target`. Meaning that we can't validate the Target SSL Certificate

So let's breakdown what we need to know.

1. What is the SSL Cert presented by the target (e.g. zookeeper) and who is it's issuer(s)
2. What is in the Truststore on Client side (e.g. kafka)

We can  use our handy `openssl` tool to check the certificate for zookeeper if we don't have direct access to the node.

```
openssl s_client -connect localhost:2182 -showcerts
```

We get back the following
```
CONNECTED(00000005)
depth=3 C = US, ST = CA, O = Confluent Demo, CN = Root X1
verify error:num=19:self signed certificate in certificate chain
verify return:0
140704287536896:error:1401E412:SSL routines:CONNECT_CR_FINISHED:sslv3 alert bad certificate:/AppleInternal/Library/BuildRoots/d9889869-120b-11ee-b796-7a03568b17ac/Library/Caches/com.apple.xbs/Sources/libressl/libressl-3.3/ssl/ssl_pkt.c:1008:SSL alert number 42
---
Certificate chain
 0 s:/C=US/ST=CA/O=Confluent Demo/OU=Global Technical Support/OU=Global Technical Support/CN=Intermediate/CN=zookeeper
   i:/C=US/ST=CA/O=Confluent Demo/OU=Global Technical Support/CN=Intermediate X2
-----BEGIN CERTIFICATE-----
................................................................
................................................................
................................................................
-----END CERTIFICATE-----
 1 s:/C=US/ST=CA/O=Confluent Demo/OU=Global Technical Support/CN=Intermediate X2
   i:/C=US/ST=CA/O=Confluent Demo/OU=Global Technical Support/CN=Intermediate X1
-----BEGIN CERTIFICATE-----
................................................................
................................................................
................................................................
-----END CERTIFICATE-----
 2 s:/C=US/ST=CA/O=Confluent Demo/OU=Global Technical Support/CN=Intermediate X1
   i:/C=US/ST=CA/O=Confluent Demo/CN=Root X1
-----BEGIN CERTIFICATE-----
................................................................
................................................................
................................................................
-----END CERTIFICATE-----
 3 s:/C=US/ST=CA/O=Confluent Demo/CN=Root X1
   i:/C=US/ST=CA/O=Confluent Demo/CN=Root X1
-----BEGIN CERTIFICATE-----
................................................................
................................................................
................................................................
-----END CERTIFICATE-----
---
Server certificate
subject=/C=US/ST=CA/O=Confluent Demo/OU=Global Technical Support/OU=Global Technical Support/CN=Intermediate/CN=zookeeper
issuer=/C=US/ST=CA/O=Confluent Demo/OU=Global Technical Support/CN=Intermediate X2
---
Acceptable client certificate CA names
/C=US/ST=CA/O=Confluent Demo/CN=Root X1
Server Temp Key: ECDH, X25519, 253 bits
---
SSL handshake has read 5190 bytes and written 105 bytes
---
New, TLSv1/SSLv3, Cipher is ECDHE-RSA-AES256-GCM-SHA384
Server public key is 2048 bit
Secure Renegotiation IS supported
Compression: NONE
Expansion: NONE
No ALPN negotiated
SSL-Session:
    Protocol  : TLSv1.2
    Cipher    : ECDHE-RSA-AES256-GCM-SHA384
    Session-ID: CAE2182D53A69CCA3F147461F2BD360AB5896189DB43BC7B9B37F7B81334DA03
    Session-ID-ctx:
    Master-Key: DB4A62F460566C617E72E0FAFD59DABE4F80D71B7AC5AECCA9DD1C69021F293BA38FF172A8E7E6C5A404EA387E3E918B
    Start Time: 1697742932
    Timeout   : 7200 (sec)
    Verify return code: 19 (self signed certificate in certificate chain)
---
```

The import bits to note above are the server cert and it's chain
```
 0 s:/C=US/ST=CA/O=Confluent Demo/OU=Global Technical Support/OU=Global Technical Support/CN=Intermediate/CN=zookeeper
   i:/C=US/ST=CA/O=Confluent Demo/OU=Global Technical Support/CN=Intermediate X2

 1 s:/C=US/ST=CA/O=Confluent Demo/OU=Global Technical Support/CN=Intermediate X2
   i:/C=US/ST=CA/O=Confluent Demo/OU=Global Technical Support/CN=Intermediate X1

 2 s:/C=US/ST=CA/O=Confluent Demo/OU=Global Technical Support/CN=Intermediate X1
   i:/C=US/ST=CA/O=Confluent Demo/CN=Root X1

 3 s:/C=US/ST=CA/O=Confluent Demo/CN=Root X1
   i:/C=US/ST=CA/O=Confluent Demo/CN=Root X1
```

Top to bottom, we have our Server certificate, we see that `s` denotes `Subject` and the `i` denotes `Issuer` and so we can follow the chain all the way to the root certificate! and you know it's the root when you see that the Subject and Issuer are the exact same.

Next we need to see what is inside the Truststore for Zookeeper. From the broker `kafka.properties` file we know Zookeeper connection has the following configuration.
*Note: While you can just look at the docker-compose.yaml file for the Environment variables, the focus here is not on the deployment method, so we can use the following command to just grep the properties while the container is running
```
docker exec -ti kafka cat /etc/kafka/kafka.properties | grep zookeeper.ssl
zookeeper.ssl.keystore.location=/mnt/ssl/kafka.keystore.jks
zookeeper.ssl.client.enable=true
zookeeper.set.acl=true
zookeeper.ssl.truststore.location=/mnt/ssl/kafka.truststore.jks
zookeeper.ssl.truststore.password=topsecret
zookeeper.ssl.keystore.password=topsecret
zookeeper.connect=zookeeper.confluentdemo.io:2182
zookeeper.clientCnxnSocket=org.apache.zookeeper.ClientCnxnSocketNetty
```

From here we see that our truststore is `kafka.truststore.jks` so let's take a look at it using `keytool`

Run the following to view it's contents
```
keytool -list -v -keystore ../../generated/ssl/kafka.truststore.jks
```
We can see that this truststore contains 1 certificate
```
Keystore type: PKCS12
Keystore provider: SUN

Your keystore contains 1 entry

Alias name: caroot
Creation date: Oct 19, 2023
Entry type: trustedCertEntry

Owner: CN=Super Real Root, O=Confluent Demo, ST=CA, C=US
Issuer: CN=Super Real Root, O=Confluent Demo, ST=CA, C=US
Serial number: 231c8d9ea26ae7930b20ed2fb1b726d5d65e6ffd
Valid from: Thu Oct 19 14:08:09 CDT 2023 until: Sat Nov 18 13:08:09 CST 2023
Certificate fingerprints:
	 SHA1: 5B:2C:08:B5:E7:14:CD:00:8B:ED:23:BE:F9:EF:E1:38:60:BA:A2:EA
	 SHA256: 13:3A:97:1D:02:EF:38:3F:DB:0B:6D:9E:E8:55:73:E0:E9:7A:1E:4F:6B:B4:02:EE:11:1E:94:C4:B2:5C:BE:7A
Signature algorithm name: SHA256withRSA
Subject Public Key Algorithm: 4096-bit RSA key
Version: 3
```

We can see that this Root Certificate is Not the one that issued any of the certificates within the Zookeeper certificate chain.

Let's take a look at the zookeeper's truststore

```
keytool -list -v -keystore ../../generated/ssl/zookeeper.truststore.jks
```
and we can see that this truststore contains 1 certificate.
```
Keystore type: PKCS12
Keystore provider: SUN

Your keystore contains 1 entry

Alias name: caroot
Creation date: Oct 19, 2023
Entry type: trustedCertEntry

Owner: CN=Root X1, O=Confluent Demo, ST=CA, C=US
Issuer: CN=Root X1, O=Confluent Demo, ST=CA, C=US
Serial number: 4543415723d0ce13ba025128d116a2efffb3e2d9
Valid from: Thu Oct 19 14:08:06 CDT 2023 until: Sat Nov 18 13:08:06 CST 2023
Certificate fingerprints:
	 SHA1: BA:36:F2:34:69:1C:95:C4:E0:BD:F3:FC:5A:41:11:27:3B:8C:08:A6
	 SHA256: 56:30:DB:A1:66:7F:5D:8C:BB:D0:A4:CD:CD:64:6D:86:65:86:5D:04:92:02:5E:CA:1C:7A:E0:27:72:9E:6A:DC
Signature algorithm name: SHA256withRSA
Subject Public Key Algorithm: 4096-bit RSA key
Version: 3
```

However this does line up with the Root Issuer for the Zookeeper certificate.

Okay, so let's fix this. Let's pretend we don't have a copy of the Root Certificate in PEM. But we know that this zookeeper truststore has it.
So we'll do the following.
1. Extract Root CA from zookeeper truststore in PEM format
2. Import Root CA PEM into our kafka truststore
3. Attempt to start kafka back up

```
keytool -export -keystore ../../generated/ssl/zookeeper.truststore.jks -alias caroot -file ../../generated/ssl/root_cert.crt
```

If we want to make sure this PEM certificate is correct we can use `openssl` to check
```
openssl x509 -in ../../generated/ssl/root_cert.crt -noout -text
```
we get
```
Certificate:
    Data:
        Version: 3 (0x2)
        Serial Number:
            45:43:41:57:23:d0:ce:13:ba:02:51:28:d1:16:a2:ef:ff:b3:e2:d9
        Signature Algorithm: sha256WithRSAEncryption
        Issuer: C = US, ST = CA, O = Confluent Demo, CN = Root X1
        Validity
            Not Before: Oct 19 19:08:06 2023 GMT
            Not After : Nov 18 19:08:06 2023 GMT
        Subject: C = US, ST = CA, O = Confluent Demo, CN = Root X1
        Subject Public Key Info:
            Public Key Algorithm: rsaEncryption
                Public-Key: (4096 bit)
                Modulus:
                    00:d0:ee:59:f2:22:77:27:1b:a2:45:e9:7b:26:c5:
                    a8:31:e6:fa:07:9c:a4:04:f1:5d:37:4a:6d:97:6e:
                    48:ee:50:25:74:85:7a:d0:9a:6e:1d:b0:a4:9e:ba:
                    0f:a9:1e:c7:f6:ed:9e:fc:9a:67:08:31:15:4e:8b:
```

Alright looks good, let's proceed and import this, since we already have an alias called `caroot`, we'll just use a different alias for the import
```
keytool -import -keystore ../../generated/ssl/kafka.truststore.jks -file ../../generated/ssl/root_cert.crt -alias correct_cert
```
And let's make sure it's successfully been imported
```
keytool -list -v -keystore ../../generated/ssl/kafka.truststore.jks
```

```
Keystore type: PKCS12
Keystore provider: SUN

Your keystore contains 2 entries
..................................
*******************************************
*******************************************


Alias name: correct_cert
Creation date: Oct 19, 2023
Entry type: trustedCertEntry

Owner: CN=Root X1, O=Confluent Demo, ST=CA, C=US
Issuer: CN=Root X1, O=Confluent Demo, ST=CA, C=US
Serial number: 4543415723d0ce13ba025128d116a2efffb3e2d9
Valid from: Thu Oct 19 14:08:06 CDT 2023 until: Sat Nov 18 13:08:06 CST 2023
```

Alright, let's start kafka back up
```
docker-compose up kafka
```
Success, no more ERROR on validating the certificate presented by Zookeeper.

## Cleanup
```
docker-compose down
./stop.sh
```