#!/bin/sh
# /etc/network/if-post-down.d/iptables-stop.sh
# Script qui arrête le filtrage "iptables"
# Formation Debian GNU/Linux par Alexis de Lattre
# http://www.via.ecp.fr/~alexis/formation-linux/

# REMISE à ZERO des règles de filtrage
iptables -F
iptables -t nat -F

# REMISE de toutes les politiques par défaut à ACCEPT
iptables -P INPUT ACCEPT
iptables -P FORWARD ACCEPT
iptables -P OUTPUT ACCEPT
