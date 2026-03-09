#!/usr/bin/env bash

set -e

# Default environment variables
export OVPN_SERVER_URL=${OVPN_SERVER_URL:-''}
export OVPN_PROTO=${OVPN_PROTO:-'udp'}
export OVPN_PORT=${OVPN_PORT:-'1194'}
export OVPN_NETWORK=${OVPN_NETWORK:-'10.8.0.0'}
export OVPN_NETMASK=${OVPN_NETMASK:-'255.255.255.0'}
export OVPN_DNS_SERVERS=${OVPN_DNS_SERVERS:-'8.8.8.8 8.8.4.4'}
export OVPN_ROUTES=${OVPN_ROUTES:-''}
export OVPN_NAT_DEVICE=${OVPN_NAT_DEVICE:-'eth0'}

# PKI/Easy-RSA variables
export EASYRSA_PKI=${EASYRSA_PKI:-'/etc/openvpn/pki'}
export EASYRSA_REQ_COUNTRY=${EASYRSA_REQ_COUNTRY:-'US'}
export EASYRSA_REQ_PROVINCE=${EASYRSA_REQ_PROVINCE:-'California'}
export EASYRSA_REQ_CITY=${EASYRSA_REQ_CITY:-'San Francisco'}
export EASYRSA_REQ_ORG=${EASYRSA_REQ_ORG:-'OpenVPN'}
export EASYRSA_REQ_EMAIL=${EASYRSA_REQ_EMAIL:-'admin@example.com'}
export EASYRSA_REQ_OU=${EASYRSA_REQ_OU:-'IT'}
export EASYRSA_KEY_SIZE=${EASYRSA_KEY_SIZE:-'2048'}
export EASYRSA_CA_EXPIRE=${EASYRSA_CA_EXPIRE:-'3650'}
export EASYRSA_CERT_EXPIRE=${EASYRSA_CERT_EXPIRE:-'3650'}
export EASYRSA_CERT_RENEW=${EASYRSA_CERT_RENEW:-'30'}
export EASYRSA_BATCH=${EASYRSA_BATCH:-'1'}

# Process template files
find /docker-entrypoint.d/ -type f 2>/dev/null | while read filename; do
  # out_dir is the filename without the leading /docker-entrypoint.d/
  # e.g. /docker-entrypoint.d/etc/openvpn/server.conf.template -> /etc/openvpn/server.conf
  out_dir="/$(dirname ${filename#/docker-entrypoint.d/})"
  out_file=$(basename "${filename}")

  mkdir -p "${out_dir}"

  if [[ "$filename" == *.template ]]; then
    out_file="${out_file%.template}"
    echo "Processing template ${filename} to ${out_dir}/${out_file}"
    envsubst < "${filename}" > "${out_dir}/${out_file}"
  else
    echo "Copying file ${filename} to ${out_dir}/${out_file}"
    cp "${filename}" "${out_dir}/${out_file}"
  fi
done

# Initialize Easy-RSA PKI if not already done
if [ ! -d "${EASYRSA_PKI}" ] || [ ! -f "${EASYRSA_PKI}/ca.crt" ]; then
  echo "Initializing Easy-RSA PKI..."

  cd /etc/openvpn

  # Initialize PKI
  if [ ! -d "${EASYRSA_PKI}" ]; then
    echo "Creating PKI directory structure..."
    easyrsa init-pki || { echo "Failed to initialize PKI"; exit 1; }
  fi

  # Build CA
  if [ ! -f "${EASYRSA_PKI}/ca.crt" ]; then
    echo "Building Certificate Authority..."
    easyrsa build-ca nopass || { echo "Failed to build CA"; exit 1; }
  fi

  # Generate DH parameters
  if [ ! -f "${EASYRSA_PKI}/dh.pem" ]; then
    echo "Generating Diffie-Hellman parameters (this may take a while)..."
    easyrsa gen-dh || { echo "Failed to generate DH parameters"; exit 1; }
  fi

  # Build server certificate
  if [ ! -f "${EASYRSA_PKI}/issued/server.crt" ]; then
    echo "Building server certificate..."
    easyrsa build-server-full server nopass || { echo "Failed to build server certificate"; exit 1; }
  fi

  # Generate TLS auth key
  if [ ! -f "${EASYRSA_PKI}/ta.key" ]; then
    echo "Generating TLS authentication key..."
    openvpn --genkey secret "${EASYRSA_PKI}/ta.key" || { echo "Failed to generate TLS auth key"; exit 1; }
  fi

  echo "PKI initialization complete!"
else
  echo "PKI already initialized, skipping..."
fi

# Create necessary directories
mkdir -p /etc/openvpn/ccd
mkdir -p /var/log/openvpn

# Setup iptables rules for NAT and forwarding
echo "Setting up iptables rules..."

# Check if IP forwarding is enabled on the host
if [ "$(cat /proc/sys/net/ipv4/ip_forward)" != "1" ]; then
  echo "ERROR: IP forwarding is not enabled on the host!"
  echo "Please enable it on the host with: echo 1 > /proc/sys/net/ipv4/ip_forward"
  echo "Or permanently by setting net.ipv4.ip_forward=1 in /etc/sysctl.conf"
  exit 1
fi

echo "IP forwarding is enabled on host: OK"

# Setup NAT
iptables -t nat -A POSTROUTING -s ${OVPN_NETWORK}/${OVPN_NETMASK} -o ${OVPN_NAT_DEVICE} -j MASQUERADE

# Allow forwarding
iptables -A FORWARD -i tun+ -j ACCEPT
iptables -A FORWARD -o tun+ -j ACCEPT

# Execute scripts
if [ -d /etc/openvpn/scripts ]; then
  echo "Executing initialization scripts in /etc/openvpn/scripts..."
  for script in /etc/openvpn/scripts/*; do
    if [ -x "$script" ]; then
      echo "Running $script..."
      "$script" || { echo "Script $script failed with exit code $?"; exit 1; }
    else
      echo "Skipping non-executable script: $script"
    fi
  done
else
  echo "No initialization scripts found in /etc/openvpn/scripts, skipping..."
fi

echo "OpenVPN server initialization complete"

exec "$@"
