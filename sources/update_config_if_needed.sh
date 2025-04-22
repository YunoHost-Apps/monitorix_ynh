#!/bin/bash

set -eu

app=__APP__
YNH_APP_BASEDIR=/etc/yunohost/apps/"$app"
YNH_HELPERS_VERSION=2.1
YNH_APP_ACTION="$1"

pushd /etc/yunohost/apps/$app/conf
source ../scripts/_common.sh
source /usr/share/yunohost/helpers
load_vars

status_dirty=false
for var in $var_list_to_manage; do
    value="$(ynh_app_setting_get --key=previous_$var)"
    if [ "${!var}" != "$value" ]; then
        status_dirty=true
        ynh_print_info "The setting '$var' changed. Updating monitorix config."
        break
    fi
done

if "$status_dirty" || [ "$YNH_APP_ACTION" == upgrade ] || [ "$YNH_APP_ACTION" == remove ]; then
    config_php_fpm
fi

if "$status_dirty"; then
    install_dir="$(ynh_app_setting_get --key=install_dir)"
    data_dir="$(ynh_app_setting_get --key=data_dir)"
    db_pwd="$(ynh_app_setting_get --key=db_pwd)"
    domain="$(ynh_app_setting_get --key=domain)"
    path="$(ynh_app_setting_get --key=path)"
    port="$(ynh_app_setting_get --key=port)"
    port_nginx_status="$(ynh_app_setting_get --key=port_nginx_status)"

    alerts_email="$(ynh_app_setting_get --key=alerts_email)"
    enable_hourly_view="$(ynh_app_setting_get --key=enable_hourly_view)"
    image_format="$(ynh_app_setting_get --key=image_format)"
    theme_color="$(ynh_app_setting_get --key=theme_color)"
    max_historic_years="$(ynh_app_setting_get --key=max_historic_years)"
    process_priority="$(ynh_app_setting_get --key=process_priority)"

    system_alerts_loadavg_enabled="$(ynh_app_setting_get --key=system_alerts_loadavg_enabled)"
    system_alerts_loadavg_timeintvl="$(ynh_app_setting_get --key=system_alerts_loadavg_timeintvl)"
    system_alerts_loadavg_threshold="$(ynh_app_setting_get --key=system_alerts_loadavg_threshold)"

    disk_alerts_loadavg_enabled="$(ynh_app_setting_get --key=disk_alerts_loadavg_enabled)"
    disk_alerts_loadavg_timeintvl="$(ynh_app_setting_get --key=disk_alerts_loadavg_timeintvl)"
    disk_alerts_loadavg_threshold="$(ynh_app_setting_get --key=disk_alerts_loadavg_threshold)"

    mail_delvd_enabled="$(ynh_app_setting_get --key=mail_delvd_enabled)"
    mail_delvd_timeintvl="$(ynh_app_setting_get --key=mail_delvd_timeintvl)"
    mail_delvd_threshold="$(ynh_app_setting_get --key=mail_delvd_threshold)"
    mail_mqueued_enabled="$(ynh_app_setting_get --key=mail_mqueued_enabled)"
    mail_mqueued_timeintvl="$(ynh_app_setting_get --key=mail_mqueued_timeintvl)"
    mail_mqueued_threshold="$(ynh_app_setting_get --key=mail_mqueued_threshold)"

    emailreports_enabled="$(ynh_app_setting_get --key=emailreports_enabled)"
    emailreports_subject_prefix="$(ynh_app_setting_get --key=emailreports_subject_prefix)"
    emailreports_hour="$(ynh_app_setting_get --key=emailreports_hour)"
    emailreports_minute="$(ynh_app_setting_get --key=emailreports_minute)"

    emailreports_daily_enabled="$(ynh_app_setting_get --key=emailreports_daily_enabled)"
    emailreports_daily_graphs="$(ynh_app_setting_get --key=emailreports_daily_graphs)"
    emailreports_daily_to="$(ynh_app_setting_get --key=emailreports_daily_to)"

    emailreports_weekly_enabled="$(ynh_app_setting_get --key=emailreports_weekly_enabled)"
    emailreports_weekly_graphs="$(ynh_app_setting_get --key=emailreports_weekly_graphs)"
    emailreports_weekly_to="$(ynh_app_setting_get --key=emailreports_weekly_to)"

    emailreports_monthly_enabled="$(ynh_app_setting_get --key=emailreports_monthly_enabled)"
    emailreports_monthly_graphs="$(ynh_app_setting_get --key=emailreports_monthly_graphs)"
    emailreports_monthly_to="$(ynh_app_setting_get --key=emailreports_monthly_to)"

    emailreports_yearly_enabled="$(ynh_app_setting_get --key=emailreports_yearly_enabled)"
    emailreports_yearly_graphs="$(ynh_app_setting_get --key=emailreports_yearly_graphs)"
    emailreports_yearly_to="$(ynh_app_setting_get --key=emailreports_yearly_to)"

    ynh_config_add --jinja --template=monitorix.conf --destination="/etc/monitorix/monitorix.conf"
    ynh_config_add --jinja --template=nginx_status.conf --destination="$nginx_status_conf"
    configure_db

    ynh_systemctl --service="$app" --action=restart --log_path=systemd --wait_until=' - Ok, ready.' --timeout=120
    ynh_systemctl --service=nginx --action=reload
    save_vars_current_value
fi
