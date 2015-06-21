set OpenSslConfigFile=jankyco_openssl.cfg
set OpenSslBinPath="openssl.exe"

REM Sign Certificates w/ Intermediate CA and use default policy
set AuthoritySectionName=intermediate_ca
set PolicySectionName=policy_anything

REM Required to be set to default value by OpenSSL Config File (Override)
set CommonName=user
set DnsName=localhost
set UserPrincipalName=test@domain.com

REM These URLs will be stamped into issued certs and must be reachable by clients for revocation checking
set CrlUrl=http://localhost:19840/crl
set AiaUrl=http://localhost:19840/certs

REM If these paths change, OpenSSL config file must be updated
set PublicKeyStore=%CD%\certs\
set PrivateKeyStore=%CD%\private\
set CrlStore=%CD%\crl\
set CsrStore=%CD%\csr\
set NewCertStore=%CD%\newcerts\

if not exist %PublicKeyStore% (
	echo Creating Public Key Certificate Store
	echo.
	mkdir %PublicKeyStore%
)

if not exist %PrivateKeyStore% (
	echo Creating Private Key Certificate Store
	echo.
	mkdir %PrivateKeyStore%
)

if not exist %CrlStore% (
	echo Creating Certificate Revocation List Store
	echo.
	mkdir %CrlStore%
)

if not exist %CsrStore% (
	echo Creating Certificate Signing Request Store
	echo.
	mkdir %CsrStore%
)

if not exist %NewCertStore% (
	echo Creating New Certificate Store
	echo.
	mkdir %NewCertStore%
)
