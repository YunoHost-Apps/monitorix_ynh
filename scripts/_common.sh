#=================================================
# SET ALL CONSTANTS
#=================================================

readonly systemd_user=root
readonly nginx_status_conf="/etc/nginx/conf.d/${app}_status.conf"

readonly db_user=$app

readonly var_list_to_manage='mysql_installed postgresql_installed memcached_installed redis_installed phpfpm_installed jail_list mount_parts home_user_dirs net_gateway net_interface_list net_max_speed ssh_port port_infos process_infos php_pools_infos'

#=================================================
# DEFINE ALL COMMON FONCTIONS
#=================================================

installed_php_fpm_filter() {
    while read -r item; do
        local version=${item%,*}
        if _ynh_apt_package_is_installed php"$version"-fpm; then
            echo "$item"
        fi
    done
}

home_dir_filter() {
    while read -r -d' ' item; do
        if [ "$item" != /home/yunohost.app ] && [ "$item" != /home/yunohost.backup ]; then
            echo "$item"
        fi
    done
}

interface_speed_map() {
    while read -r item; do
        speed=$(cat /sys/class/net/"$item"/speed 2>/dev/null || echo 1000)
        if [ "$speed" == -1 ]; then
            speed=1000
        fi
        echo "$item,$speed"
    done
}

load_vars() {
    # Big warning here
    # This function is called by the hook in install/upgrade/remove yunohost operation
    # We we need to ensure that this function the quickest as possible
    # Note that we don't use the yunohost command intentionally for optimization
    if _ynh_apt_package_is_installed mysql || _ynh_apt_package_is_installed mariadb-server; then
        readonly mysql_installed=true
    else
        readonly mysql_installed=false
    fi
    if _ynh_apt_package_is_installed postgresql; then
        readonly postgresql_installed=true
    else
        readonly postgresql_installed=false
    fi
    if _ynh_apt_package_is_installed memcached; then
        readonly memcached_installed=true
    else
        readonly memcached_installed=false
    fi
    if _ynh_apt_package_is_installed redis-server; then
        readonly redis_installed=true
    else
        readonly redis_installed=false
    fi
    if _ynh_apt_package_is_installed 'php*-fpm'; then
        readonly phpfpm_installed=true
    else
        readonly phpfpm_installed=false
    fi
    readonly jail_list="$(fail2ban-client status |
        grep 'Jail list:' | sed 's/.*Jail list://' | sed 's/,//g')"
    readonly mount_parts="$(mount |
        cut -d' '  -f3 |
        grep -E -v '^/run|^/dev|^/proc|^/sys|^/snap|^/$')"
    app_data_dirs="$(echo /home/yunohost.app/*)"
    readonly home_user_dirs="$(echo /home/* | home_dir_filter)"
    readonly net_gateway="$(ip --json route show default | jq -r '.[0].dev')"
    readonly net_interface_list="$(ip --json link show | jq -r '.[].ifname | select(. != "lo")' | interface_speed_map)"
    readonly net_max_speed="$(cat /sys/class/net/*/speed  2>/dev/null | sort | tail -n1 | sed 's|-1|1000|g')"
    readonly ssh_port="$((([ -e /etc/yunohost/settings.yml ] && grep ssh_port /etc/yunohost/settings.yml) || echo 22) | cut -d: -f2 | xargs)"
    readonly port_infos="$(python3 <<EOF
import yaml, socket
hard_coded_ports = ["25", "53", "80", "443", "587", "993"]
with open("/etc/yunohost/firewall.yml", "r") as f:
    firewall = yaml.safe_load(f)
    tcp4_port_list = [str(port) for port in firewall['ipv4']['TCP']
                      if str(port) not in hard_coded_ports]
    tcp6_port_list = [str(port) for port in firewall['ipv6']['TCP']
                      if str(port) not in hard_coded_ports]
    udp4_port_list = [str(port) for port in firewall['ipv4']['UDP']
                      if str(port) not in hard_coded_ports]
    udp6_port_list = [str(port) for port in firewall['ipv6']['UDP']
                      if str(port) not in hard_coded_ports]
with open("/etc/yunohost/services.yml", "r") as f:
    services = yaml.safe_load(f)
    if services is None:
        services = dict()
    port_map = dict()
    for key, value in services.items():
        if 'needs_exposed_ports' in value:
            for port in value['needs_exposed_ports']:
                port_map[str(port)] = key

def generate_port_info(proto, ip_version, port):
    if port in port_map:
        name = port_map[port]
    else:
        try:
            name = socket.getservbyport(int(port), proto)
        except:
            name = "Port_" + port
    return "%s,%s,%s,%s" % (port, ip_version, proto, name)

result = [generate_port_info("tcp", "4", port) for port in tcp4_port_list] + \
         [generate_port_info("tcp", "6", port) for port in tcp6_port_list] + \
         [generate_port_info("udp", "4", port) for port in udp4_port_list] + \
         [generate_port_info("udp", "6", port) for port in udp6_port_list]
result.sort()
print('\n'.join(result))
EOF
)"
    readonly process_infos="$(python3 <<EOF
import yaml, socket
hard_coded_ports = ["25", "53", "80", "443", "587", "993"]
with open("/etc/yunohost/services.yml", "r") as f:
    services = yaml.safe_load(f)
    if services is None:
        services = dict()
    results = ["%s|%s" % (k, v["description"] if "description" in v else k) for k, v in services.items()]
    print('\n'.join(results))
EOF
)"

    if compgen -G /etc/php/*/fpm/pool.d/*; then
        # Note that 'pm.status_listen' option is only supported on php >= 8.0 so we ignore older pools
        readonly php_pools_infos="$(grep -E '^\[.*\]' \
                --exclude=/etc/php/*/fpm/pool.d/"$app"_status.conf \
                --exclude=/etc/php/7.*/fpm/pool.d/* /etc/php/*/fpm/pool.d/* |
            sed -E 's|/etc/php/([[:digit:]]\.[[:digit:]]+)/fpm/pool.d/.+\.conf\:\[(.+)\]|\1,\2|' |
            installed_php_fpm_filter)"
    else
        readonly php_pools_infos=''
    fi
}

# Used by update_config_if_needed.sh hook
save_vars_current_value() {
    for var in $var_list_to_manage; do
        ynh_app_setting_set --key="previous_$var" --value="${!var}"
    done
}

install_monitorix_package() {
    # Create the temporary directory
    tempdir="$(mktemp -d)"

    # Download the deb files
    ynh_setup_source --dest_dir="$tempdir" --source_id="main"

    # Install the package
    _ynh_apt_install "$tempdir/monitorix.deb"
    cp -r /var/lib/monitorix/* "$data_dir"/
}

configure_db() {
    # Here the idea is to monitor available database
    # So if mysql is installed we monitor it but mysql could also not be installed and in this case don't need to monitor it
    # For postgresql it's the same case
    if $mysql_installed && ! ynh_mysql_user_exists --user="$db_user"; then
        ynh_mysql_create_user "$db_user" "$db_pwd"
    fi
    if $postgresql_installed && ! ynh_psql_user_exists --user="$db_user"; then
        ynh_psql_create_user "$db_user" "$db_pwd"
    fi
}

config_php_fpm() {
    for pool_dir_by_version in /etc/php/*; do
        pool_version=$(echo "$pool_dir_by_version" | cut -d/ -f4)
        pool_file="/etc/php/$pool_version/fpm/pool.d/${app}_status.conf"
        if _ynh_apt_package_is_installed "php$pool_version-fpm"; then
            ynh_config_add --jinja --template=_php_status.conf --destination="$pool_file"

            chown root:root "$pool_file"
            chmod 444 "$pool_file"
            ynh_systemctl --service="php$pool_version"-fpm.service --action=reload
        else
            if [ -e "$pool_file" ]; then
                ynh_safe_rm "$pool_file"
            fi
        fi
    done
}

configure_hooks() {
    ynh_replace --match=__APP__ --replace="$app" --file=../hooks/post_iptable_rules
    ynh_replace --match=__INSTALL_DIR__ --replace="$install_dir" --file=../hooks/post_app_install
    ynh_replace --match=__INSTALL_DIR__ --replace="$install_dir" --file=../hooks/post_app_remove
    ynh_replace --match=__INSTALL_DIR__ --replace="$install_dir" --file=../hooks/post_app_upgrade

    cp ../sources/update_config_if_needed.sh "$install_dir"/
    ynh_replace --match=__APP__ --replace="$app" --file="$install_dir"/update_config_if_needed.sh
}

configure_alerts_email() {
    ynh_config_add --template=monitorix-alert.sh --destination="$install_dir"/monitorix-alert.sh
    for alias_file in system.loadavg-alert.sh \
                      fs.loadavg-alert.sh \
                      mail.mqueued-alert.sh \
                      mail.delvd-alert.sh
    do
        alias_path="$install_dir/$alias_file"
        if [ ! -h "$alias_path" ]; then
            if [ -e "$alias_path" ]; then
                ynh_safe_rm "$alias_path"
            fi
            ln -s "$install_dir/monitorix-alert.sh" "$install_dir/$alias_file"
        fi
    done
}

ensure_vars_set() {
    ynh_app_setting_set_default --key=db_pwd --value="$(ynh_string_random --length=12)"
    ynh_app_setting_set_default --key=alerts_email --value="admins@$domain"
    ynh_app_setting_set_default --key=enable_hourly_view --value=n
    ynh_app_setting_set_default --key=image_format --value=svg
    ynh_app_setting_set_default --key=theme_color --value=black
    ynh_app_setting_set_default --key=max_historic_years --value=5
    ynh_app_setting_set_default --key=process_priority --value=0
    ynh_app_setting_set_default --key=system_alerts_loadavg_enabled --value=n
    ynh_app_setting_set_default --key=system_alerts_loadavg_timeintvl --value=3600
    ynh_app_setting_set_default --key=system_alerts_loadavg_threshold --value=5.0
    ynh_app_setting_set_default --key=disk_alerts_loadavg_enabled --value=false
    ynh_app_setting_set_default --key=disk_alerts_loadavg_timeintvl --value=3600
    ynh_app_setting_set_default --key=disk_alerts_loadavg_threshold --value=98
    ynh_app_setting_set_default --key=mail_delvd_enabled --value=n
    ynh_app_setting_set_default --key=mail_delvd_timeintvl --value=60
    ynh_app_setting_set_default --key=mail_delvd_threshold --value=100
    ynh_app_setting_set_default --key=mail_mqueued_enabled --value=n
    ynh_app_setting_set_default --key=mail_mqueued_timeintvl --value=3600
    ynh_app_setting_set_default --key=mail_mqueued_threshold --value=100
    ynh_app_setting_set_default --key=emailreports_enabled --value=n
    ynh_app_setting_set_default --key=emailreports_subject_prefix --value='Monitorix:'
    ynh_app_setting_set_default --key=emailreports_hour --value=0
    ynh_app_setting_set_default --key=emailreports_minute --value=0
    ynh_app_setting_set_default --key=emailreports_daily_enabled --value=n
    ynh_app_setting_set_default --key=emailreports_daily_graphs --value='system,fs'
    ynh_app_setting_set_default --key=emailreports_daily_to --value="admins@$domain"
    ynh_app_setting_set_default --key=emailreports_weekly_enabled --value=n
    ynh_app_setting_set_default --key=emailreports_weekly_graphs --value='system,fs'
    ynh_app_setting_set_default --key=emailreports_weekly_to --value="admins@$domain"
    ynh_app_setting_set_default --key=emailreports_monthly_enabled --value=n
    ynh_app_setting_set_default --key=emailreports_monthly_graphs --value='system,fs'
    ynh_app_setting_set_default --key=emailreports_monthly_to --value="admins@$domain"
    ynh_app_setting_set_default --key=emailreports_yearly_enabled --value=n
    ynh_app_setting_set_default --key=emailreports_yearly_graphs --value='system,fs'
    ynh_app_setting_set_default --key=emailreports_yearly_to --value="admins@$domain"
}

set_permission() {
    chown "$app":root -R /etc/monitorix
    chmod u=rX,g=rwX,o= -R /etc/monitorix
    chown www-data:root -R "$nginx_status_conf"
    chmod u=r,g=r,o= "$nginx_status_conf"
    chown "$app":root "$install_dir"
    chmod u=rwX,g=rwX,o= -R "$install_dir"
    chmod 750 "$install_dir"/monitorix-alert.sh
    chown "$app":root -R /var/log/"$app"
    chmod u=rwX,g=rwX,o= -R /var/log/"$app"

    chmod u=rwx,g=rx,o= "$data_dir"
    chown "$app":www-data "$data_dir"

    chmod u=rwx,g=rx,o= "$data_dir"/*.rrd || true
    chown "$app":root "$data_dir"/*.rrd || true
    find "$data_dir"/{reports,usage} \(   \! -perm -o= \
                                       -o \! -user "$app" \
                                       -o \! -group "$app" \) \
                   -exec chown "$app:$app" {} \; \
                   -exec chmod o= {} \;

    find "$data_dir"/www \(   \! -perm -o= \
                           -o \! -perm -g=rX \
                           -o \! -user "$app" \
                           -o \! -group www-data \) \
                   -exec chown "$app:www-data" {} \; \
                   -exec chmod g+rX,o= {} \;
}
