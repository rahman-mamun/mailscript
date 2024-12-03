#!/bin/bash

# Automated Email Server Setup Script
# Configurable parameters
SERVER_IP="80.69.174.142" # Replace with your actual server IP
DOMAIN="mamunrahman.com" # Replace with your domain
HOSTNAME="mail.${DOMAIN}"

# Update and upgrade system
echo "Updating system packages..."
sudo apt update && sudo apt upgrade -y

# Install required packages
echo "Installing necessary packages..."
sudo apt install -y postfix postfix-mysql dovecot-core dovecot-imapd dovecot-pop3d dovecot-mysql \
    mariadb-server php php-mysql php-cli php-common php-curl apache2 libapache2-mod-php certbot \
    python3-certbot-apache unzip wget

# Configure hostname and FQDN
echo "Configuring hostname and FQDN..."
sudo hostnamectl set-hostname ${HOSTNAME}
echo "${SERVER_IP} ${HOSTNAME} ${DOMAIN}" | sudo tee -a /etc/hosts

# Configure MariaDB
echo "Configuring MariaDB..."
sudo systemctl start mariadb
sudo mysql_secure_installation <<EOF

y
your-root-password
your-root-password
y
y
y
y
EOF

# Create PostfixAdmin database
echo "Setting up PostfixAdmin database..."
sudo mysql -u root -pyour-root-password <<EOF
CREATE DATABASE postfixadmin;
GRANT ALL PRIVILEGES ON postfixadmin.* TO 'postfixadmin'@'localhost' IDENTIFIED BY 'postfixadmin_password';
FLUSH PRIVILEGES;
EXIT;
EOF

# Download and configure PostfixAdmin
echo "Downloading PostfixAdmin..."
wget https://github.com/postfixadmin/postfixadmin/archive/refs/heads/master.zip
unzip master.zip
sudo mv postfixadmin-master /var/www/postfixadmin
sudo chown -R www-data:www-data /var/www/postfixadmin

# Configure Apache for PostfixAdmin
echo "Configuring Apache for PostfixAdmin..."
sudo tee /etc/apache2/sites-available/postfixadmin.conf <<EOF
<VirtualHost *:80>
    ServerName ${HOSTNAME}
    DocumentRoot /var/www/postfixadmin/public

    <Directory /var/www/postfixadmin/public>
        Options -Indexes
        AllowOverride All
    </Directory>
</VirtualHost>
EOF

sudo a2ensite postfixadmin.conf
sudo a2enmod rewrite
sudo systemctl reload apache2

# Install SSL certificates
echo "Installing SSL certificates..."
sudo certbot --apache -d ${HOSTNAME}

# Configure Postfix
echo "Configuring Postfix..."
sudo tee /etc/postfix/main.cf <<EOF
# Basic settings
myhostname = ${HOSTNAME}
mydomain = ${DOMAIN}
myorigin = \$myhostname
inet_interfaces = all
inet_protocols = ipv4
mydestination = \$myhostname, localhost.\$mydomain, localhost

# TLS settings
smtpd_tls_cert_file = /etc/letsencrypt/live/${HOSTNAME}/fullchain.pem
smtpd_tls_key_file = /etc/letsencrypt/live/${HOSTNAME}/privkey.pem
smtpd_tls_security_level = may

# Mailbox configuration
virtual_mailbox_domains = mysql:/etc/postfix/mysql-virtual-mailbox-domains.cf
virtual_mailbox_maps = mysql:/etc/postfix/mysql-virtual-mailbox-maps.cf
virtual_alias_maps = mysql:/etc/postfix/mysql-virtual-alias-maps.cf

# SMTP authentication
smtpd_sasl_auth_enable = yes
smtpd_sasl_type = dovecot
smtpd_sasl_path = private/auth
smtpd_sasl_security_options = noanonymous
EOF

sudo systemctl restart postfix

# Configure Dovecot
echo "Configuring Dovecot..."
sudo tee /etc/dovecot/dovecot.conf <<EOF
protocols = imap pop3 lmtp
listen = *
ssl = required
ssl_cert = </etc/letsencrypt/live/${HOSTNAME}/fullchain.pem
ssl_key = </etc/letsencrypt/live/${HOSTNAME}/privkey.pem
mail_location = maildir:/var/mail/vhosts/%d/%n
auth_mechanisms = plain login
passdb {
    driver = sql
    args = /etc/dovecot/dovecot-sql.conf.ext
}
EOF

sudo systemctl restart dovecot

# Configure Firewall
echo "Configuring firewall..."
sudo ufw allow 80
sudo ufw allow 443
sudo ufw allow 25
sudo ufw allow 587
sudo ufw allow 993
sudo ufw enable

echo "Email server setup complete. Visit http://${HOSTNAME}/setup.php to finish PostfixAdmin setup."
