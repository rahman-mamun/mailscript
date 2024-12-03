#!/bin/bash

# Mail Server Setup Script for mamunrahman.com
# Ubuntu 24.04 with Postfix and Dovecot
# WARNING: Run this script as root

set -e

# Fail-safe error handling
handle_error() {
    echo "Error occurred on line $1"
    exit 1
}

trap 'handle_error $LINENO' ERR

# Update and upgrade system
update_system() {
    echo "Updating system packages..."
    apt-get update
    apt-get upgrade -y
    apt-get install -y software-properties-common
}

# Install required packages
install_packages() {
    echo "Installing mail server packages..."
    apt-get install -y \
        postfix \
        dovecot-core \
        dovecot-imapd \
        dovecot-pop3d \
        dovecot-lmtpd \
        mailutils \
        certbot \
        nginx \
        openssl
}

# Configure SSL with Let's Encrypt
configure_ssl() {
    echo "Configuring SSL certificate for mamunrahman.com..."
    certbot certonly --standalone -d mail.mamunrahman.com
}

# Configure Postfix
configure_postfix() {
    echo "Configuring Postfix..."
    
    # Main configuration
    postconf -e "myhostname = mail.mamunrahman.com"
    postconf -e "mydestination = localhost, mamunrahman.com"
    postconf -e "mynetworks = 127.0.0.0/8 [::ffff:127.0.0.0]/104 [::1]/128"
    postconf -e "home_mailbox = Maildir/"
    postconf -e "mailbox_command ="
    
    # TLS/SSL Configuration
    postconf -e "smtpd_tls_cert_file = /etc/letsencrypt/live/mail.mamunrahman.com/fullchain.pem"
    postconf -e "smtpd_tls_key_file = /etc/letsencrypt/live/mail.mamunrahman.com/privkey.pem"
    postconf -e "smtpd_tls_security_level = may"
    postconf -e "smtp_tls_security_level = may"
    
    # SASL Authentication
    postconf -e "smtpd_sasl_type = dovecot"
    postconf -e "smtpd_sasl_path = private/auth"
    postconf -e "smtpd_sasl_auth_enable = yes"
    postconf -e "smtpd_recipient_restrictions = permit_sasl_authenticated,permit_mynetworks,reject_unauth_destination"
}

# Configure Dovecot
configure_dovecot() {
    echo "Configuring Dovecot..."
    
    # Backup original configuration
    cp /etc/dovecot/dovecot.conf /etc/dovecot/dovecot.conf.bak
    
    # Create a basic Dovecot configuration
    cat > /etc/dovecot/dovecot.conf << EOL
protocols = imap pop3 lmtp
listen = *

# Authentication config
auth_mechanisms = plain login
disable_plaintext_auth = no

# SSL/TLS
ssl = required
ssl_cert = </etc/letsencrypt/live/mail.mamunrahman.com/fullchain.pem
ssl_key = </etc/letsencrypt/live/mail.mamunrahman.com/privkey.pem

# Mailbox location
mail_location = maildir:~/Maildir

# Authentication process
service auth {
  unix_listener /var/spool/postfix/private/auth {
    mode = 0666
    user = postfix
    group = postfix
  }
}
EOL
}

# Create initial user
create_mail_user() {
    echo "Creating initial mail user..."
    read -p "Enter username for email: " username
    adduser $username
    passwd $username
}

# Restart services
restart_services() {
    echo "Restarting mail services..."
    systemctl restart postfix
    systemctl restart dovecot
}

# Main installation process
main() {
    echo "Starting Mail Server Configuration for mamunrahman.com"
    update_system
    install_packages
    configure_ssl
    configure_postfix
    configure_dovecot
    create_mail_user
    restart_services
    
    echo "Mail server setup completed successfully!"
}

# Run the main function
main
