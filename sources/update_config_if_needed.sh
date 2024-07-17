#!/bin/bash

set -eu

app=__APP__
YNH_APP_BASEDIR=/etc/yunohost/apps/"$app"
YNH_HELPERS_VERSION=2

pushd /etc/yunohost/apps/$app/conf
source ../scripts/_common.sh
source /usr/share/yunohost/helpers
load_vars

status_dirty=false
for var in $var_list_to_manage; do
    value="$(ynh_app_setting_get --app="$app" --key=previous_$var)"
    if [ "${!var}" != "$value" ]; then
        status_dirty=true
        ynh_print_info --message="The setting '$var' changed. Updating monitorix config."
        break
    fi
done

if "$status_dirty"; then
    install_dir="$(ynh_app_setting_get --app="$app" --key=install_dir)"
    data_dir="$(ynh_app_setting_get --app="$app" --key=data_dir)"
    db_pwd="$(ynh_app_setting_get --app="$app" --key=db_pwd)"
    domain="$(ynh_app_setting_get --app="$app" --key=domain)"
    path="$(ynh_app_setting_get --app="$app" --key=path)"
    port="$(ynh_app_setting_get --app="$app" --key=port)"
    port_nginx_status="$(ynh_app_setting_get --app="$app" --key=port_nginx_status)"

    alerts_email="$(ynh_app_setting_get --app="$app" --key=alerts_email)"
    enable_hourly_view="$(ynh_app_setting_get --app="$app" --key=enable_hourly_view)"
    image_format="$(ynh_app_setting_get --app="$app" --key=image_format)"
    theme_color="$(ynh_app_setting_get --app="$app" --key=theme_color)"
    max_historic_years="$(ynh_app_setting_get --app="$app" --key=max_historic_years)"
    process_priority="$(ynh_app_setting_get --app="$app" --key=process_priority)"

    system_alerts_loadavg_enabled="$(ynh_app_setting_get --app="$app" --key=system_alerts_loadavg_enabled)"
    system_alerts_loadavg_timeintvl="$(ynh_app_setting_get --app="$app" --key=system_alerts_loadavg_timeintvl)"
    system_alerts_loadavg_threshold="$(ynh_app_setting_get --app="$app" --key=system_alerts_loadavg_threshold)"

    disk_alerts_loadavg_enabled="$(ynh_app_setting_get --app="$app" --key=disk_alerts_loadavg_enabled)"
    disk_alerts_loadavg_timeintvl="$(ynh_app_setting_get --app="$app" --key=disk_alerts_loadavg_timeintvl)"
    disk_alerts_loadavg_threshold="$(ynh_app_setting_get --app="$app" --key=disk_alerts_loadavg_threshold)"

    mail_delvd_enabled="$(ynh_app_setting_get --app="$app" --key=mail_delvd_enabled)"
    mail_delvd_timeintvl="$(ynh_app_setting_get --app="$app" --key=mail_delvd_timeintvl)"
    mail_delvd_threshold="$(ynh_app_setting_get --app="$app" --key=mail_delvd_threshold)"
    mail_mqueued_enabled="$(ynh_app_setting_get --app="$app" --key=mail_mqueued_enabled)"
    mail_mqueued_timeintvl="$(ynh_app_setting_get --app="$app" --key=mail_mqueued_timeintvl)"
    mail_mqueued_threshold="$(ynh_app_setting_get --app="$app" --key=mail_mqueued_threshold)"

    emailreports_enabled="$(ynh_app_setting_get --app="$app" --key=emailreports_enabled)"
    emailreports_subject_prefix="$(ynh_app_setting_get --app="$app" --key=emailreports_subject_prefix)"
    emailreports_hour="$(ynh_app_setting_get --app="$app" --key=emailreports_hour)"
    emailreports_minute="$(ynh_app_setting_get --app="$app" --key=emailreports_minute)"

    emailreports_daily_enabled="$(ynh_app_setting_get --app="$app" --key=emailreports_daily_enabled)"
    emailreports_daily_graphs="$(ynh_app_setting_get --app="$app" --key=emailreports_daily_graphs)"
    emailreports_daily_to="$(ynh_app_setting_get --app="$app" --key=emailreports_daily_to)"

    emailreports_weekly_enabled="$(ynh_app_setting_get --app="$app" --key=emailreports_weekly_enabled)"
    emailreports_weekly_graphs="$(ynh_app_setting_get --app="$app" --key=emailreports_weekly_graphs)"
    emailreports_weekly_to="$(ynh_app_setting_get --app="$app" --key=emailreports_weekly_to)"

    emailreports_monthly_enabled="$(ynh_app_setting_get --app="$app" --key=emailreports_monthly_enabled)"
    emailreports_monthly_graphs="$(ynh_app_setting_get --app="$app" --key=emailreports_monthly_graphs)"
    emailreports_monthly_to="$(ynh_app_setting_get --app="$app" --key=emailreports_monthly_to)"

    emailreports_yearly_enabled="$(ynh_app_setting_get --app="$app" --key=emailreports_yearly_enabled)"
    emailreports_yearly_graphs="$(ynh_app_setting_get --app="$app" --key=emailreports_yearly_graphs)"
    emailreports_yearly_to="$(ynh_app_setting_get --app="$app" --key=emailreports_yearly_to)"

    ynh_add_config --jinja --template=monitorix.conf --destination="/etc/monitorix/monitorix.conf"
    ynh_add_config --jinja --template=nginx_status.conf --destination="$nginx_status_conf"
    configure_db

    if "$phpfpm_installed"; then
        config_php_fpm
    fi
    ynh_systemd_action --service_name="$app" --action=restart --log_path='systemd' --line_match=' - Ok, ready.'
    ynh_systemd_action --service_name=nginx --action=reload
    save_vars_current_value
fi
