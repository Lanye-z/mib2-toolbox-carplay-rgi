# MHI2Q CarPlay Route Guidance Toolbox Integration - New

## 中文说明

### 项目简介

本分支用于将最新版 **MHI2Q CarPlay Route Guidance Interface（CarPlay RGI）** 集成到 **MIB2 High Toolbox** 中。

与原有 `carplay-rgi` 安装方式相比，本分支按照新版 `luka-dev/mib2q-carplay-rgi` 的 **smartphone_integrator supervisor** 架构进行部署：不再把 `LD_PRELOAD` 直接写入 `children.carplay.envs`，而是由 `carplay_startup.sh` 启动 `dio_manager` 并仅对该进程加载 `libcarplay_hook.so`，同时由 supervisor 管理 `maneuver_render` 的生命周期。

该分支与原来的 `carplay-rgi` 安装方式相互独立，相关文件、安装脚本、备份目录和 Green Engineering Menu 页面均使用 `carplay-rgi-new` / `CarPlayRGI-new` 命名。

### 基于的项目

本项目整合以下两个开源项目：

1. [luka-dev/mib2q-carplay-rgi](https://github.com/luka-dev/mib2q-carplay-rgi)
   - 提供 CarPlay RGI 核心实现、运行组件以及新版 supervisor 部署脚本。

2. [jilleb/mib2-toolbox](https://github.com/jilleb/mib2-toolbox)
   - 提供 MIB2 High Toolbox、SD 卡部署结构、Green Engineering Menu 以及车机端脚本运行环境。

当前集成以 `MHI2Q-2026-08-30` Release 及对应的 `deploy/smartphone_integrator/` 部署方式为基础。

### 新版部署方式

新版不再在 `smartphone_integrator.json` 的 `children.carplay.envs` 中直接添加：

```text
LD_PRELOAD=/mnt/app/root/hooks/libcarplay_hook.so
```

而是将 `children.carplay` 切换为：

```text
carplay_startup.sh
```

由该启动脚本：

- 启动并维护 `maneuver_render`；
- 处理 CarPlay supervisor 生命周期；
- 在需要时执行受保护的 USB 恢复逻辑；
- 仅在启动 `dio_manager` 前设置 `LD_PRELOAD`；
- 将 supervisor 日志写入 `/tmp/carplay_wrapper.log`。

这种方式可以避免 `libcarplay_hook.so` 被继承到 `/bin/sh`、`maneuver_render` 等不需要加载 hook 的进程。

### Green Engineering Menu 页面

新增独立菜单页面：

`Main > MQBCoding > Customization > CarPlay Route Guidance - New`

包含三个操作：

1. **Install/Update CarPlay Route Guidance - New**
2. **Restore/Uninstall CarPlay Route Guidance - New**
3. **Copy CarPlay RGI New runtime logs to SD-card**

菜单定义文件：

`Toolbox/GEM/mqb-carplayRouteGuidance-new.esd`

旧版 `CarPlay Route Guidance` 页面及其脚本保持不变。

### 安装状态识别

`install_carplay_rgi_new.sh` 在修改车机前会识别当前状态：

| 状态 | 含义 | 处理方式 |
| --- | --- | --- |
| `CLEAN` | 原车状态，旧版和新版均未安装 | 备份原车配置后直接安装 `carplay-rgi-new` |
| `OLD` | 已安装原来的 `carplay-rgi` | 使用旧版原始备份恢复原车，确认恢复成功后再安装新版 |
| `NEW` | 已安装 `carplay-rgi-new` | 保留第一次保存的原车备份，直接覆盖更新新版文件和配置 |
| `INVALID` | 部分安装、OLD/NEW 混合、重复或异常配置 | 拒绝继续修改车机 |

OLD → NEW 的迁移过程也包含在安装事务中。如果新版安装过程中发生错误，脚本会尝试恢复到本次安装开始前的状态。

### 安装位置

新版 CarPlay RGI 会部署以下 7 个文件：

| 组件 | 车机目标位置 |
| --- | --- |
| `libcarplay_hook.so` | `/mnt/app/root/hooks/libcarplay_hook.so` |
| `maneuver_render` | `/mnt/app/root/hooks/maneuver_render` |
| `flag_atlas.rgba` | `/mnt/app/root/hooks/flag_atlas.rgba` |
| `carplay_startup.sh` | `/mnt/app/root/hooks/carplay_startup.sh` |
| `carplay_cleanup.sh` | `/mnt/app/root/hooks/carplay_cleanup.sh` |
| `carplay_processes.sh` | `/mnt/app/root/hooks/carplay_processes.sh` |
| `carplay_hook.jar` | `/mnt/app/eso/hmi/lsd/jars/carplay_hook.jar` |

其中 `carplay_child.json` 仅作为安装模板保存在 SD 卡：

`Toolbox/apps/carplay-rgi-new/carplay_child.json`

安装程序会使用该模板替换 `smartphone_integrator.json` 中的 `children.carplay` 对象，不会把 `carplay_child.json` 单独复制到车机文件系统。

安装程序还会修改：

- `/mnt/system/etc/eso/production/smartphone_integrator.json`
- `/mnt/system/etc/eso/production/dio_manager.json`

`dio_manager.json` 中仍需要注册以下五个 CarPlay RGI 消息 ID：

| 方向 | Message ID |
| --- | --- |
| Accessory → Device | `0x5200` StartRouteGuidanceUpdates |
| Accessory → Device | `0x5203` StopRouteGuidanceUpdates |
| Device → Accessory | `0x5201` RouteGuidanceUpdate |
| Device → Accessory | `0x5202` RouteGuidanceManeuverUpdate |
| Device → Accessory | `0x5204` RouteGuidanceLaneGuidanceInformation |

### 备份与日志

新版安装产生的备份和管理日志统一存放在：

`Backup/<VERSION>/CarPlayRGI-new/`

| 文件 | 用途 |
| --- | --- |
| `smartphone_integrator.json` | 第一次安装 NEW 前保存的原车配置 |
| `dio_manager.json` | 第一次安装 NEW 前保存的原车配置 |
| `smartphone_integrator_new.json` | 最近一次成功安装后的配置副本 |
| `dio_manager_new.json` | 最近一次成功安装后的配置副本 |
| `install_carplay_rgi_new.log` | 安装 / 更新 / OLD → NEW 迁移日志 |
| `uninstall_carplay_rgi_new.log` | 卸载及恢复日志 |
| `carplay_hook.log` | CarPlay hook 运行日志 |
| `maneuver_render.log` | maneuver renderer 运行日志 |
| `carplay_wrapper.log` | 新版 supervisor / wrapper 运行日志 |

旧版备份仍保存在：

`Backup/<VERSION>/CarPlayRGI/`

当安装器检测到 `OLD` 状态时，会先校验这里保存的旧版原车备份，再使用它恢复真正的原车配置。旧版备份不会被 `carplay-rgi-new` 覆盖。

### 卸载方式

`uninstall_carplay_rgi_new.sh` 只使用：

`Backup/<VERSION>/CarPlayRGI-new/`

中第一次保存的原车 `smartphone_integrator.json` 和 `dio_manager.json` 进行恢复。

随后删除新版安装的 7 个文件，并验证配置及文件恢复状态。

安装和卸载脚本均不会覆盖或删除原车：

`/etc/scripts/carplay_cleanup.sh`

新版 `carplay_cleanup.sh` 只会在需要时调用这个原车脚本完成 stock mdnsd / PPS cleanup。

### 日志收集

`collect_carplay_rgi_new_logs.sh` 会收集：

| 车机运行日志 | SD 卡保存位置 |
| --- | --- |
| `/tmp/carplay_hook.log` | `Backup/<VERSION>/CarPlayRGI-new/carplay_hook.log` |
| `/tmp/maneuver_render.log` | `Backup/<VERSION>/CarPlayRGI-new/maneuver_render.log` |
| `/tmp/carplay_wrapper.log` | `Backup/<VERSION>/CarPlayRGI-new/carplay_wrapper.log` |

复制时先写入临时文件，再替换已有日志副本。如果本次运行日志不存在，则保留 SD 卡上已有的上一份日志。

### SD 卡目录结构

```text
Toolbox/
├── apps/
│   ├── carplay-rgi/
│   └── carplay-rgi-new/
│       ├── carplay_hook.jar
│       ├── libcarplay_hook.so
│       ├── maneuver_render
│       ├── flag_atlas.rgba
│       ├── carplay_startup.sh
│       ├── carplay_cleanup.sh
│       ├── carplay_processes.sh
│       └── carplay_child.json
├── GEM/
│   ├── mqb-carplayRouteGuidance.esd
│   └── mqb-carplayRouteGuidance-new.esd
└── scripts/
    ├── install_carplay_rgi.sh
    ├── uninstall_carplay_rgi.sh
    ├── collect_carplay_rgi_logs.sh
    ├── clear_carplay_rgi_logs.sh
    ├── install_carplay_rgi_new.sh
    ├── uninstall_carplay_rgi_new.sh
    └── collect_carplay_rgi_new_logs.sh
```

### 基本使用方法

1. 将完整 Toolbox 文件放入 FAT32 格式 SD 卡。
2. 按 MIB2 High Toolbox 的正常方式安装 / 更新 Toolbox。
3. 保持 Toolbox SD 卡插入车机。
4. 进入 `MQBCoding > Customization > CarPlay Route Guidance - New`。
5. 执行 **Install/Update CarPlay Route Guidance - New**。
6. 等待脚本明确显示安装成功。
7. 文件同步完成后至少等待 30 秒，再重启车机。
8. 如需排查问题，在复现问题后执行日志收集，将三个运行日志复制到 SD 卡。

### 当前 payload 状态

当前分支已包含新版 supervisor 文本文件，但在真正上车安装前，`Toolbox/apps/carplay-rgi-new/` 中还必须存在 `MHI2Q-2026-08-30` Release 的以下四个二进制文件：

| 文件 | 大小 | SHA-256 |
| --- | ---: | --- |
| `carplay_hook.jar` | 178976 | `8031eb73009a8b09fb9c8663b6b08c64ed51cb966ee374cb74845c8090ab8d37` |
| `libcarplay_hook.so` | 300211 | `34dabdcfda933be6bbc8085414f31fe052dded4c0c4a1075e2ac1793dd0f162a` |
| `maneuver_render` | 121738 | `1004dc594a9f408793b91f69f75200ea71088e408caa3a9ed43bde4f6b517b30` |
| `flag_atlas.rgba` | 917504 | `b1985705eabcb0379bed9a5c0055694a4b3db7ac28cef29c57a9d7f2e619dd11` |

如果任一必须文件不存在或为空，安装脚本会直接中止，不修改 production 配置。

### 兼容性与风险提示

- 本功能面向 **Audi MHI2Q** 平台。
- 不建议直接用于 MIB1、MIB2 Standard、MHI2 或其他未经确认的平台。
- 安装前应确认 CarPlay 本身已经可以正常工作。
- OLD → NEW 迁移依赖旧版 `Backup/<VERSION>/CarPlayRGI/` 中保存的原始配置；缺少可靠备份时安装器会拒绝自动迁移。
- 本项目会修改车机持久化系统配置，错误固件、异常断电或不兼容二进制均可能导致功能异常。
- 所有操作均由使用者自行承担风险。

---

## English Description

### Overview

This branch integrates the supervisor-based version of **MHI2Q CarPlay Route Guidance Interface (CarPlay RGI)** into **MIB2 High Toolbox**.

Unlike the legacy `carplay-rgi` deployment, the new architecture does not place `LD_PRELOAD` directly in `children.carplay.envs`. `smartphone_integrator` launches `carplay_startup.sh`, which supervises the renderer and applies `LD_PRELOAD` only to the direct `dio_manager` process.

The legacy and NEW integrations remain separate. NEW files, scripts, backups, and the Green Engineering Menu page use the `carplay-rgi-new` / `CarPlayRGI-new` naming scheme.

### Green Engineering Menu

The NEW page is available at:

`Main > MQBCoding > Customization > CarPlay Route Guidance - New`

It provides three actions:

1. **Install/Update CarPlay Route Guidance - New**
2. **Restore/Uninstall CarPlay Route Guidance - New**
3. **Copy CarPlay RGI New runtime logs to SD-card**

### Installer states

| State | Meaning | Action |
| --- | --- | --- |
| `CLEAN` | Stock configuration | Save original backups and install NEW |
| `OLD` | Legacy `carplay-rgi` installed | Restore the legacy installation to stock, verify it, then install NEW |
| `NEW` | Supervisor-based version already installed | Preserve the original NEW stock backup and overwrite/update NEW |
| `INVALID` | Partial, mixed, duplicated, or malformed state | Abort without intentionally modifying production configuration |

### Installed files

The NEW deployment installs these seven files:

| Component | Destination on the head unit |
| --- | --- |
| `libcarplay_hook.so` | `/mnt/app/root/hooks/libcarplay_hook.so` |
| `maneuver_render` | `/mnt/app/root/hooks/maneuver_render` |
| `flag_atlas.rgba` | `/mnt/app/root/hooks/flag_atlas.rgba` |
| `carplay_startup.sh` | `/mnt/app/root/hooks/carplay_startup.sh` |
| `carplay_cleanup.sh` | `/mnt/app/root/hooks/carplay_cleanup.sh` |
| `carplay_processes.sh` | `/mnt/app/root/hooks/carplay_processes.sh` |
| `carplay_hook.jar` | `/mnt/app/eso/hmi/lsd/jars/carplay_hook.jar` |

`carplay_child.json` remains on the SD card as the template used to replace the `children.carplay` object. It is not installed as a standalone production file.

The installer also modifies:

- `/mnt/system/etc/eso/production/smartphone_integrator.json`
- `/mnt/system/etc/eso/production/dio_manager.json`

### Backup and logs

NEW backups and management logs are stored under:

`Backup/<VERSION>/CarPlayRGI-new/`

| File | Purpose |
| --- | --- |
| `smartphone_integrator.json` | Original stock configuration captured before the first NEW install |
| `dio_manager.json` | Original stock configuration captured before the first NEW install |
| `smartphone_integrator_new.json` | Latest successfully installed configuration copy |
| `dio_manager_new.json` | Latest successfully installed configuration copy |
| `install_carplay_rgi_new.log` | Install/update/migration log |
| `uninstall_carplay_rgi_new.log` | Uninstall/restore log |
| `carplay_hook.log` | Collected hook runtime log |
| `maneuver_render.log` | Collected renderer runtime log |
| `carplay_wrapper.log` | Collected supervisor/wrapper runtime log |

Legacy backups under `Backup/<VERSION>/CarPlayRGI/` are kept untouched and are used only when a verified OLD → NEW migration is required.

### Runtime log collection

| Runtime source | SD-card destination |
| --- | --- |
| `/tmp/carplay_hook.log` | `Backup/<VERSION>/CarPlayRGI-new/carplay_hook.log` |
| `/tmp/maneuver_render.log` | `Backup/<VERSION>/CarPlayRGI-new/maneuver_render.log` |
| `/tmp/carplay_wrapper.log` | `Backup/<VERSION>/CarPlayRGI-new/carplay_wrapper.log` |

### Payload requirement

Before using this branch on a head unit, the four binaries from upstream release `MHI2Q-2026-08-30` must exist in `Toolbox/apps/carplay-rgi-new/`:

- `carplay_hook.jar`
- `libcarplay_hook.so`
- `maneuver_render`
- `flag_atlas.rgba`

The installer aborts before modifying production configuration if any required payload file is missing or empty.

### Warning

This project modifies persistent MHI2Q system configuration. Verify platform and binary compatibility, preserve the generated backups, allow filesystem writes to finish before rebooting, and use it at your own risk.
