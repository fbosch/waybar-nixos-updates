# waybar-nixos-updates
A Waybar update checking script for NixOS that checks for available updates and displays them in your Waybar.

Here's how the module looks in Waybar with and without updates:

![Screenshot with updates](/resources/screenshot-thumbnail-has-updates.png)
![Screenshot updates](/resources/screenshot-thumbnail-updated.png)

Here's how the module's tooltip looks when updates are available:
![Screenshot with updates](/resources/screenshot-has-updates.png)

Credit goes to [this project](https://github.com/J-Carder/waybar-apt-updates) for the idea and starting point.

PRs Welcome! Things left to fix:  
- [x] Improve error Handling  
- [x] Show an "updating" icon while updating  
- [ ] Make an optional animated spinner while updating  
- [ ] Remove the additional space at the bottom of the tooltip  
  

## Dependencies:
This script assumes your flake is in ~/.config/nixos and that your flake's nixosConfigurations is named the same as your $hostname.

Commands/Programs:
1. `nix` - Used for `nix flake update` and `nix build` commands
2. `nvd` - Used for comparing system versions (`nvd diff`)

System Requirements:
1. NixOS operating system (based on the nature of the script)
2. A running Waybar instance (the script outputs JSON for Waybar integration)
3. Internet connectivity for performing update checks
4. Desktop notification system compatible with `notify-send`

## Privacy and Security Considerations
External Network Requests: The script uses `ping -c 1 -W 2 8.8.8.8` to check network connectivity and send packets to Google's DNS servers (8.8.8.8), which could potentially reveal:
- That your system is running and online
- The fact you're using this specific script
- Your IP address to Google's DNS infrastructure


## How it Works: Step by Step
1. **Configuration Setup**: Defines update intervals, file paths, and flags to track the update state.

2. **File Initialization**: Creates necessary state files if they don't exist (tracks update count, last check time, and tooltip info).

3. **Boot/Resume Detection**: Detects if the system has recently booted or resumed from suspension/hibernation to avoid unnecessary resource usage during these transition periods.

4. **Grace Period Management**: Applies a configurable grace period after boot or resume before running update checks.

5. **Network Check**: Verifies internet connectivity by pinging 8.8.8.8.

6. **System Update Status**: Checks if the system was recently rebuilt by looking for the rebuild flag.

7. **Update Check Timing**: Determines if it's time to check for updates based on the last check timestamp.

8. **Update Status Tracking**: Uses an updating flag to separate the updating phase from the updated phase.

9. **Temporary Environment**: Creates a temporary directory for performing update checks without modifying the system.

10. **Flake Update**: Runs `nix flake update` either in the config directory or temp directory based on settings.

11. **System Build**: Builds the updated system configuration to compare with the current one.

12. **Update Comparison**: Uses `nvd diff` to compare current system with the new build and count updates.

13. **Result Storage**: Saves the number of updates and detailed update information to state files.

14. **Notification**: Sends desktop notifications to inform the user about the update status.

15. **JSON Output**: Generates a JSON object with update count, status indicator, and tooltip for Waybar.

16. **Flag Management**: Cleans up system update flags if a rebuild was detected.

17. **Error Handling**: Sets appropriate status messages if update checks fail or network is unavailable.

18. **Tooltip Generation**: Creates detailed tooltips showing which packages have updates available.

19. **State Management**: Manages update state across multiple runs of the script.

20. **Output Formatting**: Formats the final output to be compatible with Waybar's custom module format.


## How to Use
Download the `update-checker` script, put it in your [PATH](https://unix.stackexchange.com/a/26059) and make it executable (`chmod +x update-checker`).

### Configuration Options

You can modify these variables at the top of the script to customize behavior:

- `UPDATE_INTERVAL`: Time in seconds between update checks (default: 3599)
- `NIXOS_CONFIG_PATH`: Path to your NixOS configuration (default: ~/.config/nixos)
- `CACHE_DIR`: Directory for storing cache files (default: ~/.cache)
- `SKIP_AFTER_BOOT`: Whether to skip update checks right after boot/resume (default: true)
- `GRACE_PERIOD`: Time in seconds to wait after boot/resume before checking (default: 60)
- `UPDATE_LOCK_FILE`: Whether to update the lock file directly or use a temporary copy (default: false)

#### Cache Files
The script uses several cache files in your ~/.cache directory:
- `nix-update-state`: Stores the current number of available updates
- `nix-update-last-run`: Tracks when the last update check was performed
- `nix-update-tooltip`: Contains the tooltip text with update details
- `nix-update-boot-marker`: Used to detect system boot/resume events
- `nix-update-update-flag`: Signals that your lock file has been updated
- `nix-update-rebuild-flag`: Signals that your system has been rebuilt
- `nix-update-updating-flag`: Signals that an update process is currently performing

### Waybar Integration

To configure, add the following to your Waybar config (`~/.config/waybar/config`).

In json:
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

In nix:
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

To style use the `#custom-nix-updates` ID in your Waybar styles file (`~/.config/waybar/styles.css`).


If you have UPDATE_LOCK_FILE set to "false", the UPDATE_FLAG file will signal that your lock file has been updated. Add the following to your update script, used to update your lock file (i.e. "nix flake update" script), so that the output of nvd diff is piped in:
`| tee >(if grep -qe '\\[U'; then touch \"$HOME/.cache/nix-update-update-flag\"; else rm -f \"$HOME/.cache/nix-update-update-flag\"; fi) &&`

For example:
```nix
checkup =
  "pushd ~/.config/nixos &&
  nix flake update nixpkgs nixpkgs-unstable &&
  nix build .#nixosConfigurations.'hyprnix'.config.system.build.toplevel &&
  nvd diff /run/current-system ./result | tee >(if grep -qe '\\[U'; then touch \"$HOME/.cache/nix-update-update-flag\"; else rm -f \"$HOME/.cache/nix-update-update-flag\"; fi) &&
  popd";
```

The REBUILD_FLAG signals this script to run after your system has been rebuilt. Add this to your update script to create the REBUILD_FLAG and send a signal to waybar to refresh after updating:
`if [ -f \"$HOME/.cache/nix-update-update-flag\" ]; then touch \"$HOME/.cache/nix-update-rebuild-flag\" && pkill -x -RTMIN+12 .waybar-wrapped; fi &&`

This works with the `signal: 12` parameter in the Waybar configuration, which causes Waybar to run the script when it receives RTMIN+12 signal.

### Notifications

The script sends desktop notifications to keep you informed:
- When starting an update check: "Checking for Updates - Please be patient"
- When throttled due to recent checks: "Please Wait" with time until next check
- When updates are found: "Update Check Complete" with the number of updates
- When no updates are found: "Update Check Complete - No updates available"
- When connectivity fails: "Update Check Failed - Not connected to the internet"

These notifications require `notify-send` to be installed on your system.

For example:
```nix
nixup =
  "pushd ~/.config/nixos &&
  echo \"NixOS rebuilding...\" &&
  sudo nixos-rebuild switch --upgrade --flake .#hyprnix &&
  if [ -f \"$HOME/.cache/nix-update-update-flag\" ]; then touch \"$HOME/.cache/nix-update-rebuild-flag\" &&
  pkill -x -RTMIN+12 .waybar-wrapped; fi &&
  popd";
```

For more information see the [Waybar wiki](https://github.com/Alexays/Waybar/wiki).
