#!/bin/bash
# Healthcheck pour le client OpenVPN

# Vérifie si le processus OpenVPN est en cours d'exécution
if ! pgrep -x openvpn > /dev/null; then
    echo "OpenVPN client process is not running"
    exit 1
fi

# Vérifie si l'interface tun existe
if ! ip link show tun0 > /dev/null 2>&1; then
    echo "TUN interface not found"
    exit 1
fi

# Optionnel: Ping test vers une IP du réseau VPN (à adapter selon vos besoins)
# if ! ping -c 1 -W 2 10.8.0.1 > /dev/null 2>&1; then
#     echo "Cannot reach VPN gateway"
#     exit 1
# fi

echo "OpenVPN client is healthy"
exit 0
