#!/bin/bash

# ==============================================================================
# Walk my NFS
# Author: t3rminux
#
# Description:
# Automates discovering and mounting NFS shares from a list of IPs.
# Can also be used to unmount all shares handled by this script.
#
# ==============================================================================

# --- Configuration & Global Variables ---
MOUNT_OPTS="ro,nolock,soft,timeo=5"

# --- Functions ---

# Function to display how to use the script
usage() {
    echo "Description:"
    echo "  A utility to bulk mount or unmount NFS shares."
    echo ""
    echo "Usage for Mounting:"
    echo "  sudo $0 [-d /path/to/base_dir] <path_to_ip_file.txt>"
    echo ""
    echo "Usage for Unmounting:"
    echo "  sudo $0 -u [-d /path/to/base_dir]"
    echo ""
    echo "Options:"
    echo "  -u, --unmount      Perform unmount and cleanup instead of mounting."
    echo "  -d, --dir <path>   Specify a custom base directory. Defaults to the current user's ~/NFS-Dump/"
    echo "  -h, --help         Show this help message."
    exit 1
}

# Function containing all the logic for unmounting shares
unmount_all() {
    echo "[*] Starting NFS Auto-Unmounter"
    echo "[*] Targeting mount points within: $BASE_DIR"

    if [ ! -d "$BASE_DIR" ]; then
        echo "[-] Error: Base directory '$BASE_DIR' not found. Nothing to do."
        exit 1
    fi

    # Find all mount points within the base directory.
    # Sort reverse to unmount children before parents, avoids 'target is busy' issues.
    MOUNT_POINTS=$(findmnt -l -n -o TARGET --target "$BASE_DIR" | sort -r)

    if [ -z "$MOUNT_POINTS" ]; then
        echo "[*] No active mounts found within '$BASE_DIR'."
    else
        echo "[+] Found the following mounts to process:"
        echo "$MOUNT_POINTS"
        echo "================================================="

        for mount_point in $MOUNT_POINTS; do
            echo "[*] Unmounting '$mount_point'..."
            timeout 10 umount "$mount_point"
            if [ $? -eq 0 ]; then
                echo "    [+] SUCCESS: Unmounted '$mount_point'"
            else
                echo "    [-] FAILED to unmount '$mount_point'."
                echo "    [-] It might be busy. Try 'umount -l' (lazy) manually."
            fi
        done
        echo "================================================="
    fi

    echo "[*] Unmount process finished."
    read -p "[?] Do you want to remove the empty directory structure? (y/N) " response
    if [[ "$response" =~ ^([yY][eE][sS]|[yY])$ ]]; then
        echo "[*] Cleaning up empty directories..."
        find "$BASE_DIR" -depth -type d -empty -delete
        echo "[+] Cleanup complete."
    else
        echo "[*] Skipping cleanup."
    fi

    echo "[*] Script finished."
    exit 0
}

# Function containing all the logic for mounting shares
mount_all() {
    IP_LIST_FILE="$1"

    # --- Pre-flight Checks for Mounting ---
    if [ ! -f "$IP_LIST_FILE" ]; then
        echo "[-] Error: IP list file not found at '$IP_LIST_FILE'"
        usage
    fi

    if ! command -v showmount &> /dev/null; then
        echo "[-] Error: 'showmount' command not found. Please install 'nfs-common' or 'nfs-utils'."
        exit 1
    fi

    # --- Main Mount Logic ---
    echo "[*] Starting NFS Auto-Mounter"
    echo "[*] Mounts will be created in: $BASE_DIR"
    echo "[*] Reading target IPs from: $IP_LIST_FILE"

    mkdir -p "$BASE_DIR"

    while IFS= read -r ip || [[ -n "$ip" ]]; do
        if [ -z "$ip" ]; then continue; fi

        echo "================================================="
        echo "[*] Processing Target: $ip"
        EXPORTS=$(timeout 10 showmount -e "$ip" 2>/dev/null | tail -n +2 | awk '{print $1}')

        if [ -z "$EXPORTS" ]; then
            echo "[-] No NFS exports found or host is unreachable for $ip."
            continue
        fi

        echo "[+] Found Exports on $ip:"
        echo "$EXPORTS"
        echo "-------------------------------------------------"

        for export_path in $EXPORTS; do
            MOUNT_POINT="$BASE_DIR/$ip$export_path"
            echo "[*] Preparing share: '$ip:$export_path'"

            echo "    -> Creating mount directory: $MOUNT_POINT"
            mkdir -p "$MOUNT_POINT"
            if [ $? -ne 0 ]; then
                echo "    [-] FAILED to create directory. Skipping."
                continue
            fi

            if mountpoint -q "$MOUNT_POINT"; then
                echo "    [!] Notice: Already mounted at '$MOUNT_POINT'. Skipping."
                continue
            fi

            echo "    -> Mounting with options: '$MOUNT_OPTS'..."
            mount -t nfs -o "$MOUNT_OPTS" "$ip:$export_path" "$MOUNT_POINT"

            if [ $? -eq 0 ]; then
                echo "    [+] SUCCESS: Mounted '$ip:$export_path'"
            else
                echo "    [-] FAILED to mount '$ip:$export_path'."
                rmdir "$MOUNT_POINT" 2>/dev/null
            fi
            echo ""
        done
    done < "$IP_LIST_FILE"

    echo "================================================="
    echo "[*] Script finished. Check the '$BASE_DIR' directory."
}


# --- Argument Parsing & Main Execution ---

# Set default BASE_DIR to the home dir of the user running sudo, or root's home.
# This ensures `~/NFS-Dump` works as the user expects.
if [ -n "$SUDO_USER" ]; then
    USER_HOME=$(getent passwd "$SUDO_USER" | cut -d: -f6)
else
    # If not using sudo, just use the current user's home.
    USER_HOME=$HOME
fi
BASE_DIR="$USER_HOME/NFS-Dump"

UNMOUNT_ACTION=false
IP_LIST_FILE=""

# Parse command-line arguments.
while [[ "$#" -gt 0 ]]; do
    case "$1" in
        -u|--unmount|unmount)
            UNMOUNT_ACTION=true
            shift
            ;;
        -d|--dir)
            if [ -n "$2" ]; then
                # Expand tilde ~ if user provides it at the beginning of the path.
                BASE_DIR="${2/#\~/$HOME}"
                shift 2
            else
                echo "[-] Error: -d/--dir requires a directory path argument."
                usage
            fi
            ;;
        -h|--help)
            usage
            ;;
        *)
            # Assume any other argument is the IP list file.
            if [ -z "$IP_LIST_FILE" ]; then
                IP_LIST_FILE="$1"
                shift
            else
                echo "[-] Error: Unknown argument or too many files: $1"
                usage
            fi
            ;;
    esac
done

# --- Final Execution ---

# Must be root to run at all.
if [ "$EUID" -ne 0 ]; then
  echo "[-] Error: This script must be run as root."
  exit 1
fi

# Route to the correct function based on parsed arguments.
if [ "$UNMOUNT_ACTION" = true ]; then
    unmount_all
else
    if [ -z "$IP_LIST_FILE" ]; then
        echo "[-] Error: No input file specified for mounting action."
        usage
    fi
    mount_all "$IP_LIST_FILE"
fi
