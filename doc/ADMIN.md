### Remove

Due of the backup core only feature the data directory in `/home/yunohost.app/monitorix` **is not removed**. It must be manually deleted to purge user data from the app.

### More sensor

If you want to see the temperature of some sensor you can install the `lm-sensor` packet. For disk temperature you can instal the `hddtemp` packet.

### Custom config

If you want do custom the monitorix config for more personnal information you can add a file in `/etc/monitorix/conf.d/`. This config file will be overwritte the original config in `/etc/monitorix/monitorix.conf`.

You will have a full complete documentation for monitorix config here : https://www.monitorix.org/documentation.html

By example you can extends the basic config by this :

```xml
<graph_enable>
        disk            = y
        lmsens          = y
        gensens         = y
</graph_enable>

# LMSENS graph
# -----------------------------------------------------------------------------
<lmsens>
        <list>
                core0   = temp1
                core1   =
                mb0     =
                cpu0    =
                fan0    =
                fan1    =
                fan2    =
                volt0   =
                volt1   =
                volt2   =
                volt3   =
                volt4   =
                volt5   =
                volt6   =
                volt7   =
        </list>
</lmsns>

# GENSENS graph
# -----------------------------------------------------------------------------
<gensens>
        <list>
                0 = cpu_temp
                1 = cpu0_freq, cpu1_freq, cpu2_freq, cpu3_freq
        </list>
        <desc>
                cpu_temp = /sys/class/thermal/thermal_zone0/temp
                cpu0_freq = /sys/devices/system/cpu/cpu0/cpufreq/cpuinfo_cur_freq
                cpu1_freq = /sys/devices/system/cpu/cpu1/cpufreq/cpuinfo_cur_freq
                cpu2_freq = /sys/devices/system/cpu/cpu2/cpufreq/cpuinfo_cur_freq
                cpu3_freq = /sys/devices/system/cpu/cpu3/cpufreq/cpuinfo_cur_freq
        </desc>
        <unit>
                cpu_temp = 1000
                cpu0_freq = 0.001
                cpu1_freq = 0.001
                cpu2_freq = 0.001
                cpu3_freq = 0.001
        </unit>
        <map>
                cpu_temp = CPU Temperature
                cpu0_freq = CPU 0 Frequency
                cpu1_freq = CPU 1 Frequency
                cpu2_freq = CPU 2 Frequency
                cpu3_freq = CPU 3 Frequency
        </map>
        <alerts>
            cpu_temp = 300, 65, /etc/monitorix/monitorix_alerts_scripts/cpu_temp.sh
        </alerts>
</gensens>

# DISK graph
# -----------------------------------------------------------------------------
<disk>
        <list>
                0 = /dev/sda
        </list>
        <alerts>
                realloc_enabled = y
                realloc_timeintvl = 0
                realloc_threshold = 1
                realloc_script = /etc/monitorix/monitorix_alerts_scripts/disk_realloc.sh
                pendsect_enabled = y
                pendsect_timeintvl = 0
                pendsect_threshold = 1
                pendsect_script = /etc/monitorix/monitorix_alerts_scripts/disk_pendsect.sh
        </alerts>
</disk>
```

In this config :

- We get the lmsensor sensor data.
- We get some sensors data not accessible with lmsensor (with gensens)
- We check the disk health and send an email if any error happens. For that you need to make some script. An example is available in `/usr/share/doc/monitorix/monitorix-alert.sh`.
