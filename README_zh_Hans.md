<!--
注意：此 README 由 <https://github.com/YunoHost/apps/tree/master/tools/readme_generator> 自动生成
请勿手动编辑。
-->

# YunoHost 上的 Monitorix

[![集成程度](https://apps.yunohost.org/badge/integration/monitorix)](https://ci-apps.yunohost.org/ci/apps/monitorix/)
![工作状态](https://apps.yunohost.org/badge/state/monitorix)
![维护状态](https://apps.yunohost.org/badge/maintained/monitorix)

[![使用 YunoHost 安装 Monitorix](https://install-app.yunohost.org/install-with-yunohost.svg)](https://install-app.yunohost.org/?app=monitorix)

*[阅读此 README 的其它语言版本。](./ALL_README.md)*

> *通过此软件包，您可以在 YunoHost 服务器上快速、简单地安装 Monitorix。*  
> *如果您还没有 YunoHost，请参阅[指南](https://yunohost.org/install)了解如何安装它。*

## 概况

Monitorix is a free, open source, lightweight system monitoring tool designed to monitor as many services and system resources as possible.

It has been created to be used under production Linux/UNIX servers, but due to its simplicity and small size can be used on embedded devices as well.


**分发版本：** 3.16.0~ynh1

**演示：** <https://www.fibranet.cat/monitorix/>

## 截图

![Monitorix 的截图](./doc/screenshots/mail.png)

## 文档与资源

- 官方应用网站： <https://monitorix.org>
- 官方管理文档： <https://www.monitorix.org/documentation.html>
- 上游应用代码库： <https://github.com/mikaku/Monitorix>
- YunoHost 商店： <https://apps.yunohost.org/app/monitorix>
- 报告 bug： <https://github.com/YunoHost-Apps/monitorix_ynh/issues>

## 开发者信息

请向 [`testing` 分支](https://github.com/YunoHost-Apps/monitorix_ynh/tree/testing) 发送拉取请求。

如要尝试 `testing` 分支，请这样操作：

```bash
sudo yunohost app install https://github.com/YunoHost-Apps/monitorix_ynh/tree/testing --debug
或
sudo yunohost app upgrade monitorix -u https://github.com/YunoHost-Apps/monitorix_ynh/tree/testing --debug
```

**有关应用打包的更多信息：** <https://yunohost.org/packaging_apps>
