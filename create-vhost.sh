#!/bin/bash
###########################
# Author : Florian DJERBI
# Object : Environment creation
# Create : 12/07/2022
# Update : 20/08/2022
###########################
PATH=/usr/sbin:/usr/bin:/sbin:/bin

#
# VARIABLES
#
_reset='\033[0m'
_red='\033[0;31m'
_green='\033[0;32m'
_cyan='\033[0;36m'


#
# FUNCTIONS
#
function _success()
{
    printf "${_green}✔ %s${_reset}\n" "$@"
}

function _error() {
    printf "${_red}✖ %s${_reset}\n" "$@"
}

function _info() {
    printf "${_cyan}▬ %s${_reset}\n" "$@"
}


function check_package(){
    pkgs="git apache2 certbot jq"
    for pkg in ${pkgs}; do
        status="$(dpkg-query -W --showformat='${db:Status-Status}' "${pkg}" 2>&1)"
            if [ ! $? = 0 ] || [ ! "${status}" = installed ]; then
                apt install $pkgs
            fi
    done
    _success "Check package done !"
}

function init(){
    echo -n "Project name (user): "
    read PROJET
    USER=$( echo "${PROJET}" | cut -c1-30 )
    echo -n "Domain name (domain.extension): "
    read DOMAIN
    echo -n "Repository URL: "
    read REPO

    URL_API=(https://api.github.com/repos/$(echo ${REPO} |sed 's|https://github.com/||')/branches)
    nb_branch=$(curl -s ${URL_API} |jq -r '. | length')
    if [ $nb_branch = 1 ];then
        BRANCH=$(curl -s ${URL_API} |jq '.[0].name' |tr -d '"')
        _success "Branch ${BRANCH} used"
    else
        _info "List of branch available"
        branches=()
        while read branch; do
            branches+=(${branch})
        done< <(curl -s ${URL_API} |jq '.[].name' |tr -d '"')
        while true; do
            nb=1
            for branch in ${branches[@]}; do
                echo "  ${nb} - ${branch}"
                ((nb+=1))
            done
            echo -n "Choice branch repo (1-${#branches[@]}): "
            read NB_BRANCH
            if [ ${NB_BRANCH} -ge 1 ] && [ ${NB_BRANCH} -le ${#branches[@]} ]; then
                BRANCH=(${branches[${NB_BRANCH}-1]})
                _success "Branch ${BRANCH} selected"
		break
            fi
        done
    fi

    while true; do
        echo -n "Path to index webpage: 
  1 - /
  2 - /dist
  3 - /public
  4 - /web
Your Choice (1-4): "
        read CHOICE_INDEX
        case ${CHOICE_INDEX} in
            1) PATH_INDEX="/"; break;;
            2) PATH_INDEX="/dist"; break;;
            3) PATH_INDEX="/public"; break;;
            4) PATH_INDEX="/web"; break;;
        esac
    done

    while true; do
        read -p "Automatic update of the site from a repo ? (yes/no): " REPO_UPDATE
        case $REPO_UPDATE in
            [Yy]*) REPO_UPDATE=true; break;;
            [Nn]*) REPO_UPDATE=false; break;;
        esac
    done

    while true; do
        read -p "Create SSL certificates ? (yes/no): " SSL
        case $SSL in
            [Yy]*) SSL=true; break;;
            [Nn]*) SSL=false; break;;
        esac
    done
}

function usercreation(){
    _info "Creating user, home directory and SSH key"
    useradd -m -s /bin/bash -d /home/${DOMAIN} ${USER}
    sudo -H -u ${USER} bash -c 'ssh-keygen -t rsa -b 4096 -N "" -C "${USER}@web1.hedras.com" -f ~/.ssh/id_rsa -q -P ""'
    mkdir -p /home/${DOMAIN}/log /var/www/${DOMAIN}
    chown -R ${USER}: /var/www/${DOMAIN}
    chown -R ${USER}: /home/${DOMAIN}/log
    printf "\nexport REPO='${REPO}'\nexport BRANCH='${BRANCH}'\nexport DOMAIN='${DOMAIN}'\n" >> /home/${DOMAIN}/.profile
    if [ "${REPO_UPDATE}" = true ] ; then
        echo "cd /var/www/${DOMAIN} && */5 * * * * git pull origin ${BRANCH} > /dev/null 2>&1" >> /var/spool/cron/crontabs/${USER}
    fi
}

function createvhost(){
echo "<VirtualHost *:80>
  ServerName ${DOMAIN}
  ServerAlias www.${DOMAIN}
  DocumentRoot /var/www/${DOMAIN}${PATH_INDEX}

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

  <Directory /var/www/${DOMAIN}>
   AllowOverride All
   Require all granted

   Options +FollowSymLinks -Indexes
  </Directory>

  CustomLog /home/${DOMAIN}/log/access.log combined
  ErrorLog /home/${DOMAIN}/log/error.log
</VirtualHost>
" > /etc/apache2/sites-available/${DOMAIN}.conf
    /usr/sbin/a2ensite ${DOMAIN}.conf > /dev/null 2>&1
    _info "Apache - Checking the Apache configuration"
    /usr/sbin/apache2ctl configtest > /dev/null 2>&1
    RESULT=$?
    if [ $RESULT -eq 0 ]; then
        _success "Apache - configtest OK"
    else
        _error "Apache - configtest failed"
        exit 1
    fi
    _success "Apache - config reload"
    /etc/init.d/apache2 reload > /dev/null 2>&1
    if [ "${SSL}" = true ]; then
        ssl-create "$@"
    fi
}

function ssl-create(){
    certbot certonly --non-interactive --email floriandjerbi@gmail.com --agree-tos --expand --webroot --webroot-path /var/www/${DOMAIN} --domain ${DOMAIN} --domain www.${DOMAIN}   > /dev/null 2>&1
    RESULT=$?
    if [ $RESULT -eq 0 ]; then
        _success "Apache - SSL create"
    else
        _error "Apache - SSL fail"
        exit 1
    fi

echo "<VirtualHost *:443>
  ServerName ${DOMAIN}
  ServerAlias www.${DOMAIN}
  DocumentRoot /var/www/${DOMAIN}${PATH_INDEX}

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

  <Directory /var/www/${DOMAIN}>
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

    _info "Apache - Checking the Apache SSL configuration"
    /usr/sbin/apache2ctl configtest > /dev/null 2>&1
    RESULT=$?
    if [ $RESULT -eq 0 ]; then
        _success "Apache - configtest OK"
    else
        _error "Apache - configtest failed"
        exit 1
    fi
    _info "Apache - config reload"
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
        _error "GitHub - no repo URL"
    else
        _info "GitHub - repo being cloned"
	git clone --branch ${BRANCH} ${REPO} /var/www/${DOMAIN} > /dev/null 2>&1
        _success "GitHub - repo is cloned"
    fi
    chown -R ${USER}: /var/www/${DOMAIN}
}


function main() {

    check_package "$@"
    init "$@"

    _info "User creation"
    usercreation "$@"
    _success "User has been created"

    _info "Apache - Vhost creation"
    createvhost "$@"
    _success "Apache - Vhost was created"

    _info "Logrotate creation"
    createlogrotate "$@"
    _success "Logrotate was created"

    _info "GitHub - Clone creation"
    createclone "$@"
    _success "GitHub - Clone was created"
}

main "$@"



