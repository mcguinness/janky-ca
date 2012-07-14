@echo off

call CertEnv.bat

if [%1] EQU []  (
  echo A valid path to an issued certificate by %AuthoritySectionName% in .pem format is required
  goto :EOF
)
set PemCertificate=%1
if not exist %PemCertificate% (
  echo A valid path to an issued certificate by %AuthoritySectionName% in .pem format is required
  goto :EOF
)

%OpenSslBinPath% ca -config %OpenSslConfigFile% -name %AuthoritySectionName% -revoke %PemCertificate% 
%OpenSslBinPath% ca -config %OpenSslConfigFile% -name %AuthoritySectionName% -gencrl -out crl\intermediate_ca.crl
REM Root CRL
%OpenSslBinPath% ca -config %OpenSslConfigFile% -gencrl -out crl\root_ca.crl