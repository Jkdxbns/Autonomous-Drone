# Autonomous-Drone

# Connecting to the Server

This guide provides instructions on how to connect to the remote server using Tailscale and a Remote Desktop Protocol (RDP) client.

---

## 1. Tailscale Setup

First, you need to connect your device to the server's private network using Tailscale.

1.  **Log into Tailscale**:
    * Open a web browser and navigate to the [Tailscale login page](https://login.tailscale.com).
    * Log in using the following shared credentials:
        * **Email**: `fypbarc@gmail.com`
        * **Password**: `Barc@123`

2.  **Install & Register**:
    * Download and install the Tailscale software for your operating system.
    * Follow the prompts to log in within the app and register your device to the network.

---

## 2. RDP Connection

Once your device is on the Tailscale network, you can connect to the server using any RDP client.

* **Open your RDP client** (e.g., Microsoft Remote Desktop, Remmina).
* Enter one of the server addresses:
    * **DNS Name**: `jetson.clouded-census.ts.net` (Recommended)
    * **Local IP**: `192.168.0.69:3390` (Use this only if you are on the same physical network)
* When prompted, use your personal credentials to log in:
    ```
    Username: <your_name>
    Password: <same_as_username>
    ```

---

## ⚠️ Important

* **Always log out from the server** when you are finished. Sessions do not close automatically.
* **Use server only for testing**.
