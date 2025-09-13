# 🔄 waybar-nixos-updates
[![License: GPL-3.0](https://img.shields.io/badge/license-GPLv3-blue.svg?style=for-the-badge)](https://opensource.org/licenses/MIT)
[![GitHub stars](https://img.shields.io/github/stars/guttermonk/waybar-nixos-updates?style=for-the-badge)](https://github.com/guttermonk/waybar-nixos-updates/stargazers)

A [Waybar](https://github.com/Alexays/Waybar) update checking script for NixOS that checks for available updates and displays them in your Waybar.

Here's how the module looks in Waybar with and without updates:

![Screenshot with updates](/resources/screenshot-thumbnail-has-updates.png)
![Screenshot updates](/resources/screenshot-thumbnail-updated.png)

Here's how the module's tooltip looks when updates are available:
![Screenshot with updates](/resources/screenshot-has-updates.png)

Credit goes to [this project](https://github.com/J-Carder/waybar-apt-updates) for the idea and starting point.

## 📦 Dependencies

When using the flake, all dependencies are automatically handled. The script requires:

### 🔧 Commands/Programs:
1. `nix` - Used for `nix flake update` and `nix build` commands
2. `nvd` - Used for comparing system versions (`nvd diff`)
3. `notify-send` - For desktop notifications
4. Standard utilities: `bash`, `grep`, `awk`, `sed`, `iproute2` (for `ip` command)

### 💻 System Requirements:
1. NixOS operating system
2. A running Waybar instance (the script outputs JSON for Waybar integration)
3. Internet connectivity for performing update checks
4. Desktop notification system compatible with `notify-send`

### 📋 Configuration Assumptions:
- Your flake is in `~/.config/nixos` (configurable via Home Manager module)
- Your flake's nixosConfigurations is named the same as your `$hostname`

## 🚀 How to Use

### 💿 Installation Methods

This project provides multiple installation methods through its Nix flake:

#### 1. Using the Flake as a Package

Add to your flake inputs:
```nix
{
  inputs.waybar-nixos-updates.url = "github:yourusername/waybar-nixos-updates";
  
  # In your system configuration:
  environment.systemPackages = [
    inputs.waybar-nixos-updates.packages.${system}.default
  ];
}
```

#### 2. Using Home Manager Module (Recommended)

This provides the most flexibility for configuration:

```nix
{
  inputs.waybar-nixos-updates.url = "github:yourusername/waybar-nixos-updates";
  
  # In your home-manager configuration:
  imports = [ inputs.waybar-nixos-updates.homeManagerModules.default ];
  
  programs.waybar-nixos-updates = {
    enable = true;
    updateInterval = 3600;          # Check every hour
    nixosConfigPath = "~/.config/nixos";
    skipAfterBoot = true;           # Skip checks after boot/resume
    gracePeriod = 60;               # Wait 60s after boot
    updateLockFile = false;         # Use temp dir for checks
  };
  
  # Then add to your waybar configuration:
  programs.waybar.settings.mainBar."custom/nix-updates" = 
    config.programs.waybar-nixos-updates.waybarConfig;
}
```

#### 3. Using NixOS Module

For system-wide installation:
```nix
{
  imports = [ inputs.waybar-nixos-updates.nixosModules.default ];
  
  services.waybar-nixos-updates.enable = true;
}
```

#### 4. Using the Legacy default.nix

You can still use the included `default.nix` file with Home Manager:
```nix
imports = [ ./path-to-waybar-nixos-updates/default.nix ];
```

#### 5. Manual Installation

For a manual installation, download the `update-checker` script, put it in your [PATH](https://unix.stackexchange.com/a/26059) and make it executable (`chmod +x update-checker`). Add the icons to your ~/.icons folder.

### ⚙️ Configuration Options
You can modify these variables at the top of the script to customize behavior:

- `UPDATE_INTERVAL`: Time in seconds between update checks (default: 3599)
- `NIXOS_CONFIG_PATH`: Path to your NixOS configuration (default: ~/.config/nixos)
- `CACHE_DIR`: Directory for storing cache files (default: ~/.cache)
- `SKIP_AFTER_BOOT`: Whether to skip update checks right after boot/resume (default: true)
- `GRACE_PERIOD`: Time in seconds to wait after boot/resume before checking (default: 60)
- `UPDATE_LOCK_FILE`: Whether to update the lock file directly or use a temporary copy (default: false)

### 🔄 Toggle Functionality
The script supports toggling update checks on/off. When disabled, it will show the last known state without performing new checks:
- To toggle: Run `update-checker toggle`
- The toggle state is preserved across restarts
- When disabled, the module shows "disabled" state with the last check timestamp

### 🎨 Waybar Integration

If you're using the Home Manager module, the waybar configuration is automatically provided through `config.programs.waybar-nixos-updates.waybarConfig`. Otherwise, configure manually:

To configure manually, add one of the following configurations to your Waybar config (`~/.config/waybar/config`).

In json (if adding directly to the config file):
```json
"custom/nix-updates": {
    "exec": "$HOME/bin/update-checker", // <--- path to script
    "signal": 12,
    "on-click": "$HOME/bin/update-checker toggle", // toggle update checking
    "on-click-right": "rm ~/.cache/nix-update-last-run", // force an update
    "interval": 3600, // refresh every hour
    "tooltip": true,
    "return-type": "json",
    "format": "{} {icon}",
    "format-icons": {
        "has-updates": "󰚰", // icon when updates needed
        "updating": "", // icon when updating
        "updated": "", // icon when all packages updated
        "disabled": "󰚰", // icon when update checking is disabled
        "error": "" // icon when errot occurs
    },
},
```

In nix (if adding it "the nix way" through home-manager):
```nix
"custom/nix-updates" = {
  exec = "$HOME/bin/update-checker";  # Or "${pkgs.waybar-nixos-updates}/bin/update-checker" if using the flake
  signal = 12;
  on-click = "$HOME/bin/update-checker toggle";  # Toggle update checking
  on-click-right = "rm ~/.cache/nix-update-last-run";
  interval = 3600;
  tooltip = true;
  return-type = "json";
  format = "{} {icon}";
  format-icons = {
    has-updates = "󰚰";
    updating = "";
    updated = "";
    disabled = "󰚰";
    error = "";
  };
};
```

**Note:** If using the Home Manager module, you can simply reference the pre-configured waybar settings:
```nix
programs.waybar.settings.mainBar."custom/nix-updates" = 
  config.programs.waybar-nixos-updates.waybarConfig;
```

To style use the `#custom-nix-updates` ID in your Waybar styles file (`~/.config/waybar/styles.css`). For more information see the [Waybar wiki](https://github.com/Alexays/Waybar/wiki).

### 💡 Complete Configuration Example

Here's a complete example of using waybar-nixos-updates with Home Manager:

```nix
# flake.nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    home-manager.url = "github:nix-community/home-manager";
    waybar-nixos-updates.url = "github:yourusername/waybar-nixos-updates";
  };

  outputs = { self, nixpkgs, home-manager, waybar-nixos-updates, ... }: {
    nixosConfigurations.hostname = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        home-manager.nixosModules.home-manager
        {
          home-manager.users.youruser = { config, ... }: {
            imports = [ waybar-nixos-updates.homeManagerModules.default ];
            
            # Enable the waybar-nixos-updates module
            programs.waybar-nixos-updates = {
              enable = true;
              updateInterval = 3600;
              nixosConfigPath = "~/.config/nixos";
              updateLockFile = false;  # Use temp directory for safety
            };
            
            # Configure Waybar
            programs.waybar = {
              enable = true;
              settings = {
                mainBar = {
                  modules-right = [ "custom/nix-updates" "clock" "battery" ];
                  "custom/nix-updates" = config.programs.waybar-nixos-updates.waybarConfig;
                };
              };
              style = ''
                #custom-nix-updates {
                  color: #89b4fa;
                  margin: 0 10px;
                }
                #custom-nix-updates.has-updates {
                  color: #f38ba8;
                  font-weight: bold;
                }
                #custom-nix-updates.updating {
                  color: #f9e2af;
                }
                #custom-nix-updates.disabled {
                  color: #6c7086;
                  opacity: 0.7;
                }
                #custom-nix-updates.error {
                  color: #eba0ac;
                }
              '';
            };
          };
        }
      ];
    };
  };
}
```

### 📤 Flake Outputs

The flake provides the following outputs:

- **packages.default**: The waybar-nixos-updates package with all dependencies
- **homeManagerModules.default**: Home Manager module for user-level configuration
- **nixosModules.default**: NixOS module for system-level installation
- **apps.default**: Direct execution of the update-checker script

### 🔍 Troubleshooting

#### Common Issues and Solutions

1. **Script not finding NixOS configuration**
   - Ensure your configuration is at `~/.config/nixos` or update the `nixosConfigPath` option
   - Verify your hostname matches your nixosConfiguration name: `echo $HOSTNAME`

2. **Icons not displaying**
   - When using Home Manager module, icons are automatically installed to `~/.icons`
   - For manual installation, ensure icons are in `~/.icons/` directory
   - Check that your notification daemon supports PNG icons

3. **Updates not being detected**
   - Check network connectivity: `ping -c 1 8.8.8.8`
   - Verify nvd is installed: `which nvd`
   - Clear cache and force update: `rm ~/.cache/nix-update-* && pkill -RTMIN+12 waybar`

4. **"Check tooltip for detailed error message"**
   - Hover over the waybar module to see the full error
   - Common causes: missing dependencies, flake evaluation errors, network issues

5. **Module shows "updating" indefinitely**
   - Remove the updating flag: `rm ~/.cache/nix-update-updating-flag`
   - Restart waybar: `pkill waybar && waybar &`

6. **Configuration changes not taking effect**
   - When using the wrapper script, restart waybar after rebuilding
   - Verify the correct script is being executed: check waybar config `exec` path

### ⚡ System Integration
You can integrate the updater with your system by modifying your flake update script and your rebuild script to pass the UPDATE_FLAG variable and the REBUILD_FLAG variable, respectively.

#### Your Flake Update Script and the UPDATE_FLAG
You can integrate your system to control the UPDATE_FLAG, which is saved in the "nix-update-update-flag" cache file. If you have UPDATE_LOCK_FILE set to "true", no further action is required. The program will detect if your lock file has been updated. If you have UPDATE_LOCK_FILE set to "false", the "nix-update-update-flag" file will signal that your lock file has been updated.

To integrate the update checker with your system, add the following to the update script you use to update your system's lock file (i.e. your "nix flake update" script), so that the output of nvd diff is piped in:
`| tee >(if grep -qe '\\[U'; then touch \"$HOME/.cache/nix-update-update-flag\"; else rm -f \"$HOME/.cache/nix-update-update-flag\"; fi) &&`

For example, here's my personal flake update script:
```nix
checkup =
  "pushd ~/.config/nixos &&
  nix flake update nixpkgs nixpkgs-unstable &&
  nix build .#nixosConfigurations.'hyprnix'.config.system.build.toplevel &&
  nvd diff /run/current-system ./result | tee >(if grep -qe '\\[U'; then touch \"$HOME/.cache/nix-update-update-flag\"; else rm -f \"$HOME/.cache/nix-update-update-flag\"; fi) &&
  popd";
```

#### 🏗️ Your Rebuild Script and the REBUILD_FLAG
The REBUILD_FLAG, which is saved in the "nix-update-rebuild-flag" cache file, signals this script to run after your system has been rebuilt. Add this to your update script to create the REBUILD_FLAG and send a signal to waybar to refresh after updating:
`if [ -f \"$HOME/.cache/nix-update-update-flag\" ]; then touch \"$HOME/.cache/nix-update-rebuild-flag\" && pkill -x -RTMIN+12 .waybar-wrapped; fi &&`

This works with the `signal: 12` parameter in the Waybar configuration, which causes Waybar to run the script when it receives RTMIN+12 signal.

For another example, here's my personal rebuild script:
```nix
nixup =
  "pushd ~/.config/nixos &&
  echo \"NixOS rebuilding...\" &&
  sudo nixos-rebuild switch --upgrade --flake .#hyprnix &&
  if [ -f \"$HOME/.cache/nix-update-update-flag\" ]; then touch \"$HOME/.cache/nix-update-rebuild-flag\" &&
  pkill -x -RTMIN+12 .waybar-wrapped; fi &&
  popd";
```

## ℹ️ Additional Information
Some additional things to expect in regards to 1) what notifications you'll receive, 2) what files will be written, 3) and how the script uses your network connection.

### 🔔 Notifications
These notifications require `notify-send` to be installed on your system. The script sends desktop notifications to keep you informed:
- When starting an update check: "Checking for Updates - Please be patient"
- When throttled due to recent checks: "Please Wait" with time until next check
- When updates are found: "Update Check Complete" with the number of updates
- When no updates are found: "Update Check Complete - No updates available"
- When connectivity fails: "Update Check Failed - Not connected to the internet"
- When an update fails: "Update Check Failed - Check tooltip for detailed error message"

### 💾 Cache Files
The script uses several cache files in your ~/.cache directory:
- `nix-update-state`: Stores the current number of available updates
- `nix-update-last-run`: Tracks when the last update check was performed
- `nix-update-tooltip`: Contains the tooltip text with update details
- `nix-update-boot-marker`: Used to detect system boot/resume events
- `nix-update-toggle`: Stores the enabled/disabled state for update checking
- `nix-update-update-flag`: Signals that your lock file has been updated
- `nix-update-rebuild-flag`: Signals that your system has been rebuilt
- `nix-update-updating-flag`: Signals that an update process is currently performing

### 🔒 Privacy and Security Considerations
The script checks network connectivity locally using the `ip` command to verify network interfaces and routing tables. This approach:
- Does not send any external network requests for connectivity checking
- Only checks local network configuration (interfaces and routes)
- Performs actual network requests only when fetching updates from configured Nix repositories
- Provides better privacy as no external connectivity checks are performed

## 🤝 Contributing

PRs are welcome! Please test your changes and ensure they work with both the flake installation methods and manual installation.

## 📜 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
