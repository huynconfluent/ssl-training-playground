# Host Names

## Start
Generate the necessary SSL files for this  lesson
```
./start.sh
```

## Run Docker
Start Zookeeper
```
docker-compose up -d zookeeper
```

Then try and start kafka after zookeeper has been up and stable
```
docker-compose up kafka
```

Cool it looks like it works! However it only seems to work when we have the following set within kafka's configuration
```
zookeeper.ssl.endpoint.identification.algorithm=
```
When we remove this, kafka fails to start up.

Remove/comment out the following line from the `docker-compose.yaml`
```
KAFKA_ZOOKEEPER_SSL_ENDPOINT_IDENTIFICATION_ALGORITHM: ''
```

Let's shutdown kafka and star tit  back up
```
docker-compose down kafka
docker-compose up kafka
```
We now see errors on kafka side
```
[2023-10-19 20:07:18,944] ERROR Failed to verify hostname: zookeeper (org.apache.zookeeper.common.ZKTrustManager)
  javax.net.ssl.SSLPeerUnverifiedException: Certificate for <zookeeper> doesn't match any of the subject alternative names: [localhost, zookeeper.confluentdemo.io]
  at org.apache.zookeeper.common.ZKHostnameVerifier.matchDNSName(ZKHostnameVerifier.java:230)
  at org.apache.zookeeper.common.ZKHostnameVerifier.verify(ZKHostnameVerifier.java:171)
  at org.apache.zookeeper.common.ZKTrustManager.performHostVerification(ZKTrustManager.java:159)
  at org.apache.zookeeper.common.ZKTrustManager.checkServerTrusted(ZKTrustManager.java:118)
..................
[2023-10-19 20:07:18,946] ERROR Unexpected throwable (org.apache.zookeeper.ClientCnxnSocketNetty)
kafka  | io.netty.handler.codec.DecoderException: javax.net.ssl.SSLHandshakeException: Failed to verify both host address and host name
```

and from Zookeeper side we should be seeing the following flood the logs
```
[2023-10-19 20:07:18,946] ERROR Unsuccessful handshake with session 0x0 (org.apache.zookeeper.server.NettyServerCnxnFactory)
[2023-10-19 20:07:18,948] WARN Exception caught (org.apache.zookeeper.server.NettyServerCnxnFactory)
io.netty.handler.codec.DecoderException: javax.net.ssl.SSLHandshakeException: Received fatal alert: certificate_unknown
```

If we only had the zookeeper logs, we assume that the certificate from the broker was bad. But with kafka's logging we can see that hostname verficiation failed.
However it looks like the certificate doesn't match any of the hostnames it found.
```
localhost
zookeper.confluentdemo.io
```

But wait a second, wasn't `zookeeper.confluentdemo.io` the hostname for zookeeper? Let's test the keystore and truststore used by the kafka broker using a cli tool.

Let's create a zookeeper client properties file at `../../generated/ssl/zk-client.properties` with the following contents
```
zookeeper.clientCnxnSocket=org.apache.zookeeper.ClientCnxnSocketNetty
zookeeper.ssl.client.enable=true
zookeeper.ssl.keystore.location=/mnt/ssl/kafka.keystore.jks
zookeeper.ssl.keystore.password=topsecret
zookeeper.ssl.truststore.location=/mnt/ssl/kafka.truststore.jks
zookeeper.ssl.truststore.password=topsecret
```
Then let's execute the following from within zookeeper container, using the `zookeeper-shell` cli tool
```
zookeeper-shell zookeeper.confluentdemo.io:2182 -zk-tls-config-file /mnt/ssl/zk-client.properties ls /
```
Results
```
Connecting to zookeeper.confluentdemo.io:2182

WATCHER::

WatchedEvent state:SyncConnected type:None path:null
[zookeeper]
```

So that seems to work. So let's go back and check what the hostname being used within the broker's properties file is.
```
zookeeper.connect=zookeeper:2182
```

So we see here we're setting the container name, but not the hostname. So this indicates to us that the hostname we're specifically trying to connect to does not match the hostnames presented by the ssl certificate, via the `Subject Alternate Names`

Since the log already provides us with what the subject alternate names are that's presented by the zookeeper keystore. We don't really need to go through the trouble of verifying. But if we did we have a few options

### Option 1
We can check the keystore itself.
```
keytool -list -v -keystore ../../generated/ssl/zookeeper.keystore.jks -storepass topsecret
```

### Option 2
We can check via `OpenSSL` tool
```
docker exec -ti zookeeper openssl s_client -connect zookeeper.confluentdemo.io:2182
```

## Solution
So we can fix this one of two ways

1. The easiest way? Use a valid hostname
```
KAFKA_ZOOKEEPER_CONNECT: zookeeper.confluentdemo.io:2182
```
2. Add `zookeeper` to the `subjectAltNames` of the zookeeper signed certificate presented by the keystore. We won't be going over re-creating the SSL Certificate here and re-creating the keystore here.



## Bonus
Let's say we're working on a older version of zookeeper where we do not have the `-zk-tls-config-file` option, we could get away with using `kafka-run-class` and specifying the SSL configurations as JVM options.
```
kafka-run-class -Dzookeeper.clientCnxnSocket=org.apache.zookeeper.ClientCnxnSocketNetty -Dzookeeper.ssl.trustStore.location=/mnt/ssl/kafka.truststore.jks -Dzookeeper.ssl.trustStore.password=topsecret -Dzookeeper.ssl.keyStore.location=/mnt/ssl/kafka.keystore.jks -Dzookeeper.ssl.keyStore.password=topsecret -Dzookeeper.client.secure=true org.apache.zookeeper.client.FourLetterWordMain zookeeper 2182 srvr true
```


## Cleanup
```
docker-compose down
./stop.sh
```