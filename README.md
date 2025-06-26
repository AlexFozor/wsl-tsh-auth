# WSL TSH Auth

A powerful WSL wrapper script that bridges Windows Teleport `tsh.exe` with Linux environments for seamless Kubernetes authentication with two-factor authentication and passkey support.

## Problem Solved

When working with Teleport in WSL (Windows Subsystem for Linux), you face two critical challenges:

1. **Authentication Limitations**: The Linux version of `tsh` running under WSL cannot access Windows hardware-based two-factor authentication (2FA) devices and passkeys, making secure authentication impossible
2. **Path Compatibility**: Generated kubeconfig files contain Windows-style paths to `tsh.exe`, which don't work in WSL environments

This script elegantly solves both issues by leveraging the Windows `tsh.exe` binary while automatically fixing path compatibility for WSL.

## Features

- **Full 2FA Support**: Utilizes Windows `tsh.exe` for complete two-factor authentication and passkey support that's unavailable to Linux binaries under WSL
- **Automatic Path Translation**: Seamlessly converts between Windows and WSL path formats
- **Smart Configuration**: Interactive setup with validation and persistent configuration storage
- **Zero-Configuration Passthrough**: All standard `tsh` commands work transparently
- **Intelligent Cluster Naming**: Automatically adds `k8s.` prefix when needed
- **Persistent Settings**: Remembers your configuration between sessions

## Installation

### Prerequisites

- Windows Subsystem for Linux (WSL)
- Teleport `tsh.exe` installed on Windows
- Bash shell in WSL

### Quick Setup

1. **Copy the script to your home directory:**
   ```bash
   cp wsl-tsh-auth.sh ~/
   ```

2. **Make it executable:**
   ```bash
   chmod +x ~/wsl-tsh-auth.sh
   ```

3. **Add the wrapper function to your shell:**
   ```bash
   nano ~/.bashrc
   ```
   
   Add this line to your `.bashrc`:
   ```bash
   tsh() { source ~/wsl-tsh-auth.sh "$@"; }
   ```

4. **Reload your shell configuration:**
   ```bash
   source ~/.bashrc
   ```

## Usage

### First Run Setup

On your first run, the script will interactively guide you through:
- Locating your Windows `tsh.exe` binary
- Setting up your Teleport kubeconfig directory

### Kubernetes Login

```bash
# Login to a Kubernetes cluster (k8s. prefix added automatically)
tsh kube login prod

# Login with full cluster name
tsh kube login k8s.production

# The script will handle 2FA/passkey authentication automatically
```

### Standard Teleport Commands

All standard `tsh` commands work transparently:

```bash
# Check status
tsh status

# List available clusters
tsh ls

# SSH to a node
tsh ssh user@hostname

# Get help
tsh --help
```

## How It Works

1. **Path Detection**: Automatically detects and validates Windows/WSL path formats
2. **Authentication**: Uses Windows `tsh.exe` for full 2FA/passkey support (hardware access unavailable to WSL Linux binaries)
3. **Path Translation**: Converts Windows paths in kubeconfig to WSL-compatible format
4. **Environment Setup**: Sets `KUBECONFIG` environment variable correctly
5. **Configuration Persistence**: Saves settings for future use

## Path Format Examples

The script accepts various path formats and automatically converts them:

**Windows Style:**
```
C:\tsh\tsh.exe
C:\Users\username\.tsh\keys\proxy\username-kube\teleport\
```

**WSL Style:**
```
/mnt/c/tsh/tsh.exe
/mnt/c/Users/username/.tsh/keys/proxy/username-kube/teleport/
```

## Configuration

The script stores configuration in `~/.wsl_tsh_auth` containing:
- Path to Windows `tsh.exe` binary
- Teleport kubeconfig directory location

## Contributing

Contributions are welcome! Please feel free to submit issues, feature requests, or pull requests.

## Troubleshooting

### Common Issues

**tsh.exe not found:**
- Ensure Teleport is properly installed on Windows
- Verify the path format is correct
- Check that the file is executable

**kubeconfig not working:**
- Verify the kubeconfig directory path
- Ensure the cluster name is correct
- Check WSL path translation is working

**2FA/Passkey issues:**
- Make sure you're using the Windows version of tsh.exe
- Verify your 2FA device is connected and working in Windows

---

*Made with ❤️ for the WSL + Teleport community*