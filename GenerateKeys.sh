#!/bin/bash

# Exit immediately if a command exits with a non-zero status
set -e

# Function to print error messages in yellow
print_error() {
    echo -e "\e[33m$1\e[0m"
}

# Print the script author information with "University of Hartford" in blue
echo -e "Script made by \e[34mcsargent04\e[0m, Undergraduate student at the \e[34mUniversity of Hartford\e[0m"

echo "Starting Secure Boot Key Generation Script..."

prompt_user() {
    local input
    while [[ -z "$commonName" ]]; do
        read -p "Enter commonName (default: csargent04 Platform Key): " input
        commonName=${input:-"csargent04 Platform Key"}
    done

    while [[ -z "$emailAddress" ]]; do
        read -p "Enter emailAddress (default: csargent@hartford.edu): " input
        emailAddress=${input:-"csargent@hartford.edu"}
    done

    while [[ -z "$countryName" ]]; do
        read -p "Enter countryName (default: US): " input
        countryName=${input:-"US"}
    done

    while [[ -z "$stateOrProvinceName" ]]; do
        read -p "Enter stateOrProvinceName (default: CT): " input
        stateOrProvinceName=${input:-"CT"}
    done
}

create_config_file() {
    local filename=$1
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
commonName           = $commonName
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

manage_config_file() {
    local filename=$1
    if [ -f "$filename" ]; then
        read -p "$filename already exists. Do you want to overwrite it? (y/n): " choice
        if [ "$choice" != "y" ]; then
            echo "Skipping creation of $filename."
            return 1
        fi
    fi
    prompt_user
    create_config_file "$filename"
    echo "$filename has been created successfully."
    return 0
}

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

mkdir -p /keys/cfg /keys/esl /keys/auth /keys/bak

if ! manage_config_file "/keys/cfg/PK.cfg"; then
    exit 0
fi

for config in KEK.cfg DB.cfg; do
    if [ -f "/keys/cfg/$config" ]; then
        read -p "/keys/cfg/$config already exists. Do you want to overwrite it? (y/n): " choice
        if [ "$choice" != "y" ]; then
            echo "Skipping creation of /keys/cfg/$config."
            continue
        fi
    fi
    cp /keys/cfg/PK.cfg /keys/cfg/$config
    sed -i "s/Platform Key/${config%.*} Key/g" /keys/cfg/$config
    echo "/keys/cfg/$config has been created successfully."
done

for config in PK.cfg KEK.cfg DB.cfg; do
    openssl req -new -config /keys/cfg/$config -keyout /dev/null -out /dev/null || { print_error "Validation failed for /keys/cfg/$config"; exit 1; }
done

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
