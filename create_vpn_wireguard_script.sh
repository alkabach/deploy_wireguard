#!/bin/bash
set -e

#Default server configuration
sudo apt update
sudo apt upgrade
sudo apt install -y wireguard
sudo apt install iptables

#Install Jail with default config
sudo apt install fail2ban
sudo systemctl enable fail2ban
sudo systemctl start fail2ban

sudo cp /etc/fail2ban/jail.conf /etc/fail2ban/jail.local

echo -e "\033[0;31;40m!!!If needed, PLEASE CONFIGURE Fail2Ban protection with vi /etc/fail2ban/jail.local \033[0m"
#Default server configuration -- END

#Extract data to forward internet traffic to internet
default_route=$(ip route | grep "default via")
main_interface=$(echo $default_route | awk '{print $5}')
echo "Main network interface: $main_interface"

# Extract external IP
default_route=$(ip route | grep "default via")
main_interface=$(echo $default_route | awk '{print $5}')
# Get the IP address associated with the main network interface
ip_info=$(ip addr show dev $main_interface)
public_ip=$(echo $ip_info | grep -oP 'inet \K[\d.]+')
echo "Public IP address: $public_ip"

#If public ip is not correct with the method above, then you can use alternative way
#sudo apt-get install curl
#public_ip=$(curl -s https://api.ipify.org)
#echo "Public IP address: $public_ip"


#Generate keys for wireguard
mkdir keys
cd keys
#generate server public and private keys
wg genkey | tee server_private.key | wg pubkey > server_public.key
#generate client public and private keys
wg genkey | tee client_private.key | wg pubkey > client_public.key
cd ..


# Variables
# Replace these with your desired values
WG_INTERFACE_NAME="wg0"
WG_SERVER_IP="10.0.0.2"
WG_SERVER_PORT="51820"
WG_SERVER_PUBLIC_KEY="$(cat keys/server_public.key)"
WG_SERVER_PRIVATE_KEY="$(cat keys/server_private.key)"
WG_CLIENT_PUBLIC_KEY="$(cat keys/client_public.key)"
WG_CLIENT_PRIVATE_KEY="$(cat keys/client_private.key)"
WG_CLIENT_IP="10.0.0.3"
WG_CLIENT_ALLOWED_IPS="0.0.0.0/0"

# Generate the server configuration file
sudo mkdir -p /etc/wireguard
sudo bash -c "cat > /etc/wireguard/${WG_INTERFACE_NAME}.conf << EOL
[Interface]
PrivateKey = ${WG_SERVER_PRIVATE_KEY}
Address = ${WG_SERVER_IP}/24
ListenPort = ${WG_SERVER_PORT}
PostUp = iptables -A FORWARD -i %i -j ACCEPT; iptables -t nat -A POSTROUTING -o $main_interface -j MASQUERADE
PostDown = iptables -D FORWARD -i %i -j ACCEPT; iptables -t nat -D POSTROUTING -o $main_interface -j MASQUERADE
[Peer]
PublicKey = ${WG_CLIENT_PUBLIC_KEY}
AllowedIPs = ${WG_CLIENT_IP}/32
EOL"

# Enable IP forwarding
sudo sed -i 's/#net.ipv4.ip_forward=1/net.ipv4.ip_forward=1/' /etc/sysctl.conf
sudo sysctl -p

# Start the WireGuard interface
sudo systemctl enable wg-quick@${WG_INTERFACE_NAME}
sudo systemctl start wg-quick@${WG_INTERFACE_NAME}

# Print the client configuration file
echo "Client configuration:"
echo "[Interface]"
echo "PrivateKey = ${WG_CLIENT_PRIVATE_KEY}"
echo "Address = ${WG_CLIENT_IP}/24"
echo "DNS = 8.8.8.8"
echo ""
echo "[Peer]"
echo "PublicKey = ${WG_SERVER_PUBLIC_KEY}"
echo "Endpoint = ${public_ip}:${WG_SERVER_PORT}"
echo "AllowedIPs = ${WG_CLIENT_ALLOWED_IPS}"
echo "PersistentKeepalive = 25"
