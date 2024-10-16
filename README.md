# ssl-training-playground

This is a repo to run through SSL training scenarios within Confluent Platform.

## Requirements
This training exercise was tested with OpenSSL 3.0.x and JDK 11.0.3
Please Note that using OpenSSL 3.1.x or newer seems to cause some issues with some of the cert creation process, so there is a requirement of using a 3.0 version for this training.
You can then set the path to the Openssl Binary via `export OPENSSL_BIN=/path/to/openssl@3.0/bin/openssl`

## OpenSSL on MacOS
By default MacOS comes with LibreSSL, which is slightly different then OpenSSL. It is recommended that you install and use OpenSSL for this training
```
openssl version
LibreSSL 3.3.6
```
You can use homebrew to install OpenSSL
```
brew install openssl@3
```
Brew installs applications into `/usr/local/opt/` so recommended to create an alias for openssl to point to this new binary
