#!/bin/bash
###########################
# Author : Florian DJERBI
# Object : Environment creation
# Create : 12/07/2022
# Update : 10/08/2022
###########################


function check_package(){
    pkgs="git apache2 certbot"
    for pkg in ${pkgs}; do
        status="$(dpkg-query -W --showformat='${db:Status-Status}' "${pkg}" 2>&1)"
            if [ ! $? = 0 ] || [ ! "${status}" = installed ]; then
                apt install $pkgs
            fi
    done
    echo "Check package done !"
}

function init(){
    echo -n "Project name (user): "
    read PROJET
    USER=$( echo "${PROJET}" | cut -c1-30 )
    echo -n "Domain name (domain.extension): "
    read DOMAIN
    echo -n "Repository URL: "
    read REPO
    echo -n "Choice branch repo: "
    read BRANCH
    index "$@"
    repo_update "$@"
}

function index() {
    while true; do
        echo -n "Path to index webpage: 
       1 - /
       2 - /dist
       3 - /public
       4 - /web
Your Choice (1-4): "
        read CHOICE_INDEX
        case ${CHOICE_INDEX} in
            1)
                PATH_INDEX="/"
    	    ;;
            2)
                PATH_INDEX="/dist"
    	    ;;
            3)
                PATH_INDEX="/public"
    	    ;;
            4)
                PATH_INDEX="/web"
    	    ;;
        esac
    done
}


function repo_update(){
    while true; do
        read -p "Automatic update of the site from a repo ? (yes/no): " REPO_UPDATE
        case $REPO_UPDATE in
            [Yy]*) (crontab -l -u ${USER}; echo "*/5 * * * * git pull origin ${BRANCH}") | crontab -; break;;
            [Nn]*) break;;
        esac
    done
}

function usercreation(){
    useradd -m -s /bin/bash -d /home/${DOMAIN} ${USER}
    echo "Creating the SSH key for GIT"
    sudo -H -u ${USER} bash -c 'ssh-keygen -t rsa -b 4096 -N "" -C "${USER}@web1.hedras.com" -f ~/.ssh/id_rsa -q -P ""'
    mkdir -p /var/www/html/${DOMAIN} /home/${DOMAIN}/log
    chown -R ${USER}: /var/www/html/${DOMAIN}
    chown -R ${USER}: /home/${DOMAIN}/log
}

function createvhost(){
echo "<VirtualHost *:80>
  ServerName ${DOMAIN}
  ServerAlias www.${DOMAIN}
  DocumentRoot /var/www/html/${DOMAIN}

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

  <Directory /var/www/html/${DOMAIN}>
   AllowOverride All
   Require all granted

   Options +FollowSymLinks -Indexes
  </Directory>

  CustomLog /home/${DOMAIN}/log/access.log combined
  ErrorLog /home/${DOMAIN}/log/error.log
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

    certbot certonly --non-interactive --email floriandjerbi@gmail.com --agree-tos --expand --webroot --webroot-path /var/www/html/${DOMAIN} --domain ${DOMAIN} --domain www.${DOMAIN}   > /dev/null 2>&1
    RESULT=$?
    if [ $RESULT -eq 0 ]; then
        echo "Apache - SSL create"
    else
        echo "Apache - SSL fail"
        exit 1
    fi

echo "<VirtualHost *:443>
  ServerName ${DOMAIN}
  ServerAlias www.${DOMAIN}
  DocumentRoot /var/www/html/${DOMAIN}${PATH_INDEX}

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

  <Directory /var/www/html/${DOMAIN}>
   AllowOverride All
   Require all granted

   Options +FollowSymLinks -Indexes
  </Directory>

  CustomLog /home/${DOMAIN}/log/access.log combined
  ErrorLog /home/${DOMAIN}/log/error.log
</VirtualHost>
<VirtualHost *:80>
    ServerName ${DOMAIN}
    ServerAlias www.${DOMAIN}

    RedirectPermanent / https://www.${DOMAIN}/
</VirtualHost>
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

function createlogrotate() {
echo "/home/${DOMAIN}/log/*.log {
        su ${USER} ${USER}
        weekly
        missingok
        rotate 7
        compress
        delaycompress
        notifempty
        create 640 ${USER} ${USER}
        sharedscripts
        postrotate
                if /etc/init.d/apache2 status > /dev/null ; then \\
                /etc/init.d/apache2 reload > /dev/null; \\
                fi;
        endscript
        prerotate
                if [ -d /etc/logrotate.d/httpd-prerotate ]; then \\
                        run-parts /etc/logrotate.d/httpd-prerotate; \\
                fi; \\
        endscript
}" > /etc/logrotate.d/${DOMAIN}
}

function createclone() {
    if [ -z ${REPO} ]; then
        echo "GitHub - no repo URL"
    else
        echo "GitHub - repo being cloned"
	git clone --branch ${BRANCH} ${REPO} /var/www/html/${DOMAIN}
        echo "GitHub - repo is cloned"
    fi
    chown -R ${USER}: /var/www/html/${DOMAIN}
    chown -R ${USER}: /home/${DOMAIN}/log
}


function main() {

    check_package "$@"
    init "$@"

    echo "User creation"
    usercreation "$@"
    echo "User has been created"

    echo "Apache - Vhost creation"
    createvhost "$@"
    echo "Apache - Vhost was created"

    echo "Logrotate creation"
    createlogrotate "$@"
    echo "Logrotate was created"

    echo "GitHub - Clone creation"
    createclone "$@"
    echo "GitHub - Clone was created"
}

main "$@"

