# CarPlay RGI iOS 27 / Amap V38 Test Package

## 中文说明

此目录提供已验证的 **iOS 27 / 高德地图 V38 融合版**测试文件，Java Build ID 为 `2026-08-30-3c1b5ab`。

`Toolbox/apps/carplay-rgi/` 继续保留原版组件；只有需要测试新版功能时，才使用本目录中的四个文件覆盖 SD 卡上的对应文件。

### 测试文件

四个文件必须作为同一套版本配套使用，不要混用其他版本的 JAR、hook 或 renderer。

| 文件 | SHA-256 |
| --- | --- |
| `carplay_hook.jar` | `94d0356d9a12730aca6dd430552c3aaf15ef9021ce3ddee87a760de966f5ad92` |
| `libcarplay_hook.so` | `87d10f67fbb3dc142642d899977bab0a6eb4009f61d3bcd873d0cce9e01511f7` |
| `maneuver_render` | `f86c7a44288d55c352837b3432874cf81836431929e625e7cded42d5664e993e` |
| `flag_atlas.rgba` | `b1985705eabcb0379bed9a5c0055694a4b3db7ac28cef29c57a9d7f2e619dd11` |

### 如何替换和测试

1. 先准备一张完整的 Toolbox SD 卡，并保留其中原版 `Toolbox/apps/carplay-rgi/` 的备份。
2. 将本 `test/` 目录中的四个文件完整复制到 SD 卡的 `Toolbox/apps/carplay-rgi/`，覆盖同名文件并保持文件名不变。
3. 将 SD 卡插入车机，进入 `MQBCoding > Customization > CarPlay Route Guidance`。
4. 执行 **Install/Update CarPlay Route Guidance Interface**，等待脚本明确提示成功。
5. 文件写入结束后至少等待 30 秒，再重启车机并测试导航。
6. 如需恢复原版，将备份的四个原版文件放回 SD 卡目录，再次执行安装/更新。

### 主要修改与优化

- 适配 iOS 26.5.1 及以上版本中第三方导航数据格式和更新时序的变化，并针对高德地图加入 V38 兼容处理。
- 优化路径代际、物理 maneuver head 对齐、距离新鲜度、短暂 inactive 状态和 maneuver rollover，减少箭头提前清除、错误跳转及距离冻结。
- 支持零距离首帧启动，并保留中国区显示距离、左右掉头判别、renderer 首帧预加载及原车导航接管等改进。

该测试包仅面向已正常启用 CarPlay 的兼容 Audi MHI2Q 主机。安装和固件修改存在风险，请自行确认兼容性并保留完整备份。

---

## English

This directory contains the verified **iOS 27 / Amap V38 merged test build**, with Java Build ID `2026-08-30-3c1b5ab`.

The original components remain in `Toolbox/apps/carplay-rgi/`. Use the four files in this directory only when you intentionally want to test the newer build on the Toolbox SD card.

### Test Files

Treat all four files as one matched release set. Do not mix the JAR, hook, or renderer with files from another version.

| File | SHA-256 |
| --- | --- |
| `carplay_hook.jar` | `94d0356d9a12730aca6dd430552c3aaf15ef9021ce3ddee87a760de966f5ad92` |
| `libcarplay_hook.so` | `87d10f67fbb3dc142642d899977bab0a6eb4009f61d3bcd873d0cce9e01511f7` |
| `maneuver_render` | `f86c7a44288d55c352837b3432874cf81836431929e625e7cded42d5664e993e` |
| `flag_atlas.rgba` | `b1985705eabcb0379bed9a5c0055694a4b3db7ac28cef29c57a9d7f2e619dd11` |

### Replacement and Testing

1. Prepare a complete Toolbox SD card and back up its original `Toolbox/apps/carplay-rgi/` directory.
2. Copy all four files from this `test/` directory into `Toolbox/apps/carplay-rgi/` on the SD card, overwriting the matching names without renaming them.
3. Insert the SD card and open `MQBCoding > Customization > CarPlay Route Guidance`.
4. Run **Install/Update CarPlay Route Guidance Interface** and wait for an explicit success message.
5. After file operations finish, wait at least 30 seconds before rebooting the head unit and testing navigation.
6. To restore the original build, copy the four backed-up original files to the SD card and run the install/update action again.

### Main Changes and Optimizations

- Adapts to third-party navigation data-format and update-timing changes on iOS 26.5.1 and later, with Amap-specific V38 compatibility handling.
- Improves route generations, physical maneuver-head alignment, distance freshness, transient inactive states, and maneuver rollover to reduce premature arrow clearing, incorrect jumps, and frozen distances.
- Supports zero-distance first-frame startup while retaining China-specific display thresholds, left/right U-turn detection, renderer first-frame preload, and stock-navigation handoff improvements.

This test package targets compatible Audi MHI2Q units with working CarPlay. Installation and firmware modification involve risk; verify compatibility and keep complete backups.
