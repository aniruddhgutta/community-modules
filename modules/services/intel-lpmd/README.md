# intel-lpmd

Service module for [intel-lpmd](https://github.com/intel/intel-lpmd), the Intel
Low Power Mode Daemon. It parks the performance cores of hybrid Intel CPUs
(Alder Lake and newer) while the workload is idle or light and gives them back
when it isn't.

## usage

The config is picked by cpu family and model from the ones shipped with the
package. To use your own, set `configFile`.

## package

The default package is `pkgs.intel-lpmd` with these patches, all of them apply
to nixpkgs' pin and to upstream `main`:

- `without-libsystemd.patch`: adds `--without-libsystemd`. sd-bus is only used
  by Mode 0 and process classification, both talk to the systemd manager, which
  doesn't exist here. Mode 1 writes the cgroup files directly and is not
  affected, Mode 0 fails at startup.
- `ppd-auto.patch`: `intel_lpmd` only runs in AUTO if it fails to connect to
  power-profiles-daemon. With a bus but without ppd the connection succeeds
  anyway, and it stays idle. `ppd` is not required, nothing here starts it.
- `no-upower.patch` or `upower-null-devices.patch`, depending on
  `upower.enable`. With the latter, `services.upower` has to be imported and
  enabled by you, the module doesn't touch it.

## notes

- Per-state EPP/EPB in the config are written on every WLT transition, on AC and
  on battery. If you use `tlp` or anything else that sets EPP, either let one of
  them own it or set the state's EPP/EPB to `-1` in your own `configFile`.
- The `*Def` values of a config are only read when power-profiles-daemon is
  running. Without it `intel_lpmd` always runs in AUTO.
- The daemon runs without its dbus interface, so `intel_lpmd_control` doesn't
  work.
