{
  description = "A Waybar update checking script for NixOS";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
        
        # The update-checker script package
        waybar-nixos-updates = pkgs.stdenv.mkDerivation {
          pname = "waybar-nixos-updates";
          version = "1.0.0";
          
          src = ./.;
          
          buildInputs = with pkgs; [
            bash
            coreutils
            libnotify
            nvd
          ];
          
          nativeBuildInputs = with pkgs; [
            makeWrapper
          ];
          
          installPhase = ''
            runHook preInstall
            
            # Install the script
            mkdir -p $out/bin
            cp update-checker $out/bin/update-checker
            chmod +x $out/bin/update-checker
            
            # Install icons
            mkdir -p $out/share/icons/waybar-nixos-updates
            cp -r .icons/* $out/share/icons/waybar-nixos-updates/
            
            # Wrap the script with required dependencies
            wrapProgram $out/bin/update-checker \
              --prefix PATH : ${pkgs.lib.makeBinPath [
                pkgs.coreutils
                pkgs.libnotify
                pkgs.nvd
                pkgs.nixVersions.stable
                pkgs.gnugrep
                pkgs.gawk
                pkgs.gnused
                pkgs.procps
                pkgs.systemd
                pkgs.iputils
              ]}
            
            runHook postInstall
          '';
          
          meta = with pkgs.lib; {
            description = "A Waybar update checking script for NixOS";
            homepage = "https://github.com/yourusername/waybar-nixos-updates";
            license = licenses.mit;
            maintainers = [ ];
            platforms = platforms.linux;
          };
        };
      in
      {
        packages = {
          default = waybar-nixos-updates;
          waybar-nixos-updates = waybar-nixos-updates;
        };
        
        apps.default = flake-utils.lib.mkApp {
          drv = waybar-nixos-updates;
          name = "update-checker";
        };
      }) // {
        # Home-Manager module
        homeManagerModules.default = { config, lib, pkgs, ... }:
          with lib;
          let
            cfg = config.programs.waybar-nixos-updates;
          in {
            options.programs.waybar-nixos-updates = {
              enable = mkEnableOption "waybar-nixos-updates";
              
              package = mkOption {
                type = types.package;
                default = self.packages.${pkgs.system}.waybar-nixos-updates;
                defaultText = literalExpression "waybar-nixos-updates";
                description = "The waybar-nixos-updates package to use.";
              };
              
              updateInterval = mkOption {
                type = types.int;
                default = 3600;
                description = "Time in seconds between update checks";
              };
              
              nixosConfigPath = mkOption {
                type = types.str;
                default = "~/.config/nixos";
                description = "Path to your NixOS configuration";
              };
              
              skipAfterBoot = mkOption {
                type = types.bool;
                default = true;
                description = "Whether to skip update checks right after boot/resume";
              };
              
              gracePeriod = mkOption {
                type = types.int;
                default = 60;
                description = "Time in seconds to wait after boot/resume before checking";
              };
              
              updateLockFile = mkOption {
                type = types.bool;
                default = false;
                description = "Whether to update the lock file directly or use a temporary copy";
              };
              
              waybarConfig = mkOption {
                type = types.attrs;
                default = {
                  exec = "${cfg.package}/bin/update-checker";
                  signal = 12;
                  on-click = "";
                  on-click-right = "rm ~/.cache/nix-update-last-run";
                  interval = cfg.updateInterval;
                  tooltip = true;
                  return-type = "json";
                  format = "{} {icon}";
                  format-icons = {
                    has-updates = "󰚰";
                    updating = "";
                    updated = "";
                    error = "";
                  };
                };
                description = "Waybar module configuration for nix-updates";
              };
            };
            
            config = mkIf cfg.enable {
              home.packages = [ cfg.package ];
              
              # Install icons to user's home directory
              home.file.".icons" = {
                source = "${cfg.package}/share/icons/waybar-nixos-updates";
                recursive = true;
              };
              
              # Create a wrapper script with user's configuration
              home.file.".config/waybar/scripts/update-checker" = {
                executable = true;
                text = ''
                  #!/usr/bin/env bash
                  export UPDATE_INTERVAL="${toString cfg.updateInterval}"
                  export NIXOS_CONFIG_PATH="${cfg.nixosConfigPath}"
                  export SKIP_AFTER_BOOT="${if cfg.skipAfterBoot then "true" else "false"}"
                  export GRACE_PERIOD="${toString cfg.gracePeriod}"
                  export UPDATE_LOCK_FILE="${if cfg.updateLockFile then "true" else "false"}"
                  exec ${cfg.package}/bin/update-checker "$@"
                '';
              };
              
              # Note: Users will need to manually add cfg.waybarConfig to their waybar configuration
              # This could be documented in the README
            };
          };
        
        # NixOS module (alternative to home-manager)
        nixosModules.default = { config, lib, pkgs, ... }:
          with lib;
          let
            cfg = config.services.waybar-nixos-updates;
          in {
            options.services.waybar-nixos-updates = {
              enable = mkEnableOption "waybar-nixos-updates";
              
              package = mkOption {
                type = types.package;
                default = self.packages.${pkgs.system}.waybar-nixos-updates;
                defaultText = literalExpression "waybar-nixos-updates";
                description = "The waybar-nixos-updates package to use.";
              };
            };
            
            config = mkIf cfg.enable {
              environment.systemPackages = [ cfg.package ];
            };
          };
      };
}