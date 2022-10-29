#!/bin/bash

#=================================================
# COMMON VARIABLES
#=================================================

# dependencies used by the app
pkg_dependencies="rrdtool perl libwww-perl libmailtools-perl libmime-lite-perl librrds-perl libdbi-perl libxml-simple-perl libhttp-server-simple-perl libconfig-general-perl pflogsumm libxml-libxml-perl"

#=================================================
# DEFINE ALL COMMON FONCTIONS
#=================================================

get_install_source() {
	ynh_setup_source --dest_dir /$tempdir

	ynh_package_update
	dpkg --force-confdef --force-confold -i /$tempdir/app.deb
	ynh_secure_remove --file=/etc/monitorix/conf.d/00-debian.conf
	ynh_package_install -f
}

config_nginx() {
    ynh_add_nginx_config

    # Add special hostname for monitorix status
	nginx_status_conf="/etc/nginx/conf.d/monitorix_status.conf"
	cp ../conf/nginx_status.conf $nginx_status_conf
	ynh_replace_string --match_string __PORT__ --replace_string $nginx_status_port --target_file $nginx_status_conf

    systemctl reload nginx
}

config_monitorix() {
    jail_list=$(fail2ban-client status | grep 'Jail list:' | sed 's/.*Jail list://' | sed 's/,//g')
    additional_jail=""
    for jail in $jail_list; do
        if ! [[ "$jail" =~ (recidive|pam-generic|yunohost|postfix|postfix-sasl|dovecot|nginx-http-auth|sshd|sshd-ddos) ]]; then
            if [ -z "$additional_jail" ]; then
                additional_jail="[$jail]"
            else
                additional_jail+=", [$jail]"
            fi
        fi
    done

	path_url_slash_less=${path_url%/}
	ynh_add_config --template="../conf/monitorix.conf" --destination="/etc/monitorix/monitorix.conf"
}

set_permission() {
    chown www-data:root -R /etc/monitorix
    chmod u=rX,g=rwX,o= -R /etc/monitorix
    chown www-data:root -R /var/lib/monitorix
    chmod u=rwX,g=rwX,o= -R /var/lib/monitorix
}
