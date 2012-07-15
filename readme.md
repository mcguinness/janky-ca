# [openssl-ca](https://github.com/jankyco/openssl-ca)

# Overview
This project provides an out of the box Public Key Infrastructure (PKI) using [openssl](http://openssl.org/).  It is a great alternative to [makecert.exe](http://msdn.microsoft.com/en-US/library/bfsktky3(v=VS.80).aspx) or Microsoft Certificate Services for development environments.  The generated PKI creates a root and intermediate Certificate Authority (CA) that can be used to issue certificates for common scenarios such as SSL/TLS, Client Authentication (e.g. Smart Cards), or Signing/Encryption (e.g. XML dsig).

Using a CA hierarchy to generate certificates simplifies certificate scenarios allowing all computers (clients/servers) to only trust the root certificate for trust chain validation.   Once the root certificate is added to a computer's Trusted Root Certification Authorities store for every computer you effectively have the same capabilities as a full commercial CA such as Verisign.   

## Requirements
- 64-bit Windows Vista+

OpenSSL was obtained from http://www.slproweb.com/products/Win32OpenSSL.html using the Win64 OpenSSL v1.0.0a Light package

_Only openssl.exe, libeay32.dll, ssleay32.dll are required.  These files are not required for runtime, only to generate new certificates._

# Configuration
Most configuration can be customized by editing the openssl config file [jankyco_openssl.cfg]. 

It is recommend you change the following default distinguished name (DN) values for certificates
<pre>
[ req_distinguished_name ]
organizationalUnitName = WebDev
organizationName = JankyCo
localityName = San Francisco
stateOrProvinceName = California
countryName = US
</pre>

# Stores

## /certs
This folder contains certificates issued by the CA.  The Intermediate CA certificate is signed by the Root CA while all new certificates are signed by the Intermediate CA.

Issued Certificates are available in the following formats:

- PKCS#7 Format Public Key Certificate (.crt)
- OpenSSL PEM Format Public Key Certificate (.pem)
- PKCS#12 Format Public + Private Key Certificate (.pfx)

*Note* If you don't assign an export password when generating a certificate, the .pfx will have no protection of the private key.

## /private
Private key used to generate a certificate signing request (CSR).  

## /crl
Revoked certificates are published to this folder and are available as a Certificate Revocation List.

## database
Internal file-based database used for tracking serial numbers and issuing certificates for Certificate Authorities.  If this folder is removed, all previously issued certificates cannot be revoked. *Do Not Touch, You Break You Buy!*

# PKI Setup

The default setup creates 1 root authority and 1 intermediate or issuing authority.  Only the Intermediate CA is issued by the Root CA.  All other certificates are to be issued by the Intermediate CA.

1. Open a command prompt on change path to root of repository
2. Run *OneTimeCreateCA.bat* and generate a Root Certificate Authority when prompted
3. Run *OneTimeCreateCA.bat* and generate an Intermediate Certificate Authority when prompted

The resulting certificates and
private keys can be found in the /certs and /private subfolders.  *DO NOT REPLACE* these files or rerun the OneTimeCreateCA.bat script.  It will invalidate all issued certificates.  As the name implies, this is a **ONE TIME** operation

## Certificate Revocation List

The default configuration stamps URLs into issued certificates for revocation checking.  These are not changeable once a certificate is issued.  The default value is defined in **CertEnv.bat**.  If you intend on having more than 1 node in your environment change these values to something other than localhost **BEFORE** create the CA environment.

<pre>
set CrlUrl=http://localhost:19840/crl
set AiaUrl=http://localhost:19840/certs
</pre>

# Trust CA
Once the CA is created, you need to trust the CA.  From and Administrator command prompt, run the **TrustRootCerts.bat** file.  This root certificate chain is found in certs\ca_chain.p7b.  

**Note** *This step should be performed on every node in your development environment (client & server).*

# Issue Certificate

1. Open a command prompt on change path to root of repository
2. Run *CreateCert.bat*

The Menu will ask you why type of Certificate you want to create.  

- Client Authentication (Use this for SmartCards or SSL/TLS Clients such as Browsers)
- Server Authentication (Use this for SSL/TLS Servers)
- Invalid (Expired)

##Client Authentication Templates

These templates are defined in the the openssl config file [jankyco_openssl.cfg]. 

###All Purpose Client
- Secure Email EKU
- Client Authentication EKU
- Smart Card Logon EKU
- Principal Name Subject Alternative Name
- Email Subject Alternative Name

###Email Client
- Secure Email EKU
- Client Authentication EKU
- Email Subject Alternative Name

###Expired Client
- Client Authentication EKU
*Certificate is not valid and is expired*

###Revoked Client
- Secure Email EKU
- Client Authentication EKU
- Smart Card Logon EKU
- Principal Name Subject Alternative Name
- Email Subject Alternative Name
*Certificate Serial is published in CRL as revoked*

###Simple Subject Client
- Client Authentication EKU

###SmartCard Client
- Client Authentication EKU
- Smart Card Logon EKU
- Principal Name Subject Alternative Name

## CRL Server
By default issued certificates specify a CRL distribution point over HTTP.  If revocation checking is enabled in your environment you need to host the CRL on the specified URL. 

If you have IISExpress installed, you can run the *CrlServer.bat* to spin up an IIS instance.  Otherwise you need to host the CRLs yourself.



