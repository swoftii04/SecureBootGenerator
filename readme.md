# SecureBootGenerator

## Overview

`SecureBootGenerator` is a shell script designed to assist in generating secure boot keys and configuration settings for your system. This script simplifies the process of setting up secure boot by automating key generation and configuration steps.

## Features

- Generates secure boot keys
- Configures secure boot settings
- Supports both Bash and Fish shells

## Prerequisites

Before running the script, ensure you have the following installed on your system:

- OpenSSL
- Efitools
- Mokutil
- Util-linux (for uuidgen)
- Pesign
- Sbsigntool
- Systemd-boot

## Installation

### Installing Dependencies

#### Ubuntu/Debian
1. Open a terminal.
2. Run the following commands to install the required dependencies:
    ```bash
    sudo apt update
    sudo apt install -y openssl efitools mokutil uuid-runtime pesign sbsigntool systemd-boot
    ```

#### Fedora
1. Open a terminal.
2. Run the following command to install the required dependencies:
    ```bash
    sudo dnf install -y openssl efitools mokutil util-linux pesign sbsigntool systemd-boot
    ```

#### Arch Linux
1. Open a terminal.
2. Run the following command to install the required dependencies:
    ```bash
    sudo pacman -Sy openssl efitools mokutil util-linux pesign sbsigntools systemd
    ```

## Usage

### Running the Script with Bash

1. Clone the repository:
    ```bash
    git clone https://github.com/swoftii04/SecureBootGenerator.git
    cd SecureBootGenerator
    ```

2. Make the script executable:
    ```bash
    chmod +x SecureBootGenerator.sh
    ```

3. Run the script:
    ```bash
    sudo ./SecureBootGenerator.sh
    ```

### Running the Script with Fish

1. Clone the repository:
    ```fish
    git clone https://github.com/swoftii04/SecureBootGenerator.git
    cd SecureBootGenerator
    ```

2. Make the script executable:
    ```fish
    chmod +x SecureBootGenerator.fish
    ```

3. Run the script:
    ```fish
    sudo ./SecureBootGenerator.fish
    ```

## Script Details

The `secure_boot_generator.sh` script performs the following actions:

1. Generates a set of secure boot keys using OpenSSL.
2. Configures the system's secure boot settings to use the generated keys.
3. Provides feedback on the status of the secure boot configuration.

For more details, please refer to the comments within the script file.

## Contributing

Contributions are welcome! Please fork the repository and submit a pull request with your changes.

## License

This project is licensed under the MIT License. See the [LICENSE](LICENSE) file for details.

## Contact

For any questions or issues, please open an issue on the [GitHub repository](https://github.com/swoftii04/SecureBootGenerator/issues).
