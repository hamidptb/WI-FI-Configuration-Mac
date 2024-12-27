# WifiConfigure

A simple macOS application to quickly switch between home (DHCP) and office (manual) network configurations.

## Features

- Quick switching between DHCP and manual network configurations
- Save and restore manual network settings
- Separate DNS configuration management
- Pre-configured DNS server options (Google, Cloudflare, etc.)
- Native macOS app with SwiftUI interface

## Requirements

- macOS 12.4 or later
- Administrative privileges (required for network configuration)

## Usage

1. Launch the application
2. Choose between "Home (Using DHCP)" or "Office (Manually)" configuration
3. If using manual configuration:
   - Enter IP Address
   - Enter Subnet Mask
   - Enter Router Address
   - Enter DNS Servers (optional)
4. Click "Apply Settings" to save and apply the configuration

The DNS tab allows you to:
- Set custom DNS servers
- Quick-select popular DNS services
- Apply DNS settings independently of network configuration

## Development

This app was developed for personal use to simplify switching between home and office network configurations on macOS. It uses:
- SwiftUI for the user interface
- macOS network configuration commands
- UserDefaults for persistent storage of settings

## Note

This application requires administrative privileges to modify network settings. Make sure you have the necessary permissions before using it.

## License

This project is for personal use. Feel free to modify and use it according to your needs. 