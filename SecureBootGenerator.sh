#!/bin/bash

# Exit immediately if a command exits with a non-zero status
set -e

# Function to print error messages in yellow
print_error() {
    echo -e "\e[33m$1\e[0m"
}

# Function to print the script author information
print_author_info() {
    echo -e "Script made by \e[32mswoftii04\e[0m, Undergraduate student at the \e[32mUniversity of Hartford\e[0m"
}

# Function to set default values for PK and DB keys
set_default_values() {
    commonName="swoftii0404 Platform Key"
    emailAddress="csargent@hartford.edu"
    countryName="US"
    stateOrProvinceName="CT"
}

# Function to prompt the user for custom key information
prompt_custom_values() {
    read -p "Enter Common Name (default: ${commonName}): " input
    commonName="${input:-$commonName}"
    read -p "Enter Email Address (default: ${emailAddress}): " input
    emailAddress="${input:-$emailAddress}"
    read -p "Enter Country Name (default: ${countryName}): " input
    countryName="${input:-$countryName}"
    read -p "Enter State or Province Name (default: ${stateOrProvinceName}): " input
    stateOrProvinceName="${input:-$stateOrProvinceName}"
}

# Function to create a configuration file
create_config_file() {
    local filename=$1
    local keyName=$2
    cat <<EOF > $filename
[ req ]
default_bits         = 4096
encrypt_key          = no
string_mask          = utf8only
utf8                 = yes
prompt               = no
distinguished_name   = my_dist_name
x509_extensions      = my_x509_exts

[ my_dist_name ]
commonName           = $commonName $keyName
emailAddress         = $emailAddress
countryName          = $countryName
stateOrProvinceName  = $stateOrProvinceName

[ my_x509_exts ]
keyUsage             = digitalSignature, nonRepudiation, keyEncipherment
extendedKeyUsage     = codeSigning, timeStamping
basicConstraints     = critical,CA:FALSE
subjectKeyIdentifier = hash
authorityKeyIdentifier = keyid,issuer
EOF
}

# Function to manage the creation of configuration files
manage_config_file() {
    local filename=$1
    local keyName=$2
    create_config_file "$filename" "$keyName"
    echo "$filename has been created successfully."
}

# Function to check for existing keys
check_existing_keys() {
    local variables=("PK" "KEK" "db")
    for var in "${variables[@]}"; do
        output=$(efi-readvar -v $var 2>&1)
        if echo "$output" | grep -q "Variable.*has no entries"; then
            continue
        elif echo "$output" | grep -q "Variable does not exist"; then
            continue
        else
            print_error "Existing $var key found. Please go into firmware settings and delete existing keys."
            exit 1
        fi
    done
}

# Function to handle key generation
handle_key_generation() {
    print_author_info
    echo "Starting Secure Boot Key Generation Script..."

    sbstate=$(mokutil --sb-state)
    if [[ "$sbstate" == *"SecureBoot enabled"* ]]; then
        print_error "Secure Boot is enabled. Exiting script."
        exit 1
    fi

    echo "Secure Boot is disabled. Continuing with key generation..."

    if [[ $EUID -ne 0 ]]; then
        print_error "This script must be run as root"
        exit 1
    fi

    check_existing_keys

    # Create necessary directories if they don't exist
    mkdir -p /keys/cfg /keys/esl /keys/auth /keys/bak

    # Check if necessary key config files exist
    if [[ -d "/secure-boot-keys" && -n "$(ls -A /secure-boot-keys 2>/dev/null)" ]]; then
        read -p "Existing secure boot keys found. Do you want to use the existing keys? (y/n): " use_existing
        if [[ "$use_existing" == "y" ]]; then
            cp /secure-boot-keys/* /keys/cfg/
            echo "Using existing key configs."
        else
            read -p "Do you want to overwrite the existing keys and create new ones? (y/n): " create_new
            if [[ "$create_new" != "y" ]]; then
                print_error "Required keys are missing. Please re-run the script and choose 'y' to create new keys."
                exit 2
            fi
            rm -rf /secure-boot-keys/*
            create_all_configs
        fi
    else
        read -p "No existing keys found. Do you want to create new keys? (y/n): " create_new
        if [[ "$create_new" != "y" ]]; then
            print_error "Required keys are missing. Please re-run the script and choose 'y' to create new keys."
            exit 2
        fi
        create_all_configs
    fi

    # Generate keys
    echo "Generating Platform Key (PK)..."
    openssl req -x509 -sha256 -days 5490 -outform PEM \
        -config /keys/cfg/PK.cfg \
        -keyout /keys/PK.key -out /keys/PK.pem
    openssl x509 -text -noout -inform PEM -in /keys/PK.pem

    echo "Generating Key Exchange Key (KEK)..."
    openssl req -x509 -sha256 -days 5490 -outform PEM \
        -config /keys/cfg/KEK.cfg \
        -keyout /keys/KEK.key -out /keys/KEK.pem
    openssl x509 -text -noout -inform PEM -in /keys/KEK.pem

    echo "Generating Signature Database (db)..."
    openssl req -x509 -sha256 -days 5490 -outform PEM \
        -config /keys/cfg/db.cfg \
        -keyout /keys/db.key -out /keys/db.pem
    openssl x509 -text -noout -inform PEM -in /keys/db.pem

    ls -l /keys | grep -v ^d

    echo "$(uuidgen --random)" > /keys/guid.txt
    cat /keys/guid.txt

    cert-to-efi-sig-list -g "$(< /keys/guid.txt)" /keys/PK.pem /keys/esl/PK.esl
    sign-efi-sig-list -g "$(< /keys/guid.txt)" -t "$(date +'%F %T')" -c /keys/PK.pem -k /keys/PK.key PK /keys/esl/PK.esl /keys/auth/PK.auth

    cert-to-efi-sig-list -g "$(< /keys/guid.txt)" /keys/KEK.pem /keys/esl/KEK.esl
    sign-efi-sig-list -g "$(< /keys/guid.txt)" -t "$(date +'%F %T')" -c /keys/PK.pem -k /keys/PK.key KEK /keys/esl/KEK.esl /keys/auth/KEK.auth

    cert-to-efi-sig-list -g "$(< /keys/guid.txt)" /keys/db.pem /keys/esl/db.esl
    sign-efi-sig-list -g "$(< /keys/guid.txt)" -t "$(date +'%F %T')" -c /keys/KEK.pem -k /keys/KEK.key db /keys/esl/db.esl /keys/auth/db.auth

    ls -l /keys/auth/

    efi-updatevar -f /keys/auth/db.auth db
    efi-updatevar -f /keys/auth/KEK.auth KEK
    efi-updatevar -f /keys/auth/PK.auth PK

    efi-readvar

    bootctl status --no-pager

    echo "Signing the shim binary..."
    pesign -S -i /boot/efi/EFI/fedora/shimx64.efi
    cp -v /boot/efi/EFI/fedora/shimx64.efi /keys/bak/
    pesign -r -u0 -i /boot/efi/EFI/fedora/shimx64.efi -o /boot/efi/EFI/fedora/shimx64.efi.empty
    pesign -S -i /boot/efi/EFI/fedora/shimx64.efi.empty
    sbsign /boot/efi/EFI/fedora/shimx64.efi.empty --key /keys/db.key --cert /keys/db.pem --output /boot/efi/EFI/fedora/shimx64.efi
    pesign -S -i /boot/efi/EFI/fedora/shimx64.efi
    rm /boot/efi/EFI/fedora/shimx64.efi.empty

    echo "Signing the kernel..."
    pesign -S -i /boot/vmlinuz-$(uname -r)
    sbsign /boot/vmlinuz-$(uname -r) --key /keys/db.key --cert /keys/db.pem --output /boot/vmlinuz-$(uname -r)
    pesign -S -i /boot/vmlinuz-$(uname -r)

    keyctl list %:.builtin_trusted_keys

    echo "Script completed successfully, please reboot into firmware setup and enable secure boot..."
}

# Function to create all necessary configuration files
create_all_configs() {
    # Prompt for custom values once
    set_default_values
    prompt_custom_values

    # Create all keys with the same info
    manage_config_file "/keys/cfg/PK.cfg" "Platform Key"
    manage_config_file "/keys/cfg/KEK.cfg" "KEK Key"
    manage_config_file "/keys/cfg/db.cfg" "db Key"
}

# Run the main function to handle key generation
handle_key_generation
