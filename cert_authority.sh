#!/bin/bash

# Simple OpenSSL Certificate Authority
# Author: Karl McGuinness
# Version: 0.2

# Load environment variables
vars=$(cat .env | grep -v "#" | xargs)
eval export $vars


# If these paths change, CONFIG_FILE must be updated
CONFIG_FILE=$PWD/ca_openssl.cfg
PUBLIC_KEY_STORE=$CERT_AUTHORITY_HOME/certs
PRIVATE_KEY_STORE=$CERT_AUTHORITY_HOME/private
CRL_STORE=$CERT_AUTHORITY_HOME/crl
CSR_STORE=$CERT_AUTHORITY_HOME/csr
NEW_CERT_STORE=$CERT_AUTHORITY_HOME/newcerts
AUTHORITY_DB=$CERT_AUTHORITY_HOME/database

CA_ROOT_PRIVATE_KEY=$CERT_AUTHORITY_HOME/private/root_ca.pem
CA_ROOT_PUBLIC_KEY=$CERT_AUTHORITY_HOME/certs/root_ca.pem
CA_INTERMEDIATE_PRIVATE_KEY=$CERT_AUTHORITY_HOME/private/intermediate_ca.pem
CA_INTERMEDIATE_PUBLIC_KEY=$CERT_AUTHORITY_HOME/certs/intermediate_ca.pem

# Sign Certificates w/ Intermediate CA and use default policy
AUTHORITY_SECTION_NAME="intermediate_ca"
POLICY_SECTION_NAME="policy_anything"

create_root() {
  if [ ! -d "$PUBLIC_KEY_STORE" ]; then
    echo "Creating public key certificate store"
    mkdir "$PUBLIC_KEY_STORE"
  fi

  if [ ! -d "$PRIVATE_KEY_STORE" ]; then
    echo "Creating private key certificate store"
    mkdir "$PRIVATE_KEY_STORE"
  fi

  if [ ! -d "$CRL_STORE" ]; then
    echo "Creating certificate revocation list store"
    mkdir "$CRL_STORE"
  fi

  if [ ! -d "$CSR_STORE" ]; then
    echo "Creating certificate signing request store"
    mkdir "$CSR_STORE"
  fi

  if [ ! -d "$NEW_CERT_STORE" ]; then
    echo "Creating new certificate store"
    mkdir "$NEW_CERT_STORE"
  fi

  if [ ! -d "$AUTHORITY_DB" ]; then
    echo "Creating authority database"
    mkdir "$AUTHORITY_DB"
  fi

  echo
}

# $1 - CA Authority Type (Root or Intermediate)
reset_db() {
  local authority_type=$1; shift

  local authority_db=$CERT_AUTHORITY_HOME/database/$(echo "$authority_type" | tr '[:upper:]' '[:lower:]')
  local authority_index=$authority_db/index.txt
  local authority_serial=$authority_db/serial
  local authority_crlnumber=$authority_db/crlnumber

  if [ -d "$authority_db" ]; then
    echo "Existing certificate authority database $authority_db exists"
    read -p "Do you want to destroy your existing certificate authority database? (Y/N)" -n 1 -r
    if [[ ! $REPLY =~ ^[Yy]$ ]]
    then
      echo "Rebuilding certificate authority database"
        echo `rm -rf $authority_db`
    fi
    echo
  fi

  if [ ! -d "$authority_db" ]; then
    echo "Creating certificate authority database"
    echo
    mkdir "$authority_db"
  fi

  if [ ! -e "$authority_index" ]; then
    echo `touch "$authority_index"`
  fi

  if [ ! -e "$authority_serial" ]; then
    echo 01 >"$authority_serial"
  fi

  if [ ! -e "$authority_crlnumber" ]; then
    echo 00 >"$authority_crlnumber"
  fi
}

# $1 - CA Authority Type (Root or Intermediate)
create_ca() {
  local authority_type=$1; shift
  CSR_COMMON_NAME="$AUTHORITY_CN_PREFIX $authority_type CA"
  local authority="$(echo "$authority_type" | tr '[:upper:]' '[:lower:]')_ca"
  local private_key=$PRIVATE_KEY_STORE/${authority}.pem
  local cert_pem=$PUBLIC_KEY_STORE/${authority}.pem
  local cert_der=$PUBLIC_KEY_STORE/${authority}.crt
  local csr=$CSR_STORE/${authority}.csr
  local extension_name

  echo "Creating $CSR_COMMON_NAME certificate authority"
  echo

  reset_db "$authority_type"

  if [ "$authority_type" == "Root" ]; then
    extension_name="ca_extensions"

    echo "Generating self-signed root certificate..."
    echo
    openssl req -config "$CONFIG_FILE" -new -x509 -extensions ca_extensions -days 5000 -keyout "$private_key" -out "$cert_pem"
    if [ ! -e "$private_key" ]; then
      echo "Error occurred generating private key $private_key!" >&2
      exit 1
    fi
    if [ ! -e "$cert_pem" ]; then
      echo "Error occurred generating certificate $cert_pem!" >&2
      exit 1
    fi

    echo "Converting certificate format..."
    echo
    openssl x509 -in "$cert_pem" -out "$cert_der" -outform DER
    if [ ! -e "$cert_der" ]; then
      echo "Error occurred converting public key $cert_der!" >&2
      exit 1
    fi
  else
    extension_name="intermediate_extensions"

    read -p "Add CRL Distribution Point Extension ($CA_CRL_URL)? [y/n]: " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
      read -p "Are you sure? The CRL URL must be available or certificate validation may fail! [y/n]: " -n 1 -r
      echo
      if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        extension_name="${extension_name}_no_crl"
      fi
    else
      extension_name="${extension_name}_no_crl"
    fi

    echo "Generating certificate signing request for new certificate authority..."
    echo
    openssl req -config "$CONFIG_FILE" -new -keyout "$private_key" -out "$csr"
    if [ ! -e "$private_key" ]; then
      echo "Error occurred generating private key $private_key!" >&2
      exit 1
    fi
    if [ ! -e "$csr" ]; then
      echo "Error occurred generating certificate signing request $csr!" >&2
      exit 1
    fi

    echo "Signing certificate request..."
    echo
    openssl ca -config "$CONFIG_FILE" -policy "$POLICY_SECTION_NAME" -extensions "$extension_name" -in "$csr" -out "$cert_pem"
    rm "$csr"
    if [ ! -e "$cert_pem" ]; then
      echo "Error occurred signing certificate $csr!" >&2
      exit 1
    fi

    echo "Converting certificate format..."
    echo
    openssl x509 -in "$cert_pem" -out "$cert_der" -outform DER
    if [ ! -e "$cert_der" ]; then
      echo "Error occurred converting public key $cert_pem!" >&2
      exit 1
    fi
  fi

  echo "Successfully generated certificate for $CSR_COMMON_NAME"
  echo -e  "\tPrivate Key (PEM): $private_key"
  echo -e  "\tPublic Key (PEM): $cert_pem"
  echo -e  "\tPublic Key (DER): $cert_der"
  echo
}

gen_ca_chain() {
  local root_cert_pem="$PUBLIC_KEY_STORE/root_ca.pem"
  local intermediate_cert_pem="$PUBLIC_KEY_STORE/intermediate_ca.pem"

  local ca_chain_pem="$PUBLIC_KEY_STORE/ca_chain.pem"
  local ca_chain_pkcs="$PUBLIC_KEY_STORE/ca_chain.p7b"

  echo "Generating certificate chain for authorities"
  echo

  cat "$root_cert_pem" > "$ca_chain_pem"
  if [ -e "$intermediate_cert_pem" ]; then
    cat "$intermediate_cert_pem" >> "$ca_chain_pem"
    openssl crl2pkcs7 -nocrl -certfile "$root_cert_pem" -certfile "$intermediate_cert_pem" -out "$ca_chain_pkcs" -outform DER
  else
    openssl crl2pkcs7 -nocrl -certfile "$root_cert_pem" -out "$ca_chain_pkcs" -outform DER
  fi

  if [ ! -e "$ca_chain_pkcs" ]; then
    echo "Error occurred generating certificate chain for authorities $root_cert_pem & $intermediate_cert_pem!" >&2
    exit 1
  fi

  echo "Successfully generated certificate authority chain certificate"
  echo -e  "\tPublic Key Chain (PEM): $ca_chain_pem"
  echo -e  "\tPublic Key Chain (PKCS): $ca_chain_pkcs"
  echo
}

# $1 - extension_name variable to return
select_cert_template() {
  local template="server"
  local extension_name="client_auth_extensions"

  echo "Select a Certificate Template"
  PS3="Enter Certificate Template (1-2):"
  select opt in "Client Authentication" "Server Authentication"; do
      case "$REPLY" in
        1) template="client"; break;;
        2) template="server"; break;;
        *) echo "Invalid template. Select a valid template."; continue;;
      esac
  done
  echo

  case $template in
    client)
      echo "Select Client Certificate Extensions"
      PS3="Enter Client Certificate Extension (1-4):"
      select opt in "Simple Subject Name" "Email" "User Principal Name (Smartcard)" "All"; do
          case "$REPLY" in
            1) extension_name="client_auth_extensions"; break;;
            2) extension_name="client_auth_email_extensions"; break;;
            3) extension_name="client_auth_smartcard_extensions"; break;;
          4) extension_name="client_auth_all_extensions"; break;;
            *) echo "Invalid extension. Select a valid extension.";continue;;
          esac
      done
      ;;
    server)
      echo "Select Server Certificate Extension"
      PS3="Enter Server Certificate Extension (1-2):"
      select opt in "Simple Subject Name" "DNS Subject Alternative Name"; do
          case "$REPLY" in
            1 ) extension_name="server_auth_extensions"; break;;
          2 ) extension_name="server_auth_san_extensions"; break;;
            *) echo "Invalid extension. Select a valid extension.";continue;;
          esac
      done
      ;;
  esac
  echo

  eval "$1=$extension_name"
}

# $1 - certificate template to request
prompt_csr_subject() {

  echo "Generating CSR with Certificate Template: $template_extension"
  echo

  case $template_extension in
    client_auth_extensions)
      echo "Enter the [Simple Name] for the client certificate subject: "
      while read -e simple_name && [[ -z "$simple_name" ]]; do :; done
      CSR_COMMON_NAME="$simple_name"
      CSR_EMAIL=""
      CSR_USER_PRINCIPAL_NAME=""
      CSR_SUBJECT_ALT_NAME=""
      ;;
    client_auth_email_extensions)
      echo "Enter the [Email Address] for the client certificate: "
      while read -e email && [ -z "$email" ]; do :; done
      CSR_COMMON_NAME="$email"
      CSR_EMAIL="$email"
      CSR_USER_PRINCIPAL_NAME=""
      CSR_SUBJECT_ALT_NAME=""
      ;;
    client_auth_smartcard_extensions)
      echo "Enter the [User Principal Name] for the client certificate: "
      while read -e upn && [ -z "$upn" ]; do :; done
      CSR_COMMON_NAME="$upn"
      CSR_EMAIL=""
      CSR_USER_PRINCIPAL_NAME="$upn"
      CSR_SUBJECT_ALT_NAME=""
      ;;
    client_auth_all_extensions)
      echo "Enter the [Simple Name] for the client certificate subject: "
      while read -e simple_name && [[ -z "$simple_name" ]]; do :; done
      echo "Enter the [Email] for the client certificate: "
      while read -e email && [ -z "$email" ]; do :; done
      echo "Enter the [User Principal Name] for the client certificate: "
      while read -e upn && [ -z "$upn" ]; do :; done
      CSR_COMMON_NAME="$simple_name"
      CSR_EMAIL="$email"
      CSR_USER_PRINCIPAL_NAME="$upn"
      CSR_SUBJECT_ALT_NAME=""
      ;;
    server_auth_extensions)
      echo "Enter the [Simple Name] for the server certificate subject: "
      while read -e simple_name && [[ -z "$simple_name" ]]; do :; done
      CSR_COMMON_NAME="$simple_name"
      CSR_EMAIL=""
      CSR_USER_PRINCIPAL_NAME=""
      CSR_SUBJECT_ALT_NAME=""
      ;;
    server_auth_san_extensions)
      echo "Enter the [Simple Name] for the server certificate subject: "
      while read -e simple_name && [[ -z "$simple_name" ]]; do :; done
      CSR_COMMON_NAME="$simple_name"
      CSR_SUBJECT_ALT_NAME=""
      CSR_EMAIL=""
      CSR_USER_PRINCIPAL_NAME=""

      while read -e -p "Enter a [DNS Subject Alternative Name] for the server certificate: "  dns && [ "$dns" != "" ]; do
        if [[ "$CSR_SUBJECT_ALT_NAME" != *"$dns"* ]]; then
          if [ -z "${CSR_SUBJECT_ALT_NAME:+x}" ]; then
            CSR_SUBJECT_ALT_NAME="DNS:$dns"
          else
            CSR_SUBJECT_ALT_NAME="$CSR_SUBJECT_ALT_NAME,DNS:$dns"
          fi
        fi
      done
      ;;
    all_extensions)
      echo "Enter the [User Principal Name] for the certificate: "
      while read -e upn && [ -z "$upn" ]; do :; done
      CSR_COMMON_NAME="$upn"
      CSR_USER_PRINCIPAL_NAME="$upn"
      echo "Enter the [DNS Subject Alternative Name] for the certificate: "
      while read dns && [ -z "$dns" ]; do :; done
      CSR_SUBJECT_ALT_NAME="$dns"
      ;;
    *)
      echo "Invalid extension: $template_extension"
      ;;
  esac

}

# $1 - certificate extension to request
create_cert() {
  local template_extension=$1; shift

  echo "Generating signing request with template [$template_extension]..."
  echo -e "\tCommon Name: $CSR_COMMON_NAME"
  echo -e "\tEmail: $CSR_EMAIL"
  echo -e "\tUser Principal Name: $CSR_USER_PRINCIPAL_NAME"
  echo -e "\tSubject Alternative Name: $CSR_SUBJECT_ALT_NAME"
  echo

  read -p "Add CRL Distribution Point Extension ($CA_CRL_URL)? [y/n]: " -n 1 -r
  echo
  if [[ $REPLY =~ ^[Yy]$ ]]; then
    read -p "Are you sure? The CRL URL must be available or certificate validation may fail! [y/n]: " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
      template_extension="${template_extension}_no_crl"
    fi
  else
    template_extension="${template_extension}_no_crl"
  fi

  local cert_name=${CSR_COMMON_NAME}
  if [ -e "$PRIVATE_KEY_STORE/${cert_name}.pem" ] || [ -e "$PUBLIC_KEY_STORE/${cert_name}.pem" ]; then

    read -p "Override existing certificate ($PUBLIC_KEY_STORE/${cert_name}.pem)? [y/n]: " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]
    then
      i=1
      while [ -e "$PRIVATE_KEY_STORE/${cert_name}_$i.pem" ] ; do
        let i++
      done
      cert_name=${cert_name}_$i
    fi
  fi

  local private_key=$PRIVATE_KEY_STORE/${cert_name}.pem
  local cert_pem=$PUBLIC_KEY_STORE/${cert_name}.pem
  local cert_der=$PUBLIC_KEY_STORE/${cert_name}.crt
  local cert_pfx=$PRIVATE_KEY_STORE/${cert_name}.pfx
  local csr=$CSR_STORE/${cert_name}.csr

  openssl req -config "$CONFIG_FILE" -new -keyout "$private_key" -out "$csr"
  if [ ! -e "$private_key" ]; then
    echo "Error occurred generating private key $private_key!" >&2
    exit 1
  fi
  if [ ! -e "$csr" ]; then
    echo "Error occurred generating certificate signing request $csr!" >&2
    exit 1
  fi
  echo
  echo "Signing certificate request.."
  openssl ca -config "$CONFIG_FILE" -name "$AUTHORITY_SECTION_NAME" -policy "$POLICY_SECTION_NAME" -extensions "$template_extension" -in "$csr" -out "$cert_pem"
  rm "$csr"
  if [ ! -e "$cert_pem" ]; then
    echo "Error occurred signing certificate $csr!" >&2
    exit 1
  fi
  echo "Converting certificate formats..."
  echo
  openssl x509 -in "$cert_pem" -out "$cert_der" -outform DER
  if [ ! -e "$cert_der" ]; then
    echo "Error occurred converting public key $cert_pem!" >&2
    exit 1
  fi
  openssl pkcs12 -nodes -export -out "$cert_pfx" -in "$cert_pem" -inkey "$private_key"
  if [ ! -e "$cert_pem" ] || [ ! -e "$private_key" ]; then
    echo "Error occurred converting public/private key $cert_pem & $private_key!" >&2
    exit 1
  fi

  echo "Successfully generated certificate for $CSR_COMMON_NAME"
  echo -e  "\tPrivate Key (PEM): $private_key"
  echo -e  "\tPrivate Key (PFX): $cert_pfx"
  echo -e  "\tPublic Key (PEM): $cert_pem"
  echo -e  "\tPublic Key (DER): $cert_der"
}

# $1 - path of pem cert to revoke
revoke_cert() {

  local cert_pem="$1"; shift

  echo "Revoking certificate $cert_pem..."
  echo

  if [ ! -e "$cert_pem" ]; then
    echo "Certificate $cert_pem does not exist!" >&2
    exit 1
  fi

  openssl ca -config "$CONFIG_FILE" -name "$AUTHORITY_SECTION_NAME" -revoke "$cert_pem"
  openssl ca -config "$CONFIG_FILE" -name "$AUTHORITY_SECTION_NAME" -gencrl -out "$CRL_STORE/intermediate_ca.crl"
  openssl ca -config "$CONFIG_FILE" -gencrl -out "$CRL_STORE/root_ca.crl"

  echo "Successfully revoked certificate $cert_pem"
}

trust_roots() {

  echo "Adding system trust to certificate authorities.."
  echo

  if [ ! -e "$CA_ROOT_PUBLIC_KEY" ]; then
    echo "Certificate Authority public key $CA_ROOT_PUBLIC_KEY does not exist!" >&2
    exit 1
  fi

  if [ ! -e "$CA_INTERMEDIATE_PUBLIC_KEY" ]; then
    echo "Certificate Authority public key $CA_ROOT_PUBLIC_KEY does not exist!" >&2
    exit 1
  fi

  if [ "$(id -u)" != "0" ]; then
      echo "You must run this script as root/administrator to modify system trust settings" >&2
      exit 1
  fi

  if [ "$(uname)" == "Darwin" ]; then
    security add-trusted-cert -d -r trustRoot -k "/Library/Keychains/System.keychain" "$CA_ROOT_PUBLIC_KEY"
    security add-trusted-cert -d -r trustRoot -k "/Library/Keychains/System.keychain" "$CA_INTERMEDIATE_PUBLIC_KEY"
  #elif [ "$(expr substr $(uname -s) 1 5)" == "Linux" ]; then
      # Do something under Linux platform
  #elif [ "$(expr substr $(uname -s) 1 10)" == "MINGW32_NT" ]; then
      # Do something under Windows NT platform
  fi
}

exe() { echo "\$ $@" ; "$@" ; }

file_must_exist() {
  local path="$1"; shift
  if [ ! -e "$path" ]; then
    echo "$path does not exist!" >&2
    exit 1
  fi
}

usage() {
  echo "Usage:"
  echo " $0 [ --connect <host:port> <client pem> | --issue <template extension> | --revoke <subject> | --trust | --verify <subject>"
  echo " $0 [ --help | -h ]"
  echo
}

main() {

  if [ -z "${CERT_AUTHORITY_HOME:+x}" ]; then
    echo "\$CERT_AUTHORITY_HOME environment variable must be defined!" >&2
    exit 1
  fi

  if [ ! -d "$CERT_AUTHORITY_HOME" ]; then
    echo "\$CERT_AUTHORITY_HOME defines a directory \"${CERT_AUTHORITY_HOME}\" that does not exist!" >&2
    exit 1
  fi

  # Reset in case getopts has been used previously in the shell.
 # OPTIND=1

  local boostrap=0
  local template_extension

  i=$(($# + 1)) # index of the first non-existing argument
  declare -A longoptspec
  # Use associative array to declare how many arguments a long option
  # expects. In this case we declare that loglevel expects/has one
  # argument and range has two. Long options that aren't listed in this
  # way will have zero arguments by default.
  longoptspec=( [connect]=2 [issue]=1 [revoke]=1 [verify]=2 )
  optspec=":i:r:t:v:h-:"
  while getopts "$optspec" opt; do
  while true; do
    case "${opt}" in
      -) #OPTARG is name-of-long-option or name-of-long-option=value
        if [[ ${OPTARG} =~ .*=.* ]] # with this --key=value format only one argument is possible
          then
            opt=${OPTARG/=*/}
            ((${#opt} <= 1)) && {
                echo "Syntax error: Invalid long option '$opt'" >&2
                exit 2
            }
            if (($((longoptspec[$opt])) != 1))
            then
                echo "Syntax error: Option '$opt' does not support this syntax." >&2
                exit 2
            fi
            OPTARG=${OPTARG#*=}
          else #with this --key value1 value2 format multiple arguments are possible
              opt="$OPTARG"
              ((${#opt} <= 1)) && {
                  echo "Syntax error: Invalid long option '$opt'" >&2
                  exit 2
              }
              OPTARG=(${@:OPTIND:$((longoptspec[$opt]))})
              ((OPTIND+=longoptspec[$opt]))
              #echo $OPTIND
              ((OPTIND > i)) && {
                  echo "Syntax error: Not all required arguments for option '$opt' are given." >&2
                  exit 3
              }
          fi

          continue #now that opt/OPTARG are set we can process them as
          # if getopts would've given us long options
          ;;
      bootstrap)
          boostrap=1
          ;;
      connect)
          echo
          echo '-------------------------------------------------------------------------------'
          echo 'Mutual TLS Connect'
          echo '-------------------------------------------------------------------------------'
          echo

          echo "connecting to ${OPTARG[0]} with client certificate '$CERT_AUTHORITY_HOME/certs/${OPTARG[1]}.pem'"
          echo
          file_must_exist "$CERT_AUTHORITY_HOME/certs/${OPTARG[1]}.pem"
          exe openssl s_client -connect ${OPTARG[0]} -cert "$CERT_AUTHORITY_HOME/certs/${OPTARG[1]}.pem" -certform pem -key "$CERT_AUTHORITY_HOME/private/${OPTARG[1]}.pem" -keyform pem -CAfile "$CERT_AUTHORITY_HOME/certs/ca_chain.pem"
          exit 0
          ;;
      i|issue)
          template_extension=${OPTARG[0]}
          ;;
      r|revoke)
          echo
          echo '-------------------------------------------------------------------------------'
          echo 'Certificate Revocation'
          echo '-------------------------------------------------------------------------------'
          echo

          local cert=${OPTARG[0]}
          if [ ! -e "$cert" ]; then
            cert="$CERT_AUTHORITY_HOME/certs/${OPTARG[0]}.pem"
            file_must_exist "$cert"
          fi
          revoke_cert "$cert"
          exit 0
          ;;
      t|trust)
          echo
          echo '-------------------------------------------------------------------------------'
          echo 'Certificate Authority Trust'
          echo '-------------------------------------------------------------------------------'
          echo

          trust_roots
          exit 0
          ;;
      v|verify)
          echo
          echo '-------------------------------------------------------------------------------'
          echo 'Certificate Verify'
          echo '-------------------------------------------------------------------------------'
          echo

          file_must_exist "$CERT_AUTHORITY_HOME/certs/${OPTARG[0]}.pem"
          exe openssl verify -CAfile "$CERT_AUTHORITY_HOME/certs/ca_chain.pem" -issuer_checks -policy_check "$CERT_AUTHORITY_HOME/certs/${OPTARG[0]}.pem"
          exit 0
          ;;
      h|help)
          usage
          exit 0
          ;;
      ?)
          echo "Syntax error: Unknown short option '$OPTARG'" >&2
          exit 2
          ;;
      *)
          echo "Syntax error: Unknown long option '$opt'" >&2
          exit 2
          ;;
    esac
  break; done
  done


  if [ ! -e "$CA_ROOT_PRIVATE_KEY" ] || [ ! -e "$CA_INTERMEDIATE_PRIVATE_KEY" ] || [ "$boostrap" -eq 1 ] ; then
    echo
    echo '-------------------------------------------------------------------------------'
    echo 'Certificate Authority'
    echo '-------------------------------------------------------------------------------'
    echo
    create_root
    for authority in "Root" "Intermediate"; do
      create_ca "$authority"
    done
    gen_ca_chain
  fi

  echo
  echo '-------------------------------------------------------------------------------'
  echo 'New Certificate Request'
  echo '-------------------------------------------------------------------------------'
  echo

  if [ -z "${template_extension:+x}" ] && [ -z "${select_cert_template:+x}" ]; then
    select_cert_template template_extension
    prompt_csr_subject "$template_extension"
  fi

  create_cert "$template_extension"
}

main "$@"
