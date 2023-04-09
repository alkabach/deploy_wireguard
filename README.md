# deploy_wireguard
Script to deploy wireguard server to Ubuntu 22 version from scratch

One line command

wget -O- https://raw.githubusercontent.com/alkabach/deploy_wireguard/main/create_vpn_wireguard_script.sh | sed 's/\r$//' | bash

If you would like to install 2 vpn servers on one machine, for example Outline and wireguard, first install wireguard and then outline to operate correctly
