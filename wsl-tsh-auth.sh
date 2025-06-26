#!/bin/bash

set -u  # Exit on undefined variables

# Installation instructions:
# 1. cp wsl-tsh-auth.sh ~/
# 2. chmod +x ~/wsl-tsh-auth.sh
# 3. nano ~/.bashrc
# 4. Add to .bashrc: tsh() { source ~/wsl-tsh-auth.sh "$@"; }
# 5. source ~/.bashrc

CONFIG_FILE="$HOME/.wsl_tsh_auth"
NEED_UPDATE=0

# ANSI color codes
CYAN='\033[36m'
GRAY='\033[90m'
GREEN='\033[32m'
RED='\033[31m'
YELLOW='\033[33m'
UNDERLINE='\033[4m'
UNDERLINE_OFF='\033[24m'
RESET='\033[0m'

# Parse and normalize Windows/Linux paths to Linux WSL format
parse_path() {
  local USER_PATH="$1"

  # Convert double backslashes to single
  USER_PATH=$(echo "$USER_PATH" | sed -E 's|\\\\|\\|g')
  # Convert all backslashes to forward slashes
  USER_PATH=$(echo "$USER_PATH" | sed 's|\\|/|g')
  # Remove leading slash before drive letter
  USER_PATH=$(echo "$USER_PATH" | sed -E 's|^/([A-Za-z]):|\1:|')

  # Convert Windows path to WSL format
  if [[ "$USER_PATH" =~ ^([A-Za-z]):/(.*) ]]; then
    local drive_letter="${BASH_REMATCH[1]}"
    local rest="${BASH_REMATCH[2]}"
    drive_letter=$(echo "$drive_letter" | tr '[:upper:]' '[:lower:]')
    echo "/mnt/$drive_letter/$rest"
  elif [[ "$USER_PATH" == /mnt/* ]]; then
    echo "$USER_PATH"
  else
    echo ""
  fi
}

# Delete N lines from terminal output using ANSI escape sequences
delete_last_lines() {
  local n=$1
  for ((i=0; i<n; i++)); do
    echo -en "\033[1A\033[2K"  # Move up and clear line
  done
}

# Interactive path input with validation and cleanup
request_path() {
  local prompt="$1"
  local check_type="$2"  # "file" or "dir"
  local result=""
  local first_try=1
  local lines_printed=0

  while true; do
    if [[ $first_try -eq 1 ]]; then
      echo
      if [[ "$check_type" == "file" ]]; then
        echo -e "Path example: ${GRAY}${UNDERLINE}/mnt/c/tsh/tsh.exe${UNDERLINE_OFF}${RESET} or ${GRAY}${UNDERLINE}C:\\\tsh\\\tsh.exe${UNDERLINE_OFF}${RESET}"
        ((lines_printed++))
      else
        echo -e "Path example: ${GRAY}${UNDERLINE}/mnt/c/Users/<username>/.tsh/keys/<proxy>/<username>-kube/teleport/${UNDERLINE_OFF}${RESET}"
        echo -e "or ${GRAY}${UNDERLINE}C:\\\Users\\\<username>\\\.tsh\\\keys\\\<proxy>\\\<username>-kube\\\teleport\\ ${UNDERLINE_OFF}${RESET}"
        ((lines_printed+=3))
      fi
      echo -en "${CYAN}$prompt${RESET}"
      read -r USER_PATH
      ((lines_printed++))
      first_try=0
    else
      echo -e "${YELLOW}Please try again.${RESET}"
      echo -en "${CYAN}$prompt${RESET}"
      read -r USER_PATH
      ((lines_printed+=2))
    fi

    # Validate path format and existence
    result=$(parse_path "$USER_PATH")
    if [[ -z "$result" ]]; then
      echo -en "${YELLOW}Invalid path format. ${RESET}"
      continue
    fi
    if [[ "$check_type" == "file" && ! -f "$result" ]]; then
      echo -en "${YELLOW}File not found at $result. ${RESET}"
      continue
    elif [[ "$check_type" == "dir" && ! -d "$result" ]]; then
      echo -en "${YELLOW}Directory not found at $result. ${RESET}"
      continue
    fi
    echo
    ((lines_printed++))
    break
  done

  # Clean up prompt lines and show result
  delete_last_lines "$lines_printed"
  echo -e "${GREEN}Path accepted: $result${RESET}"
  echo
  REQUEST_PATH_RESULT="$result"
}

# Convert Linux WSL path back to Windows format for sed replacement
linux_to_win_path() {
  local linux_path="$1"
  local drive_letter
  drive_letter=$(echo "$linux_path" | sed -nE 's|/mnt/([a-zA-Z])/.*|\1|p' | tr '[:lower:]' '[:upper:]')
  local win_path
  win_path=$(echo "$linux_path" | sed -E "s|/mnt/[a-zA-Z]/|${drive_letter}:/|" | sed 's|/|\\|g')
  echo "$win_path"
}

# Save configuration to file
update_config() {
  local tsh_path="$1"
  local kube_dir="$2"
  echo "$tsh_path" > "$CONFIG_FILE"
  echo "$kube_dir" >> "$CONFIG_FILE"
  echo -e "${GREEN}Config updated: $CONFIG_FILE${RESET}"
}

# Display help information
show_help() {
  echo -e "${CYAN}WSL TSH Auth Script${RESET}"
  echo -e "${GRAY}A wrapper script for tsh with enhanced Kubernetes support${RESET}"
  echo
  echo -e "${YELLOW}Usage:${RESET}"
  echo -e "  tsh [command] [args...]"
  echo -e "  tsh kube login <cluster_name>"
  echo
  echo -e "${YELLOW}Examples:${RESET}"
  echo -e "  tsh kube login prod          # Login to k8s.prod cluster"
  echo -e "  tsh status                   # Show tsh status"
  echo -e "  tsh ls                       # List available clusters"
  echo
}

# Main Teleport Kubernetes login handler
tp_kube_login() {
  local CLUSTER="$1"
  
  # Auto-add k8s prefix if missing
  if [[ "$CLUSTER" != k8s.* ]]; then
    echo -e "${YELLOW}[WARN] Cluster name does not start with 'k8s.'. Adding prefix automatically.${RESET}"
    CLUSTER="k8s.$CLUSTER"
  fi

  # Attempt login without password first
  "$TSH_PATH" kube login "$CLUSTER" --proxy=tp.wb.ru
  local LOGIN_STATUS=$?
  
  # Handle password requirement
  if [ $LOGIN_STATUS -ne 0 ]; then
    echo -en "${CYAN}Teleport requested a password, please enter: ${RESET}"
    read -rs PASSWORD
    echo
    echo "$PASSWORD" | "$TSH_PATH" kube login "$CLUSTER" --proxy=tp.wb.ru
    LOGIN_STATUS=$?
    if [ $LOGIN_STATUS -ne 0 ]; then
      echo -e "${RED}Error: Failed to log in to cluster $CLUSTER${RESET}"
      return 1
    fi
  fi

  # Get kubeconfig directory
  local OLD_KUBECONFIG_DIR="$KUBECONFIG_DIR"
  if [[ -z "$KUBECONFIG_DIR" || ! -d "$KUBECONFIG_DIR" ]]; then
    request_path "Enter path to Teleport kubeconfig folder without filename: " "dir"
    KUBECONFIG_DIR="$REQUEST_PATH_RESULT"
    NEED_UPDATE=1
  fi

  # Verify kubeconfig file exists
  local WIN_KUBECONFIG_PATH="${KUBECONFIG_DIR}/${CLUSTER}-kubeconfig"
  if [ ! -f "$WIN_KUBECONFIG_PATH" ]; then
    echo -e "${RED}Error: kubeconfig file does not exist at $WIN_KUBECONFIG_PATH${RESET}"
    return 1
  fi

  # Fix Windows paths in kubeconfig for WSL compatibility
  local TSH_PATH_WIN=$(linux_to_win_path "$TSH_PATH")
  local TSH_PATH_WIN_ESCAPED=$(echo "$TSH_PATH_WIN" | sed 's|\\|\\\\|g')
  sed -i "s|$TSH_PATH_WIN_ESCAPED|$TSH_PATH|g" "$WIN_KUBECONFIG_PATH"

  # Set environment and save config
  export KUBECONFIG="$WIN_KUBECONFIG_PATH"
  echo -e "${CYAN}KUBECONFIG set to $KUBECONFIG${RESET}"
  echo

  if [[ "$KUBECONFIG_DIR" != "$OLD_KUBECONFIG_DIR" || $NEED_UPDATE == 1 ]]; then
    update_config "$TSH_PATH" "$KUBECONFIG_DIR"
  fi
}

# Load existing configuration
if [ -f "$CONFIG_FILE" ]; then
  TSH_PATH=$(sed -n '1p' "$CONFIG_FILE")
  KUBECONFIG_DIR=$(sed -n '2p' "$CONFIG_FILE")
else
  TSH_PATH=""
  KUBECONFIG_DIR=""
fi

# Get and validate tsh.exe path
if [[ -z "$TSH_PATH" || ! -f "$TSH_PATH" ]]; then
  request_path "Enter full path to tsh.exe: " "file"
  TSH_PATH="$REQUEST_PATH_RESULT"
  NEED_UPDATE=1
fi

# Verify tsh executable works
if ! "$TSH_PATH" version >/dev/null 2>&1; then
  echo -e "${RED}Error: tsh executable at $TSH_PATH is not working or not found${RESET}"
  echo -e "${YELLOW}Please check the path and make sure tsh is properly installed${RESET}"
  exit 1
fi

# Command line argument handling
if [[ $# -eq 0 ]]; then
  show_help
  exit 0
fi

if [[ "$1" == "--help" || "$1" == "-h" ]]; then
  show_help
  exit 0
fi

# Handle Kubernetes login command
if [[ $# -ge 3 && "$1" == "kube" && "$2" == "login" && -n "$3" ]]; then
  echo -e "${CYAN}Starting WSL TSH Auth login script for cluster: $3${RESET}"
  echo

  if tp_kube_login "$3"; then
    echo -e "${GREEN}Teleport connection setup complete.${RESET}"
    echo
  else
    echo -e "${RED}Teleport connection setup failed.${RESET}"
    echo
  fi
else
  # Pass through all other commands to tsh
  "$TSH_PATH" "$@"
fi
