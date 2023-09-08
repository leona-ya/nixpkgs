{ config, lib, pkgs, ... }:

let
  cfg = config.services.youtrack;
  
  package = cfg.package.override {
    baseStatePath = cfg.statePath;
  };
in
{
  imports = [
    (lib.mkRenamedOptionModule [ "services" "youtrack" "baseUrl" ] [ "services" "youtrack" "settings" "base-url" ])
  ];

  options.services.youtrack = {

    enable = lib.mkEnableOption (lib.mdDoc "YouTrack service");

    address = lib.mkOption {
      description = lib.mdDoc ''
        The interface youtrack will listen on.
      '';
      default = "127.0.0.1";
      type = lib.types.str;
    };

    package = lib.mkOption {
      description = lib.mdDoc ''
        Package to use.
      '';
      type = lib.types.package;
      relatedPackages = [ "youtrack_2022_3" "youtrack_2023_1" ];
    };

    port = lib.mkOption {
      description = lib.mdDoc ''
        The port youtrack will listen on.
      '';
      default = 8080;
      type = lib.types.port;
    };

    statePath = lib.mkOption {
      description = lib.mdDoc ''
        Path were the YouTrack state is stored.
        To this path the base version (e.g. 2023_1) of the used package will be appended.
      '';
      type = lib.types.path;
      default = "/var/lib/youtrack";
    };

    virtualHost = lib.mkOption {
      description = lib.mdDoc ''
        Name of the nginx virtual host to use and setup.
        If null, do not setup anything.
      '';
      default = null;
      type = lib.types.nullOr lib.types.str;
    };

    jvmOpts = lib.mkOption {
      description = lib.mdDoc ''
        Extra options to pass to the JVM.
        See https://www.jetbrains.com/help/youtrack/standalone/Configure-JVM-Options.html
        for more information.
      '';
      type = lib.types.separatedString " ";
      example = "--J-XX:MetaspaceSize=250m";
      default = "";
    };

    maxMemory = lib.mkOption {
      description = lib.mdDoc ''
        Maximum Java heap size
      '';
      type = lib.types.str;
      default = "1g";
    };

    maxMetaspaceSize = lib.mkOption {
      description = lib.mdDoc ''
        Maximum java Metaspace memory.
      '';
      type = lib.types.str;
      default = "350m";
    };

    settings = lib.mkOption {
      type = with lib.types; attrsOf (oneOf [ bool int str ]);
      description = lib.mdDoc ''
        Settings directly set in a YouTrack configuration file.
        See https://www.jetbrains.com/help/youtrack/server/2023.1/YouTrack-Java-Start-Parameters.html
        for more information.
      '';
      example = {
        tls-redirect-from-http = true;
        jetbrains.youtrack.admin.restore = true;
      };
      default = {};
    };
  };

  config = lib.mkIf cfg.enable {
    # XXX: Drop all version feature switches at the point when we consider YT 2022.3 as outdated.
    services.youtrack.package = with pkgs;
      lib.mkDefault (
        if lib.versionOlder config.system.stateVersion "23.11" then youtrack_2022_3
        else youtrack_2023_1
      );

    services.youtrack.settings = {
      listen-address = cfg.address;
      listen-port = toString cfg.port;
    };

    systemd.services.youtrack = let
      service_2022_3 = let
        mergeAttrList = lib.foldl' lib.mergeAttrs {};
        stdParams = mergeAttrList [
          (lib.optionalAttrs (cfg.settings ? base-url && cfg.settings.base-url != null) {
            "jetbrains.youtrack.baseUrl" = cfg.settings.base-url;
          })
          {
          "java.aws.headless" = "true";
          "jetbrains.youtrack.disableBrowser" = "true";
          }
        ];
        extraAttr = lib.concatStringsSep " " (lib.mapAttrsToList (k: v: "-D${k}=${v}") (stdParams // cfg.settings));
      in {
        environment.HOME = cfg.statePath;
        environment.YOUTRACK_JVM_OPTS = "${extraAttr}";
        after = [ "network.target" ];
        wantedBy = [ "multi-user.target" ];
        path = with pkgs; [ unixtools.hostname ];
        serviceConfig = {
          Type = "simple";
          User = "youtrack";
          Group = "youtrack";
          Restart = "on-failure";
          ExecStart = ''${package}/bin/youtrack --J-Xmx${cfg.maxMemory} --J-XX:MaxMetaspaceSize=${cfg.maxMetaspaceSize} ${cfg.jvmOpts} ${cfg.address}:${toString cfg.port}'';
        };
      };
      service_2023_1 = {
        after = [ "network.target" ];
        wantedBy = [ "multi-user.target" ];
        path = with pkgs; [ unixtools.hostname ];
        preStart = ''
          # This detects old (i.e. <= 2022.3) installations that were not migrated yet
          # and migrates them to the new state directory style
          if [[ -d ${cfg.statePath}/teamsysdata ]] && [[ ! -d ${cfg.statePath}/2022_3 ]]
          then
            mkdir -p ${cfg.statePath}/2022_3
            mv ${cfg.statePath}/teamsysdata ${cfg.statePath}/2022_3
            mv ${cfg.statePath}/.youtrack ${cfg.statePath}/2022_3
          fi
          mkdir -p ${cfg.statePath}/${package.baseVersion}/{backups,conf,data,logs,temp}
        '' + lib.optionalString (lib.versionAtLeast package.version "2023.1") ''
          ${package}/bin/youtrack configure -J-Ddisable.configuration.wizard.on.upgrade=true
          ${package}/bin/youtrack configure --listen-port=${toString cfg.port} ${lib.concatStringsSep " " (lib.mapAttrsToList (name: value: "--${name}=${toString value}") cfg.settings )}
        '';
        serviceConfig = lib.mkMerge [
          {
            Type = "simple";
            User = "youtrack";
            Group = "youtrack";
            Restart = "on-failure";
            ExecStart = "${package}/bin/youtrack run --J-Xmx${cfg.maxMemory} --J-XX:MaxMetaspaceSize=${cfg.maxMetaspaceSize} ${cfg.jvmOpts}";
          }
          (lib.mkIf (cfg.statePath == "/var/lib/youtrack") {
            StateDirectory = "youtrack youtrack/${package.baseVersion}";
          })
        ];
      };
    in if lib.versionAtLeast package.version "2023.1" then service_2023_1 else service_2022_3;

    users.users.youtrack = {
      description = "Youtrack service user";
      isSystemUser = true;
      home = cfg.statePath;
      createHome = true;
      group = "youtrack";
    };

    users.groups.youtrack = {};

    services.nginx = lib.mkIf (cfg.virtualHost != null) {
      upstreams.youtrack.servers."${cfg.address}:${toString cfg.port}" = {};
      virtualHosts.${cfg.virtualHost}.locations = {
        "/" = {
          proxyPass = "http://youtrack";
          extraConfig = ''
            client_max_body_size 10m;
            proxy_http_version 1.1;
            proxy_set_header X-Forwarded-Host $http_host;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
          '';
        };

        "/api/eventSourceBus" = {
          proxyPass = "http://youtrack";
          extraConfig = ''
            proxy_cache off;
            proxy_buffering off;
            proxy_read_timeout 86400s;
            proxy_send_timeout 86400s;
            proxy_set_header Connection "";
            chunked_transfer_encoding off;
            client_max_body_size 10m;
            proxy_http_version 1.1;
            proxy_set_header X-Forwarded-Host $http_host;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
          '';
        };
      };
    };
  };

  meta.maintainers = [ lib.maintainers.leona ];
}
