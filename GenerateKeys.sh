#!/bin/bash

# Define key names and directory
KEY_DIR="/root/secure-boot-keys"
PK_KEY="PK"
KEK_KEY="KEK"
DB_KEY="db"
CONFIG_FILE="/keys/cfg/PK.cfg"

# Function to remove existing keys from the directory
cleanup_keys() {
    echo "Removing any existing keys in $KEY_DIR..."
    rm -f $KEY_DIR/*
    echo "All existing keys have been removed."
}

# Check Secure Boot state
SB_STATE=$(mokutil --sb-state | grep -i "SecureBoot enabled")
if [ -n "$SB_STATE" ]; then
    echo "Error: Secure Boot is enabled. Please disable it before running this script."
    exit 1
fi

# Create the directory to store the keys
mkdir -p $KEY_DIR

# Cleanup existing keys
cleanup_keys

cd $KEY_DIR

# Generate the Platform Key (PK) with configuration
openssl req -new -x509 -newkey rsa:2048 -keyout $PK_KEY.key -out $PK_KEY.crt -nodes -days 3650 -config $CONFIG_FILE
cert-to-efi-sig-list -g $(uuidgen) $PK_KEY.crt $PK_KEY.esl
sign-efi-sig-list -c $PK_KEY.crt -k $PK_KEY.key PK $PK_KEY.esl $PK_KEY.auth

# Generate the Key Exchange Key (KEK) with configuration
openssl req -new -x509 -newkey rsa:2048 -keyout $KEK_KEY.key -out $KEK_KEY.crt -nodes -days 3650 -config $CONFIG_FILE
cert-to-efi-sig-list -g $(uuidgen) $KEK_KEY.crt $KEK_KEY.esl
sign-efi-sig-list -c $PK_KEY.crt -k $PK_KEY.key KEK $KEK_KEY.esl $KEK_KEY.auth

# Generate the Database Key (db) with configuration
openssl req -new -x509 -newkey rsa:2048 -keyout $DB_KEY.key -out $DB_KEY.crt -nodes -days 3650 -config $CONFIG_FILE
cert-to-efi-sig-list -g $(uuidgen) $DB_KEY.crt $DB_KEY.esl
sign-efi-sig-list -c $KEK_KEY.crt -k $KEK_KEY.key db $DB_KEY.esl $DB_KEY.auth

# Enroll keys using efi-updatevar
efi-updatevar -f $PK_KEY.auth PK
if [ $? -ne 0 ]; then
    echo "Failed to enroll Platform Key (PK)."
    exit 1
fi

efi-updatevar -f $KEK_KEY.auth KEK
if [ $? -ne 0 ]; then
    echo "Failed to enroll Key Exchange Key (KEK)."
    exit 1
fi

efi-updatevar -f $DB_KEY.auth db
if [ $? -ne 0 ]; then
    echo "Failed to enroll Database Key (db)."
    exit 1
fi

# Display completion message
echo "Secure Boot keys have been generated, signed, and enrolled successfully. Keys are stored in $KEY_DIR."
