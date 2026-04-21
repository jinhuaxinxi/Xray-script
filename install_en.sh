#!/usr/bin/env bash
# =============================================================================
# Note: Generated through Qwen3-Coder.
# Script Name: install.sh
# Script Repository: https://github.com/zxcvos/Xray-script
# Function Description: Installation bootstrap script for the Xray-script project.
#                       Responsible for checking and installing system dependencies,
#                       downloading project files, processing command-line parameters,
#                       initializing configuration, setting language, and launching the main menu.
# Author: zxcvos
# Date: 2025-07-25
# Version: 1.0.0
# Dependencies: bash, curl, wget, git, jq, sed, awk, grep
# Configuration:
#   - Download project files from GitHub to specified directory
#   - ${SCRIPT_CONFIG_DIR}/config.json: Used to read/set language and version information
# Xray Official Links:
#   - Xray-core: https://github.com/XTLS/Xray-core
#   - REALITY: https://github.com/XTLS/REALITY
#   - XHTTP: https://github.com/XTLS/Xray-core/discussions/4113
# Xray Configuration Templates:
#   - Xray Configuration Examples: https://github.com/chika0801/Xray-examples
#   - Optimal Combination Examples: https://github.com/lxhao61/integrated-examples
#   - xhttp Five-in-One Configuration: https://github.com/XTLS/Xray-core/discussions/4118
#
# Copyright (C) 2025 zxcvos
# =============================================================================

# set -Eeuxo pipefail

# --- Environment and Constant Settings ---
# Add commonly used paths to the PATH environment variable to ensure the script can find required commands in different environments
PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin:~/bin:/snap/bin
export PATH

# Define color codes for colored terminal output
readonly GREEN='\033[32m'  # Green
readonly YELLOW='\033[33m' # Yellow
readonly RED='\033[31m'    # Red
readonly NC='\033[0m'      # No color (reset)

# Get the absolute path of the current script directory and filename
readonly CUR_DIR="$(cd -P -- "$(dirname -- "$0")" && pwd -P)" # Current script directory
readonly CUR_FILE="$(basename "$0")"                          # Current script filename

# Define paths for configuration files and related directories
readonly SCRIPT_CONFIG_DIR="${HOME}/.xray-script"              # Main configuration directory
readonly SCRIPT_CONFIG_PATH="${SCRIPT_CONFIG_DIR}/config.json" # Script main configuration file path

# --- Global Variable Declaration ---
# Declare global variables for storing i18n data, project root directory, and quick installation options
declare -A I18N_DATA=(
    ['error']='Error'
    ['root']='This script must be run with root privileges'
    ['supported']='Current system is not supported. Please switch to Ubuntu 16+, Debian 9+, CentOS 7+.'
    ['ubuntu']='Current version is not supported. Please switch to Ubuntu 16+ and try again.'
    ['debian']='Current version is not supported. Please switch to Debian 9+ and try again.'
    ['centos']='Current version is not supported. Please switch to CentOS 7+ and try again.'
    ['tip']='Update Notice'
    ['new']='A new script version is available. Do you want to update?'
    ['now']='Update now? [Y/n] '
    ['promptly']='Please update the script promptly.'
    ['completed']='Update completed'
    ['download']='Downloading'
    ['failed']='Download failed'
    ['downloaded']='The file has been downloaded to'
)                        # Default i18n data (English)
declare PROJECT_ROOT=''  # Project installation root directory (dynamically set)
declare I18N_DIR=''      # i18n files directory (dynamically set)
declare CORE_DIR=''      # Core scripts directory (dynamically set)
declare SERVICE_DIR=''   # Service configuration directory (dynamically set)
declare CONFIG_DIR=''    # Configuration files directory (dynamically set)
declare TOOL_DIR=''      # Tool scripts directory (dynamically set)
declare QUICK_INSTALL='' # Store quick installation options (e.g., --vision, --xhttp)
declare SCRIPT_CONFIG='' # Store script configuration content
declare LANG_PARAM=''    # Store language parameter specified from command line
declare FORCE_CHECK_DEPS=0 # Whether to force check/install dependencies (0/1)

# =============================================================================
# Function Name: _os
# Function Description: Detect the name of the current operating system distribution.
# Parameters: None
# Return Value: Operating system name (echo output: debian/ubuntu/centos/amazon/...)
# =============================================================================
function _os() {
    local os="" # Declare local variable to store the operating system name

    # Check for Debian/Ubuntu series
    if [[ -f "/etc/debian_version" ]]; then
        # Read /etc/os-release file and extract ID field
        source /etc/os-release && os="${ID}"
        # Output the detected operating system name
        printf -- "%s" "${os}" && return
    fi

    # Check for Red Hat/CentOS series
    if [[ -f "/etc/redhat-release" ]]; then
        os="centos"
        # Output the detected operating system name
        printf -- "%s" "${os}" && return
    fi
}

# =============================================================================
# Function Name: _os_full
# Function Description: Get the complete distribution information of the current operating system.
# Parameters: None
# Return Value: Complete operating system version information (echo output)
# =============================================================================
function _os_full() {
    # Check for Red Hat/CentOS series
    if [[ -f /etc/redhat-release ]]; then
        # Extract distribution name and version number from /etc/redhat-release file
        awk '{print ($1,$3~/^[0-9]/?$3:$4)}' /etc/redhat-release && return
    fi

    # Check for common os-release file
    if [[ -f /etc/os-release ]]; then
        # Extract PRETTY_NAME field from /etc/os-release file
        awk -F'[= "]' '/PRETTY_NAME/{print $3,$4,$5}' /etc/os-release && return
    fi

    # Check for LSB (Linux Standard Base) release file
    if [[ -f /etc/lsb-release ]]; then
        # Extract DESCRIPTION field from /etc/lsb-release file
        awk -F'[="]+' '/DESCRIPTION/{print $2}' /etc/lsb-release && return
    fi
}

# =============================================================================
# Function Name: _os_ver
# Function Description: Get the major version number of the current operating system.
# Parameters: None
# Return Value: Operating system major version number (echo output)
# =============================================================================
function _os_ver() {
    # Call _os_full function to get complete version information, then extract numbers and dots
    local main_ver="$(echo $(_os_full) | grep -oE "[0-9.]+")"
    # Output the major version number (the part before the first dot)
    printf -- "%s" "${main_ver%%.*}"
}

# =============================================================================
# Function Name: cmd_exists
# Function Description: Check if a specified command exists in the system.
# Parameters:
#   $1: Command name to check
# Return Value: 0-command exists 1-command does not exist (exit code from command check tool)
# =============================================================================
function cmd_exists() {
    local cmd="$1" # Get the command name parameter

    # Try different methods to check if command exists
    if eval type type >/dev/null 2>&1; then
        # Use the type command to check
        eval type "$cmd" >/dev/null 2>&1
    elif command >/dev/null 2>&1; then
        # Use the command -v command to check
        command -v "$cmd" >/dev/null 2>&1
    else
        # Use the which command to check
        which "$cmd" >/dev/null 2>&1
    fi
}

# =============================================================================
# Function Name: parse_args
# Function Description: Parse command-line arguments.
# Parameters:
#   $@: All command-line arguments
# Return Value: None (directly modifies global variables QUICK_INSTALL, PROJECT_ROOT, LANG_PARAM)
# =============================================================================
function parse_args() {
    # Iterate through all command-line arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
        # If the parameter is language setting
        --lang=*)
            LANG_PARAM="${1}"
            ;;
        --check-deps)
            FORCE_CHECK_DEPS=1
            ;;
        esac
        shift # Move to the next parameter
    done
}

# =============================================================================
# Function Name: load_i18n
# Function Description: Load internationalization (i18n) data.
# Parameters: None
# Return Value: None (directly modifies global variable I18N_DATA)
# =============================================================================
function load_i18n() {
    local lang="${LANG_PARAM#*=}" # Extract language code from LANG_PARAM

    # If script configuration file exists, try to get language code from file
    if [[ -z "${lang}" && -f "${SCRIPT_CONFIG_PATH}" ]]; then
        # Try to get language code from script configuration file
        if cmd_exists "jq"; then
            lang="$(jq -r '.language' "${SCRIPT_CONFIG_PATH}" 2>/dev/null)"
        fi
    fi

    # If language is set to "auto", use the first part of system environment variable LANG as language code
    if [[ "$lang" == "auto" ]]; then
        lang=$(echo "$LANG" | cut -d'_' -f1)
    fi

    # If language is set to "en", load English prompt messages
    if [[ "$lang" == "en" ]]; then
        I18N_DATA=(
            ['error']='Error'
            ['root']='This script must be run as root'
            ['supported']='Not supported OS'
            ['ubuntu']='Not supported OS, please change to Ubuntu 18+ and try again.'
            ['debian']='Not supported OS, please change to Debian 9+ and try again.'
            ['centos']='Not supported OS, please change to CentOS 7+ and try again.'
            ['tip']='Update Notice'
            ['new']='A new version of the script is available. Do you want to update?'
            ['now']='Update now? [Y/n]'
            ['promptly']='Please update the script promptly.'
            ['completed']='Update completed'
            ['download']='Downloading'
            ['failed']='Download failed'
            ['downloaded']='The file has been downloaded to'
        )
    fi
}

# =============================================================================
# Function Name: _error
# Function Description: Print error message in red and exit the script.
# Parameters:
#   $@: Error message content
# Return Value: None (directly print to stderr >&2, then exit 1)
# =============================================================================
function _error() {
    # Print error title in red
    printf "${RED}[${I18N_DATA['error']}] ${NC}"
    # Print the passed error message
    printf -- "%s" "$@"
    # Print newline
    printf "\n"
    # Exit script with error code 1
    exit 1
}

# =============================================================================
# Function Name: check_os
# Function Description: Check if the operating system is supported.
# Parameters: None
# Return Value: None (if not supported, call _error to exit)
# =============================================================================
function check_os() {
    # Check operating system type and version
    case "$(_os)" in
    # CentOS series
    centos)
        # Check if version is >= 7
        if [[ "$(_os_ver)" -lt 7 ]]; then
            _error "${I18N_DATA['centos']}"
        fi
        ;;
    # Ubuntu series
    ubuntu)
        # Check if version is >= 16
        if [[ "$(_os_ver)" -lt 16 ]]; then
            _error "${I18N_DATA['ubuntu']}"
        fi
        ;;
    # Debian series
    debian)
        # Check if version is >= 9
        if [[ "$(_os_ver)" -lt 9 ]]; then
            _error "${I18N_DATA['debian']}"
        fi
        ;;
    # Other unsupported operating systems
    *)
        _error "${I18N_DATA['supported']}"
        ;;
    esac
}

# =============================================================================
# Function Name: check_dependencies
# Function Description: Check if necessary dependency software is installed.
# Parameters: None
# Return Value: 0-all dependencies installed 1-dependencies missing (from command check result)
# =============================================================================
function check_dependencies() {
    # Define list of basic required packages
    local packages=("ca-certificates" "openssl" "curl" "wget" "git" "jq" "tzdata" "qrencode" "socat")
    local missing_packages=() # Declare array to store missing packages

    # Check specific packages according to operating system type
    case "$(_os)" in
    centos)
        # Add system administration tools for CentOS/RHEL
        packages+=("crontabs" "util-linux" "iproute" "procps-ng" "bind-utils")
        # Iterate through package list to check if installed
        for pkg in "${packages[@]}"; do
            if ! rpm -q "$pkg" &>/dev/null; then
                missing_packages+=("$pkg") # If not installed, add to missing list
            fi
        done
        ;;
    debian | ubuntu)
        # Add system administration tools for Debian/Ubuntu
        packages+=("cron" "bsdmainutils" "iproute2" "procps" "dnsutils")
        # Iterate through package list to check if installed
        for pkg in "${packages[@]}"; do
            if ! dpkg -s "$pkg" &>/dev/null; then
                missing_packages+=("$pkg") # If not installed, add to missing list
            fi
        done
        ;;
    esac

    # If missing packages list is empty, return 0 (success)
    [[ ${#missing_packages[@]} -eq 0 ]]
}

# =============================================================================
# Function Name: install_dependencies
# Function Description: Install necessary dependency packages according to operating system type.
# Parameters: None
# Return Value: None (execute package manager commands to install software)
# =============================================================================
function install_dependencies() {
    # Define list of basic required packages
    local packages=("ca-certificates" "openssl" "curl" "wget" "git" "jq" "tzdata" "qrencode" "socat")

    # Add specific packages according to operating system type and execute installation
    case "$(_os)" in
    centos)
        # Add system administration tools for CentOS/RHEL
        packages+=("crontabs" "util-linux" "iproute" "procps-ng" "bind-utils")
        # Check if dnf package manager is available (newer versions)
        if cmd_exists "dnf"; then
            # Use dnf to update system and install packages
            dnf update -y
            dnf install -y dnf-plugins-core
            dnf update -y
            for pkg in "${packages[@]}"; do
                dnf install -y ${pkg}
            done
        else
            # Use yum package manager (older versions)
            yum update -y
            yum install -y epel-release yum-utils
            yum update -y
            for pkg in "${packages[@]}"; do
                yum install -y ${pkg}
            done
        fi
        ;;
    ubuntu | debian)
        # Add system administration tools for Debian/Ubuntu
        packages+=("cron" "bsdmainutils" "iproute2" "procps" "dnsutils")
        # Update package list and install packages
        apt update -y
        for pkg in "${packages[@]}"; do
            apt install -y ${pkg}
        done
        ;;
    esac
}

# =============================================================================
# Function Name: download_github_files
# Function Description: Download files from a specified directory using GitHub API.
# Parameters:
#   $1: Local target directory
#   $2: GitHub API project URL
# Return Value: None (execute file download and decompression process)
# =============================================================================
function download_github_files() {
    local target_dir="$1"     # Local target directory
    local github_api_url="$2" # GitHub API project URL

    # Create target directory
    mkdir -p "${target_dir}"
    # Switch to target directory
    cd "${target_dir}"

    # Print information about starting download
    echo -e "${GREEN}[${I18N_DATA['download']}]${NC} ${github_api_url}"
    # Use curl to download tar.gz format files from GitHub API and decompress
    if ! curl -sL "${github_api_url}" | tar xz --strip-components=1; then
        # If download fails, call _error to exit
        _error "${I18N_DATA['failed']}: ${github_api_url}"
    fi
}

# =============================================================================
# Function Name: download_xray_script_files
# Function Description: Download all files of the Xray-script project.
# Parameters:
#   $1: Local target root directory
# Return Value: None (call download_github_files to download project)
# =============================================================================
function download_xray_script_files() {
    local target_dir="$1" # Local target root directory
    # Define GitHub API project URL
    local script_github_api="https://api.github.com/repos/zxcvos/xray-script/tarball/main"

    # Call download_github_files to download project
    download_github_files "${target_dir}" "${script_github_api}"
}

# =============================================================================
# Function Name: check_xray_script_version
# Function Description: Check if the version of locally installed Xray-script is consistent with the latest version on GitHub.
#                       If not consistent, prompt the user.
# Parameters: None (directly use global variable PROJECT_ROOT)
# Return Value: None (print version check information to standard output)
# =============================================================================
function check_xray_script_version() {
    # Define GitHub API URL and local version file path
    local script_config_github_url="https://raw.githubusercontent.com/zxcvos/Xray-script/main/config.json"
    local is_update='n' # Initialize update flag to 'n' (do not update)

    # Read local version number
    local local_version="$(jq -r '.version' "${SCRIPT_CONFIG_PATH}")"
    # Get remote version number from GitHub API
    local remote_version="$(curl -fsSL "$script_config_github_url" | jq -r '.version')"

    # Compare local and remote version numbers
    if [[ "${local_version}" != "${remote_version}" ]]; then
        # If not consistent, prompt user about new version
        echo -e "${GREEN}[${I18N_DATA['tip']}]${NC} ${I18N_DATA['new']}"
        # Ask user if they want to update
        read -rp "${I18N_DATA['now']}" -e -i "Y" is_update

        # Decide whether to update based on user choice
        case "${is_update,,}" in # ${is_update,,} convert to lowercase
        y | yes)
            # If user chooses to update
            # Switch to HOME directory
            cd "${HOME}"
            # Define temporary directory
            readonly temp_dir="${SCRIPT_CONFIG_DIR}/xray-script-temp"
            # Create temporary directory
            mkdir -vp "${temp_dir}"
            # Download latest files to temporary directory
            download_xray_script_files "${temp_dir}"
            # Delete old project directory
            rm -rf "${PROJECT_ROOT}"
            # Move temporary directory to become new project directory
            mv -f "${temp_dir}" "${PROJECT_ROOT}"
            # Delete old script file
            rm -f "${CUR_DIR}/${CUR_FILE}"
            # Update current script file
            cp -f "${PROJECT_ROOT}/install.sh" "${CUR_DIR}/${CUR_FILE}"
            # Update version number
            sed -i "s|${local_version}|${remote_version}|" "${SCRIPT_CONFIG_PATH}" && sleep 1
            # Print update completion information
            echo -e "${GREEN}[${I18N_DATA['tip']}]${NC} ${I18N_DATA['completed']}"
            # Restart script
            bash "${CUR_DIR}/${CUR_FILE}"
            # Exit script to avoid repeated execution
            exit 0
            ;;
        *)
            # If user chooses not to update, prompt to update promptly
            echo -e "${YELLOW}[${I18N_DATA['tip']}]${NC} ${I18N_DATA['promptly']}"
            ;;
        esac
    fi
}

# =============================================================================
# Function Name: main
# Function Description: Main entry function of the script.
#                       1. Parse command-line arguments.
#                       2. Load i18n data.
#                       3. Check root privileges.
#                       4. Check operating system.
#                       5. Check and install dependencies.
#                       6. Handle project directory and configuration.
#                       7. Start the main script.
# Parameters:
#   $@: All command-line arguments
# Return Value: None (coordinate calling other functions to complete the entire installation process)
# =============================================================================
function main() {
    # Parse command-line arguments
    parse_args "$@"
    # Load i18n data
    load_i18n

    # Check if running with root privileges
    [[ $EUID -ne 0 ]] && _error "${I18N_DATA['root']}"

    # Check operating system
    check_os

    local is_first_run=0
    if [[ ! -f "${SCRIPT_CONFIG_PATH}" ]]; then
        is_first_run=1
    fi

    # Check/install dependencies only on first run or when explicitly forced
    if [[ "${is_first_run}" -eq 1 || "${FORCE_CHECK_DEPS}" -eq 1 ]]; then
        # Check dependencies, install if missing
        if ! check_dependencies; then
            install_dependencies
        fi

        # Check dependencies again (after installation)
        if ! check_dependencies; then
            install_dependencies
        fi
    fi

    # Check if script configuration directory and configuration file exist, if not create and download default configuration
    if [[ ! -d "${SCRIPT_CONFIG_DIR}" ]]; then
        mkdir -p "${SCRIPT_CONFIG_DIR}"
    fi
    if [[ ! -f "${SCRIPT_CONFIG_PATH}" ]]; then
        wget -O "${SCRIPT_CONFIG_PATH}" https://raw.githubusercontent.com/zxcvos/Xray-script/main/config.json
    fi

    # Handle quick installation and custom directory options from command-line arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
        # Quick installation options
        --vision | --xhttp | --fallback)
            QUICK_INSTALL="${1}"
            ;;
        # Custom installation directory option
        -d)
            shift
            PROJECT_ROOT="${1}"
            ;;
        esac
        shift
    done

    # Read installation path recorded in script configuration file
    local script_path="$(jq -r '.path' "${SCRIPT_CONFIG_PATH}")"
    # If configuration file has no recorded path and command line has not specified one, use default path
    if [[ -z "${script_path}" && -z "${PROJECT_ROOT}" ]]; then
        PROJECT_ROOT='/usr/local/xray-script' # Set default project root directory
        # Update default path to script configuration file
        SCRIPT_CONFIG="$(jq --arg path "${PROJECT_ROOT}" '.path = $path' "${SCRIPT_CONFIG_PATH}")"
        echo "${SCRIPT_CONFIG}" >"${SCRIPT_CONFIG_PATH}" && sleep 2
    # If configuration file already has recorded path, use that path
    elif [[ -n "${script_path}" ]]; then
        PROJECT_ROOT="${script_path}"
    # If configuration file has no path but command line specified one, use command line specified path and update configuration file
    elif [[ -n "${PROJECT_ROOT}" ]]; then
        # Update command line specified path to script configuration file
        SCRIPT_CONFIG="$(jq --arg path "${PROJECT_ROOT}" '.path = $path' "${SCRIPT_CONFIG_PATH}")"
        echo "${SCRIPT_CONFIG}" >"${SCRIPT_CONFIG_PATH}" && sleep 2
    fi

    # Set paths for various subdirectories
    I18N_DIR="${PROJECT_ROOT}/i18n"
    CORE_DIR="${PROJECT_ROOT}/core"
    SERVICE_DIR="${PROJECT_ROOT}/service"
    CONFIG_DIR="${PROJECT_ROOT}/config"
    TOOL_DIR="${PROJECT_ROOT}/tool"

    # Check if project root directory exists
    if [[ -d "${PROJECT_ROOT}" ]]; then
        # If exists, check for version updates
        check_xray_script_version
    else
        # If not exists, download project files
        download_xray_script_files "${PROJECT_ROOT}"
    fi

    # Check language setting in configuration file
    local lang="$(jq -r '.language' "${SCRIPT_CONFIG_PATH}")"
    if [[ -z "${lang}" && -z "${LANG_PARAM}" ]]; then
        # If language not set and not specified from command line, run menu script to select language
        bash "${CORE_DIR}/menu.sh" '--language'
        case $? in
        2) LANG_PARAM="en" ;; # Select English
        *) LANG_PARAM="zh" ;; # Default Chinese
        esac
        # Update language setting in configuration file
        SCRIPT_CONFIG="$(jq --arg language "${LANG_PARAM}" '.language = $language' "${SCRIPT_CONFIG_PATH}")"
        echo "${SCRIPT_CONFIG}" >"${SCRIPT_CONFIG_PATH}" && sleep 2
    elif [[ "${LANG_PARAM}" =~ ^--lang= ]]; then
        # If language specified from command line, update configuration file
        SCRIPT_CONFIG="$(jq --arg language "${LANG_PARAM#*=}" '.language = $language' "${SCRIPT_CONFIG_PATH}")"
        echo "${SCRIPT_CONFIG}" >"${SCRIPT_CONFIG_PATH}" && sleep 2
    fi

    # Start the main script, passing quick installation options
    bash "${CORE_DIR}/main.sh" "${QUICK_INSTALL}"
}

# --- Script Execution Entry Point ---
# Pass all parameters received by the script to the main function to start execution
main "$@"
