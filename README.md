# waybar-nixos-updates
A Waybar update checking script for NixOS.

Here's how the module looks in Waybar with and without updates:
![Screenshot with updates](/resources/screenshot-thumbnail-has-updates.png)
![Screenshot updates](/resources/screenshot-thumbnail-updated.png)

Here's how the module's tooltip looks when updates are available:
![Screenshot with updates](/resources/screenshot-has-updates.png)

Credit goes to [this project](https://github.com/J-Carder/waybar-apt-updates) for the idea and starting point.


## Dependencies:
This script assumes your flake is in ~/.config/nixos and that your flake's nixosConfigurations is named the same as your $hostname.

Commands/Programs:
1. `nix` - Used for `nix flake update` and `nix build` commands
2. `nvd` - Used for comparing system versions (`nvd diff`)

System Requirements:
1. NixOS operating system (based on the nature of the script)
2. A running Waybar instance (the script outputs JSON for Waybar integration)
3. Internet connectivity for performing update checks

## Privacy
External Network Requests: The script uses `ping -c 1 -W 2 8.8.8.8` to check network connectivity and send packets to Google's DNS servers (8.8.8.8), which could potentially reveal:
- That your system is running and online
- The fact you're using this specific script
- Your IP address to Google's DNS infrastructure


## How it Works: Step by Step
1. **Configuration Setup**: Defines update intervals, file paths, and flags to track the update state.

2. **File Initialization**: Creates necessary state files if they don't exist (tracks update count, last check time, and tooltip info).

3. **Network Check**: Verifies internet connectivity by pinging 8.8.8.8.

4. **System Update Status**: Checks if the system was recently rebuilt by looking for the rebuild flag.

5. **Update Check Timing**: Determines if it's time to check for updates based on the last check timestamp.

6. **Temporary Environment**: Creates a temporary directory for performing update checks without modifying the system.

7. **Flake Update**: Runs `nix flake update` either in the config directory or temp directory based on settings.

8. **System Build**: Builds the updated system configuration to compare with the current one.

9. **Update Comparison**: Uses `nvd diff` to compare current system with the new build and count updates.

10. **Result Storage**: Saves the number of updates and detailed update information to state files.

11. **Notification**: Sends desktop notifications to inform the user about the update status.

12. **JSON Output**: Generates a JSON object with update count, status indicator, and tooltip for Waybar.

13. **Flag Management**: Cleans up system update flags if a rebuild was detected.

14. **Error Handling**: Sets appropriate status messages if update checks fail or network is unavailable.

15. **Tooltip Generation**: Creates detailed tooltips showing which packages have updates available.

16. **State Management**: Manages update state across multiple runs of the script.

17. **Output Formatting**: Formats the final output to be compatible with Waybar's custom module format.


## How to Use
Download the `update-checker` script, put it in your [PATH](https://unix.stackexchange.com/a/26059) and make it executable (`chmod +x update-checker`).

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
        "has-updates": "", // icon when updates needed
        "updated": "" // icon when all packages updated
    },
},
```

In nix:
```nix
"custom/nix-updates" = {
  exec = "update-checker-v13";
  signal = 12;
  on-click = "";
  on-click-right = "rm ~/.cache/nix-update-last-run";
  interval = 3600;
  tooltip = true;
  return-type = "json";
  format = "{} {icon}";
  format-icons = {
    has-updates = "";
    updated = "";
  };
};
```

To style use the `#custom-nix-updates` ID in your Waybar styles file (`~/.config/waybar/styles.css`).


If you have you have UPDATE_LOCK_FILE set to "false", the UPDATE_FLAG file will signal that your lock file has been updated. Add the following to your update script, used to update your lock file (i.e. "nix flake update" script), so that the output of nvd diff is piped in:
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
`touch $HOME/.cache/nix-update-rebuild-flag && pkill -x -RTMIN+12 .waybar-wrapped &&`

For example:
```nix
nixup =
  "pushd ~/.config/nixos &&
  echo \"NixOS rebuilding...\" &&
  sudo nixos-rebuild switch --upgrade --flake .#hyprnix &&
  touch $HOME/.cache/nix-update-rebuild-flag &&
  pkill -x -RTMIN+12 .waybar-wrapped &&
  popd";
```

For more information see the [Waybar wiki](https://github.com/Alexays/Waybar/wiki).
