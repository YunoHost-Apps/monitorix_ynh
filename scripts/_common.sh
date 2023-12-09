#=================================================
# SET ALL CONSTANTS
#=================================================

pkg_version="3.15.0-izzy1"
systemd_user=root

nginx_status_conf="/etc/nginx/conf.d/monitorix_status.conf"

#=================================================
# DEFINE ALL COMMON FONCTIONS
#=================================================

install_monitorix_package() {
    # Create the temporary directory
    tempdir="$(mktemp -d)"

    # Download the deb files
    ynh_setup_source --dest_dir="$tempdir" --source_id="main"

    # Install the package
    ynh_package_install "$tempdir/monitorix.deb"

    # The doc says it should be called only once,
    # but the code says multiple calls are supported.
    # Also, they're already installed so that should be quasi instantaneous.
    ynh_install_app_dependencies monitorix="$pkg_version"

    # Mark packages as dependencies, to allow automatic removal
    apt-mark auto monitorix
}

config_monitorix() {
    jail_list=$(fail2ban-client status | grep 'Jail list:' | sed 's/.*Jail list://' | sed 's/,//g')
    f2b_additional_jail=""
    for jail in $jail_list; do
        if ! [[ "$jail" =~ (recidive|pam-generic|yunohost|postfix|postfix-sasl|dovecot|nginx-http-auth|sshd|sshd-ddos) ]]; then
            if [ -z "$f2b_additional_jail" ]; then
                f2b_additional_jail="[$jail]"
            else
                f2b_additional_jail+=", [$jail]"
            fi
        fi
    done

    ynh_add_config --template=../conf/monitorix.conf --destination="/etc/monitorix/monitorix.conf"
}

set_permission() {
    chown www-data:root -R /etc/monitorix
    chmod u=rX,g=rwX,o= -R /etc/monitorix
    chown www-data:root -R /var/lib/monitorix
    chmod u=rwX,g=rwX,o= -R /var/lib/monitorix
}

_ynh_systemd_restart_monitorix() {
    # Reload monitorix
    # While we stop monitorix sometime the built-in web server is not stopped cleanly. So are sure that everything is cleanly stoped by that
    # So this fix that

    ynh_systemd_action --service_name=$app --action="stop" --log_path="systemd"
    sleep 1
    pkill -f "monitorix-httpd listening on" || true
    ynh_systemd_action --service_name="$app" --action="start" --log_path 'systemd' --line_match ' - Ok, ready.'
}
