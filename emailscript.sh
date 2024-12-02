#!/bin/bash

# Interactive Email Server Setup Script
# Configurable parameters
SERVER_IP="94.237.38.37"
DOMAIN="fi-di.xyz"
HOSTNAME="mail.${DOMAIN}"

# Color codes for better readability
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to display step-by-step menu
show_menu() {
    clear
    echo -e "${GREEN}===== Email Server Setup Menu =====${NC}"
    echo "1. Update System Packages"
    echo "2. Install Necessary Packages"
    echo "3. Configure Hostname and FQDN"
    echo "4. Install SSL/TLS Certificates"
    echo "5. Configure Postfix"
    echo "6. Configure Dovecot"
    echo "7. Create Mail User"
    echo "8. Restart Email Services"
    echo "9. Configure Firewall"
    echo "10. Setup Spam and Virus Protection"
    echo "11. Exit"
    echo -e "${YELLOW}Current Server IP: ${SERVER_IP}${NC}"
    echo -e "${YELLOW}Current Domain: ${DOMAIN}${NC}"
}

# Step 1: Update System Packages
update_system() {
    echo -e "${GREEN}Updating System Packages...${NC}"
    sudo apt update && sudo apt upgrade -y
    read -p "Press Enter to continue..."
}

# Step 2: Install Necessary Packages
install_packages() {
    echo -e "${GREEN}Installing Necessary Packages...${NC}"
    sudo apt install -y postfix dovecot-core dovecot-imapd dovecot-pop3d \
        opendkim opendkim-tools spamassassin clamav ssl-cert
    read -p "Press Enter to continue..."
}

# Step 3: Configure Hostname and FQDN
configure_hostname() {
    echo -e "${GREEN}Configuring Hostname...${NC}"
    sudo hostnamectl set-hostname ${HOSTNAME}
    echo "${HOSTNAME}" | sudo tee /etc/hostname

    # Update /etc/hosts
    sudo tee /etc/hosts << EOF
127.0.0.1 localhost
127.0.1.1 ${HOSTNAME} ${DOMAIN}
${SERVER_IP} ${HOSTNAME} ${DOMAIN}

# The following lines are desirable for IPv6 capable hosts
::1     localhost ip6-localhost ip6-loopback
ff02::1 ip6-allnodes
ff02::2 ip6-allrouters
EOF
    read -p "Press Enter to continue..."
}

# Step 4: Install SSL/TLS Certificates
install_ssl() {
    echo -e "${GREEN}Installing SSL/TLS Certificates...${NC}"
    sudo apt install certbot -y
    sudo certbot certonly --standalone -d ${HOSTNAME}
    read -p "Press Enter to continue..."
}

# Step 5: Configure Postfix
configure_postfix() {
    echo -e "${GREEN}Configuring Postfix...${NC}"
    sudo tee /etc/postfix/main.cf << EOF
# Basic settings
myhostname = ${HOSTNAME}
mydestination = \$myhostname, ${DOMAIN}, localhost.\$mydomain, localhost
mynetworks = 127.0.0.0/8 [::ffff:127.0.0.0]/104 [::1]/128
inet_interfaces = all
inet_protocols = all

# TLS/SSL Configuration
smtpd_tls_cert_file = /etc/letsencrypt/live/${HOSTNAME}/fullchain.pem
smtpd_tls_key_file = /etc/letsencrypt/live/${HOSTNAME}/privkey.pem
smtpd_tls_security_level = may
smtpd_tls_auth_only = yes

# SMTP Authentication
smtpd_sasl_type = dovecot
smtpd_sasl_path = private/auth
smtpd_sasl_auth_enable = yes
smtpd_sasl_security_options = noanonymous
smtpd_recipient_restrictions = 
    permit_sasl_authenticated,
    permit_mynetworks,
    reject_unauth_destination

# Outgoing mail settings
relayhost = 
myorigin = \$myhostname
EOF
    read -p "Press Enter to continue..."
}

# Step 6: Configure Dovecot
configure_dovecot() {
    echo -e "${GREEN}Configuring Dovecot...${NC}"
    sudo tee /etc/dovecot/dovecot.conf << EOF
protocols = imap pop3
listen = *

# Authentication mechanisms
auth_mechanisms = plain login

# SSL/TLS Configuration
ssl = required
ssl_cert = </etc/letsencrypt/live/${HOSTNAME}/fullchain.pem
ssl_key = </etc/letsencrypt/live/${HOSTNAME}/privkey.pem

# Mail location
mail_location = maildir:~/Maildir

# Authentication configuration
service auth {
  unix_listener /var/spool/postfix/private/auth {
    mode = 0666
    user = postfix
    group = postfix
  }
}
EOF
    read -p "Press Enter to continue..."
}

# Step 7: Create Mail User
create_mail_user() {
    echo -e "${GREEN}Creating Mail User...${NC}"
    read -p "Enter username for email account: " USERNAME
    sudo adduser ${USERNAME}
    read -p "Press Enter to continue..."
}

# Step 8: Restart Services
restart_services() {
    echo -e "${GREEN}Restarting Email Services...${NC}"
    sudo systemctl restart postfix
    sudo systemctl restart dovecot
    read -p "Press Enter to continue..."
}

# Step 9: Configure Firewall
configure_firewall() {
    echo -e "${GREEN}Configuring UFW Firewall...${NC}"
    sudo apt install ufw -y
    sudo ufw allow 25/tcp   # SMTP
    sudo ufw allow 465/tcp  # SMTPS
    sudo ufw allow 587/tcp  # Submission
    sudo ufw allow 143/tcp  # IMAP
    sudo ufw allow 993/tcp  # IMAPS
    sudo ufw allow 110/tcp  # POP3
    sudo ufw allow 995/tcp  # POP3S
    sudo ufw enable
    read -p "Press Enter to continue..."
}

# Step 10: Spam and Virus Protection
setup_spam_protection() {
    echo -e "${GREEN}Setting Up Spam and Virus Protection...${NC}"
    sudo systemctl enable spamassassin
    sudo systemctl start spamassassin
    sudo systemctl enable clamav-daemon
    sudo systemctl start clamav-daemon
    read -p "Press Enter to continue..."
}

# Main Menu Loop
while true; do
    show_menu
    read -p "Enter your choice (1-11): " choice
    
    case $choice in
        1) update_system ;;
        2) install_packages ;;
        3) configure_hostname ;;
        4) install_ssl ;;
        5) configure_postfix ;;
        6) configure_dovecot ;;
        7) create_mail_user ;;
        8) restart_services ;;
        9) configure_firewall ;;
        10) setup_spam_protection ;;
        11) 
            echo -e "${GREEN}Exiting...${NC}"
            exit 0
            ;;
        *) 
            echo -e "${RED}Invalid option. Please try again.${NC}"
            read -p "Press Enter to continue..."
            ;;
    esac
done
