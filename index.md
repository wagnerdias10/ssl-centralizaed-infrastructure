---
# 🔒 Centralized SSL Infrastructure - Complete Implementation Guide
**© 2025 Wagner | Original Project: [SSL Centralized Infrastructure](https://github.com/wagnerdias10/ssl-centralizaed-infrastructure)**

---

> **📋 Document Information**  
> **Author:** Wagner Dias
> **Project:** SSL Centralized Infrastructure  
> **Repository:** https://github.com/wagnerdias10/ssl-centralizaed-infrastructure  
> **License:** © 2025 Wagner - Documentation protected by copyright  
> **Usage:** Allowed with mandatory attribution to original author


---

## 🎯 Scenario and Prerequisites

### 🌐 Infrastructure Overview

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                          example INTERNAL NETWORK TOPOLOGY                      │
│                                192.168.204.0/24                                 │
└─────────────────────────────────────────────────────────────────────────────────┘

┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│  Windows Server │    │   NGINX Proxy   │    │   Jenkins VM    │    │   Client PCs    │
│   DNS Server    │    │  Reverse Proxy  │    │   Backend App   │    │   End Users     │
│  192.168.204.1  │    │ 192.168.204.139 │    │ 192.168.204.137 │    │ 192.168.204.x   │
│                 │    │                 │    │                 │    │                 │
│ ┌─────────────┐ │    │ ┌─────────────┐ │    │ ┌─────────────┐ │    │ ┌─────────────┐ │
│ │ DNS Records │ │    │ │   SSL/TLS   │ │    │ │   Jenkins   │ │    │ │  Browsers   │ │
│ │*.example.local│ ◄──┤ │ Termination │ │    │ │  Port 8081  │ │    │ │   + Root CA │ │
│ │192.168.204  │ │    │ │   + Proxy   │ │ ◄──┤ │   HTTP      │ │ ◄──│ │  Installed  │ │
│ │   .139      │ │    │ │  Forwarding │ │    │ │             │ │    │ │             │ │
│ └─────────────┘ │    │ └─────────────┘ │    │ └─────────────┘ │    │ └─────────────┘ │
└─────────────────┘    └─────────────────┘    └─────────────────┘    └─────────────────┘
         │                        │                        │                        │
         │                        │                        │                        │
         └────────────────────────┼────────────────────────┼────────────────────────┘
                                  │                        │
                              HTTPS/443                HTTP/8081
                           (SSL Terminated)          (Internal Only)
```

### 🏗️ SSL Certificate Chain Architecture

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                           PKI CERTIFICATE HIERARCHY                             │
└─────────────────────────────────────────────────────────────────────────────────┘

                              ┌─────────────────┐
                              │   ROOT CA       │
                              │ example Root CA │
                              │   Internal      │
                              │ (Self-Signed)   │
                              │ Validity: 10y   │
                              └─────────┬───────┘
                                        │
                                   Signs & Issues
                                        │
                                        ▼
                              ┌─────────────────┐
                              │ INTERMEDIATE CA │
                              │example Intermediate  
                              │ CA Internal     │
                              │ (Signed by Root)│
                              │ Validity: 5y    │
                              │ pathlen:0       │
                              └─────────┬───────┘
                                        │
                                   Signs & Issues
                                        │
                                        ▼
                              ┌─────────────────┐
                              │ WILDCARD CERT   │
                              │   *.example.local    
                              │(Signed by Inter)│
                              │ Validity: 1y    │
                              │ SAN: Multiple   │
                              └─────────────────┘

Certificate Chain File (wildcard_chain.crt):
┌─────────────────────────────────────────────────────────────────┐
│ 1. Wildcard Certificate (*.example.local)                       │
│ 2. Intermediate CA Certificate                                  │
│ 3. Root CA Certificate                                          │
└─────────────────────────────────────────────────────────────────┘
```

### 🔄 Traffic Flow Diagram

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                              TRAFFIC FLOW                                       │
└─────────────────────────────────────────────────────────────────────────────────┘

Client Browser                NGINX Proxy               Jenkins Backend
     │                            │                           │
     │ 1. https://jenkins.example.local│                      │
     ├───────────────────────────►│                           │
     │                            │                           │
     │ 2. SSL Handshake           │                           │
     │    (Wildcard Cert)         │                           │
     │◄───────────────────────────┤                           │
     │                            │                           │
     │ 3. Encrypted HTTPS Request │                           │
     ├───────────────────────────►│                           │
     │                            │ 4. Decrypt & Forward      │
     │                            │    HTTP Request           │
     │                            ├──────────────────────────►│
     │                            │                           │
     │                            │ 5. HTTP Response          │
     │                            │◄──────────────────────────┤
     │ 6. Encrypted HTTPS Response│                           │
     │◄───────────────────────────┤                           │
     │                            │                           │

Headers Added by NGINX:
┌─────────────────────────────────────────────────────────────────┐
│ X-Real-IP: Client's actual IP                                   │
│ X-Forwarded-For: Client IP chain                                │
│ X-Forwarded-Proto: https                                        │
│ X-Forwarded-Host: jenkins.example.local                         │
│ Host: jenkins.example.local                                     │
└─────────────────────────────────────────────────────────────────┘
```

### 📋 Base Infrastructure

*   **Windows Server 2019:** Acts as our DNS server.
    *   **IP Address:** 192.168.204.1 (Example)
    *   **Service:** DNS enabled and configured.
*   **VMware ESXi (or similar):** Hypervisor to host our virtual machines.
*   **NGINX VM (Reverse Proxy):** Virtual machine that will centralize SSL and route traffic.
    *   **Operating System:** Ubuntu 24.04 LTS
    *   **IP Address:** 192.168.204.139 (Example)
    *   **Initial State:** RESTORED SNAPSHOT (to ensure a clean environment).
*   **Jenkins VM (Example Service):** Virtual machine that will host a web service (Jenkins) accessed via NGINX.
    *   **Operating System:** Ubuntu 24.04 LTS
    *   **IP Address:** 192.168.204.137 (Example)
    *   **Initial State:** RESTORED SNAPSHOT (to ensure a clean environment).

### 🌟 Main Objectives

*   **Centralized SSL on NGINX:** All HTTPS traffic will be managed by NGINX, simplifying certificate configuration for multiple services. 🔒
*   **Wildcard Certificate for `*.example.local`:** We'll use a wildcard certificate to cover all subdomains within our `example.local` domain (e.g., `jenkins.example.local`, `gitlab.example.local`). This avoids the need for one certificate per service. ✨
*   **Reverse Proxy for Multiple Services:** NGINX will act as a single entry point, directing requests to appropriate backend services. 🔄
*   **Own PKI Infrastructure:** We'll create our own Root and Intermediate Certificate Authority (CA) to issue internal certificates, ensuring total control and trust in our local environment. 🏛️
*   **Scalable Configuration:** The structure will be designed to facilitate adding new services with minimal effort. 📈

---

## 📝️ PART 1: Complete NGINX VM Configuration

### Step 1: Initial NGINX VM Preparation

#### 1.1. Connect to NGINX VM

*   **Where to Access:** Use a terminal (Linux/macOS) or PuTTY/WSL (Windows) to connect via SSH.
*   **Command Context:** `ssh` is the command for Secure Shell, an encrypted network protocol that allows secure remote access to a computer.
    ```bash
    # Connect to NGINX VM
    ssh user@192.168.204.139
    ```
    *   Replace `user` with the username configured on your Ubuntu VM.

#### 1.2. Update Operating System

*   **Command Context:**
    *   `sudo apt update`: Updates the list of available packages from repositories.
    *   `sudo apt upgrade -y`: Installs new versions of packages that are already installed.
    ```bash
    # Update package list
    sudo apt update

    # Upgrade all installed packages
    sudo apt upgrade -y
    ```

*   **Verification:**
    *   **Success:** The final message from `apt upgrade` should indicate that all packages were processed.
    *   **Error:** If there are errors, check your internet connection and disk space (`df -h`).

#### 1.3. Install Essential Tools

*   **Command Context:**
    *   `openssl`: Command-line tool for managing SSL/TLS certificates, keys, and PKI.
    *   `curl`: Tool for transferring data with URL syntax.
    *   `wget`: Utility for downloading files from the web.
    *   `nano`: Simple command-line text editor.
    *   `tree`: Displays directory contents in tree format.
    *   `htop`: Interactive process monitor.
    *   `net-tools`: Contains network utilities like `netstat`.
    *   `nginx`: The web server and reverse proxy we'll configure.
    ```bash
    # Install essential tools, including NGINX
    sudo apt install -y openssl curl wget nano tree htop net-tools nginx
    ```

*   **Verification:**
    ```bash
    # Check NGINX version
    nginx -v

    # Check NGINX service status
    sudo systemctl status nginx
    ```
    *   **Expected Output for `nginx -v`:** Something like `nginx version: nginx/1.24.0`.
    *   **Expected Output for `sudo systemctl status nginx`:** Status should be `active (running)`.

### Step 2: Create Complete Directory Structure

#### 2.1. Stop NGINX Temporarily

*   **Command Context:** `sudo systemctl stop nginx` sends a signal to the NGINX service to stop running.
    ```bash
    # Stop NGINX temporarily
    sudo systemctl stop nginx
    ```

*   **Verification:**
    ```bash
    # Check NGINX status
    sudo systemctl status nginx
    ```
    *   **Expected Output:** Status should be `inactive (dead)`.

#### 2.2. Create Directory Structure

*   **Command Context:**
    *   `sudo mkdir -p <path>`: Creates a directory and all necessary parent directories.
    *   `sudo chmod 700 <path>`: Sets directory permissions. `700` means only the owner (root) has full permissions.
    *   `sudo chown -R www-data:www-data <path>`: Changes directory owner and group recursively.

    ```bash
    # Create complete structure for PKI
    sudo mkdir -p /etc/ssl/private/ca/{newcerts,certs,crl}
    sudo chmod 700 /etc/ssl/private/ca

    # Create structure for NGINX
    sudo mkdir -p /etc/nginx/{ssl,sites-available,sites-enabled,conf.d}
    sudo chmod 700 /etc/nginx/ssl

    # Create directories for site-specific logs
    sudo mkdir -p /var/log/nginx/sites

    # Create directories for SSL management scripts and templates
    sudo mkdir -p /opt/ssl-management/{scripts,backups,templates}

    # Create cache directory for NGINX and set correct permissions
    sudo mkdir -p /var/cache/nginx/proxy
    sudo chown -R www-data:www-data /var/cache/nginx
    ```

*   **Verification:**
    ```bash
    # Check PKI structure created
    echo "PKI Structure:"
    tree /etc/ssl/private/ca

    # Check NGINX structure created
    echo -e "\nNGINX Structure:"
    tree /etc/nginx

    # Check SSL management structure created
    echo -e "\nSSL Management Structure:"
    tree /opt/ssl-management

    # Check cache directory permissions
    ls -ld /var/cache/nginx
    ```

### Step 3: Complete PKI Infrastructure Configuration

#### 3.1. Initialize CA Database

*   **Command Context:**
    *   `sudo touch index.txt`: Creates an empty file that the CA will use as a database.
    *   `sudo sh -c "echo 1000 > serial"`: Creates a `serial` file and initializes it with the number `1000`.
    *   `sudo sh -c "echo 1000 > crlnumber"`: Creates a `crlnumber` file and initializes it with `1000`.
    ```bash
    # Navigate to CA directory
    cd /etc/ssl/private/ca

    # Create CA control files
    sudo touch index.txt
    sudo sh -c "echo 1000 > serial"
    sudo sh -c "echo 1000 > crlnumber"
    ```

*   **Verification:**
    ```bash
    # Check created files
    ls -la /etc/ssl/private/ca/
    cat /etc/ssl/private/ca/serial
    cat /etc/ssl/private/ca/crlnumber
    ```
    *   **Expected Output:** `cat serial` and `cat crlnumber` should show `1000`.

#### 3.2. Create Root CA Configuration 

*   **Where to Access:** Create the file `/etc/ssl/private/ca/openssl_root.cnf`.
*   **File Context:** This file defines how the Root CA will operate. **IMPORTANT:** We include the `[ v3_intermediate_ca ]` section which is necessary to sign the Intermediate CA.
    ```bash
    sudo nano /etc/ssl/private/ca/openssl_root.cnf
    ```
    Paste the content below into the `nano` editor.

    ```ini
    # OpenSSL Configuration for Root CA
    # Centralized PKI Infrastructure - example Internal

    [ ca ]
    default_ca = CA_default

    [ CA_default ]
    # CA directories and files
    dir               = /etc/ssl/private/ca
    certs             = $dir/certs
    new_certs_dir     = $dir/newcerts
    database          = $dir/index.txt
    serial            = $dir/serial
    private_key       = $dir/rootCA.key
    certificate       = $dir/rootCA.crt
    crlnumber         = $dir/crlnumber
    crl               = $dir/crl.pem
    crl_extensions    = crl_ext

    # Validity settings
    default_days      = 3650
    default_crl_days  = 30
    default_md        = sha256

    # Policy settings
    preserve          = no
    policy            = policy_strict

    [ policy_strict ]
    countryName             = optional
    stateOrProvinceName     = optional
    organizationName        = optional
    organizationalUnitName  = optional
    commonName              = supplied
    emailAddress            = optional

    [ req ]
    default_bits        = 4096
    distinguished_name  = req_distinguished_name
    string_mask         = utf8only
    default_md          = sha256

    [ req_distinguished_name ]
    countryName                     = Country Name (2 letter code)
    countryName_default             = US
    stateOrProvinceName             = State or Province Name (full name)
    stateOrProvinceName_default     = California
    localityName                    = Locality Name (eg, city)
    localityName_default            = San Francisco
    organizationName                = Organization Name (eg, company)
    organizationName_default        = exampleInternal
    organizationalUnitName          = Organizational Unit Name (eg, section)
    organizationalUnitName_default  = IT
    commonName                      = Common Name (e.g. server FQDN or YOUR name)
    commonName_max                  = 64

    [ v3_ca ]
    subjectKeyIdentifier = hash
    authorityKeyIdentifier = keyid:always,issuer
    basicConstraints = critical, CA:true
    keyUsage = critical, digitalSignature, cRLSign, keyCertSign

    # CORRECTION APPLIED: Section needed to sign the Intermediate CA
    [ v3_intermediate_ca ]
    subjectKeyIdentifier = hash
    authorityKeyIdentifier = keyid:always,issuer
    basicConstraints = critical, CA:true, pathlen:0
    keyUsage = critical, digitalSignature, cRLSign, keyCertSign

    [ crl_ext ]
    authorityKeyIdentifier=keyid:always
    ```
    *   Press `Ctrl+X`, then `Y` and `Enter` to save and exit.

*   **Verification:**
    ```bash
    # Check file content
    cat /etc/ssl/private/ca/openssl_root.cnf
    ```

#### 3.3. Generate Root CA

*   **Command Context:** `openssl req -x509` is used to generate a self-signed certificate.
    ```bash
    # Navigate to CA directory
    cd /etc/ssl/private/ca

    # Generate Root CA private key and certificate
    sudo openssl req -x509 -new -nodes -newkey rsa:4096 -sha256 -days 3650 \
        -keyout rootCA.key \
        -out rootCA.crt \
        -config /etc/ssl/private/ca/openssl_root.cnf \
        -extensions v3_ca \
        -subj "/C=US/ST=California/L=San Francisco/O=exampleInternal/OU=IT/CN=example Root CA Internal"

    # Set correct permissions
    sudo chmod 600 rootCA.key
    sudo chmod 644 rootCA.crt
    ```

*   **Verification:**
    ```bash
    # Check file existence
    ls -la /etc/ssl/private/ca/rootCA.key
    ls -la /etc/ssl/private/ca/rootCA.crt

    # Check certificate content
    sudo openssl x509 -in rootCA.crt -text -noout | head -20

    # Check certificate validity
    sudo openssl x509 -in rootCA.crt -noout -dates
    ```

#### 3.4. Create Intermediate CA Configuration

*   **Where to Access:** Create the file `/etc/ssl/private/ca/openssl_intermediate.cnf`.
    ```bash
    sudo nano /etc/ssl/private/ca/openssl_intermediate.cnf
    ```
    Paste the content below into the `nano` editor.

    ```ini
    # OpenSSL Configuration for Intermediate CA

    [ ca ]
    default_ca = CA_default

    [ CA_default ]
    dir               = /etc/ssl/private/ca
    certs             = $dir/certs
    new_certs_dir     = $dir/newcerts
    database          = $dir/index.txt
    serial            = $dir/serial
    private_key       = $dir/intermediateCA.key
    certificate       = $dir/intermediateCA.crt
    crlnumber         = $dir/crlnumber
    crl               = $dir/intermediate_crl.pem
    crl_extensions    = crl_ext

    default_days      = 1825
    default_crl_days  = 30
    default_md        = sha256

    preserve          = no
    policy            = policy_strict

    [ policy_strict ]
    countryName             = optional
    stateOrProvinceName     = optional
    organizationName        = optional
    organizationalUnitName  = optional
    commonName              = supplied
    emailAddress            = optional

    [ req ]
    default_bits        = 4096
    distinguished_name  = req_distinguished_name
    string_mask         = utf8only
    default_md          = sha256

    [ req_distinguished_name ]
    countryName                     = Country Name (2 letter code)
    countryName_default             = US
    stateOrProvinceName             = State or Province Name (full name)
    stateOrProvinceName_default     = California
    localityName                    = Locality Name (eg, city)
    localityName_default            = San Francisco
    organizationName                = Organization Name (eg, company)
    organizationName_default        = exampleInternal
    organizationalUnitName          = Organizational Unit Name (eg, section)
    organizationalUnitName_default  = IT
    commonName                      = Common Name (e.g. server FQDN or YOUR name)
    commonName_max                  = 64

    [ v3_intermediate_ca ]
    subjectKeyIdentifier = hash
    authorityKeyIdentifier = keyid:always,issuer
    basicConstraints = critical, CA:true, pathlen:0
    keyUsage = critical, digitalSignature, cRLSign, keyCertSign

    [ v3_wildcard_cert ]
    subjectKeyIdentifier = hash
    authorityKeyIdentifier = keyid:always,issuer
    basicConstraints = CA:FALSE
    keyUsage = digitalSignature, nonRepudiation, keyEncipherment, dataEncipherment
    extendedKeyUsage = serverAuth
    subjectAltName = @wildcard_alt_names

    [ wildcard_alt_names ]
    DNS.1 = *.example.local
    DNS.2 = example.local
    DNS.3 = nginx.example.local
    DNS.4 = jenkins.example.local
    DNS.5 = gitlab.example.local
    DNS.6 = rancher.example.local
    DNS.7 = monitoring.example.local
    DNS.8 = portainer.example.local
    IP.1 = 192.168.204.139

    [ crl_ext ]
    authorityKeyIdentifier=keyid:always
    ```
    *   Press `Ctrl+X`, then `Y` and `Enter` to save and exit.

#### 3.5. Generate Intermediate CA 

*   **Command Context:** Now that `openssl_root.cnf` contains the `[ v3_intermediate_ca ]` section, the command will work correctly.
    ```bash
    # Navigate to CA directory
    cd /etc/ssl/private/ca

    # Generate Intermediate CA private key and CSR
    sudo openssl req -new -nodes -newkey rsa:4096 -sha256 \
        -keyout intermediateCA.key \
        -out intermediateCA.csr \
        -config /etc/ssl/private/ca/openssl_intermediate.cnf \
        -subj "/C=US/ST=California/L=San Francisco/O=exampleInternal/OU=IT/CN=example Intermediate CA Internal"

    # Sign Intermediate CA CSR with Root CA
    sudo openssl ca -batch \
        -in intermediateCA.csr \
        -out intermediateCA.crt \
        -days 1825 \
        -config /etc/ssl/private/ca/openssl_root.cnf \
        -extensions v3_intermediate_ca

    # Set correct permissions
    sudo chmod 600 intermediateCA.key
    sudo chmod 644 intermediateCA.crt
    ```

*   **Verification:**
    ```bash
    # Check file existence
    ls -la /etc/ssl/private/ca/intermediateCA.key
    ls -la /etc/ssl/private/ca/intermediateCA.crt

    # Check Intermediate CA certificate content
    sudo openssl x509 -in intermediateCA.crt -text -noout | grep -A5 "Subject:"

    # Verify Intermediate CA was signed by Root CA
    sudo openssl x509 -in intermediateCA.crt -noout -issuer -subject
    sudo openssl x509 -in rootCA.crt -noout -subject
    ```

### Step 4: Create Wildcard Certificate

#### 4.1. Wildcard Certificate Configuration

*   **Where to Access:** Create the file `/etc/nginx/ssl/wildcard_csr.cnf`.
    ```bash
    sudo nano /etc/nginx/ssl/wildcard_csr.cnf
    ```
    Paste the content below into the `nano` editor.

    ```ini
    [ req ]
    default_bits        = 4096
    distinguished_name  = req_distinguished_name
    string_mask         = utf8only
    default_md          = sha256
    req_extensions      = v3_req

    [ req_distinguished_name ]
    countryName                     = Country Name (2 letter code)
    countryName_default             = US
    stateOrProvinceName             = State or Province Name (full name)
    stateOrProvinceName_default     = California
    localityName                    = Locality Name (eg, city)
    localityName_default            = San Francisco
    organizationName                = Organization Name (eg, company)
    organizationName_default        = exampleInternal
    organizationalUnitName          = Organizational Unit Name (eg, section)
    organizationalUnitName_default  = IT
    commonName                      = Common Name (e.g. server FQDN or YOUR name)
    commonName_max                  = 64
    commonName_default              = *.example.local

    [ v3_req ]
    subjectAltName = @alt_names

    [ alt_names ]
    DNS.1 = *.example.local
    DNS.2 = example.local
    DNS.3 = nginx.example.local
    DNS.4 = jenkins.example.local
    DNS.5 = gitlab.example.local
    DNS.6 = rancher.example.local
    DNS.7 = monitoring.example.local
    DNS.8 = portainer.example.local
    IP.1 = 192.168.204.139
    ```
    *   Press `Ctrl+X`, then `Y` and `Enter` to save and exit.

#### 4.2. Generate Wildcard Certificate

*   **Command Context:** We'll generate the private key and CSR for the wildcard certificate, then sign it with the Intermediate CA.
    ```bash
    # Navigate to NGINX SSL directory
    cd /etc/nginx/ssl

    # Generate wildcard certificate private key and CSR
    sudo openssl req -new -nodes -newkey rsa:4096 -sha256 \
        -keyout wildcard.example.local.key \
        -out wildcard.example.local.csr \
        -config /etc/nginx/ssl/wildcard_csr.cnf \
        -subj "/C=US/ST=California/L=San Francisco/O=exampleInternal/OU=IT/CN=*.example.local"

    # Sign CSR with Intermediate CA
    sudo openssl ca -batch \
        -in wildcard.example.local.csr \
        -out wildcard.example.local.crt \
        -days 365 \
        -config /etc/ssl/private/ca/openssl_intermediate.cnf \
        -extensions v3_wildcard_cert

    # Set correct permissions
    sudo chmod 600 wildcard.example.local.key
    sudo chmod 644 wildcard.example.local.crt
    ```

*   **Verification:**
    ```bash
    # Check file existence
    ls -la /etc/nginx/ssl/wildcard.example.local.key
    ls -la /etc/nginx/ssl/wildcard.example.local.crt

    # Check Subject Alternative Names (SANs)
    sudo openssl x509 -in wildcard.example.local.crt -text -noout | grep -A10 "Subject Alternative Name"
    ```

#### 4.3. Create Certificate Chain (Full Chain)

**What is Full Chain?** ⛓️  
The "certificate chain" is a file that contains the server certificate, followed by the CA certificates that signed it, in order.

*   **Command Context:** We concatenate the certificates in the correct order.
    ```bash
    # Copy CA certificates to NGINX SSL directory
    sudo cp /etc/ssl/private/ca/intermediateCA.crt /etc/nginx/ssl/
    sudo cp /etc/ssl/private/ca/rootCA.crt /etc/nginx/ssl/

    # Create full chain file
    sudo cat wildcard.example.local.crt intermediateCA.crt rootCA.crt > wildcard_chain.crt
    ```

*   **Verification:**
    ```bash
    # Check chain file existence
    ls -la /etc/nginx/ssl/wildcard_chain.crt

    # Check number of certificates in chain (should be 3)
    sudo openssl crl2pkcs7 -nocrl -certfile wildcard_chain.crt | openssl pkcs7 -print_certs -text -noout | grep "Subject:"

    # Verify chain validity
    sudo openssl verify -CAfile /etc/nginx/ssl/rootCA.crt \
        -untrusted /etc/nginx/ssl/intermediateCA.crt \
        /etc/nginx/ssl/wildcard.example.local.crt
    ```
    *   **Expected Output:** `/etc/nginx/ssl/wildcard.example.local.crt: OK`.

### Step 5: Complete NGINX Configuration

#### 5.1. Generate DH Parameters

*   **Command Context:** Diffie-Hellman parameters are used to strengthen the security of SSL/TLS key exchanges.
    ```bash
    # Navigate to NGINX SSL directory
    cd /etc/nginx/ssl

    # Generate Diffie-Hellman parameters (may take a few minutes)
    sudo openssl dhparam -out /etc/nginx/ssl/dhparam.pem 2048

    # Set correct permissions
    sudo chmod 644 /etc/nginx/ssl/dhparam.pem
    ```

*   **Verification:**
    ```bash
    # Check file existence
    ls -la /etc/nginx/ssl/dhparam.pem
    ```

#### 5.2. Backup and Main NGINX Configuration 

*   **File Context:** This file defines NGINX global configurations. **CORRECTION APPLIED:** The `worker_rlimit_nofile` directive has been moved to the main context (outside the `events` block).
    ```bash
    # Backup original configuration
    sudo cp /etc/nginx/nginx.conf /etc/nginx/nginx.conf.backup

    # Create new optimized configuration
    sudo nano /etc/nginx/nginx.conf
    ```
    Paste the content below into the `nano` editor.

    ```nginx
    # Main NGINX Configuration - Centralized SSL Reverse Proxy
    # example Internal Infrastructure

    user www-data;
    worker_processes auto;
    # CORRECTION APPLIED: worker_rlimit_nofile in main context
    worker_rlimit_nofile 8192;
    pid /run/nginx.pid;
    include /etc/nginx/modules-enabled/*.conf;

    events {
        worker_connections 2048;
        use epoll;
        multi_accept on;
    }

    http {
        ##
        # Basic Settings
        ##
        sendfile on;
        tcp_nopush on;
        tcp_nodelay on;
        keepalive_timeout 65;
        keepalive_requests 1000;
        types_hash_max_size 2048;
        server_tokens off;
        client_max_body_size 100m;
        client_body_timeout 60;
        client_header_timeout 60;
        send_timeout 60;

        # Buffer sizes
        client_body_buffer_size 128k;
        client_header_buffer_size 1k;
        large_client_header_buffers 4 4k;
        output_buffers 1 32k;
        postpone_output 1460;

        ##
        # MIME Types
        ##
        include /etc/nginx/mime.types;
        default_type application/octet-stream;

        ##
        # Global SSL Settings
        ##
        ssl_protocols TLSv1.2 TLSv1.3;
        ssl_ciphers ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305:DHE-RSA-AES128-GCM-SHA256:DHE-RSA-AES256-GCM-SHA384;
        ssl_prefer_server_ciphers off;
        ssl_session_cache shared:SSL:50m;
        ssl_session_timeout 1d;
        ssl_session_tickets off;

        # DH Settings
        ssl_dhparam /etc/nginx/ssl/dhparam.pem;

        ##
        # Global Security Headers
        ##
        add_header X-Frame-Options DENY always;
        add_header X-Content-Type-Options nosniff always;
        add_header X-XSS-Protection "1; mode=block" always;
        add_header Referrer-Policy "strict-origin-when-cross-origin" always;
        add_header Strict-Transport-Security "max-age=31536000; includeSubDomains; preload" always;

        ##
        # Logging Settings
        ##
        log_format main '$remote_addr - $remote_user [$time_local] "$request" '
                        '$status $body_bytes_sent "$http_referer" '
                        '"$http_user_agent" "$http_x_forwarded_for" '
                        'rt=$request_time uct="$upstream_connect_time" '
                        'uht="$upstream_header_time" urt="$upstream_response_time"';

        access_log /var/log/nginx/access.log main;
        error_log /var/log/nginx/error.log warn;

        ##
        # Gzip Settings
        ##
        gzip on;
        gzip_vary on;
        gzip_proxied any;
        gzip_comp_level 6;
        gzip_min_length 1000;
        gzip_types
            application/atom+xml
            application/geo+json
            application/javascript
            application/x-javascript
            application/json
            application/ld+json
            application/manifest+json
            application/rdf+xml
            application/rss+xml
            application/xhtml+xml
            application/xml
            font/eot
            font/otf
            font/ttf
            image/svg+xml
            text/css
            text/javascript
            text/plain
            text/xml;

        ##
        # Proxy Settings
        ##
        proxy_buffering on;
        proxy_buffer_size 128k;
        proxy_buffers 4 256k;
        proxy_busy_buffers_size 256k;
        proxy_temp_file_write_size 256k;
        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
        proxy_http_version 1.1;

        # Default proxy headers
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_set_header X-Forwarded-Port $server_port;
        proxy_set_header X-Forwarded-Host $host;

        ##
        # Rate Limiting
        ##
        limit_req_zone $binary_remote_addr zone=general:10m rate=10r/s;
        limit_req_zone $binary_remote_addr zone=login:10m rate=1r/s;
        limit_conn_zone $binary_remote_addr zone=addr:10m;

        ##
        # Cache Settings
        ##
        proxy_cache_path /var/cache/nginx/proxy levels=1:2 keys_zone=proxy_cache:10m max_size=1g inactive=60m use_temp_path=off;
        proxy_cache_key "$scheme$request_method$host$request_uri";

        ##
        # Default server (catches unmapped requests)
        ##
        server {
            listen 80 default_server;
            listen [::]:80 default_server;
            listen 443 ssl default_server;
            listen [::]:443 ssl default_server;

            ssl_certificate /etc/nginx/ssl/wildcard_chain.crt;
            ssl_certificate_key /etc/nginx/ssl/wildcard.example.local.key;

            server_name _;
            
            return 444;
        }

        ##
        # Status and monitoring server
        ##
        server {
            listen 127.0.0.1:8080;
            server_name localhost;

            location /nginx_status {
                stub_status on;
                access_log off;
                allow 127.0.0.1;
                deny all;
            }

            location /health {
                access_log off;
                return 200 "healthy\n";
                add_header Content-Type text/plain;
            }
        }

        ##
        # Include site configurations
        ##
        include /etc/nginx/sites-enabled/*;
        include /etc/nginx/conf.d/*.conf;
    }
    ```
    *   Press `Ctrl+X`, then `Y` and `Enter` to save and exit.

#### 5.3. WebSocket Configuration

*   **Where to Access:** Create the file `/etc/nginx/conf.d/websocket.conf`.
    ```bash
    sudo nano /etc/nginx/conf.d/websocket.conf
    ```
    Paste the content below into the `nano` editor.

    ```nginx
    # WebSocket support configuration
    map $http_upgrade $connection_upgrade {
        default upgrade;
        '' close;
    }

    # Protocol detection configuration
    map $http_x_forwarded_proto $proxy_x_forwarded_proto {
        default $http_x_forwarded_proto;
        '' $scheme;
    }

    # Forwarded port configuration
    map $http_x_forwarded_port $proxy_x_forwarded_port {
        default $http_x_forwarded_port;
        '' $server_port;
    }
    ```
    *   Press `Ctrl+X`, then `Y` and `Enter` to save and exit.

#### 5.4. Test and Start NGINX 

*   **CORRECTION APPLIED:** We disable the default NGINX site to avoid conflicts with our `default_server`.
    ```bash
    # Disable default NGINX site to avoid conflicts
    sudo unlink /etc/nginx/sites-enabled/default

    # Test NGINX configuration
    echo "Testing NGINX configuration syntax..."
    sudo nginx -t

    # If test is successful, start NGINX
    echo "Starting NGINX service..."
    sudo systemctl start nginx

    # Enable NGINX to start automatically
    echo "Enabling NGINX to start automatically..."
    sudo systemctl enable nginx

    # Check NGINX status
    echo "Checking NGINX status..."
    sudo systemctl status nginx
    ```

*   **Verification:**
    *   **Success for `sudo nginx -t`:** Both messages `syntax is ok` and `test is successful` should appear.
    *   **Success for `sudo systemctl status nginx`:** Status should be `active (running)`.

---

## 📝️ PART 2: Complete Jenkins VM Configuration

### Step 6: Jenkins VM Preparation

#### 6.1. Connect to Jenkins VM

*   **Where to Access:** Use a terminal to connect via SSH.
    ```bash
    # Connect to Jenkins VM
    ssh user@192.168.204.137
    ```

#### 6.2. Update Operating System

    ```bash
    # Update package list
    sudo apt update

    # Upgrade all installed packages
    sudo apt upgrade -y
    ```

#### 6.3. Install Java

*   **Command Context:** Jenkins is a Java application, so we need to install a JDK.
    ```bash
    # Install Java (OpenJDK 17)
    sudo apt install -y openjdk-17-jdk
    ```

*   **Verification:**
    ```bash
    # Check Java version
    java -version
    ```
    *   **Expected Output:** Should show `openjdk version "17.0.x"`.

### Step 7: Jenkins Installation

*   **Command Context:** Installing Jenkins using the official repository.
    ```bash
    # Add Jenkins GPG key
    curl -fsSL https://pkg.jenkins.io/debian/jenkins.io-2023.key | sudo tee \
      /usr/share/keyrings/jenkins-keyring.asc > /dev/null

    # Add Jenkins repository
    echo deb [signed-by=/usr/share/keyrings/jenkins-keyring.asc] \
      https://pkg.jenkins.io/debian binary/ | sudo tee \
      /etc/apt/sources.list.d/jenkins.list > /dev/null

    # Update repositories
    sudo apt update

    # Install Jenkins
    sudo apt install -y jenkins
    ```

*   **Verification:**
    ```bash
    # Check Jenkins status
    sudo systemctl status jenkins
    ```
    *   **Expected Output:** Status should be `active (running)`.

### Step 8: Configure Jenkins for Reverse Proxy

#### 8.1. Configure Port and Parameters

*   **Where to Access:** Edit the file `/etc/default/jenkins`.
    ```bash
    # Edit Jenkins configuration
    sudo nano /etc/default/jenkins
    ```
    Paste the content below (replacing existing content) into the `nano` editor.

    ```bash
    # Jenkins Configuration for Reverse Proxy
    # HTTP Port
    HTTP_PORT=8081

    # Disable HTTPS (will be handled by NGINX)
    HTTPS_PORT=-1

    # Jenkins arguments
    JENKINS_ARGS="--webroot=/var/cache/$NAME/war --httpPort=$HTTP_PORT"

    # JVM settings
    JAVA_ARGS="-Djava.awt.headless=true"
    JAVA_ARGS="$JAVA_ARGS -Xmx1024m"
    JAVA_ARGS="$JAVA_ARGS -Dhudson.security.csrf.DefaultCrumbIssuer.EXCLUDE_SESSION_ID=true"
    JAVA_ARGS="$JAVA_ARGS -Djenkins.install.runSetupWizard=false"

    # Jenkins user
    JENKINS_USER="jenkins"
    JENKINS_GROUP="jenkins"

    # Jenkins home directory
    JENKINS_HOME="/var/lib/jenkins"

    # Jenkins log
    JENKINS_LOG="/var/log/jenkins/$NAME.log"

    # Network settings for reverse proxy
    JENKINS_ARGS="$JENKINS_ARGS --httpListenAddress=0.0.0.0"

    # Additional proxy settings
    JAVA_ARGS="$JAVA_ARGS -Dhudson.TcpSlaveAgentListener.hostName=jenkins.example.local"
    JAVA_ARGS="$JAVA_ARGS -Dhudson.TcpSlaveAgentListener.port=50000"
    ```
    *   Press `Ctrl+X`, then `Y` and `Enter` to save and exit.

#### 8.2. Systemd Configuration

*   **Where to Access:** Create the file `/etc/systemd/system/jenkins.service.d/override.conf`.
    ```bash
    # Create directory for systemd overrides
    sudo mkdir -p /etc/systemd/system/jenkins.service.d/
    
    # Create override file
    sudo nano /etc/systemd/system/jenkins.service.d/override.conf
    ```
    Paste the content below into the `nano` editor.

    ```ini
    [Service]
    Environment="JENKINS_PORT=8081"
    Environment="JENKINS_OPTS=--httpPort=8081 --httpListenAddress=0.0.0.0"
    ```
    *   Press `Ctrl+X`, then `Y` and `Enter` to save and exit.

#### 8.3. Apply Configurations

*   **Command Context:** We reload systemd and restart Jenkins.
    ```bash
    # Reload systemd configurations
    echo "Reloading systemd configurations..."
    sudo systemctl daemon-reload

    # Stop Jenkins
    echo "Stopping Jenkins service..."
    sudo systemctl stop jenkins

    # Start Jenkins again
    echo "Starting Jenkins service..."
    sudo systemctl start jenkins

    # Wait for initialization
    echo "Waiting 30 seconds for Jenkins to initialize..."
    sleep 30

    # Check if it's running on port 8081
    echo "Checking if Jenkins is listening on port 8081..."
    sudo netstat -tlnp | grep :8081
    ```

*   **Verification:**
    ```bash
    # Check Jenkins status
    sudo systemctl status jenkins

    # Test local access
    curl -I http://localhost:8081

    # Test external access
    curl -I http://192.168.204.137:8081
    ```
    *   **Expected Output:** Both `curl -I` commands should return HTTP status `200 OK` or `302 Found`.

---

## 📝️ PART 3: DNS Configuration on Windows Server

### Step 9: Configure DNS Records

#### 9.1. Access DNS Manager

*   **Where to Access:** On your Windows Server 2019.
    1.  Open **Server Manager**.
    2.  Click on **Tools**.
    3.  Select **DNS**.
    4.  Expand **Forward Lookup Zones**.

#### 9.2. Create/Verify `example.local` Zone

If the `example.local` zone doesn't exist:
1.  Right-click on **Forward Lookup Zones**.
2.  Select **New Zone...**.
3.  Select **Primary zone** and click **Next**.
4.  Enter `example.local` as **Zone name**.
5.  Follow instructions to complete.

#### 9.3. Add DNS Records

*   **Where
*   to Access:** Right-click on the `example.local` zone and select **New Host (A or AAAA)...**.

<table class="data-table">
  <thead>
    <tr>
      <th scope="col">Host Name</th>
      <th scope="col">Type</th>
      <th scope="col">IP Address</th>
      <th scope="col">Description</th>
    </tr>
  </thead>
  <tbody>
    <tr>
      <td>nginx</td>
      <td>A</td>
      <td>192.168.204.139</td>
      <td>NGINX Reverse Proxy Server</td>
    </tr>
    <tr>
      <td>jenkins</td>
      <td>A</td>
      <td>192.168.204.139</td>
      <td>Jenkins via proxy</td>
    </tr>
    <tr>
      <td>gitlab</td>
      <td>A</td>
      <td>192.168.204.139</td>
      <td>GitLab via proxy</td>
    </tr>
    <tr>
      <td>*</td>
      <td>A</td>
      <td>192.168.204.139</td>
      <td>Wildcard for new services</td>
    </tr>
  </tbody>
</table>

*   **For the `*` (wildcard) record:** Leave the **Host name (optional)** field empty or type `*`.

#### 9.4. Verify DNS

*   **Where to Access:** On any client machine in your network.
    ```cmd
    # On Windows Server or a client machine
    nslookup nginx.example.local
    nslookup jenkins.example.local
    nslookup anything.example.local
    ```

*   **Verification:**
    *   **Success:** For each `nslookup` command, the output should show IP address `192.168.204.139`.
    *   **Error:** If `nslookup` returns `Non-existent domain`, check DNS records and if the client is using Windows Server as DNS.

---

## 🔄 PART 4: Reverse Proxy Configuration for Jenkins

### Step 10: Create Jenkins Configuration in NGINX

#### 10.1. Return to NGINX VM

*   **Where to Access:** Connect again to your NGINX VM.
    ```bash
    # Connect to NGINX VM
    ssh user@192.168.204.139
    ```

#### 10.2. Create Jenkins Configuration

*   **Where to Access:** Create the file `/etc/nginx/sites-available/jenkins.example.local.conf`.
    ```bash
    # Create specific configuration for Jenkins
    sudo nano /etc/nginx/sites-available/jenkins.example.local.conf
    ```
    Paste the content below into the `nano` editor.

    ```nginx
    # NGINX Configuration for jenkins.example.local
    # Created for centralized SSL infrastructure

    upstream jenkins_backend {
        server 192.168.204.137:8081 max_fails=3 fail_timeout=30s;
        keepalive 32;
    }

    # HTTP to HTTPS redirect
    server {
        listen 80;
        listen [::]:80;
        server_name jenkins.example.local;

        # Rate limiting
        limit_req zone=general burst=20 nodelay;
        limit_conn addr 10;

        # Site-specific logs
        access_log /var/log/nginx/sites/jenkins.access.log main;
        error_log /var/log/nginx/sites/jenkins.error.log;

        return 301 https://$server_name$request_uri;
    }

    # HTTPS server
    server {
        listen 443 ssl http2;
        listen [::]:443 ssl http2;
        server_name jenkins.example.local;

        # SSL certificates
        ssl_certificate /etc/nginx/ssl/wildcard_chain.crt;
        ssl_certificate_key /etc/nginx/ssl/wildcard.example.local.key;

        # Rate limiting
        limit_req zone=general burst=20 nodelay;
        limit_conn addr 10;

        # Logs
        access_log /var/log/nginx/sites/jenkins.access.log main;
        error_log /var/log/nginx/sites/jenkins.error.log;

        # Jenkins-specific settings
        client_max_body_size 100m;
        proxy_read_timeout 600;
        proxy_connect_timeout 600;
        proxy_send_timeout 600;

        # Additional security headers
        add_header X-Service-Name "jenkins" always;

        location / {
            proxy_pass http://jenkins_backend;
            
            # Basic proxy headers
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
            proxy_set_header X-Forwarded-Port $server_port;
            proxy_set_header X-Forwarded-Host $host;

            # Jenkins-specific headers
            proxy_set_header X-Forwarded-Ssl on;
            proxy_redirect http:// https://;

            # WebSocket support for Jenkins
            proxy_http_version 1.1;
            proxy_set_header Upgrade $http_upgrade;
            proxy_set_header Connection $connection_upgrade;
        }

        # Health check endpoint
        location /health {
            access_log off;
            proxy_pass http://jenkins_backend;
            proxy_connect_timeout 5s;
            proxy_read_timeout 5s;
        }

        # Static files (cache)
        location ~* \.(jpg|jpeg|png|gif|ico|css|js|pdf|txt|woff|woff2)$ {
            proxy_pass http://jenkins_backend;
            proxy_cache proxy_cache;
            proxy_cache_valid 200 1h;
            expires 1h;
            add_header Cache-Control "public, immutable";
        }
    }
    ```
    *   Press `Ctrl+X`, then `Y` and `Enter` to save and exit.

#### 10.3. Enable Site and Test

*   **Command Context:** We create a symbolic link to enable the site and reload NGINX.
    ```bash
    # Create logs directory if it doesn't exist
    sudo mkdir -p /var/log/nginx/sites

    # Enable the site by creating a symbolic link
    echo "Enabling Jenkins configuration in NGINX..."
    sudo ln -s /etc/nginx/sites-available/jenkins.example.local.conf /etc/nginx/sites-enabled/

    # Test NGINX configuration
    echo "Testing NGINX configuration syntax..."
    sudo nginx -t

    # If test is OK, reload NGINX
    echo "Reloading NGINX..."
    sudo systemctl reload nginx

    # Check enabled sites
    echo "Checking enabled sites in NGINX:"
    ls -la /etc/nginx/sites-enabled/

    # Check NGINX status
    echo "Checking NGINX status..."
    sudo systemctl status nginx
    ```

*   **Verification:**
    *   **Success for `sudo nginx -t`:** Should return `syntax is ok` and `test is successful`.
    *   **Success for `ls -la`:** Should show the symbolic link `jenkins.example.local.conf`.
    *   **Success for `sudo systemctl status nginx`:** Status should be `active (running)`.

### Step 11: Test Connectivity

*   **Where to Access:** On the NGINX VM.
    ```bash
    # Test connectivity from NGINX VM to Jenkins VM
    echo "Testing connectivity NGINX -> Jenkins (192.168.204.137:8081)..."
    if timeout 5 bash -c "</dev/tcp/192.168.204.137/8081" && echo "Jenkins accessible" || echo "Jenkins NOT accessible"; then
        echo "TCP connectivity OK."
    else
        echo "ERROR: TCP connectivity failed."
    fi

    # Test with curl directly to Jenkins backend
    echo "Testing HTTP response from Jenkins backend..."
    curl -I http://192.168.204.137:8081
    ```

*   **Verification:**
    *   **Success:** Should return `Jenkins accessible` and HTTP status `200 OK` or `302 Found`.
    *   **Error:** If it fails, check if Jenkins is running and if there's no firewall blocking.

---

## 🔒 PART 5: Client Trust Configuration

### Step 12: Distribute Root CA

#### 12.1. Export Root CA

*   **Where to Access:** On the NGINX VM.
    ```bash
    # On NGINX VM, display Root CA certificate content
    sudo cat /etc/ssl/private/ca/rootCA.crt
    ```
    *   **Action:** Copy all displayed content, including the `-----BEGIN CERTIFICATE-----` and `-----END CERTIFICATE-----` lines.

#### 12.2. Install Root CA on Windows

*   **Method via Graphical Interface:**
    1.  **Save Content:** Paste the content into a file and save as `example_RootCA.crt`.
    2.  **Install Certificate:** Right-click the file and select **Install Certificate**.
    3.  **Location:** Select **Local Machine** and click **Next**.
    4.  **Store:** Select **Place all certificates in the following store**.
    5.  Click **Browse** and select **Trusted Root Certification Authorities**.
    6.  Click **OK**, then **Next** and **Finish**.

*   **Method via PowerShell (as Administrator):**
    ```powershell
    # Import certificate to Trusted Root store
    Import-Certificate -FilePath "C:\temp\example_RootCA.crt" -CertStoreLocation Cert:\LocalMachine\Root

    # Verify installation
    Get-ChildItem -Path Cert:\LocalMachine\Root | Where-Object {$_.Subject -like "*example Root CA Internal*"}
    ```

#### 12.3. Install Root CA on Ubuntu/Linux

*   **Where to Access:** On an Ubuntu/Linux client machine.
    ```bash
    # Copy certificate to CA certificates directory
    sudo cp example_RootCA.crt /usr/local/share/ca-certificates/example-root-ca.crt

    # Update system certificate cache
    sudo update-ca-certificates

    # Verify certificate was added
    ls /etc/ssl/certs/ | grep example-root-ca
    ```

#### 12.4. Restart Browsers

**IMPORTANT:** After installing the Root CA, you must **completely close and reopen all browsers** so they load the new trusted certificate store. 🔄

---

## ✅ PART 6: Testing and Validation

### Step 13: Complete Tests

#### 13.1. DNS Resolution Test

*   **Where to Access:** On any client machine in your network.
    ```bash
    # Test DNS resolution
    nslookup jenkins.example.local
    nslookup nginx.example.local
    ```

*   **Verification:**
    *   **Success:** Both commands should resolve to IP `192.168.204.139`.

#### 13.2. Connectivity Test

*   **Where to Access:** On the NGINX VM and a client machine.
    ```bash
    # On NGINX VM: Test direct connectivity with Jenkins
    echo "Testing connectivity NGINX -> Jenkins backend..."
    curl -I http://192.168.204.137:8081

    # On a client machine: Test HTTPS access via NGINX
    echo "Testing HTTPS access via NGINX..."
    curl -k https://jenkins.example.local
    curl -k https://nginx.example.local
    ```

*   **Verification:**
    *   **Success:** Should return status `200 OK` or `302 Found` for all tests.

#### 13.3. Browser Test

*   **Where to Access:** On a client machine with Root CA installed.
    1.  Open your web browser.
    2.  Access `https://jenkins.example.local`.
    3.  **Check Certificate:** The padlock should be **green and closed**.
    4.  Verify that the Jenkins login page loads correctly.

*   **Verification:**
    *   **Success:** Green padlock, valid certificate, Jenkins page loaded.
    *   **Error:** If there are certificate issues, review Root CA installation.

### Step 14: Final Jenkins Configuration

#### 14.1. Access Jenkins via HTTPS

*   **Where to Access:** In your browser, access `https://jenkins.example.local`.
    1.  **On Jenkins VM**, get the initial password:
        ```bash
        sudo cat /var/lib/jenkins/secrets/initialAdminPassword
        ```
    2.  Copy the password and paste it in the browser.
    3.  Follow the Jenkins setup wizard.

#### 14.2. Configure Jenkins URL

*   **Where to Access:** In the Jenkins dashboard.
    1.  Go to **Manage Jenkins**.
    2.  Click on **Configure System**.
    3.  In the **Jenkins Location** section, change **Jenkins URL** to `https://jenkins.example.local/`.
    4.  Click **Save**.

---

## ⚙️ PART 7: Automation and Monitoring Scripts

### Step 15: Useful Scripts

#### 15.1. Infrastructure Status Script

*   **Where to Access:** On the NGINX VM. Create the file `/opt/ssl-management/scripts/infrastructure_status.sh`.
    ```bash
    sudo nano /opt/ssl-management/scripts/infrastructure_status.sh
    ```
    Paste the content below into the `nano` editor.

    ```bash
    #!/bin/bash
    # Infrastructure status script for centralized SSL infrastructure

    echo "=== CENTRALIZED SSL INFRASTRUCTURE STATUS ==="
    echo "Date: $(date)"
    echo ""

    # 1. NGINX Status
    echo "1. NGINX:"
    if systemctl is-active --quiet nginx; then
        echo "   ✅ NGINX is running"
    else
        echo "   ❌ NGINX is NOT running"
    fi

    # 2. NGINX Configuration
    echo "2. NGINX Configuration:"
    if sudo nginx -t &>/dev/null; then
        echo "   ✅ Configuration is valid"
    else
        echo "   ❌ NGINX configuration error"
    fi

    # 3. Certificates
    echo "3. Certificates:"
    check_cert() {
        local cert_file=$1
        local cert_name=$2
        
        if [ -f "$cert_file" ]; then
            local expiry_date=$(sudo openssl x509 -in "$cert_file" -noout -enddate | cut -d= -f2)
            local expiry_epoch=$(date -d "$expiry_date" +%s)
            local current_epoch=$(date +%s)
            local days_left=$(( ($expiry_epoch - $current_epoch) / 86400 ))
            
            if [ $days_left -gt 30 ]; then
                echo "   ✅ $cert_name: $days_left days remaining"
            elif [ $days_left -gt 7 ]; then
                echo "   ⚠️ $cert_name: $days_left days remaining (WARNING)"
            else
                echo "   ❌ $cert_name: $days_left days remaining (CRITICAL)"
            fi
        else
            echo "   ❌ $cert_name: File NOT found"
        fi
    }

    check_cert "/etc/nginx/ssl/wildcard.example.local.crt" "Wildcard Certificate"
    check_cert "/etc/ssl/private/ca/intermediateCA.crt" "Intermediate CA"
    check_cert "/etc/ssl/private/ca/rootCA.crt" "Root CA"

    # 4. Backend connectivity
    echo "4. Backend Connectivity:"
    if timeout 3 bash -c "</dev/tcp/192.168.204.137/8081" 2>/dev/null; then
        echo "   ✅ Jenkins (192.168.204.137:8081) accessible"
    else
        echo "   ❌ Jenkins (192.168.204.137:8081) - NOT accessible"
    fi

    echo ""
    echo "=== END OF REPORT ==="
    ```
    *   Press `Ctrl+X`, then `Y` and `Enter` to save and exit.
    *   Make the script executable:
        ```bash
        sudo chmod +x /opt/ssl-management/scripts/infrastructure_status.sh
        ```

#### 15.2. Backup Script

*   **Where to Access:** On the NGINX VM. Create the file `/opt/ssl-management/scripts/backup_pki.sh`.
    ```bash
    sudo nano /opt/ssl-management/scripts/backup_pki.sh
    ```
    Paste the content below into the `nano` editor.

    ```bash
    #!/bin/bash
    # Backup script for PKI and NGINX infrastructure

    BACKUP_DIR="/opt/ssl-management/backups"
    DATE=$(date +%Y%m%d_%H%M%S)
    BACKUP_FILE="pki_nginx_backup_${DATE}.tar.gz"

    echo "Starting PKI and NGINX infrastructure backup..."

    # Create backup directory if it doesn't exist
    mkdir -p "$BACKUP_DIR"

    # Create backup file
    tar -czf "${BACKUP_DIR}/${BACKUP_FILE}" \
        /etc/ssl/private/ca/ \
        /etc/nginx/ssl/ \
        /etc/nginx/sites-available/ \
        /opt/ssl-management/scripts/ \
        /opt/ssl-management/templates/ \
        /etc/nginx/nginx.conf \
        /etc/nginx/conf.d/websocket.conf \
        --absolute-names

    if [ $? -eq 0 ]; then
        echo "✅ Backup created successfully: ${BACKUP_DIR}/${BACKUP_FILE}"
    else
        echo "❌ ERROR creating backup"
        exit 1
    fi

    # Keep only the last 30 backups
    echo "Removing backups older than 30 days..."
    find "$BACKUP_DIR" -name "pki_nginx_backup_*.tar.gz" -mtime +30 -delete
    if [ $? -eq 0 ]; then
        echo "✅ Old backup cleanup completed"
    else
        echo "⚠️ Warning: Error in old backup cleanup"
    fi

    echo "Backup completed!"
    ```
    *   Press `Ctrl+X`, then `Y` and `Enter` to save and exit.
    *   Make the script executable:
        ```bash
        sudo chmod +x /opt/ssl-management/scripts/backup_pki.sh
        ```

#### 15.3. Configure Cron Jobs

*   **Where to Access:** On the NGINX VM.
    ```bash
    # Edit root crontab
    sudo crontab -e
    ```
    *   Add the following lines at the end of the file:
        ```cron
        # Daily PKI and NGINX infrastructure backup (2:00 AM)
        0 2 * * * /opt/ssl-management/scripts/backup_pki.sh >> /var/log/ssl-management_backup.log 2>&1

        # Weekly status check (Monday 8:00 AM)
        0 8 * * 1 /opt/ssl-management/scripts/infrastructure_status.sh >> /var/log/ssl-management_status.log 2>&1
        ```
    *   Press `Ctrl+X`, then `Y` and `Enter` to save and exit.

---

## ➕ PART 8: Template for New Services

### Step 16: Reusable Template

#### 16.1. Create Template

*   **Where to Access:** On the NGINX VM. Create the file `/opt/ssl-management/templates/service_template.conf`.
    ```bash
    sudo nano /opt/ssl-management/templates/service_template.conf
    ```
    Paste the content below into the `nano` editor.

    ```nginx
    # Template for new services
    # Replace: SERVICE_NAME, BACKEND_IP, BACKEND_PORT

    upstream SERVICE_NAME_backend {
        server BACKEND_IP:BACKEND_PORT max_fails=3 fail_timeout=30s;
        keepalive 32;
    }

    # HTTP to HTTPS redirect
    server {
        listen 80;
        listen [::]:80;
        server_name SERVICE_NAME.example.local;

        limit_req zone=general burst=20 nodelay;
        limit_conn addr 10;

        access_log /var/log/nginx/sites/SERVICE_NAME.access.log main;
        error_log /var/log/nginx/sites/SERVICE_NAME.error.log;

        return 301 https://$server_name$request_uri;
    }

    # HTTPS server
    server {
        listen 443 ssl http2;
        listen [::]:443 ssl http2;
        server_name SERVICE_NAME.example.local;

        ssl_certificate /etc/nginx/ssl/wildcard_chain.crt;
        ssl_certificate_key /etc/nginx/ssl/wildcard.example.local.key;

        limit_req zone=general burst=20 nodelay;
        limit_conn addr 10;

        access_log /var/log/nginx/sites/SERVICE_NAME.access.log main;
        error_log /var/log/nginx/sites/SERVICE_NAME.error.log;

        client_max_body_size 100m;
        proxy_read_timeout 300;
        proxy_connect_timeout 300;
        proxy_send_timeout 300;

        add_header X-Service-Name "SERVICE_NAME" always;

        location / {
            proxy_pass http://SERVICE_NAME_backend;
            
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
            proxy_set_header X-Forwarded-Port $server_port;
            proxy_set_header X-Forwarded-Host $host;

            proxy_http_version 1.1;
            proxy_set_header Upgrade $http_upgrade;
            proxy_set_header Connection $connection_upgrade;
        }

        location /health {
            access_log off;
            proxy_pass http://SERVICE_NAME_backend/health;
            proxy_connect_timeout 5s;
            proxy_read_timeout 5s;
        }
    }
    ```
    *   Press `Ctrl+X`, then `Y` and `Enter` to save and exit.

#### 16.2. Script to Add New Services

*   **Where to Access:** On the NGINX VM. Create the file `/opt/ssl-management/scripts/add_service.sh`.
    ```bash
    sudo nano /opt/ssl-management/scripts/add_service.sh
    ```
    Paste the content below into the `nano` editor.

    ```bash
    #!/bin/bash
    # Script to add new services to NGINX centralized SSL infrastructure

    # Colors for terminal output
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[1;33m'
    BLUE='\033[0;34m'
    NC='\033[0m' # No Color

    echo -e "${BLUE}=== Add New Service to NGINX Reverse Proxy ===${NC}"

    # Check if correct number of arguments was provided
    if [ $# -ne 3 ]; then
        echo -e "${RED}❌ Incorrect usage.${NC}"
        echo "Usage: $0 <service_name> <backend_ip> <backend_port>"
        echo "Example: $0 gitlab 192.168.204.135 8080"
        exit 1
    fi

    SERVICE_NAME=$1
    BACKEND_IP=$2
    BACKEND_PORT=$3

    echo -e "${GREEN}Adding service: ${SERVICE_NAME}.example.local -> ${BACKEND_IP}:${BACKEND_PORT}${NC}"

    # 1. Validate parameters
    echo "1. Validating parameters..."
    if [[ ! $SERVICE_NAME =~ ^[a-zA-Z0-9-]+$ ]]; then
        echo -e "${RED}❌ Error: Service name must contain only letters, numbers, and hyphens.${NC}"
        exit 1
    fi

    if [[ ! $BACKEND_IP =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
        echo -e "${RED}❌ Error: Invalid backend IP.${NC}"
        exit 1
    fi

    if [[ ! $BACKEND_PORT =~ ^[0-9]+$ ]] || [ $BACKEND_PORT -lt 1 ] || [ $BACKEND_PORT -gt 65535 ]; then
        echo -e "${RED}❌ Error: Backend port must be a number between 1 and 65535.${NC}"
        exit 1
    fi
    echo -e "${GREEN}   ✅ Parameters are valid.${NC}"

    # 2. Check if service already exists
    echo "2. Checking if service ${SERVICE_NAME} already exists..."
    if [ -f "/etc/nginx/sites-available/${SERVICE_NAME}.example.local.conf" ]; then
        echo -e "${RED}❌ Error: Service '${SERVICE_NAME}' already exists.${NC}"
        exit 1
    fi
    echo -e "${GREEN}   ✅ Service '${SERVICE_NAME}' doesn't exist, proceeding.${NC}"

    # 3. Test backend connectivity
    echo "3. Testing connectivity to backend ${BACKEND_IP}:${BACKEND_PORT}..."
    if ! timeout 5 bash -c "</dev/tcp/$BACKEND_IP/$BACKEND_PORT" 2>/dev/null; then
        echo -e "${YELLOW}⚠️ Warning: Could not connect to backend ${BACKEND_IP}:${BACKEND_PORT}.${NC}"
        read -p "Do you want to continue anyway? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            echo -e "${RED}❌ Operation cancelled by user.${NC}"
            exit 1
        fi
    else
        echo -e "${GREEN}   ✅ Backend connectivity OK.${NC}"
    fi

    # 4. Create configuration from template
    echo "4. Creating configuration file from template..."
    TEMPLATE_PATH="/opt/ssl-management/templates/service_template.conf"
    CONFIG_FILE_TMP="/tmp/${SERVICE_NAME}.example.local.conf.tmp"
    CONFIG_FILE_FINAL="/etc/nginx/sites-available/${SERVICE_NAME}.example.local.conf"
    SYMLINK_FILE="/etc/nginx/sites-enabled/${SERVICE_NAME}.example.local.conf"

    if [ ! -f "$TEMPLATE_PATH" ]; then
        echo -e "${RED}❌ Error: Template not found at '$TEMPLATE_PATH'.${NC}"
        exit 1
    fi

    cp "$TEMPLATE_PATH" "$CONFIG_FILE_TMP"
    sed -i "s/SERVICE_NAME/${SERVICE_NAME}/g" "$CONFIG_FILE_TMP"
    sed -i "s/BACKEND_IP/${BACKEND_IP}/g" "$CONFIG_FILE_TMP"
    sed -i "s/BACKEND_PORT/${BACKEND_PORT}/g" "$CONFIG_FILE_TMP"

    if [ $? -eq 0 ]; then
        echo -e "${GREEN}   ✅ Template processed successfully.${NC}"
    else
        echo -e "${RED}❌ Error processing template.${NC}"
        rm -f "$CONFIG_FILE_TMP"
        exit 1
    fi

    # 5. Move to correct location and create symbolic link
    echo "5. Moving configuration and creating symbolic link..."
    mv "$CONFIG_FILE_TMP" "$CONFIG_FILE_FINAL"
    if [ $? -ne 0 ]; then
        echo -e "${RED}❌ Error moving configuration file.${NC}"
        exit 1
    fi

    ln -s "$CONFIG_FILE_FINAL" "$SYMLINK_FILE"
    if [ $? -ne 0 ]; then
        echo -e "${RED}❌ Error creating symbolic link.${NC}"
        rm -f "$CONFIG_FILE_FINAL"
        exit 1
    fi
    echo -e "${GREEN}   ✅ Configuration file and symbolic link created.${NC}"

    # 6. Create logs directory
    echo "6. Creating logs directory for the service..."
    mkdir -p /var/log/nginx/sites
    echo -e "${GREEN}   ✅ Logs directory ensured.${NC}"

    # 7. Test NGINX configuration and reload
    echo "7. Testing NGINX configuration..."
    if sudo nginx -t; then
        echo -e "${GREEN}   ✅ NGINX configuration valid. Reloading NGINX...${NC}"
        sudo systemctl reload nginx
        if [ $? -eq 0 ]; then
            echo -e "${GREEN}   ✅ NGINX reloaded successfully!${NC}"
            echo ""
            echo -e "${GREEN}Service '${SERVICE_NAME}.example.local' added successfully! 🎉${NC}"
            echo ""
            echo -e "${BLUE}IMPORTANT next steps:${NC}"
            echo "1. Add DNS record on Windows Server: ${SERVICE_NAME}.example.local -> 192.168.204.139"
            echo "2. Configure backend service at ${BACKEND_IP}:${BACKEND_PORT}"
            echo "3. Test access via browser: https://${SERVICE_NAME}.example.local"
            echo "4. Check logs: tail -f /var/log/nginx/sites/${SERVICE_NAME}.access.log"
        else
            echo -e "${RED}❌ Error reloading NGINX.${NC}"
            rm -f "$CONFIG_FILE_FINAL"
            rm -f "$SYMLINK_FILE"
            exit 1
        fi
    else
        echo -e "${RED}❌ NGINX configuration error. Removing created files...${NC}"
        rm -f "$CONFIG_FILE_FINAL"
        rm -f "$SYMLINK_FILE"
        exit 1
    fi
    ```
    *   Press `Ctrl+X`, then `Y` and `Enter` to save and exit.
    *   Make the script executable:
        ```bash
        sudo chmod +x /opt/ssl-management/scripts/add_service.sh
        ```

---

## 📊 PART 9: Monitoring Dashboard

### Step 17: Create Internal Dashboard

#### 17.1. Dashboard Configuration

*   **Where to Access:** On the NGINX VM. Create the file `/etc/nginx/sites-available/dashboard.example.local.conf`.
    ```bash
    sudo nano /etc/nginx/sites-available/dashboard.example.local.conf
    ```
    Paste the content below into the `nano` editor.

    ```nginx
    # Internal monitoring dashboard
    server {
        listen 80;
        server_name dashboard.example.local;
        return 301 https://$server_name$request_uri;
    }

    server {
        listen 443 ssl http2;
        server_name dashboard.example.local;

        ssl_certificate /etc/nginx/ssl/wildcard_chain.crt;
        ssl_certificate_key /etc/nginx/ssl/wildcard.example.local.key;

        root /var/www/dashboard;
        index index.html;

        # Restrict access to internal network
        allow 192.168.204.0/24;
        deny all;

        access_log /var/log/nginx/dashboard.access.log main;
        error_log /var/log/nginx/dashboard.error.log;

        location / {
            try_files $uri $uri/ =404;
        }

        location /api/status {
            add_header Content-Type application/json;
            return 200 '{"status":"ok","timestamp":"$time_iso8601","server":"$hostname"}';
        }

        location /nginx_status {
            stub_status on;
            access_log off;
        }
    }
    ```
    *   Press `Ctrl+X`, then `Y` and `Enter` to save and exit.

#### 17.2. Create Dashboard Page

*   **Where to Access:** On the NGINX VM.
    ```bash
    # Create directory for dashboard
    sudo mkdir -p /var/www/dashboard

    # Create dashboard HTML page
    sudo nano /var/www/dashboard/index.html
    ```
    Paste the content below into the `nano` editor.

    ```html
    <!DOCTYPE html>
    <html lang="en-US">
    <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <title>Dashboard - example SSL Infrastructure</title>
        <style>
            * { margin: 0; padding: 0; box-sizing: border-box; }
            body { 
                font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; 
                background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
                min-height: 100vh;
                padding: 20px;
            }
            .container { 
                max-width: 1200px; 
                margin: 0 auto; 
            }
            .header {
                text-align: center;
                color: white;
                margin-bottom: 30px;
            }
            .header h1 {
                font-size: 2.5em;
                margin-bottom: 10px;
                text-shadow: 2px 2px 4px rgba(0,0,0,0.3);
            }
            .header p {
                font-size: 1.2em;
                opacity: 0.9;
            }
            .grid { 
                display: grid; 
                grid-template-columns: repeat(auto-fit, minmax(300px, 1fr)); 
                gap: 20px; 
            }
            .card { 
                background: rgba(255,255,255,0.95); 
                padding: 25px; 
                border-radius: 15px; 
                box-shadow: 0 8px 32px rgba(0,0,0,0.1);
                backdrop-filter: blur(10px);
                border: 1px solid rgba(255,255,255,0.2);
            }
            .card h2 { 
                color: #333; 
                border-bottom: 3px solid #667eea; 
                padding-bottom: 10px; 
                margin-bottom: 20px;
                font-size: 1.4em;
            }
            .metric { 
                display: flex; 
                justify-content: space-between; 
                align-items: center;
                margin: 15px 0; 
                padding: 10px;
                background: rgba(102, 126, 234, 0.1);
                border-radius: 8px;
            }
            .metric span:first-child {
                font-weight: 600;
                color: #555;
            }
            .status-ok { color: #28a745; font-weight: bold; }
            .status-warning { color: #ffc107; font-weight: bold; }
            .status-error { color: #dc3545; font-weight: bold; }
            .links a { 
                display: block;
                padding: 12px 15px;
                margin: 8px 0;
                background: linear-gradient(45deg, #667eea, #764ba2);
                color: white; 
                text-decoration: none; 
                border-radius: 8px;
                transition: all 0.3s ease;
                text-align: center;
                font-weight: 500;
            }
            .links a:hover { 
                transform: translateY(-2px);
                box-shadow: 0 4px 15px rgba(102, 126, 234, 0.4);
            }
            .timestamp {
                text-align: center;
                color: rgba(255,255,255,0.8);
                margin-top: 30px;
                font-size: 0.9em;
            }
            .status-indicator {
                width: 12px;
                height: 12px;
                border-radius: 50%;
                display: inline-block;
                margin-right: 8px;
            }
            .status-indicator.online { background-color: #28a745; }
            .status-indicator.offline { background-color: #dc3545; }
            .status-indicator.warning { background-color: #ffc107; }
        </style>
    </head>
    <body>
        <div class="container">
            <div class="header">
                <h1>📊 Centralized SSL Dashboard</h1>
                <p>example Internal Infrastructure - Real-Time Monitoring</p>
            </div>
            
            <div class="grid">
                <div class="card">
                    <h2>✅ Active Services</h2>
                    <div class="metric">
                        <span><span class="status-indicator online"></span>Jenkins</span>
                        <span class="status-ok">🟢 Online</span>
                    </div>
                    <div class="metric">
                        <span><span class="status-indicator online"></span>NGINX Proxy</span>
                        <span class="status-ok">🟢 Active</span>
                    </div>
                    <div class="metric">
                        <span><span class="status-indicator online"></span>DNS Server</span>
                        <span class="status-ok">🟢 Resolving</span>
                    </div>
                </div>
                
                <div class="card">
                    <h2>🔒 SSL Certificates</h2>
                    <div class="metric">
                        <span>Wildcard Certificate</span>
                        <span class="status-ok">✅ Valid (365 days)</span>
                    </div>
                    <div class="metric">
                        <span>Root CA</span>
                        <span class="status-ok">✅ Valid (10 years)</span>
                    </div>
                    <div class="metric">
                        <span>Intermediate CA</span>
                        <span class="status-ok">✅ Valid (5 years)</span>
                    </div>
                </div>
                
                <div class="card">
                    <h2>🔗 Quick Links</h2>
                    <div class="links">
                        <a href="https://jenkins.example.local" target="_blank">🚀 Jenkins CI/CD</a>
                        <a href="https://nginx.example.local" target="_blank">🌐 NGINX Status</a>
                        <a href="/nginx_status" target="_blank">📈 Server Stats</a>
                        <a href="/api/status" target="_blank">⚙️ API Status</a>
                    </div>
                </div>
                
                <div class="card">
                    <h2>ℹ️ System Information</h2>
                    <div class="metric">
                        <span>Main Server</span>
                        <span>nginx.example.local</span>
                    </div>
                    <div class="metric">
                        <span>Proxy IP</span>
                        <span>192.168.204.139</span>
                    </div>
                    <div class="metric">
                        <span>Domain</span>
                        <span>*.example.local</span>
                    </div>
                    <div class="metric">
                        <span>Last Update</span>
                        <span id="timestamp">Loading...</span>
                    </div>
                </div>
                
                <div class="card">
                    <h2>🛡️ Security</h2>
                    <div class="metric">
                        <span>SSL/TLS</span>
                        <span class="status-ok">✅ TLS 1.2/1.3</span>
                    </div>
                    <div class="metric">
                        <span>HSTS</span>
                        <span class="status-ok">✅ Enabled</span>
                    </div>
                    <div class="metric">
                        <span>Rate Limiting</span>
                        <span class="status-ok">✅ Active</span>
                    </div>
                    <div class="metric">
                        <span>Security Headers</span>
                        <span class="status-ok">✅ Configured</span>
                    </div>
                </div>
                
                <div class="card">
                    <h2>📈 Statistics</h2>
                    <div class="metric">
                        <span>NGINX Uptime</span>
                        <span class="status-ok" id="uptime">Calculating...</span>
                    </div>
                    <div class="metric">
                        <span>Active Connections</span>
                        <span id="connections">Loading...</span>
                    </div>
                    <div class="metric">
                        <span>Requests/min</span>
                        <span id="requests">Loading...</span>
                    </div>
                </div>
            </div>
            
            <div class="timestamp">
                <p>Dashboard updated at: <span id="last-update"></span></p>
                <p>Centralized SSL Infrastructure - example Internal © 2025</p>
            </div>
        </div>
        
        <script>
            // Update timestamp
            function updateTimestamp() {
                const now = new Date();
                document.getElementById('timestamp').textContent = now.toLocaleString('en-US');
                document.getElementById('last-update').textContent = now.toLocaleString('en-US');
            }
            
            // Simulate statistics data
            function updateStats() {
                const uptimeDays = Math.floor(Math.random() * 30) + 1;
                document.getElementById('uptime').textContent = `${uptimeDays} days`;
                
                const connections = Math.floor(Math.random() * 50) + 10;
                document.getElementById('connections').textContent = connections;
                
                const requests = Math.floor(Math.random() * 100) + 20;
                document.getElementById('requests').textContent = requests;
            }
            
            // Update on initialization
            updateTimestamp();
            updateStats();
            
            // Update every 30 seconds
            setInterval(() => {
                updateTimestamp();
                updateStats();
            }, 30000);
        </script>
    </body>
    </html>
    ```
    *   Press `Ctrl+X`, then `Y` and `Enter` to save and exit.

#### 17.3. Enable Dashboard

*   **Command Context:** We set correct permissions and enable the site.
    ```bash
    # Set correct permissions for dashboard directory
    sudo chown -R www-data:www-data /var/www/dashboard
    sudo chmod -R 755 /var/www/dashboard

    # Enable dashboard site
    echo "Enabling Dashboard configuration in NGINX..."
    sudo ln -s /etc/nginx/sites-available/dashboard.example.local.conf /etc/nginx/sites-enabled/

    # Test NGINX configuration
    echo "Testing NGINX configuration syntax..."
    sudo nginx -t

    # Reload NGINX
    echo "Reloading NGINX..."
    sudo systemctl reload nginx
    ```

#### 17.4. Add DNS for Dashboard

*   **Where to Access:** On your Windows Server 2019, in **DNS Manager**, in the `example.local` zone.
    1.  Right-click on the `example.local` zone.
    2.  Select **New Host (A or AAAA)...**.
    3.  **Host name:** `dashboard`
    4.  **IP address:** `192.168.204.139`
    5.  Click **Add Host**.

---

## 🔍 PART 10: Troubleshooting and Maintenance

### Step 18: Troubleshooting Guide

#### 18.1. Complete Diagnostic Script

*   **Where to Access:** On the NGINX VM. Create the file `/opt/ssl-management/scripts/diagnose.sh`.
    ```bash
    sudo nano /opt/ssl-management/scripts/diagnose.sh
    ```
    Paste the content below into the `nano` editor.

    ```bash
    #!/bin/bash
    # Complete diagnostic script for centralized SSL infrastructure

    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[1;33m'
    BLUE='\033[0;34m'
    NC='\033[0m' # No Color

    echo -e "${BLUE}=== COMPLETE SSL INFRASTRUCTURE DIAGNOSIS ===${NC}"
    echo "Started at: $(date)"
    echo ""

    # 1. Check basic services
    echo -e "${BLUE}1. Checking basic services...${NC}"
    services=("nginx" "systemd-resolved")
    for service in "${services[@]}"; do
        if systemctl is-active --quiet "$service"; then
            echo -e "   ${GREEN}✅ $service is running${NC}"
        else
            echo -e "   ${RED}❌ $service is NOT running${NC}"
        fi
    done

    # 2. Check ports
    echo -e "${BLUE}2. Checking ports...${NC}"
    ports=("80" "443")
    for port in "${ports[@]}"; do
        if sudo netstat -tlnp | grep -q ":$port "; then
            echo -e "   ${GREEN}✅ Port $port is in use${NC}"
        else
            echo -e "   ${RED}❌ Port $port is NOT in use${NC}"
        fi
    done

    # 3. Check certificate file existence
    echo -e "${BLUE}3. Checking certificate files...${NC}"
    cert_files=(
        "/etc/nginx/ssl/wildcard.example.local.crt"
        "/etc/nginx/ssl/wildcard.example.local.key"
        "/etc/nginx/ssl/wildcard_chain.crt"
        "/etc/ssl/private/ca/rootCA.crt"
        "/etc/ssl/private/ca/intermediateCA.crt"
        "/etc/nginx/ssl/dhparam.pem"
    )

    for file in "${cert_files[@]}"; do
        if [ -f "$file" ]; then
            echo -e "   ${GREEN}✅ $(basename "$file") exists${NC}"
        else
            echo -e "   ${RED}❌ $(basename "$file") NOT found${NC}"
        fi
    done

    # 4. Check certificate validity
    echo -e "${BLUE}4. Checking certificate validity...${NC}"
    check_cert_validity() {
        local cert_file=$1
        local cert_name=$2
        
        if [ -f "$cert_file" ]; then
            local expiry_date=$(sudo openssl x509 -in "$cert_file" -noout -enddate | cut -d= -f2)
            local expiry_epoch=$(date -d "$expiry_date" +%s)
            local current_epoch=$(date +%s)
            local days_left=$(( ($expiry_epoch - $current_epoch) / 86400 ))
            
            if [ $days_left -gt 30 ]; then
                echo -e "   ${GREEN}✅ $cert_name: $days_left days remaining${NC}"
            elif [ $
            days_left -gt 7 ]; then
                echo -e "   ${YELLOW}⚠️ $cert_name: $days_left days remaining (WARNING)${NC}"
            else
                echo -e "   ${RED}❌ $cert_name: $days_left days remaining (CRITICAL)${NC}"
            fi
        else
            echo -e "   ${RED}❌ $cert_name: File NOT found${NC}"
        fi
    }

    check_cert_validity "/etc/nginx/ssl/wildcard.example.local.crt" "Wildcard Certificate"
    check_cert_validity "/etc/ssl/private/ca/intermediateCA.crt" "Intermediate CA"
    check_cert_validity "/etc/ssl/private/ca/rootCA.crt" "Root CA"

    # 5. Test NGINX configuration
    echo -e "${BLUE}5. Testing NGINX configuration...${NC}"
    if sudo nginx -t &>/dev/null; then
        echo -e "   ${GREEN}✅ NGINX configuration is valid${NC}"
    else
        echo -e "   ${RED}❌ NGINX configuration error${NC}"
    fi

    # 6. Check backend connectivity
    echo -e "${BLUE}6. Testing backend connectivity...${NC}"
    if timeout 5 bash -c "</dev/tcp/192.168.204.137/8081" 2>/dev/null; then
        echo -e "   ${GREEN}✅ Jenkins (192.168.204.137:8081) accessible${NC}"
    else
        echo -e "   ${RED}❌ Jenkins (192.168.204.137:8081) - NOT accessible${NC}"
    fi

    # 7. Check DNS resolution
    echo -e "${BLUE}7. Testing DNS resolution...${NC}"
    domains=("jenkins.example.local" "nginx.example.local" "dashboard.example.local")
    for domain in "${domains[@]}"; do
        if nslookup "$domain" >/dev/null 2>&1; then
            echo -e "   ${GREEN}✅ $domain resolves correctly${NC}"
        else
            echo -e "   ${RED}❌ $domain does NOT resolve${NC}"
        fi
    done

    # 8. Check recent NGINX logs
    echo -e "${BLUE}8. Checking recent NGINX logs...${NC}"
    error_count=$(find /var/log/nginx/ -name "*.log" -mtime -1 -exec sudo grep -c "error" {} + 2>/dev/null | awk '{sum+=$1} END {print sum+0}')
    if [ "$error_count" -gt 0 ]; then
        echo -e "   ${YELLOW}⚠️ $error_count errors found in logs in the last 24h${NC}"
    else
        echo -e "   ${GREEN}✅ No significant errors in logs${NC}"
    fi

    # 9. Check system resources
    echo -e "${BLUE}9. Checking system resources...${NC}"
    cpu_usage=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | cut -d'%' -f1)
    mem_usage=$(free | grep Mem | awk '{printf "%.1f", $3/$2 * 100.0}')
    disk_usage=$(df -h / | awk 'NR==2{print $5}' | cut -d'%' -f1)

    echo "   CPU: ${cpu_usage}%"
    echo "   Memory: ${mem_usage}%"
    echo "   Disk: ${disk_usage}%"

    echo ""
    echo -e "${BLUE}=== END OF DIAGNOSIS ===${NC}"
    ```
    *   Press `Ctrl+X`, then `Y` and `Enter` to save and exit.
    *   Make the script executable:
        ```bash
        sudo chmod +x /opt/ssl-management/scripts/diagnose.sh
        ```

#### 18.2. Common Problems and Solutions

**Problem 1: "502 Bad Gateway" in NGINX**
*   **Cause:** NGINX couldn't connect to the backend server.
*   **Solutions:**
    1.  **Check if backend is running:**
        ```bash
        # On Jenkins VM:
        sudo systemctl status jenkins
        # On NGINX VM:
        sudo netstat -tlnp | grep :8081
        ```
    2.  **Check NGINX logs:**
        ```bash
        sudo tail -f /var/log/nginx/error.log
        ```
    3.  **Test connectivity:**
        ```bash
        timeout 5 bash -c "</dev/tcp/192.168.204.137/8081" && echo "Connected" || echo "Failed"
        ```

**Problem 2: "SSL Certificate Error" in Browser**
*   **Cause:** Browser doesn't trust the certificate.
*   **Solutions:**
    1.  **Check certificate:**
        ```bash
        sudo openssl x509 -in /etc/nginx/ssl/wildcard.example.local.crt -text -noout | grep -A5 "Subject Alternative Name"
        ```
    2.  **Check certificate chain:**
        ```bash
        sudo openssl verify -CAfile /etc/nginx/ssl/rootCA.crt \
            -untrusted /etc/nginx/ssl/intermediateCA.crt \
            /etc/nginx/ssl/wildcard.example.local.crt
        ```
    3.  **Check Root CA installation on client.**

**Problem 3: "DNS Resolution Failed"**
*   **Cause:** Domain name is not being resolved.
*   **Solutions:**
    1.  **Test DNS:**
        ```cmd
        nslookup jenkins.example.local 192.168.204.1
        ```
    2.  **Check client DNS configuration:**
        ```cmd
        ipconfig /all | findstr "DNS Servers"
        ```
    3.  **Clear DNS cache:**
        ```cmd
        ipconfig /flushdns
        ```

---

## 📝 PART 11: Documentation and Procedures

### Step 19: Operational Documentation

#### 19.1. Create Procedures Documentation

*   **Where to Access:** On the NGINX VM. Create the file `/opt/ssl-management/README.md`.
    ```bash
    sudo nano /opt/ssl-management/README.md
    ```
    Paste the content below into the `nano` editor.

    ```markdown
    # Centralized SSL Infrastructure - example Internal

    ## Overview
    This infrastructure provides centralized SSL for all internal services using NGINX as reverse proxy. It uses an internal PKI (Root CA and Intermediate CA) to issue trusted certificates within the local network.

    ## Architecture
    - **NGINX Proxy (VM):** 192.168.204.139 (Ubuntu 24.04 LTS)
    - **Jenkins (VM):** 192.168.204.137:8081 (Ubuntu 24.04 LTS)
    - **DNS Server:** Windows Server 2019 (192.168.204.1)
    - **Internal Domain:** `*.example.local`

    ## Certificates
    - **Root CA:** `example Root CA Internal` (Validity: 10 years)
    - **Intermediate CA:** `example Intermediate CA Internal` (Validity: 5 years)
    - **Wildcard Certificate:** `*.example.local` (Validity: 1 year)

    ## Operational Procedures

    ### 1. Add New Service
    1. **Configure Backend:** Ensure the service is running.
    2. **Run Script:** On NGINX VM:
        ```bash
        sudo /opt/ssl-management/scripts/add_service.sh <name> <ip> <port>
        ```
    3. **Add DNS Record:** On Windows Server DNS, add `A` record.
    4. **Test Access:** Access `https://<name>.example.local`.

    ### 2. Infrastructure Backup
    - **Manual:**
        ```bash
        sudo /opt/ssl-management/scripts/backup_pki.sh
        ```
    - **Automatic:** Configured via cron for daily execution at 2:00 AM.

    ### 3. Monitoring
    - **Dashboard:** Access `https://dashboard.example.local`
    - **Quick Status:**
        ```bash
        sudo /opt/ssl-management/scripts/infrastructure_status.sh
        ```
    - **Complete Diagnosis:**
        ```bash
        sudo /opt/ssl-management/scripts/diagnose.sh
        ```

    ## Contacts
    - **Administrator:** Wagner (Technology)
    - **Documentation:** `/opt/ssl-management/` on NGINX VM
    ```
    *   Press `Ctrl+X`, then `Y` and `Enter` to save and exit.

#### 19.2. Create Maintenance Checklist

*   **Where to Access:** On the NGINX VM. Create the file `/opt/ssl-management/MAINTENANCE.md`.
    ```bash
    sudo nano /opt/ssl-management/MAINTENANCE.md
    ```
    Paste the content below into the `nano` editor.

    ```markdown
    # Maintenance Checklist - Centralized SSL Infrastructure

    ## 🗓️ Weekly Maintenance
    - [ ] **Check service status:**
        ```bash
        sudo systemctl status nginx
        sudo systemctl status jenkins # On Jenkins VM
        ```
    - [ ] **Run complete diagnosis:**
        ```bash
        sudo /opt/ssl-management/scripts/diagnose.sh
        ```
    - [ ] **Check NGINX error logs:**
        ```bash
        sudo tail -100 /var/log/nginx/error.log
        ```
    - [ ] **Check disk space:**
        ```bash
        df -h
        ```
    - [ ] **Test access to main services:**
        - Access `https://jenkins.example.local` and `https://dashboard.example.local`

    ## 📅 Monthly Maintenance
    - [ ] **Check certificate validity:**
        ```bash
        sudo openssl x509 -in /etc/nginx/ssl/wildcard.example.local.crt -noout -dates
        ```
    - [ ] **Review access logs:**
        ```bash
        sudo less /var/log/nginx/access.log
        ```
    - [ ] **Check automatic backups:**
        ```bash
        ls -la /opt/ssl-management/backups/
        ```
    - [ ] **Update operating system:**
        ```bash
        sudo apt update && sudo apt upgrade -y
        ```

    ## 📋 Quarterly Maintenance
    - [ ] **Review NGINX configurations**
    - [ ] **Check performance and optimizations**
    - [ ] **Review rate limiting policies**
    - [ ] **Document infrastructure changes**

    ## 📆 Annual Maintenance
    - [ ] **Renew wildcard certificate**
    - [ ] **Review and update documentation**
    - [ ] **Evaluate infrastructure upgrade needs**
    - [ ] **Review backup and recovery policies**
    ```
    *   Press `Ctrl+X`, then `Y` and `Enter` to save and exit.

---

## ✅ PART 12: Final Validation and Testing

### Step 20: Complete Final Tests

#### 20.1. Complete Functionality Test

*   **Where to Access:** On the NGINX VM.
    ```bash
    # Run complete infrastructure diagnosis
    echo "Running complete infrastructure diagnosis..."
    sudo /opt/ssl-management/scripts/diagnose.sh
    ```

*   **Verification:**
    *   **Success:** All checks should return `✅` (green) or `⚠️` (yellow) with clear explanations.
    *   **Error:** If there are any `❌`, follow the script instructions to debug.

#### 20.2. Browser Access Test

*   **Where to Access:** On a client machine with Root CA installed.
    1.  **Access Jenkins:** `https://jenkins.example.local`
        *   Check green padlock and certificate validity.
        *   Login and navigate through some pages.
    2.  **Access Dashboard:** `https://dashboard.example.local`
        *   Check green padlock and certificate validity.
        *   Confirm dashboard loads correctly.

*   **Verification:**
    *   **Success:** Both sites should load via HTTPS with trusted certificates.
    *   **Error:** If there are issues, consult the Troubleshooting Guide.

#### 20.3. DNS Resolution Test

*   **Where to Access:** On any client machine in the network.
    ```bash
    # Test DNS resolution
    nslookup jenkins.example.local
    nslookup dashboard.example.local
    ping jenkins.example.local
    ```

*   **Verification:**
    *   **Success:** All commands should resolve to `192.168.204.139` and `ping` should succeed.
    *   **Error:** Review DNS configuration and client DNS settings.

#### 20.4. Basic Performance Test

*   **Where to Access:** On a client machine.
    ```bash
    # Create format file for curl
    cat > curl-format.txt << 'EOF'
         time_namelookup:  %{time_namelookup}\n
            time_connect:  %{time_connect}\n
         time_appconnect:  %{time_appconnect}\n
        time_pretransfer:  %{time_pretransfer}\n
           time_redirect:  %{time_redirect}\n
      time_starttransfer:  %{time_starttransfer}\n
                         ----------\n
              time_total:  %{time_total}\n
    EOF

    # Run basic performance test
    echo "Running performance test for https://jenkins.example.local..."
    curl -w "@curl-format.txt" -o /dev/null -s "https://jenkins.example.local"
    ```

*   **Verification:**
    *   **Success:** Output will show timing for each connection phase. Low values indicate good performance.
    *   **Error:** If `time_total` is very high, it may indicate network issues or overload.

---

## 📊 Infrastructure Architecture Diagrams

### 🏗️ Complete System Architecture

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                    CENTRALIZED SSL INFRASTRUCTURE OVERVIEW                      │
└─────────────────────────────────────────────────────────────────────────────────┘

                                 ┌─────────────────┐
                                 │   INTERNET      │
                                 │   (Optional)    │
                                 └─────────┬───────┘
                                           │
                                           │
                                 ┌─────────▼───────┐
                                 │  FIREWALL/      │
                                 │  ROUTER         │
                                 │ 192.168.204.1   │
                                 └─────────┬───────┘
                                           │
                    ┌──────────────────────┼──────────────────────┐
                    │                      │                      │
                    │         INTERNAL NETWORK (192.168.204.0/24) │
                    │                      │                      │
                    └──────────────────────┼──────────────────────┘
                                           │
        ┌──────────────────┬───────────────┼───────────────┬──────────────────┐
        │                  │               │               │                  │
┌───────▼────────┐ ┌───────▼────────┐ ┌───▼────┐ ┌───────▼────────┐ ┌───────▼────────┐
│ Windows Server │ │  NGINX Proxy   │ │Jenkins │ │   Dashboard    │ │  Client PCs    │
│  DNS Server    │ │ SSL Terminator │ │Backend │ │   Monitoring   │ │   End Users    │
│192.168.204.1   │ │192.168.204.139 │ │.137:81 │ │   Internal     │ │192.168.204.x   │
│                │ │                │ │        │ │                │ │                │
│ ┌────────────┐ │ │ ┌────────────┐ │ │┌──────┐│ │ ┌────────────┐ │ │ ┌────────────┐ │
│ │DNS Records │ │ │ │SSL/TLS     │ │ ││Jenkins│ │ │ │Real-time │ │ │ │ │Browsers  │ │ 
│ │*.example.local │ │ │ │Certificates││ ││HTTP  │││ │Status    │ │ │ │ │+ Root CA │ │ 
│ │A Records   │ │ │ │+ Proxy     │ │ ││:8081 ││ │ │Dashboard   │ │ │ │Installed   │ │
│ │            │ │ │ │Rules       │ │ │└──────┘│ │ │            │ │ │ │            │ │
│ └────────────┘ │ │ └────────────┘ │ │        │ │ └────────────┘ │ │ └────────────┘ │
└────────────────┘ └────────────────┘ └────────┘ └────────────────┘ └────────────────┘
         │                   │            │              │                   │
         │                   │            │              │                   │
         └───────────────────┼────────────┼──────────────┼───────────────────┘
                             │            │              │
                        DNS Resolution   HTTP/8081   HTTPS/443
                        (*.example.local)   (Internal)   (External)
```

### 🔐 PKI Certificate Trust Chain

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                         PKI TRUST CHAIN ARCHITECTURE                            │
└─────────────────────────────────────────────────────────────────────────────────┘

                    ┌─────────────────────────────────────┐
                    │           ROOT CA                   │
                    │    example Root CA Internal         │
                    │                                     │
                    │  • Self-Signed Certificate          │
                    │  • 4096-bit RSA Key                 │
                    │  • SHA-256 Signature                │
                    │  • Validity: 10 years               │
                    │  • Installed on all clients         │
                    │  • Stored: /etc/ssl/private/ca/     │
                    └─────────────┬───────────────────────┘
                                  │
                                  │ Signs
                                  ▼
                    ┌─────────────────────────────────────┐
                    │       INTERMEDIATE CA               │
                    │   example Intermediate CA Internal  │
                    │                                     │
                    │  • Signed by Root CA                │
                    │  • 4096-bit RSA Key                 │
                    │  • SHA-256 Signature                │
                    │  • Validity: 5 years                │
                    │  • pathlen:0 (no sub-CAs)           │
                    │  • Used for server certificates     │
                    └─────────────┬───────────────────────┘
                                  │
                                  │ Signs
                                  ▼
                    ┌─────────────────────────────────────┐
                    │       SERVER CERTIFICATE            │
                    │         *.example.local             │
                    │                                     │
                    │  • Wildcard Certificate             │
                    │  • 4096-bit RSA Key                 │
                    │  • SHA-256 Signature                │
                    │  • Validity: 1 year                 │
                    │  • SAN: *.example.local, jenkins.example.    
                    │    local, nginx.example.local, etc. │
                    │  • Used by NGINX for all services   │
                    └─────────────────────────────────────┘

Trust Verification Process:
┌─────────────────────────────────────────────────────────────────┐
│ 1. Client receives server certificate (*.example.local)         │
│ 2. Client checks if certificate is signed by trusted CA         │
│ 3. Client follows chain: Server → Intermediate → Root           │
│ 4. Client verifies Root CA is in trusted store                  │
│ 5. If all checks pass: ✅ Certificate is trusted               │     
│ 6. If any check fails: ❌ Certificate error displayed          │
└─────────────────────────────────────────────────────────────────┘
```

### 🌐 Network Traffic Flow

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                           NETWORK TRAFFIC FLOW                                  │
└─────────────────────────────────────────────────────────────────────────────────┘

Client Request Flow:
┌─────────────┐    ┌─────────────┐    ┌─────────────┐    ┌─────────────┐
│   Client    │    │    DNS      │    │   NGINX     │    │  Backend    │
│  Browser    │    │   Server    │    │   Proxy     │    │  Service    │
│             │    │             │    │             │    │ (Jenkins)   │
└──────┬──────┘    └──────┬──────┘    └──────┬──────┘    └──────┬──────┘
       │                  │                  │                  │
       │ 1. DNS Query     │                  │                  │
       │ jenkins.example.local               │                  │
       ├─────────────────►│                  │                  │
       │                  │                  │                  │
       │ 2. DNS Response  │                  │                  │
       │ 192.168.204.139  │                  │                  │
       │◄─────────────────┤                  │                  │
       │                  │                  │                  │
       │ 3. HTTPS Request │                  │                  │
       │ (SSL Handshake)  │                  │                  │
       │────────────────────────────────────►│                  │
       │                  │                  │                  │
       │ 4. SSL Certificate                  │                  │
       │ (*.example.local)│                  │                  │
       │◄────────────────────────────────────┤                  │
       │                  │                  │                  │
       │ 5. Encrypted     │                  │                  │
       │ HTTPS Request    │                  │                  │
       │────────────────────────────────────►│                  │
       │                  │                  │ 6. Decrypt &     │
       │                  │                  │ Forward HTTP     │
       │                  │                  ├─────────────────►│
       │                  │                  │                  │
       │                  │                  │ 7. HTTP Response │
       │                  │                  │◄─────────────────┤
       │ 8. Encrypted     │                  │                  │
       │ HTTPS Response   │                  │                  │
       │◄────────────────────────────────────┤                  │
       │                  │                  │                  │

Security Headers Added by NGINX:
┌─────────────────────────────────────────────────────────────────┐
│ • Strict-Transport-Security: max-age=31536000                   │
│ • X-Frame-Options: DENY                                         │
│ • X-Content-Type-Options: nosniff                               │
│ • X-XSS-Protection: 1; mode=block                               │
│ • Referrer-Policy: strict-origin-when-cross-origin              │
│ • X-Service-Name: jenkins                                       │
└─────────────────────────────────────────────────────────────────┘
```

---

##  FINAL SUMMARY AND CHECKLIST

### ✅ Complete Implementation Checklist

*   **Base Infrastructure:**
    *   ✅ NGINX VM configured (192.168.204.139)
    *   ✅ Jenkins VM configured (192.168.204.137)
    *   ✅ Windows Server DNS configured
*   **PKI (Public Key Infrastructure):**
    *   ✅ Root CA created and configured
    *   ✅ Intermediate CA created and signed by Root CA
    *   ✅ Wildcard certificate `*.example.local` created and signed by Intermediate CA
    *   ✅ Certificate chain (full chain) configured
*   **NGINX Reverse Proxy:**
    *   ✅ Optimized main configuration (`nginx.conf`) - 
    *   ✅ SSL/TLS configured securely
    *   ✅ Security headers implemented
    *   ✅ Rate limiting configured
    *   ✅ Cache and compression enabled
    *   ✅ Default site disabled - 
*   **Services:**
    *   ✅ Jenkins configured for reverse proxy (port 8081, no HTTPS)
    *   ✅ Monitoring dashboard created and restricted to internal network
    *   ✅ WebSocket configurations implemented
*   **DNS:**
    *   ✅ `A` records configured on Windows Server
    *   ✅ Wildcard DNS (`*.example.local`) working
    *   ✅ DNS resolution tested and validated
*   **Automation and Monitoring:**
    *   ✅ Automatic backup scripts (`backup_pki.sh`)
    *   ✅ Diagnostic scripts (`diagnose.sh`)
    *   ✅ Scripts to add new services (`add_service.sh`)
    *   ✅ Cron jobs configured
    *   ✅ Basic monitoring dashboard
*   **Security:**
    *   ✅ Root CA distributed to clients
    *   ✅ Certificates with correct permissions
    *   ✅ Security headers implemented
    *   ✅ Rate limiting configured
*   **Documentation:**
    *   ✅ Complete guide created (this document)
    *   ✅ Operational procedures documented (`README.md`)
    *   ✅ Troubleshooting guide created
    *   ✅ Maintenance checklist (`MAINTENANCE.md`)

### 🌐 Final Access URLs

*   **Jenkins:** `https://jenkins.example.local`
*   **Dashboard:** `https://dashboard.example.local`
*   **NGINX Status (internal):** `https://dashboard.example.local/nginx_status`

### ➡️ Next Steps

1.  **Test everything working according to this guide**
2.  **Add new services** using the `add_service.sh` script
3.  **Document any specific customizations**

---

## 🌟 Conclusion

*   **Enterprise-Level Infrastructure** with own PKI and centralized SSL
*   **Complete Automation** with scripts for backup, diagnosis, and expansion
*   **Professional Documentation** for maintenance and growth
*   **Total Scalability** to easily add new services

## 📄 Document Credits

This comprehensive guide was created by **Wagner** as part of the **SSL Centralized Infrastructure** project.

- **📁 Source Code:** [GitHub Repository](https://github.com/wagnerdias10/ssl-centralizaed-infrastructure)
- **📖 Documentation:** [GitHub Pages](https://wagnerdias10.github.io/ssl-centralizaed-infrastructure/)
- **👤 Author:** [Wagner's GitHub Profile](https://github.com/wagnerdias10)

### ⚖️ Usage Terms

- ✅ **Allowed:** Personal and educational use with attribution
- ✅ **Allowed:** Reference and citation with link to original source
- ❌ **Prohibited:** Complete copy without attribution to author
- ❌ **Prohibited:** Commercial use without express authorization
- ❌ **Prohibited:** Redistribution as own work

**© 2025 Wagner - All rights reserved | SSL Centralized Infrastructure Project**