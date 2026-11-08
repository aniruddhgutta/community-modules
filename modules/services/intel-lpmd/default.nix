{
  config,
  lib,
  options,
  pkgs,
  ...
}:
let
  cfg = config.services.intel-lpmd;
in
{
  options.services.intel-lpmd = {
    enable = lib.mkEnableOption "[intel-lpmd](${cfg.package.meta.homepage}), the Intel Low Power Mode Daemon";

    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.intel-lpmd.overrideAttrs (old: {
        patches = (old.patches or [ ]) ++ [
          # sd-bus is only needed with systemd as the init system
          ./patches/without-libsystemd.patch

          # fall back to AUTO when there is a bus, but no power-profiles-daemon on it
          ./patches/ppd-auto.patch
          (if cfg.upower.enable then ./patches/upower-null-devices.patch else ./patches/no-upower.patch)
        ];

        buildInputs = lib.subtractLists (
          [ pkgs.systemdLibs ] ++ lib.optional (!cfg.upower.enable) pkgs.upower
        ) old.buildInputs;

        configureFlags =
          lib.filter (f: !lib.hasPrefix "--with-systemdsystemunitdir" f) old.configureFlags
          ++ [
            "--without-libsystemd"
            "--without-systemdsystemunitdir"
          ];
      });
      defaultText = lib.literalExpression "pkgs.intel-lpmd, built without libsystemd and with arrow lake-h support";
      description = ''
        The package to use for `intel_lpmd`.

        The default is `pkgs.intel-lpmd` with a few patches, see the README for the details.
      '';
    };

    upower.enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Whether to build `intel_lpmd` against [upower](${pkgs.upower.meta.homepage}) and wait for
        `upowerd`. It has to be enabled separately with {option}`services.upower.enable`.

        Without it, the AC state is read from `/sys/class/power_supply`, which is all `intel_lpmd`
        uses upower for. The only difference is that a plug or unplug is picked up when the next
        state is applied instead of when it happens. That only matters for configs with per-state
        AC/DC values (the SoC slider, min/max perf percentages), the arrow lake-h one has none.
      '';
    };

    configFile = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = null;
      example = lib.literalExpression "./intel_lpmd_config.xml";
      description = ''
        The config file to pass to `intel_lpmd` with `--config`.

        By default the config matching the CPU model is picked from the ones shipped with the package.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ cfg.package ];

    # the shipped per-model configs, looked up by cpu family and model
    environment.etc."intel_lpmd".source = "${cfg.package}/share/intel-lpmd";

    assertions = [
      {
        assertion = !cfg.upower.enable || (options ? services.upower && config.services.upower.enable);
        message = "`services.intel-lpmd.upower.enable` needs the `upower` service module imported and `services.upower.enable` set";
      }
    ];

    finit.services.intel-lpmd = {
      description = "Intel Low Power Mode Daemon";

      conditions = [
        "service/syslogd/ready"
      ]
      ++ lib.optional cfg.upower.enable "service/upower/ready";

      command = lib.escapeShellArgs (
        [
          (lib.getExe cfg.package)
          "--no-daemon"
        ]
        ++ lib.optionals (cfg.configFile != null) [
          "--config"
          cfg.configFile
        ]
      );

      # the pid lock lives in /var/run/intel_lpmd
      runtime-dir = "intel_lpmd";

      log = true;
    };
  };
}
