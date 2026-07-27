# CarPlay Route Guidance Interface Update

This fork adds a CarPlay Route Guidance Interface integration for supported
MHI2Q units.

这个 fork 为受支持的 MHI2Q 车机新增了 CarPlay Route Guidance Interface
集成。

## What changed

## 更新内容

- Added a new `Toolbox/apps/carplay-rgi` application payload.
  新增 `Toolbox/apps/carplay-rgi` 应用文件。
- Added install and restore entries to the MQB navigation green menu.
  在 MQB navigation 绿色工程菜单中新增安装和恢复入口。
- Added `install_carplay_rgi.sh` to copy the CarPlay hook, renderer, atlas, and
  Java helper into the unit.
  新增 `install_carplay_rgi.sh`，用于将 CarPlay hook、renderer、atlas 和 Java
  helper 复制到车机。
- Added `uninstall_carplay_rgi.sh` to restore the backed-up production
  configuration files and remove the installed CarPlay RGI files.
  新增 `uninstall_carplay_rgi.sh`，用于恢复已备份的 production 配置文件，并移除
  已安装的 CarPlay RGI 文件。

## Installation behavior

## 安装行为

The installer checks that the required files are present on the SD card, mounts
the application and system partitions as writable, backs up
`smartphone_integrator.json` and `dio_manager.json`, installs the CarPlay RGI
files, and patches the production configuration needed for route guidance
rendering.

安装脚本会检查 SD 卡上是否存在所需文件，将 application 和 system 分区挂载为可写，
备份 `smartphone_integrator.json` 和 `dio_manager.json`，安装 CarPlay RGI 文件，
并修改路线引导渲染所需的 production 配置。

Backups are stored on the SD card under:

备份会保存在 SD 卡的以下路径：

```text
Backup/<VERSION>/<FAZIT>/CarPlayRGI
```

## Restore behavior

## 恢复行为

The restore script requires the backup created during installation. It restores
the original production JSON files before removing the installed hook, renderer,
atlas, and Java helper.

恢复脚本需要安装时创建的备份。它会先恢复原始 production JSON 文件，然后再移除已安装的
hook、renderer、atlas 和 Java helper。

## Notes

## 注意事项

- This feature is intended for MHI2Q route guidance rendering.
  此功能用于 MHI2Q 路线引导渲染。
- Keep the SD card inserted while running the install or restore action.
  执行安装或恢复操作时，请保持 SD 卡插入车机。
- Reboot the headunit after the script finishes.
  脚本执行完成后，请重启车机。
- As with all toolbox changes, use this carefully and keep your backups.
  与所有 toolbox 修改一样，请谨慎使用并保留备份。
