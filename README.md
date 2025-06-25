# walkmynfs 🚶‍♂️

A straightforward and effective Bash utility for NFS reconnaissance during internal penetration tests.

`walkmynfs` streamlines the tedious process of discovering and mounting network shares. It takes a list of target IPs, automatically enumerates all NFS exports, and mounts them into a clean, structured directory on your local machine. This allows you to efficiently browse for misconfigurations, sensitive files, and potential pivot points.

Designed for safety and efficiency, it mounts all shares in read-only mode to prevent accidental modification of target systems and includes a simple unmount option for easy cleanup.

## Features

-   **Auto-Discovery:** Scans a list of target IPs and finds all exported NFS shares.
-   **Auto-Mounting:** Mounts all discovered shares in read-only mode for safe recon.
-   **Clean Unmounting:** A simple `-u` flag detaches all shares and cleans up the local directories.
-   **Flexible:** Lets you specify a custom base directory with the `-d` flag.

## Installation & Usage

1.  **Clone the repo:**
    ```bash
    git clone [https://github.com/t3rminux/walkmynfs.git](https://github.com/t3rminux/walkmynfs.git)
    cd walkmynfs
    chmod +x walkmynfs.sh
    ```

2.  **Create your target list:**
    ```bash
    # ips.txt
    10.10.1.1
    10.10.1.2
    ```

3.  **Mount shares:**
    ```bash
    sudo ./walkmynfs.sh ips.txt
    ```

4.  **Unmount all shares:**
    ```bash
    sudo ./walkmynfs.sh -u
    ```

## Options

| Flag             | Description                                          |
| ---------------- | ---------------------------------------------------- |
| `-u`, `--unmount`  | Perform unmount and cleanup.                         |
| `-d`, `--dir <path>` | Specify a custom base directory (Default: `~/NFS-Dump`). |
| `-h`, `--help`     | Show the help message.                               |
