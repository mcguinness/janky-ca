@echo off

call CertEnv.bat

REM Common Name is %CommonNamePrefix% %AuthorityType% CA
set CommonNamePrefix=Test

choice /C RI /M "Select CA Type: [R] Root Authority [I] Intermediate Authority"
if errorlevel 1 (set AuthorityType=Root)
if errorlevel 2 (set AuthorityType=Intermediate)
echo.

set CommonName=%CommonNamePrefix% %AuthorityType% CA
set AuthorityDatabase=%CD%\database\%AuthorityType%
set AuthorityIndex=%AuthorityDatabase%\index.txt
set AuthoritySerial=%AuthorityDatabase%\serial
set AuthorityCrlNumber==%AuthorityDatabase%\crlnumber

echo Cleaning Existing Certificate Authority State
echo.

if exist %AuthorityDatabase% (
	echo Existing certificate authority database has been created
	echo Are you sure you want to destroy database for certificate authority
	rmdir /s %AuthorityDatabase%
)

if not exist AuthorityIndex (
	echo Creating Certificate Authority database
	echo.
	mkdir %AuthorityDatabase%
	echo. 2>%AuthorityIndex%
)

if not exist %AuthoritySerial% (
	echo Creating Certificate Authority Serial State
	echo.
	echo 01 >%AuthoritySerial%
)

if not exist %AuthorityCrlNumber% (
	echo Creating Certificate Authority CRL State
	echo.
	echo 00 >%AuthorityCrlNumber%
)

if [%AuthorityType%] EQU [Root] (
	set ExtensionName=ca_extensions
)
if [%AuthorityType%] EQU [Intermediate] (
	set ExtensionName=intermediate_extensions
)

set RootAuthorityPemCertificate=certs\Root_CA.pem
set PemAuthorityChain=certs\ca_chain.pem
set P7bAuthorityChain=certs\ca_chain.p7b

set PrivateKey=private\%AuthorityType%_CA.pvk
set PemCertificate=certs\%AuthorityType%_CA.pem
set DerCertificate=certs\%AuthorityType%_CA.crt
set CSR=%CsrStore%%AuthorityType%_CA_req.pem

if [%AuthorityType%] EQU [Root] (
	echo Generating Self-Signed Root Certificate...
	echo.
	%OpenSslBinPath% req -config %OpenSslConfigFile% -new -x509 -extensions %ExtensionName% -days 5000 -keyout %PrivateKey% -out %PemCertificate%
	echo Converting Certificate Format...
	echo.
	%OpenSslBinPath% x509 -in %PemCertificate% -out %DerCertificate% -outform DER
	echo Finished Generating Self-Signed Root Certificate
)

if [%AuthorityType%] EQU [Intermediate] (
	echo Generating Private Key...
	echo.
	%OpenSslBinPath% req -config %OpenSslConfigFile% -new -keyout %PrivateKey% -out %CSR%
	echo Generating Public Key...
	echo.
	%OpenSslBinPath% ca -config %OpenSslConfigFile% -policy policy_anything -extensions %ExtensionName% -in %CSR% -out %PemCertificate%
	echo Converting Certificate Format...
	echo.
	%OpenSslBinPath% x509 -in %PemCertificate% -out %DerCertificate% -outform DER
)

echo Generating Certificate Chain Public Key.
echo.
if exist %PemAuthorityChain% (
  del /f %PemAuthorityChain%
)
echo Creating Certificate Chain file %PemAuthorityChain%...
type %RootAuthorityPemCertificate% > %PemAuthorityChain%

if [%AuthorityType%] EQU [Intermediate] (
	type %PemCertificate% >> %PemAuthorityChain%
)

if exist %P7bAuthorityChain% (
  del /f %P7bAuthorityChain%
)
echo Creating Certificate Chain file %P7bAuthorityChain%...
if [%AuthorityType%] EQU [Intermediate] (
  %OpenSslBinPath% crl2pkcs7 -nocrl -certfile %RootAuthorityPemCertificate% -certfile %PemCertificate% -out %P7bAuthorityChain% -outform DER
) else (
  %OpenSslBinPath% crl2pkcs7 -nocrl -certfile %RootAuthorityPemCertificate% -out %P7bAuthorityChain% -outform DER
)
