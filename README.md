<!--
N.B.: This README was automatically generated by https://github.com/YunoHost/apps/tree/master/tools/README-generator
It shall NOT be edited by hand.
-->

# Monitorix for YunoHost

[![Integration level](https://dash.yunohost.org/integration/monitorix.svg)](https://dash.yunohost.org/appci/app/monitorix) ![Working status](https://ci-apps.yunohost.org/ci/badges/monitorix.status.svg) ![Maintenance status](https://ci-apps.yunohost.org/ci/badges/monitorix.maintain.svg)

[![Install Monitorix with YunoHost](https://install-app.yunohost.org/install-with-yunohost.svg)](https://install-app.yunohost.org/?app=monitorix)

*[Lire ce readme en français.](./README_fr.md)*

> *This package allows you to install Monitorix quickly and simply on a YunoHost server.
If you don't have YunoHost, please consult [the guide](https://yunohost.org/#/install) to learn how to install it.*

## Overview

Monitorix is a free, open source, lightweight system monitoring tool designed to monitor as many services and system resources as possible.

It has been created to be used under production Linux/UNIX servers, but due to its simplicity and small size can be used on embedded devices as well.


**Shipped version:** 3.15.0~ynh3

**Demo:** https://www.fibranet.cat/monitorix/

## Screenshots

![Screenshot of Monitorix](./doc/screenshots/mail.png)

## Documentation and resources

* Official app website: <https://monitorix.org>
* Official admin documentation: <https://www.monitorix.org/documentation.html>
* Upstream app code repository: <https://github.com/mikaku/Monitorix>
* YunoHost Store: <https://apps.yunohost.org/app/monitorix>
* Report a bug: <https://github.com/YunoHost-Apps/monitorix_ynh/issues>

## Developer info

Please send your pull request to the [testing branch](https://github.com/YunoHost-Apps/monitorix_ynh/tree/testing).

To try the testing branch, please proceed like that.

``` bash
sudo yunohost app install https://github.com/YunoHost-Apps/monitorix_ynh/tree/testing --debug
or
sudo yunohost app upgrade monitorix -u https://github.com/YunoHost-Apps/monitorix_ynh/tree/testing --debug
```

**More info regarding app packaging:** <https://yunohost.org/packaging_apps>
