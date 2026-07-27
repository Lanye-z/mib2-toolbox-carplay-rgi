# CarPlay Route Guidance Interface Update

This fork adds a CarPlay Route Guidance Interface integration for supported
MHI2Q/MU1316 units.

## What changed

- Added a new `Toolbox/apps/carplay-rgi` application payload.
- Added install and restore entries to the MQB navigation green menu.
- Added `install_carplay_rgi.sh` to copy the CarPlay hook, renderer, atlas, and
  Java helper into the unit.
- Added `uninstall_carplay_rgi.sh` to restore the backed-up production
  configuration files and remove the installed CarPlay RGI files.

## Installation behavior

The installer checks that the required files are present on the SD card, mounts
the application and system partitions as writable, backs up
`smartphone_integrator.json` and `dio_manager.json`, installs the CarPlay RGI
files, and patches the production configuration needed for route guidance
rendering.

Backups are stored on the SD card under:

```text
Backup/<VERSION>/<FAZIT>/CarPlayRGI
```

## Restore behavior

The restore script requires the backup created during installation. It restores
the original production JSON files before removing the installed hook, renderer,
atlas, and Java helper.

## Notes

- This feature is intended for MHI2Q/MU1316 route guidance rendering.
- Keep the SD card inserted while running the install or restore action.
- Reboot the headunit after the script finishes.
- As with all toolbox changes, use this carefully and keep your backups.
