# Overview

OpenSSL provides all the necessary PKI operations out-of-the-box for a fully functional Certificate Authority (CA).  It's often necessary to have your own CA for developer use cases such as digital signatures (e.g. JWT), encryption, or TLS authentication but a pain in the ass to remember all the openssl commands needed to generate X.509 certificates for all these use cases.

This project contains a simple shell script `cert_authority.sh` to automate common PKI operations for a Certificate Authority.

- Create Certificate Authority
- Add Certificate Authority to KeyStore
- Issue Certificate
- Revoke Certificate

> **Do not use this project for production use cases!**  Certificate parameters were chosen for developer productivity not security.

# Certificate Authority

The script creates a **Root Certificate Authority** and an **Intermediate Certificate Authority** which acts as the issuing authority for certificate requests.  This models more *real-world* deployments and allows you to generate additional subordinate certificate authorities in the future if you have complex uses cases.

The `ca_openssl.cfg` file defines the directories, parameters, and certificate templates for openssl operations. Default parameters can be modified in `ca_openssl.cfg` for advanced use cases

Both the Root and Intermediate CA is really just a set of persisted files and folders that are persisted locally and referenced via `CERT_AUTHORITY_HOME` environment variable.

> `CERT_AUTHORITY_HOME` is the keystore for the CA and contains private keys!  You are responsible for protecting this directory with appropriate permissions

directory | description
--------- | -----------
certs | public-key certificates issued by the CA in both [pem](https://en.wikipedia.org/wiki/Privacy-enhanced_Electronic_Mail) and binary [der](https://en.wikipedia.org/wiki/X.690#DER_encoding) format
crl | certificate revocation list for the CA
csr | certificate signing requests for the CA
database | issued certificate serial numbers for the CA
private | private keys for certificate requests in [pem](https://en.wikipedia.org/wiki/Privacy-enhanced_Electronic_Mail) as well as [pkcs12](https://en.wikipedia.org/wiki/PKCS_12)

The CA chain is also published in `$CERT_AUTHORITY_HOME\certs` as `ca_chain.pem` and `ca_chain.p7b` (PKCS)

## One Time Setup

1. Create a local directory for your Certificate Authority
   > **This folder will act the keystore for your CA and will contain private keys!**  Ensure that this folder is protected and only accessible by you
2. Set `CERT_AUTHORITY_HOME` environment variable to your directory
3. Optionally change the `AUTHORITY_CN_PREFIX` variable in `cert_authority.sh` to the desired name for your CA
   > The common name for the CA is `$AUTHORITY_CN_PREFIX $AUTHORITY_TYPE CA`
3. Run `cert_authority.sh` script to create your Root Certificate Authority and Intermediate Authority

You will be asked whether you want to stamp a CRL distribution extension into the CA certificate.  If you opt-in to this choice, you must host the CRL on a web server for revocation checking.

> You can change the default CRL URL in `cert_authority.sh` which defaults to `http://localhost:19840/crl`

A simple solution is to use the [node.js zero-configuration command-line http server](https://www.npmjs.com/package/http-server) which can be installed via `npm install http-server -g` and run with `http-server $CERT_AUTHORITY_HOME -p 19840`

## Issue Certificate

Once the CA is created you can issue a client or server certificate using pre-defined certificate templates in `ca_openssl.cfg`.

The distinguished name for certificates is generated using the following template

```
[ req_distinguished_name ]
commonName = $ENV::CSR_COMMON_NAME
organizationalUnitName = Dev
organizationName = Janky Co
localityName = San Francisco
stateOrProvinceName = California
countryName = US
```

> You can change all distinguished name components in `req_distinguished_name` except for `commonName`

The `cert_authority.sh` script provides an interactive menu for issuing certificates.

1. Select Client or Server Authentication
2. Select Certificate Extensions
3. Optionally add a CRL Distribution Point Extension
4. Sign the Certificate
5. Commit the request
6. Select a password to export the private key

When you complete the flow a new certificate will be issued and converted to multiple formats. The script will output the location for your public and private keys.

> Certificates by default are issued with very long lifetimes (5840 days)
