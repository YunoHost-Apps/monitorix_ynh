#=================================================
# SET ALL CONSTANTS
#=================================================

app=$YNH_APP_INSTANCE_NAME

#=================================================
# DEFINE ALL COMMON FONCTIONS
#=================================================

install_dependances() {
	ynh_install_app_dependencies rrdtool perl libwww-perl libmailtools-perl libmime-lite-perl librrds-perl libdbi-perl libxml-simple-perl libhttp-server-simple-perl libconfig-general-perl pflogsumm libxml-libxml-perl
}

get_install_source() {
	ynh_setup_source --dest_dir /tmp

	ynh_package_update
	dpkg --force-confdef --force-confold -i /tmp/app.deb
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

	monitorix_conf=/etc/monitorix/monitorix.conf
	cp ../conf/monitorix.conf $monitorix_conf 
	ynh_replace_string --match_string __SERVICE_PORT__ --replace_string $port --target_file $monitorix_conf
	ynh_replace_string --match_string __YNH_DOMAIN__ --replace_string $domain --target_file $monitorix_conf
	ynh_replace_string --match_string __NGINX_STATUS_PORT__ --replace_string $nginx_status_port --target_file $monitorix_conf
	ynh_replace_string --match_string __YNH_WWW_PATH__/ --replace_string "${path_url%/}/" --target_file $monitorix_conf
	ynh_replace_string --match_string __YNH_WWW_PATH__ --replace_string $path_url --target_file $monitorix_conf
	ynh_replace_string --match_string __MYSQL_USER__ --replace_string $dbuser --target_file $monitorix_conf
	ynh_replace_string --match_string __MYSQL_PASSWORD__ --replace_string $dbpass --target_file $monitorix_conf
	ynh_replace_string --match_string __F2B_ADDITIONAL_JAIL__ --replace_string "$additional_jail" --target_file $monitorix_conf
}

set_permission() {
    chown www-data:root -R /etc/monitorix
    chmod u=rX,g=rwX,o= -R /etc/monitorix
    chown www-data:root -R /var/lib/monitorix
    chmod u=rwX,g=rwX,o= -R /var/lib/monitorix
}
