#=================================================
# SET ALL CONSTANTS
#=================================================

readonly systemd_user=root
readonly nginx_status_conf="/etc/nginx/conf.d/${app}_status.conf"

readonly db_user=$app

readonly var_list_to_manage='mysql_installed postgresql_installed memcached_installed redis_installed phpfpm_installed jail_list mount_parts home_user_dirs php_pools_infos net_gateway net_interface_list'

#=================================================
# DEFINE ALL COMMON FONCTIONS
#=================================================

installed_php_fpm_filter() {
    while read -r item; do
        local version=${item%,*}
        if ynh_package_is_installed --package=php"$version"-fpm; then
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
        speed=$(cat /sys/class/net/"$item"/speed || echo 1000)
        echo "$item,$speed"
    done
}

load_vars() {
    if ynh_package_is_installed --package=mysql; then
        readonly mysql_installed=true
    else
        readonly mysql_installed=false
    fi
    if ynh_package_is_installed --package=postgresql; then
        readonly postgresql_installed=true
    else
        readonly postgresql_installed=false
    fi
    if ynh_package_is_installed --package=memcached; then
        readonly memcached_installed=true
    else
        readonly memcached_installed=false
    fi
    if ynh_package_is_installed --package=redis-server; then
        readonly redis_installed=true
    else
        readonly redis_installed=false
    fi
    if ynh_package_is_installed --package='php*-fpm'; then
        readonly phpfpm_installed=true
    else
        readonly phpfpm_installed=false
    fi
    readonly jail_list="$(fail2ban-client status |
        grep 'Jail list:' | sed 's/.*Jail list://' | sed 's/,//g')"
    readonly mount_parts="$(mount |
        cut -d' '  -f3 |
        grep -E -v '^/run|^/dev|^/proc|^/sys|^/snap')"
    app_data_dirs="$(echo /home/yunohost.app/*)"
    readonly home_user_dirs="$(echo /home/* | home_dir_filter)"
    readonly net_gateway="$(ip --json route show default | jq -r '.[0].dev')"
    readonly net_interface_list="$(ip --json link show | jq -r '.[].ifname | select(. != "lo")' | interface_speed_map)"

    if compgen -G /etc/php/*/fpm/pool.d; then
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
        ynh_app_setting_set --app "$app" --key previous_$var --value "${!var}"
    done
}

install_monitorix_package() {
    # Create the temporary directory
    tempdir="$(mktemp -d)"

    # Download the deb files
    ynh_setup_source --dest_dir="$tempdir" --source_id="main"

    # Install the package
    ynh_package_install "$tempdir/monitorix.deb"
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
        if ynh_package_is_installed --package="php$pool_version-fpm"; then
            ynh_add_jinja_config --template=_php_status.conf --destination="$pool_file"

            chown root:root "$pool_file"
            chmod 444 "$pool_file"
            ynh_systemd_action --service_name="php$pool_version"-fpm.service --action=reload
        else
            if [ -e "$pool_file" ]; then
                ynh_secure_remove --file="$pool_file"
            fi
        fi
    done
}

configure_hooks() {
    ynh_replace_string --match_string=__APP__ --replace_string="$app" --target_file=../hooks/post_iptable_rules
    ynh_replace_string --match_string=__INSTALL_DIR__ --replace_string="$install_dir" --target_file=../hooks/post_app_install
    ynh_replace_string --match_string=__INSTALL_DIR__ --replace_string="$install_dir" --target_file=../hooks/post_app_remove
    ynh_replace_string --match_string=__INSTALL_DIR__ --replace_string="$install_dir" --target_file=../hooks/post_app_upgrade

    cp ../sources/update_config_if_needed.sh "$install_dir"/
    ynh_replace_string --match_string=__APP__ --replace_string="$app" --target_file="$install_dir"/update_config_if_needed.sh
}

configure_alerts_email() {
    ynh_add_config --template=monitorix-alert.sh --destination="$install_dir"/monitorix-alert.sh
    for alias_file in system.loadavg-alert.sh \
                      fs.loadavg-alert.sh \
                      mail.mqueued-alert.sh \
                      mail.delvd-alert.sh
    do
        alias_path="$install_dir/$alias_file"
        if [ ! -h "$alias_path" ]; then
            if [ -e "$alias_path" ]; then
                ynh_secure_remove --file="$alias_path"
            fi
            ln -s "$install_dir/monitorix-alert.sh" "$install_dir/$alias_file"
        fi
    done
}

ensure_vars_set() {
    if [ -z "${db_pwd:-}" ]; then
        db_pwd="$(ynh_string_random 12)"
        ynh_app_setting_set --app="$app" --key=db_pwd --value="$db_pwd"
    fi

    if [ -z "${alerts_email:-}" ]; then
        alerts_email="admins@$domain"
        ynh_app_setting_set --app="$app" --key=alerts_email --value="$alerts_email"
    fi
    if [ -z "${enable_hourly_view:-}" ]; then
        enable_hourly_view=n
        ynh_app_setting_set --app="$app" --key=enable_hourly_view --value="$enable_hourly_view"
    fi
    if [ -z "${image_format:-}" ]; then
        image_format=svg
        ynh_app_setting_set --app="$app" --key=image_format --value="$image_format"
    fi
    if [ -z "${theme_color:-}" ]; then
        theme_color=black
        ynh_app_setting_set --app="$app" --key=theme_color --value="$theme_color"
    fi
    if [ -z "${max_historic_years:-}" ]; then
        max_historic_years=5
        ynh_app_setting_set --app="$app" --key=max_historic_years --value="$max_historic_years"
    fi
    if [ -z "${process_priority:-}" ]; then
        process_priority=0
        ynh_app_setting_set --app="$app" --key=process_priority --value="$process_priority"
    fi

    if [ -z "${system_alerts_loadavg_enabled:-}" ]; then
        system_alerts_loadavg_enabled=n
        ynh_app_setting_set --app="$app" --key=system_alerts_loadavg_enabled --value="$system_alerts_loadavg_enabled"
    fi
    if [ -z "${system_alerts_loadavg_timeintvl:-}" ]; then
        system_alerts_loadavg_timeintvl=3600
        ynh_app_setting_set --app="$app" --key=system_alerts_loadavg_timeintvl --value="$system_alerts_loadavg_timeintvl"
    fi
    if [ -z "${system_alerts_loadavg_threshold:-}" ]; then
        system_alerts_loadavg_threshold=5.0
        ynh_app_setting_set --app="$app" --key=system_alerts_loadavg_threshold --value="$system_alerts_loadavg_threshold"
    fi

    if [ -z "${disk_alerts_loadavg_enabled:-}" ]; then
        disk_alerts_loadavg_enabled=false
        ynh_app_setting_set --app="$app" --key=disk_alerts_loadavg_enabled --value="$disk_alerts_loadavg_enabled"
    fi
    if [ -z "${disk_alerts_loadavg_timeintvl:-}" ]; then
        disk_alerts_loadavg_timeintvl=3600
        ynh_app_setting_set --app="$app" --key=disk_alerts_loadavg_timeintvl --value="$disk_alerts_loadavg_timeintvl"
    fi
    if [ -z "${disk_alerts_loadavg_threshold:-}" ]; then
        disk_alerts_loadavg_threshold=98
        ynh_app_setting_set --app="$app" --key=disk_alerts_loadavg_threshold --value="$disk_alerts_loadavg_threshold"
    fi

    if [ -z "${mail_delvd_enabled:-}" ]; then
        mail_delvd_enabled=n
        ynh_app_setting_set --app="$app" --key=mail_delvd_enabled --value="$mail_delvd_enabled"
    fi
    if [ -z "${mail_delvd_timeintvl:-}" ]; then
        mail_delvd_timeintvl=60
        ynh_app_setting_set --app="$app" --key=mail_delvd_timeintvl --value="$mail_delvd_timeintvl"
    fi
    if [ -z "${mail_delvd_threshold:-}" ]; then
        mail_delvd_threshold=100
        ynh_app_setting_set --app="$app" --key=mail_delvd_threshold --value="$mail_delvd_threshold"
    fi
    if [ -z "${mail_mqueued_enabled:-}" ]; then
        mail_mqueued_enabled=n
        ynh_app_setting_set --app="$app" --key=mail_mqueued_enabled --value="$mail_mqueued_enabled"
    fi
    if [ -z "${mail_mqueued_timeintvl:-}" ]; then
        mail_mqueued_timeintvl=3600
        ynh_app_setting_set --app="$app" --key=mail_mqueued_timeintvl --value="$mail_mqueued_timeintvl"
    fi
    if [ -z "${mail_mqueued_threshold:-}" ]; then
        mail_mqueued_threshold=100
        ynh_app_setting_set --app="$app" --key=mail_mqueued_threshold --value="$mail_mqueued_threshold"
    fi

    if [ -z "${emailreports_enabled:-}" ]; then
        emailreports_enabled=n
        ynh_app_setting_set --app="$app" --key=emailreports_enabled --value="$emailreports_enabled"
    fi
    if [ -z "${emailreports_subject_prefix:-}" ]; then
        emailreports_subject_prefix='Monitorix:'
        ynh_app_setting_set --app="$app" --key=emailreports_subject_prefix --value="$emailreports_subject_prefix"
    fi
    if [ -z "${emailreports_hour:-}" ]; then
        emailreports_hour=0
        ynh_app_setting_set --app="$app" --key=emailreports_hour --value="$emailreports_hour"
    fi
    if [ -z "${emailreports_minute:-}" ]; then
        emailreports_minute=0
        ynh_app_setting_set --app="$app" --key=emailreports_minute --value="$emailreports_minute"
    fi

    if [ -z "${emailreports_daily_enabled:-}" ]; then
        emailreports_daily_enabled=n
        ynh_app_setting_set --app="$app" --key=emailreports_daily_enabled --value="$emailreports_daily_enabled"
    fi
    if [ -z "${emailreports_daily_graphs:-}" ]; then
        emailreports_daily_graphs='system,fs'
        ynh_app_setting_set --app="$app" --key=emailreports_daily_graphs --value="$emailreports_daily_graphs"
    fi
    if [ -z "${emailreports_daily_to:-}" ]; then
        emailreports_daily_to="admins@$domain"
        ynh_app_setting_set --app="$app" --key=emailreports_daily_to --value="$emailreports_daily_to"
    fi

    if [ -z "${emailreports_weekly_enabled:-}" ]; then
        emailreports_weekly_enabled=n
        ynh_app_setting_set --app="$app" --key=emailreports_weekly_enabled --value="$emailreports_weekly_enabled"
    fi
    if [ -z "${emailreports_weekly_graphs:-}" ]; then
        emailreports_weekly_graphs='system,fs'
        ynh_app_setting_set --app="$app" --key=emailreports_weekly_graphs --value="$emailreports_weekly_graphs"
    fi
    if [ -z "${emailreports_weekly_to:-}" ]; then
        emailreports_weekly_to="admins@$domain"
        ynh_app_setting_set --app="$app" --key=emailreports_weekly_to --value="$emailreports_weekly_to"
    fi

    if [ -z "${emailreports_monthly_enabled:-}" ]; then
        emailreports_monthly_enabled=n
        ynh_app_setting_set --app="$app" --key=emailreports_monthly_enabled --value="$emailreports_monthly_enabled"
    fi
    if [ -z "${emailreports_monthly_graphs:-}" ]; then
        emailreports_monthly_graphs='system,fs'
        ynh_app_setting_set --app="$app" --key=emailreports_monthly_graphs --value="$emailreports_monthly_graphs"
    fi
    if [ -z "${emailreports_monthly_to:-}" ]; then
        emailreports_monthly_to="admins@$domain"
        ynh_app_setting_set --app="$app" --key=emailreports_monthly_to --value="$emailreports_monthly_to"
    fi

    if [ -z "${emailreports_yearly_enabled:-}" ]; then
        emailreports_yearly_enabled=n
        ynh_app_setting_set --app="$app" --key=emailreports_yearly_enabled --value="$emailreports_yearly_enabled"
    fi
    if [ -z "${emailreports_yearly_graphs:-}" ]; then
        emailreports_yearly_graphs='system,fs'
        ynh_app_setting_set --app="$app" --key=emailreports_yearly_graphs --value="$emailreports_yearly_graphs"
    fi
    if [ -z "${emailreports_yearly_to:-}" ]; then
        emailreports_yearly_to="admins@$domain"
        ynh_app_setting_set --app="$app" --key=emailreports_yearly_to --value="$emailreports_yearly_to"
    fi
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
