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
- Required system permissions to configure secure boot

## Usage

### Running the Script with Bash

1. Clone the repository:
    ```bash
    git clone https://github.com/swoftii04/SecureBootGenerator.git
    cd SecureBootGenerator
    ```

2. Make the script executable:
    ```bash
    chmod +x secure_boot_generator.sh
    ```

3. Run the script:
    ```bash
    ./secure_boot_generator.sh
    ```

### Running the Script with Fish

1. Clone the repository:
    ```fish
    git clone https://github.com/swoftii04/SecureBootGenerator.git
    cd SecureBootGenerator
    ```

2. Make the script executable:
    ```fish
    chmod +x secure_boot_generator.sh
    ```

3. Run the script:
    ```fish
    ./secure_boot_generator.sh
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
