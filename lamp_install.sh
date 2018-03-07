#!/bin/bash

root_check() {
    # Runs 'id -u' to force the user to run as root
    if [ $(id -u) != 0 ]; then
        echo 'Must be runned as root!'
        exit 1
    fi
}

distro_check() {
    # Reads /etc/issue to find out the distro and saves it as a variable
    distro=$(cat /etc/issue | tr -d '\n' | awk '{print $1}')
    # If the distro is ubuntu or debian, using apt
    if [[ $distro == [uU]buntu || [dD]ebian ]]; then
        echo 'Found OS, using: apt'
        deb_install
    # If the distro is redhat or centos, using yum
    elif [[ $distro =~ [cC]ent\(os|OS\) || [rR]ed ]]; then
        echo 'Found OS, using: yum'
        red_install
    else
        # If the distro doesn't match, exits
        echo 'Distrobution not supported'
        exit 1
    fi
}

tls_check() {
    # This only works for debian, have not added redhat support
    read -p 'Do you want to enable SSL/TLS?(y/n): ' tls
    case $tls in
        [yY] ) echo 'Enabling TLS..'
               a2enmod ssl
               a2ensite default-ssl.conf
               systemctl restart apache2
               systemctl reload apache2
               ;;
        [nN] ) echo 'Skipping TLS'
               return 0
               ;;
        # If not Y/y or N/n is entered, calls the function again to not exit
        * )    echo 'Enter Y/y or N/n..'
               tls_check
               ;;
    esac
}

ip_check() {
    # Try to find the ip address of the machine
    if [ $(command -v ip) ]; then
        # If found, adds it as a variable and prints it to be able to make it as a global variable
        ip=$(ip route get 8.8.8.8 | awk 'NR==1 {print $NF}')
        echo $ip
        return 0
    else
        # Else, just uses YOUR_IP
        echo 'YOUR_IP'
        return 0
    fi
}

deb_install() {
    # Installing for debian-based, first update and upgrade
    apt update && apt upgrade -y
    apt install apache2 -y
    systemctl start apache2
    # Install TLS if the user wants
    tls_check
    # Enabling apache at boot
    systemctl enable apache2
    # Installing php7.1
    apt install php7.1 libapache2-mod-php7.1 php7.1-mysql php7.1-xml php7.1-gd -y
    # Adding /info.php to the website for test
    printf '<?php\nphpinfo();\n?>\n' > /var/www/html/info.php
    systemctl restart apache2
    # Installing MariaDB
    apt install mariadb-server mariadb-client -y
    echo '**************************'
    echo 'USER INTERACTION REQUIRED!'
    echo '**************************'
    # MariaDB configuration
    mysql_secure_installation
    systemctl restart mysql
    echo '****************************************************'
    echo 'Everything has finished installing..'
    echo Visit https://$ip_addr/info.php to check if it works
    echo '****************************************************'
}

red_install() {
    # Installing for redhat-based
    yum -y update
    # Installing apache
    yum install httpd openssl mod_ssl -y
    # Starting and enabling apache at start
    systemctl start httpd
    systemctl enable httpd
    # Installing PHP
    yum install php php-mysql php-xml php-gd -y
    # Adding /info.php to the website for test
    printf '<?php\nphpinfo();\n?>\n' > /var/www/html/info.php
    systemctl restart apache2
    # Install MariaDB
    yum install mariadb mariadb-server mariadb-client mysql
    echo '**************************'
    echo 'USER INTERACTION REQUIRED!'
    echo '**************************'
    # MariaDB configuration
    mysql_secure_installation
    systemctl restart mariadb

    echo '*************************************************************************************'
    echo Visit https://$ip_addr/info.php to check if it works
    echo 'To enable SSL/TLS, see: https://www.server-world.info/en/note?os=CentOS_7&p=httpd&f=7'
    echo '*************************************************************************************'

}

main() {
    # Calls all the functions and sets the echoed value from 'distro_check' as the packagemanager
    root_check
    ip_addr=$(ip_check)
    distro_check
}
main
