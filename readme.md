# Overview

OpenSSL provides all the necessary PKI operations out-of-the-box for a fully functional Certificate Authority (CA).  It's often necessary to have your own CA for developer use cases such as digital signatures (e.g. JWT), encryption, or TLS authentication but a pain in the ass to remember all the openssl commands needed to generate X.509 certificates for all these use cases.

This project contains a simple shell script `cert_authority.sh` to automate common PKI operations for a Certificate Authority.

- Create Certificate Authority
- Add Certificate Authority to KeyStore
- Issue Certificate
- Revoke Certificate
- Verify Certificate
- Test Mutual-TLS Connection

> **Do not use this project for production use cases!**  Certificate parameters were chosen for developer productivity not security.

# Requirements

- OpenSSL is installed and resolvable in current path
- Node.js is installed if you want to run the default web server for the Certificate Authority

> Currently this script has only been tested on OSX but should work on other bash environments (PRs welcome!)

# Certificate Authority

The script creates a **Root Certificate Authority** and an **Intermediate Certificate Authority** which acts as the issuing authority for certificate requests.  This models more *real-world* deployments and allows you to generate additional subordinate certificate authorities in the future if you have complex uses cases.

The `ca_openssl.cfg` file defines the directories, parameters, and certificate templates for openssl operations. Default parameters can be modified in `ca_openssl.cfg` for advanced use cases

Both the Root and Intermediate CA is really just a set of files and folders that are persisted locally and referenced via `CERT_AUTHORITY_HOME` environment variable.

> `CERT_AUTHORITY_HOME` is the keystore for the CA and contains private keys!  You are responsible for protecting this directory with appropriate permissions

directory | description
--------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
certs     | public-key certificates issued by the CA in both [pem](https://en.wikipedia.org/wiki/Privacy-enhanced_Electronic_Mail) and binary [der](https://en.wikipedia.org/wiki/X.690#DER_encoding) format
crl       | certificate revocation list for the CA
csr       | certificate signing requests for the CA
database  | issued certificate serial numbers for the CA
private   | private keys for certificate requests in [pem](https://en.wikipedia.org/wiki/Privacy-enhanced_Electronic_Mail) as well as [pkcs12](https://en.wikipedia.org/wiki/PKCS_12)

The CA chain is also published in `$CERT_AUTHORITY_HOME\certs` as `ca_chain.pem` and `ca_chain.p7b` (PKCS)

## One Time Setup

1. Create a local directory for your Certificate Authority
   > **This folder will act the keystore for your CA and will contain private keys!**  Ensure that this folder is protected and only accessible by you!
2. Set `CERT_AUTHORITY_HOME` environment variable to your directory
3. Set the certificate revocation list (CRL) and authority info access (AIA) URLs for the CA by modifying the `CA_CRL_URL` and `CA_AIA_URL` variable in the `.env` file.
   > Make sure the hostname is also specified in your hosts file if you are not using a valid DNS name (e.g. ` echo "127.0.0.1 ca.example.com">>/etc/hosts`)
4. Optionally modify CA subject name and distinguished name (DN) fields for the certificate signing requests (CSR) in the `.env` file
5. Run `cert_authority.sh --bootstrap` script to create your Root Certificate Authority and Intermediate Authority

You will be asked whether you want to stamp a CRL distribution extension into the CA certificate.  If you opt-in to this choice, you must host the CRL on a web server available for revocation checking or certificate validation will fail!  A [default web server](#certificate_authority_web_server) for the CA is included in this project

### Certificate Authority Web Server

This project also includes a node.js web server to publish CRLs and CA certificates for Authority Info Access (AIA).

You can run the server with the following command

1. `npm install` && `npm run server`

Alternatively you can use an existing web server by specifying virtual directories for `$CERT_AUTHORITY_HOME/certs` and `$CERT_AUTHORITY_HOME/crl`.  A simple solution is to use the [node.js zero-configuration command-line http server](https://www.npmjs.com/package/http-server) which can be installed via `npm install http-server -g` and run with `http-server $CERT_AUTHORITY_HOME -p 19840`

> Make sure you change the default CRL/AIAs URL in `.env` which defaults to `http://ca.example.com:19840/crl` and `http://ca.example.com:19840/certs`.  See setup step #3 for more details!

## Issue Certificate

Once the CA is created you can issue a client or server certificate using pre-defined certificate templates in `ca_openssl.cfg`.

The distinguished name for certificates is generated using the following template

```
[ req_distinguished_name ]
commonName = $ENV::CSR_COMMON_NAME
organizationalUnitName = $ENV::CSR_ORGANIZATIONAL_UNIT_NAME
organizationName = $ENV::CSR_ORGANIZATION_NAME
localityName = $ENV::CSR_LOCALITY_NAME
stateOrProvinceName = $ENV::CSR_STATE_OR_PROVINCE_NAME
countryName = US
```

> You can modify DN components using environment variables specified in the `.env` or via process override

The `cert_authority.sh` script provides an interactive menu for issuing certificates.

1. Select Client or Server Authentication
2. Select Certificate Extensions
3. Optionally add a CRL Distribution Point Extension
4. Sign the Certificate
5. Commit the request
6. Select a password to export the private key

When you complete the flow a new certificate will be issued and converted to multiple formats. The script will output the location for your public and private keys.

> Certificates by default are issued with very long lifetimes (5840 days)

You can also specify a template name as a command-line argument by running `cert_authority.sh --issue <template extension>` such as `cert_authority.sh --issue server_auth_san_extensions`.

> Make sure you specify the `CSR_COMMON_NAME`, `CSR_EMAIL`, `CSR_SUBJECT_ALT_NAME`, and/or `CSR_USER_PRINCIPAL_NAME` environment variables for the selected template

## Revoke Certificate

`cert_authority.sh --revoke file`

## Trust Root Certificates

## Verify Certificate

`cert_authority.sh --verify file`

### Mutual TLS Test Server

Simple Mutual TLS Web Server

1. Issue a client certificate
2. Import client certificate into certificate store used by browser
3. Issue a server certificate
4. Launch Mutual TLS Web Server with server certificate and CA chain
   > `node https_test_server.js --cert "${CERT_AUTHORITY_HOME}/certs/{dnshost}.pem" --key "${CERT_AUTHORITY_HOME}/private/{dnshost}.pem" --ca "${CERT_AUTHORITY_HOME}/certs/ca_chain.pem" --mutual`
5. Visit web page (e.g. `https://{dnshost}:44303`)
6. Select certificate when prompted
