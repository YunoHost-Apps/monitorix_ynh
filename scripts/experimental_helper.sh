# Create a dedicated config file from a jinja template
#
# usage: ynh_add_jinja_config --template="template" --destination="destination"
# | arg: -t, --template=     - Template config file to use
# | arg: -d, --destination=  - Destination of the config file
# | arg: -i, --ignore_vars=  - List separated by space of script variables to ignore and don't pass in the jinja context.
# |                            This could be useful mainly for special share which can't be retried by reference name (like the array).
#
# examples:
#    ynh_add_jinja_config --template="app.conf" --destination="$install_dir/app.conf"
#    ynh_add_jinja_config --template="app-env" --destination="$install_dir/app-env" --ignore_vars="complex_array yolo"
#
# The template can be by default the name of a file in the conf directory
#
# The helper will verify the checksum and backup the destination file
# if it's different before applying the new template.
#
# And it will calculate and store the destination file checksum
# into the app settings when configuration is done.
#
##
## About the variables passed to the template:
##
#
# All variable defined in the script are available into the template (as string) except someone described below.
# If a variable make crash the helper for some reason (by example if the variable is of type array)
# or you just want to don't pass a specific variable for some other reason you can add it in the '--ignore_vars=' parameter as described above.
# Here are the list of ignored variable and so there won't never be available in the template:
# - All system environment variable like (TERM, USER, PATH, LANG, etc).
#   If you need someone you just need to declare an other variable with the same value.
#   Note that all Yunohost variable whose name begins by 'YNH_' are available and can be used in the template.
# - This following list:
#        legacy_args args_array template destination ignore_vars template_path python_env_var ignore_var_regex
#        progress_scale progress_string0 progress_string1 progress_string2
#        old changed binds types file_hash formats
#
##
## Usage in templates:
##
#
# For a full documentation of the template you can refer to: https://jinja.palletsprojects.com/en/3.1.x/templates/
# In Yunohost context there are no really some specificity except that all variable passed are of type string.
# So here are some example of recommended usage:
#
# If you need a conditional block
#
# {% if should_my_block_be_shown == 'true' %}
# ...
# {% endif %}
#
# or
#
# {% if should_my_block_be_shown == '1' %}
# ...
# {% endif %}
#
# If you need to iterate with loop:
#
# {% for yolo in var_with_multiline_value.splitlines() %}
# ...
# {% endfor %}
#
# or
#
# {% for jail in my_var_with_coma.split(',') %}
# ...
# {% endfor %}
#
ynh_add_jinja_config() {
    # Declare an array to define the options of this helper.
    local legacy_args=tdi
    local -A args_array=([t]=template= [d]=destination= [i]=ignore_vars= )
    local template
    local destination
    local ignore_vars
    # Manage arguments with getopts
    ynh_handle_getopts_args "$@"
    local template_path

    #
    ## List of all vars ignored and not passed to the template
    # WARNING Update the list on the helper documentation at the top of the helper, if you change this list
    #

    # local vars used in the helper
    ignore_vars+=" legacy_args args_array template destination ignore_vars template_path python_env_var ignore_var_regex"
    # yunohost helpers
    ignore_vars+=" progress_scale progress_string0 progress_string1 progress_string2"
    # Arrays used in config panel
    ignore_vars+=" old changed binds types file_hash formats"

    if [ -f "$YNH_APP_BASEDIR/conf/$template" ]; then
        template_path="$YNH_APP_BASEDIR/conf/$template"
    elif [ -f "$template" ]; then
        template_path=$template
    else
        ynh_die --message="The provided template $template doesn't exist"
    fi

    ynh_backup_if_checksum_is_different --file="$destination"

    # Make sure to set the permissions before we copy the file
    # This is to cover a case where an attacker could have
    # created a file beforehand to have control over it
    # (cp won't overwrite ownership / modes by default...)
    touch "$destination"
    chown root:root "$destination"
    chmod 640 "$destination"

    local python_env_var=''
    local ignore_var_regex
    ignore_var_regex="$(echo "$ignore_vars" | sed -E 's@^\s*(.*\w)\s*$@\1@g' | sed -E 's@(\s+)@|@g')"
    while read -r one_var; do
        # Blacklist of var to not pass to template
        if { [[ "$one_var" =~ ^[A-Z0-9_]+$ ]] && [[ "$one_var" != YNH_* ]]; } \
            || [[ "$one_var" =~ ^($ignore_var_regex)$ ]]; then
            continue
        fi
        # Well python is very bad for the last character on raw string
        # https://stackoverflow.com/questions/647769/why-cant-pythons-raw-string-literals-end-with-a-single-backslash
        # So the solution here is to add one last char '-' so we know what it is
        # and we are sure that it not \ or ' or something else which will be problematic with python
        # And then we remove it while we are processing
        python_env_var+="$one_var=r'''${!one_var}-'''[:-1],"
    done <<< "$(compgen -v)"

    _ynh_apply_default_permissions "$destination"
    (
        python3 -c 'import os, sys, jinja2; sys.stdout.write(
                    jinja2.Template(source=sys.stdin.read(),
                                    undefined=jinja2.StrictUndefined,
                    ).render('"$python_env_var"'));' <"$template_path" >"$destination"
    )
    ynh_store_file_checksum --file="$destination"
}
