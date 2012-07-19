@echo off

call CertEnv.bat

choice /C CSI /M "Select Certificate Type: [C] Client Authentication [S] Server Authentication [I] Invalid Certificate"
if errorlevel 1 (set AuthType=Client)
if errorlevel 2 (set AuthType=Server)
if errorlevel 3 (set AuthType=Invalid)
echo.

if [%AuthType%] EQU [Client] (
	choice /C CESA /M "Select Template: [C] Simple Subject Name [E] Email [S] Smart Card [A] All"
	if errorlevel 1 (set ExtensionName=client_auth_extensions)
	if errorlevel 2 (set ExtensionName=client_auth_email_extensions)
	if errorlevel 3 (set ExtensionName=client_auth_smartcard_extensions)
	if errorlevel 4 (set ExtensionName=client_auth_all_extensions)
	echo.
)

if [%AuthType%] EQU [Server] (
	choice /C CD /M "Select Template: [C] Simple Subject Name [D] DNS Subject Alternative Name"
	if errorlevel 1 (set ExtensionName=server_auth_extensions)
	if errorlevel 2 (set ExtensionName=server_auth_dns_extensions)
	echo.
)

if [%AuthType%] EQU [Invalid] (
	choice /C E /M "Select Template: [E] Expired"
	if errorlevel 1 (set ExtensionName=client_auth_extensions)
	if errorlevel 1 (set Expired=True)
	echo.
)

choice /C YN /M "Add CRL Distribution Point Extension: [Y] Yes [N] No"
if errorlevel 2 (set ExtensionName=%ExtensionName%_no_crl)
echo.

echo Enter the Simple Name for the Certificate Subject
set /P CommonName=CN: 

if [%CommonName%] EQU [] (
	echo Subject Common Name ^(CN^) must be specified to generate a new client authentication certificate
	echo.
	goto :EOF
)

REM Required to be set to default value by OpenSSL Config File
set DnsName=localhost
set UserPrincipalName=%CommonName%

if [%ExtensionName%] EQU [client_auth_extensions] (
	set UserPrincipalName=%CommonName%
)

if [%ExtensionName%] EQU [client_auth_email_extensions] (
	echo Enter the Subject Alternative Name email address for the Certificate
	set /P UserPrincipalName=Email: 
	if [%UserPrincipalName%] EQU [] (
		echo Email must be specified to generate a new client authentication certificate
		echo.
		goto :EOF
	)
)

if [%ExtensionName%] EQU [client_auth_smartcard_extensions] (
	echo Enter the Subject Alternative Name ^(UPN^) for the Certificate
	set /P UserPrincipalName=Principal Name: 
	if [%UserPrincipalName%] EQU [] (
		echo Principal Name must be specified to generate a new client authentication certificate
		echo.
		goto :EOF
	)
)

if [%ExtensionName%] EQU [client_auth_all_extensions] (
	echo Enter the Subject Alternative Name ^(UPN^) and email adddress for the Certificate
	set /P UserPrincipalName=Principal Name^/Email: 
	if [%UserPrincipalName%] EQU [] (
		echo Principal Name^/Email must be specified to generate a new client authentication certificate
		echo.
		goto :EOF
	)
)

if [%ExtensionName%] EQU [server_auth_dns_extensions] (
	echo Enter the Subject Alternative Name ^(DNS^) for the Certificate
	set /P DnsName=DNS Name: 
	if [%DnsName%] EQU [] (
		echo Subject Alternative Name ^(DNS Name^) must be specified to generate a new server authentication certificate
		echo.
		goto :EOF
	)
)

if [%ExtensionName%] EQU [all_extensions] (
	set DnsName=%2
	set UserPrincipalName=3
	if [%DnsName%] EQU [] (
		echo Argument 2: Subject Alternative Name ^(DNS Name^) must be specified to generate a new server authentication certificate
		echo.
		goto :EOF
	)
	if [%UserPrincipalName%] EQU [] (
		echo Argument 3: Subject Alternative Name ^(Principal Name^) must be specified to generate a new client authentication certificate
		echo.
		goto :EOF
	)
)
REM The format of the date is YYMMDDHHMMSSZ (the same as an ASN1 UTCTime structure).
set ExpiredStartTime=110101010000Z
set ExpiredEndTime=120101010000Z
set PrivateKey=private\%CommonName%_%ExtensionName%.pvk
set CSR=csr\%CommonName%_%ExtensionName%_req.pem
set PemCertificate=certs\%CommonName%_%ExtensionName%.pem
set DerCertificate=certs\%CommonName%_%ExtensionName%.crt
set PfxCertificate=certs\%CommonName%_%ExtensionName%.pfx

echo Generating Private Key...
echo.
@%OpenSslBinPath% req -config %OpenSslConfigFile% -new -keyout %PrivateKey% -out %CSR%
echo Generating Public Key...
echo.
if [%Expired%] EQU [True] (
	%OpenSslBinPath% ca -config %OpenSslConfigFile% -name %AuthoritySectionName% -policy %PolicySectionName% -extensions %ExtensionName% -startdate %ExpiredStartTime% -enddate %ExpiredEndTime% -in %CSR% -out %PemCertificate%
) else (
	%OpenSslBinPath% ca -config %OpenSslConfigFile% -name %AuthoritySectionName% -policy %PolicySectionName% -extensions %ExtensionName% -in %CSR% -out %PemCertificate%
)
echo Converting Certificate Format...
echo.
%OpenSslBinPath% x509 -in %PemCertificate% -out %DerCertificate% -outform DER
echo Generating PFX with Private Key and Public Certificate...
echo.
%OpenSslBinPath% pkcs12 -nodes -export -out %PfxCertificate% -in %PemCertificate% -inkey %PrivateKey%