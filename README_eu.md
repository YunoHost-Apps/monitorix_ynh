<!--
Ohart ongi: README hau automatikoki sortu da <https://github.com/YunoHost/apps/tree/master/tools/readme_generator>ri esker
EZ editatu eskuz.
-->

# Monitorix YunoHost-erako

[![Integrazio maila](https://dash.yunohost.org/integration/monitorix.svg)](https://ci-apps.yunohost.org/ci/apps/monitorix/) ![Funtzionamendu egoera](https://ci-apps.yunohost.org/ci/badges/monitorix.status.svg) ![Mantentze egoera](https://ci-apps.yunohost.org/ci/badges/monitorix.maintain.svg)

[![Instalatu Monitorix YunoHost-ekin](https://install-app.yunohost.org/install-with-yunohost.svg)](https://install-app.yunohost.org/?app=monitorix)

*[Irakurri README hau beste hizkuntzatan.](./ALL_README.md)*

> *Pakete honek Monitorix YunoHost zerbitzari batean azkar eta zailtasunik gabe instalatzea ahalbidetzen dizu.*  
> *YunoHost ez baduzu, kontsultatu [gida](https://yunohost.org/install) nola instalatu ikasteko.*

## Aurreikuspena

Monitorix is a free, open source, lightweight system monitoring tool designed to monitor as many services and system resources as possible.

It has been created to be used under production Linux/UNIX servers, but due to its simplicity and small size can be used on embedded devices as well.


**Paketatutako bertsioa:** 3.15.0~ynh8

**Demoa:** <https://www.fibranet.cat/monitorix/>

## Pantaila-argazkiak

![Monitorix(r)en pantaila-argazkia](./doc/screenshots/mail.png)

## Dokumentazioa eta baliabideak

- Aplikazioaren webgune ofiziala: <https://monitorix.org>
- Administratzaileen dokumentazio ofiziala: <https://www.monitorix.org/documentation.html>
- Jatorrizko aplikazioaren kode-gordailua: <https://github.com/mikaku/Monitorix>
- YunoHost Denda: <https://apps.yunohost.org/app/monitorix>
- Eman errore baten berri: <https://github.com/YunoHost-Apps/monitorix_ynh/issues>

## Garatzaileentzako informazioa

Bidali `pull request`a [`testing` abarrera](https://github.com/YunoHost-Apps/monitorix_ynh/tree/testing).

`testing` abarra probatzeko, ondorengoa egin:

```bash
sudo yunohost app install https://github.com/YunoHost-Apps/monitorix_ynh/tree/testing --debug
edo
sudo yunohost app upgrade monitorix -u https://github.com/YunoHost-Apps/monitorix_ynh/tree/testing --debug
```

**Informazio gehiago aplikazioaren paketatzeari buruz:** <https://yunohost.org/packaging_apps>
