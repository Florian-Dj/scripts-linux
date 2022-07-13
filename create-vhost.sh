#!/bin/bash
###########################
# Author : Florian DJERBI
# Object : Environment creation
# Create : 12/07/2022
# Update : 13/07/2022
###########################

echo -n "Project name (user): "
read PROJET
USER=$( echo "${PROJET}" | cut -c1-30 )
echo -n "Domain name (domain.extension): "
read DOMAIN


function usercreation(){
    useradd -m -s /bin/bash -d /home/${DOMAIN} ${USER}
    echo "Creating the SSH key for GIT"
    sudo -H -u ${USER} bash -c 'ssh-keygen -t rsa -b 4096 -N "" -C "${USER}@${DOMAIN}" -f ~/.ssh/id_rsa -q -P ""'
    sudo -H -u ${USER} bash -c 'mkdir /var/www/html/${DOMAIN}'
}

function createvhost(){
echo "<VirtualHost *:80>
  ServerName ${DOMAIN}
  ServerAlias www.${DOMAIN}
  DocumentRoot /var/www/html/${USER}

  <IfModule mod_suexec.c>
    SuexecUserGroup \"${USER}\" \"${USER}\"
  </IfModule>

  # Apache
  AddDefaultCharset UTF-8
  Options +FollowSymLinks -Indexes

  # Deflate
  AddOutputFilterByType DEFLATE text/html text/css application/javascript application/x-javascript application/xml application/xhtml+xml

  # Etag
  FileETag None

  <Directory /var/www/html/${USER}>
   AllowOverride All
   Require all granted

   Options +FollowSymLinks -Indexes
  </Directory>

  CustomLog /home/${USER}/log/access.log combined
  ErrorLog /home/${USER}/log/error.log
</VirtualHost>
" > /etc/apache2/sites-available/${DOMAIN}.conf
    /usr/sbin/a2ensite ${DOMAIN}.conf
    echo "Apache - Checking the Apache configuration"
    /usr/sbin/apache2ctl configtest > /dev/null 2>&1
    RESULT=$?
    if [ $RESULT -eq 0 ]; then
        echo "Apache - configtest OK"
    else
        echo "Apache - configtest failed"
        exit 1
    fi
    echo "Apache - config reload"
    /etc/init.d/apache2 reload > /dev/null 2>&1

    certbot certonly --non-interactive --email floriandjerbi@gmail.com --agree-tos --expand --webroot --webroot-path /var/www/html/${USER} --domain ${DOMAIN} --domain www.${DOMAIN}   > /dev/null 2>&1
        RESULT=$?
        if [ $RESULT -eq 0 ]; then
                 _success "Apache - SSL create"
        else
                _error "Apache - SSL fail"
                exit 1
        fi

echo"<VirtualHost *:443>
  ServerName ${DOMAIN}
  ServerAlias www.${DOMAIN}
  DocumentRoot /var/www/html/${USER}

  <IfModule mod_suexec.c>
    SuexecUserGroup \"${USER}\" \"${USER}\"
  </IfModule>


#  Protocols h2 h2c http/1.1

  # SSL
  SSLEngine on
  SSLCertificateFile /etc/letsencrypt/live/${DOMAIN}/cert.pem
  SSLCertificateKeyFile /etc/letsencrypt/live/${DOMAIN}/privkey.pem
  SSLCertificateChainFile /etc/letsencrypt/live/${DOMAIN}/chain.pem

  # Apache
  AddDefaultCharset UTF-8
  Options +FollowSymLinks -Indexes

  # Deflate
  AddOutputFilterByType DEFLATE text/html text/css application/javascript application/x-javascript application/xml application/xhtml+xml

  # Etag
  FileETag None

  <Directory /var/www/html/${USER}>
   AllowOverride All
   Require all granted

   Options +FollowSymLinks -Indexes
  </Directory>

  CustomLog /home/${USER}/log/access.log combined
  ErrorLog /home/${USER}/log/error.log
</VirtualHost>
<VirtualHost */80>
    ServeurName ${DOMAIN}
    ServeurAlias www.${DOMAIN}

    RedirectPermanent / https://www.${DOMAIN}/
" > /etc/apache2/sites-available/${DOMAIN}.conf

    echo "Apache - Checking the Apache SSL configuration"
    /usr/sbin/apache2ctl configtest > /dev/null 2>&1
    RESULT=$?
    if [ $RESULT -eq 0 ]; then
        echo "Apache - configtest OK"
    else
        echo "Apache - configtest failed"
        exit 1
    fi
    echo "Apache - config reload"
    /etc/init.d/apache2 reload > /dev/null 2>&1
}


function main() {
    echo "User creation"
    usercreation
    echo "User has been created"

    echo "Apache - Vhost creation"
    createvhost
    echo "Apache - Vhost was created"

    echo "Logrotate creation"
    createlogrotate
    echo "Logrotate was created"
}


main "$@"
