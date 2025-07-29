PRs Welcome! Things left to fix:
- [x] Improve error Handling
- [x] Show an "updating" icon while updating
- [x] Add notification icons
- [x] Create a nix flake
- [x] Failed updates populate a detailed error message in the tooltip
- [ ] Make an optional animated spinner while updating
- [x] Remove the additional space at the bottom of the tooltip
- [ ] Look at the fork's way of handling the temp build using a flag vs temp dir
- [ ] Replace ping with an offline and more private network connection checker
- [ ] Add an optional on/off toggle


# waybar-nixos-updates
A Waybar update checking script for NixOS that checks for available updates and displays them in your Waybar.

Here's how the module looks in Waybar with and without updates:

![Screenshot with updates](/resources/screenshot-thumbnail-has-updates.png)
![Screenshot updates](/resources/screenshot-thumbnail-updated.png)

Here's how the module's tooltip looks when updates are available:
![Screenshot with updates](/resources/screenshot-has-updates.png)

Credit goes to [this project](https://github.com/J-Carder/waybar-apt-updates) for the idea and starting point.

## Dependencies:
This script assumes your flake is in ~/.config/nixos and that your flake's nixosConfigurations is named the same as your $hostname. It also uses the following commands/programs:
1. `nix` - Used for `nix flake update` and `nix build` commands
2. `nvd` - Used for comparing system versions (`nvd diff`)

System Requirements:
1. NixOS operating system (based on the nature of the script)
2. A running Waybar instance (the script outputs JSON for Waybar integration)
3. Internet connectivity for performing update checks
4. Desktop notification system compatible with `notify-send`

## How to Use
You can either use the nix flake (default.nix), or install it manually. For a manual installation, download the `update-checker` script, put it in your [PATH](https://unix.stackexchange.com/a/26059) and make it executable (`chmod +x update-checker`). Add the icons to your ~/.icons folder.

### Configuration Options
You can modify these variables at the top of the script to customize behavior:

- `UPDATE_INTERVAL`: Time in seconds between update checks (default: 3599)
- `NIXOS_CONFIG_PATH`: Path to your NixOS configuration (default: ~/.config/nixos)
- `CACHE_DIR`: Directory for storing cache files (default: ~/.cache)
- `SKIP_AFTER_BOOT`: Whether to skip update checks right after boot/resume (default: true)
- `GRACE_PERIOD`: Time in seconds to wait after boot/resume before checking (default: 60)
- `UPDATE_LOCK_FILE`: Whether to update the lock file directly or use a temporary copy (default: false)

### Waybar Integration
To configure, add one of the following configurations to your Waybar config (`~/.config/waybar/config`).

In json (if adding directly to the config file):
```json
"custom/nix-updates": {
    "exec": "$HOME/bin/update-checker", // <--- path to script
    "signal": 12,
    "on-click": "", // refresh on click
    "on-click-right": "rm ~/.cache/nix-update-last-run", // force an update
    "interval": 3600, // refresh every hour
    "tooltip": true,
    "return-type": "json",
    "format": "{} {icon}",
    "format-icons": {
        "has-updates": "󰚰", // icon when updates needed
        "updating": "", // icon when updating
        "updated": "", // icon when all packages updated
        "error": "" // icon when errot occurs
    },
},
```

In nix (if adding it "the nix way" through home-manager):
```nix
"custom/nix-updates" = {
  exec = "$HOME/bin/update-checker";
  signal = 12;
  on-click = "";
  on-click-right = "rm ~/.cache/nix-update-last-run";
  interval = 3600;
  tooltip = true;
  return-type = "json";
  format = "{} {icon}";
  format-icons = {
    has-updates = "󰚰";
    updating = "";
    updated = "";
    error = "";
  };
};
```

To style use the `#custom-nix-updates` ID in your Waybar styles file (`~/.config/waybar/styles.css`). For more information see the [Waybar wiki](https://github.com/Alexays/Waybar/wiki).

### System Integration
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

#### Your Rebuild Script and the REBUILD_FLAG
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

## Additional Information
Some additional things to expect in regards to 1) what notifications you'll receive, 2) what files will be written, 3) and how the script uses your network connection.

### Notifications
These notifications require `notify-send` to be installed on your system. The script sends desktop notifications to keep you informed:
- When starting an update check: "Checking for Updates - Please be patient"
- When throttled due to recent checks: "Please Wait" with time until next check
- When updates are found: "Update Check Complete" with the number of updates
- When no updates are found: "Update Check Complete - No updates available"
- When connectivity fails: "Update Check Failed - Not connected to the internet"
- When an update fails: "Update Check Failed - Check tooltip for detailed error message"

### Cache Files
The script uses several cache files in your ~/.cache directory:
- `nix-update-state`: Stores the current number of available updates
- `nix-update-last-run`: Tracks when the last update check was performed
- `nix-update-tooltip`: Contains the tooltip text with update details
- `nix-update-boot-marker`: Used to detect system boot/resume events
- `nix-update-update-flag`: Signals that your lock file has been updated
- `nix-update-rebuild-flag`: Signals that your system has been rebuilt
- `nix-update-updating-flag`: Signals that an update process is currently performing

### Privacy and Security Considerations
Aside from checking repos for updates, this script uses external network requests to check for internet connectivity.

In regards to external network requests, the script uses `ping -c 1 -W 2 8.8.8.8` to check network connectivity and sends packets to Google's DNS servers (8.8.8.8), which could potentially reveal:
- That your system is running and online
- The fact you're using this specific script
- Your IP address to Google's DNS infrastructure
