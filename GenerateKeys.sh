#!/bin/bash

# Exit immediately if a command exits with a non-zero status
set -e

echo "Starting Secure Boot Key Generation Script..."

# Check if Secure Boot is enabled
sbstate=$(mokutil --sb-state)
if [[ "$sbstate" == *"SecureBoot enabled"* ]]; then
    echo "Secure Boot is enabled. Exiting script."
    exit 1
fi

echo "Secure Boot is disabled. Continuing with key generation..."

# Ensure the script is run with root privileges
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root"
   exit 1
fi

# Create directories if they don't exist
mkdir -p /keys/cfg /keys/esl /keys/auth /keys/bak

# Generate Platform Key (PK)
echo "Generating Platform Key (PK)..."
openssl req -x509 -sha256 -days 5490 -outform PEM \
    -config /keys/cfg/PK.cfg \
    -keyout /keys/PK.key -out /keys/PK.pem
openssl x509 -text -noout -inform PEM -in /keys/PK.pem

# Copy configuration and modify for Key Exchange Key (KEK)
echo "Copying and modifying configuration for Key Exchange Key (KEK)..."
cp -v /keys/cfg/{PK,KEK}.cfg
sed -i 's/Platform Key/Key Exchange Key/g' /keys/cfg/KEK.cfg

# Generate KEK
echo "Generating Key Exchange Key (KEK)..."
openssl req -x509 -sha256 -days 5490 -outform PEM \
    -config /keys/cfg/KEK.cfg \
    -keyout /keys/KEK.key -out /keys/KEK.pem
openssl x509 -text -noout -inform PEM -in /keys/KEK.pem

# Copy configuration and modify for Signature Database (db)
echo "Copying and modifying configuration for Signature Database (db)..."
cp -v /keys/cfg/{PK,db}.cfg
sed -i 's/Platform Key/Signature Database/g' /keys/cfg/db.cfg

# Generate db
echo "Generating Signature Database (db)..."
openssl req -x509 -sha256 -days 5490 -outform PEM \
    -config /keys/cfg/db.cfg \
    -keyout /keys/db.key -out /keys/db.pem
openssl x509 -text -noout -inform PEM -in /keys/db.pem

# List keys
ls -l /keys | grep -v ^d

# Generate GUID and save to file
echo "$(uuidgen --random)" > /keys/guid.txt
cat /keys/guid.txt

# Convert certificates to EFI Signature Lists
cert-to-efi-sig-list -g "$(< /keys/guid.txt)" /keys/PK.pem /keys/esl/PK.esl
sign-efi-sig-list -g "$(< /keys/guid.txt)" -t "$(date +'%F %T')" -c /keys/PK.pem -k /keys/PK.key PK /keys/esl/PK.esl /keys/auth/PK.auth

cert-to-efi-sig-list -g "$(< /keys/guid.txt)" /keys/KEK.pem /keys/esl/KEK.esl
sign-efi-sig-list -g "$(< /keys/guid.txt)" -t "$(date +'%F %T')" -c /keys/PK.pem -k /keys/PK.key KEK /keys/esl/KEK.esl /keys/auth/KEK.auth

cert-to-efi-sig-list -g "$(< /keys/guid.txt)" /keys/db.pem /keys/esl/db.esl
sign-efi-sig-list -g "$(< /keys/guid.txt)" -t "$(date +'%F %T')" -c /keys/KEK.pem -k /keys/KEK.key db /keys/esl/db.esl /keys/auth/db.auth

# List auth keys
ls -l /keys/auth/

# Update EFI variables
efi-updatevar -f /keys/auth/db.auth db
efi-updatevar -f /keys/auth/KEK.auth KEK
efi-updatevar -f /keys/auth/PK.auth PK

# Read EFI variables
efi-readvar

# Check boot status
bootctl status --no-pager

# Sign the shim binary
echo "Signing the shim binary..."
pesign -S -i /boot/efi/EFI/fedora/shimx64.efi
cp -v /boot/efi/EFI/fedora/shimx64.efi /keys/bak/
pesign -r -u0 -i /boot/efi/EFI/fedora/shimx64.efi -o /boot/efi/EFI/fedora/shimx64.efi.empty
pesign -S -i /boot/efi/EFI/fedora/shimx64.efi.empty
sbsign /boot/efi/EFI/fedora/shimx64.efi.empty --key /keys/db.key --cert /keys/db.pem --output /boot/efi/EFI/fedora/shimx64.efi
pesign -S -i /boot/efi/EFI/fedora/shimx64.efi
rm /boot/efi/EFI/fedora/shimx64.efi.empty

# Sign the kernel
echo "Signing the kernel..."
pesign -S -i /boot/vmlinuz-$(uname -r)
sbsign /boot/vmlinuz-$(uname -r) --key /keys/db.key --cert /keys/db.pem --output /boot/vmlinuz-$(uname -r)
pesign -S -i /boot/vmlinuz-$(uname -r)

# List trusted keys
keyctl list %:.builtin_trusted_keys

echo "Script completed successfully."
