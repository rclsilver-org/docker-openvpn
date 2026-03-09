# OpenVPN Server Docker Image

![Build Status](https://github.com/rclsilver-org/docker-openvpn/workflows/Build%20and%20Push%20Docker%20Image/badge.svg)
![Lint Status](https://github.com/rclsilver-org/docker-openvpn/workflows/Lint%20Dockerfile/badge.svg)

Docker image based on Alpine Linux containing OpenVPN, Easy-RSA, and iptables for port forwarding.

## Features

- **OpenVPN**: VPN server
- **Easy-RSA**: PKI certificate management
- **iptables**: For NAT and port forwarding
- **Supervisor**: Process management

## Prerequisites

- Docker and Docker Compose
- Access to `NET_ADMIN` capability to manage network interfaces
- Access to `/dev/net/tun` device
- **IP forwarding enabled on the host**

### Enable IP forwarding on the host

The container will check if IP forwarding is enabled on the host and will fail to start if it's not.

**Temporary (until reboot):**
```bash
echo 1 > /proc/sys/net/ipv4/ip_forward
```

**Permanent:**
```bash
# Add to /etc/sysctl.conf or /etc/sysctl.d/99-openvpn.conf
echo "net.ipv4.ip_forward=1" | sudo tee -a /etc/sysctl.conf

# Apply changes
sudo sysctl -p
```

## Installation

### Using pre-built image from GitHub Container Registry

You can use the pre-built image directly from GitHub Container Registry:

```bash
docker pull ghcr.io/rclsilver-org/docker-openvpn:latest
```

Then update your `docker-compose.yaml` to use the registry image:

```yaml
services:
  openvpn:
    image: ghcr.io/rclsilver-org/docker-openvpn:latest
    # ...rest of configuration
```

### Building locally

Alternatively, you can build the image locally:

```bash
docker-compose build
```

## Configuration

1. Copy the example configuration file:
```bash
cp docker-compose.override.yaml.example docker-compose.override.yaml
```

2. Edit `docker-compose.override.yaml` with your settings:
   - `OVPN_SERVER_URL`: Public URL or IP of your server
   - `OVPN_PROTO`: Protocol (udp or tcp)
   - `OVPN_PORT`: Listening port
   - `OVPN_NETWORK`: VPN network
   - `OVPN_NETMASK`: Network mask
   - `OVPN_DNS_SERVERS`: DNS servers for clients
   - `OVPN_NAT_DEVICE`: Network interface for NAT (usually eth0)
   - `EASYRSA_REQ_*`: PKI certificate information (country, province, city, organization, email, etc.)
   - `EASYRSA_KEY_SIZE`: RSA key size (default: 2048)
   - `EASYRSA_CA_EXPIRE`: CA certificate expiration in days (default: 3650)
   - `EASYRSA_CERT_EXPIRE`: Client/server certificate expiration in days (default: 3650)

## PKI Initialization

The PKI (Public Key Infrastructure) is **automatically initialized** on the first container start. The entrypoint script will:
- Initialize the Easy-RSA PKI directory structure
- Generate the Certificate Authority (CA)
- Create Diffie-Hellman parameters
- Generate the server certificate
- Create the TLS authentication key

If you need to manually reinitialize the PKI, you can delete the volume and restart:

```bash
docker-compose down
docker volume rm docker-openvpn_openvpn
docker-compose up -d
```

## Usage

### Start the server

```bash
docker-compose up -d
```

On first start, the PKI initialization may take a few minutes, especially when generating DH parameters.

### Create a client certificate

```bash
docker-compose exec openvpn bash
cd /etc/openvpn
easyrsa build-client-full CLIENT_NAME nopass
exit
```

### Generate client configuration

You can create a `.ovpn` file for your clients with:

```bash
cat > client.ovpn << EOF
client
dev tun
proto ${OVPN_PROTO}
remote ${OVPN_SERVER_URL} ${OVPN_PORT}
resolv-retry infinite
nobind
persist-key
persist-tun
remote-cert-tls server
cipher AES-256-GCM
auth SHA256
compress lz4-v2
verb 3
<ca>
$(cat /etc/openvpn/pki/ca.crt)
</ca>
<cert>
$(cat /etc/openvpn/pki/issued/CLIENT_NAME.crt)
</cert>
<key>
$(cat /etc/openvpn/pki/private/CLIENT_NAME.key)
</key>
<tls-auth>
$(cat /etc/openvpn/pki/ta.key)
</tls-auth>
key-direction 1
EOF
```

### Check logs

```bash
docker-compose logs -f openvpn
```

### Check status

```bash
docker-compose exec openvpn supervisorctl status
```

## Port Forwarding

The image supports port forwarding via iptables. NAT rules are automatically configured on container startup.

To add custom port forwarding rules, you can:
1. Modify the `docker-entrypoint.sh` script
2. Or execute iptables commands manually in the container

Example to forward port 8080 to a VPN client:
```bash
docker-compose exec openvpn iptables -t nat -A PREROUTING -p tcp --dport 8080 -j DNAT --to-destination 10.8.0.2:8080
docker-compose exec openvpn iptables -A FORWARD -p tcp -d 10.8.0.2 --dport 8080 -j ACCEPT
```

## Volumes

- `openvpn`: Contains OpenVPN configuration and PKI certificates

## Security

- The server uses TLS certificates for authentication
- AES-256-GCM encryption
- SHA256 authentication
- TLS-Auth to prevent DoS attacks

## Troubleshooting

### Container won't start

Check that:
- The `tun` module is loaded on the host: `lsmod | grep tun`
- If not: `modprobe tun`
- The container has the correct capabilities: `NET_ADMIN`

### Clients cannot connect

Check:
- Firewall rules on the host
- The port is properly exposed
- Server logs: `docker-compose logs openvpn`

### No internet access through VPN

Check:
- IP forwarding is enabled: `cat /proc/sys/net/ipv4/ip_forward` (should return 1)
- NAT iptables rules are in place: `docker-compose exec openvpn iptables -t nat -L -n -v`

## CI/CD

This project uses GitHub Actions for automated builds and testing:

- **Build and Push**: Automatically builds multi-architecture images (amd64, arm64) and pushes to GitHub Container Registry
- **Dockerfile Lint**: Validates Dockerfile using Hadolint

Images are automatically built and pushed on:
- Push to `main`/`master` branch (tagged as `latest`)
- Git tags matching `v*` (tagged with version number)
- Pull requests (built but not pushed)

### Available tags

- `latest`: Latest build from the main branch
- `vX.Y.Z`: Specific version tags
- `sha-<commit>`: Build from specific commit
