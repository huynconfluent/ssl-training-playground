# ssl-training-playground

This is a repo to run through SSL training scenarios within Confluent Platform.

## Requirements
This training exercise was tested with OpenSSL 3.x and JDK 11.0.3

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