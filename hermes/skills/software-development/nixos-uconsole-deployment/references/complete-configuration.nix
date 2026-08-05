# Full working NixOS configuration for uConsole CM5
# Generated from successful session — includes:
# Sway + greetd (tuigreet or auto-login) + custom status bar + Cyberpunk Pink theme + wayvnc + WiFi/firewall

{ config, pkgs, lib, ... }:

{
  # === CM5 Overlay Parameters ===
  hardware.raspberry-pi.config.cm5."dt-overlays".clockworkpi-uconsole-cm5.params = {
    no_rp1eth.enable = true;
    no_sound_switch.enable = true;
    energy_full_design_uwh.enable = true;
    energy_full_design_uwh.value = "24790000";
    charge_full_design_uah.enable = true;
    charge_full_design_uah.value = "6700000";
  };

  networking.hostName = "uconsole-cm5";
  networking.firewall.allowedTCPPorts = [ 5900 ];
  time.timeZone = "Europe/Zurich";

  # === User ===
  users.users.silly82 = {
    isNormalUser = true;
    description = "Silvan Walker";
    extraGroups = [ "wheel" "networkmanager" "dialout" "video" "input" ];
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIARgeRbeX7aLNcDqWqGgt8Q5gPkAocgTAZ6NVkTbee28 silvanwalker@MacBookPro.tardis.home"
    ];
    initialPassword = "changeme";
  };

  users.users.root.openssh.authorizedKeys.keys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIARgeRbeX7aLNcDqWqGgt8Q5gPkAocgTAZ6NVkTbee28 silvanwalker@MacBookPro.tardis.home"
  ];

  security.sudo.extraRules = [
    { groups = [ "wheel" ];
      commands = [
        { command = "ALL";
          options = [ "NOPASSWD" ];
        }
      ];
    }
  ];

  # === Sway ===
  programs.sway = {
    enable = true;
    wrapperFeatures.gtk = true;
    extraPackages = with pkgs; [
      waybar foot fuzzel mako swaylock swayidle brightnessctl wl-clipboard
    ];
  };

  environment.systemPackages = with pkgs; [
    networkmanagerapplet nemo imv mpv wayvnc pavucontrol font-awesome
  ];

  services.pipewire = {
    enable = true;
    alsa.enable = true;
    pulse.enable = true;
  };

  # === Foot Terminal — Cyberpunk Pink Theme ===
  environment.etc."foot/foot.ini".text = ''
    [main]
    font=Iosevka:size=12,monospace:size=12
    term=xterm-256color

    [colors]
    background=0d0d0d
    foreground=ffb8d0
    cursor=ff0066 0d0d0d     # NOTE: use colors.cursor, NOT [cursor] section
    regular0=1a0a1e
    regular1=ff0066
    regular2=00ff41
    regular3=ffd700
    regular4=00d4ff
    regular5=ff00ff
    regular6=00ffcc
    regular7=bfbfbf
    bright0=404040
    bright1=ff2a6d
    bright2=66ff99
    bright3=ffeb3b
    bright4=05d9e8
    bright5=ff66ff
    bright6=00ffcc
    bright7=ffffff

    [scrollback]
    lines=10000
  '';

  # === Sway Status Bar Script (simple shell, no i3status) ===
  # NOTE: This avoids i3status battery module bugs. 
  # Use `iw` not `iwgetid` — iwgetid is not available on NixOS.
  environment.etc."sway/status".text = ''
    #!/bin/sh
    while true; do
      ssid=$(iw dev wlan0 info 2>/dev/null | awk '/ssid/ {print $2}')
      [ -z "$ssid" ] && ssid="-"
      cap=$(cat /sys/class/power_supply/axp20x-battery/capacity 2>/dev/null || echo "?")
      now=$(date +%H:%M)
      echo "  $ssid  |  $cap%  |  $now"
      sleep 2
    done
  '';

  # === Sway Config ===
  # PITFALL: CM5 uses DSI-2 (NOT DSI-1 like CM4)
  # PITFALL: 'font' (singular) in bar block, NOT 'fonts'
  # PITFALL: Waybar needs 'exec waybar' NOT 'bar { status_command waybar }'
  # PITFALL: ${} in '' strings is Nix-interpolated — use $var (no braces) for shell vars
  environment.etc."sway/config".text = ''
    set $mod Mod1

    output DSI-2 transform 90 scale 2.0

    set $term foot
    set $menu fuzzel

    bindsym $mod+Return exec $term
    bindsym $mod+d exec $menu
    bindsym $mod+Shift+q kill
    bindsym $mod+Shift+c reload
    bindsym $mod+Shift+e exec swaynag -t warning -m "Exit Sway?" -b "Yes" "swaymsg exit"

    # WiFi
    bindsym $mod+Shift+w exec $term -e nmtui

    # Scale toggle
    bindsym $mod+z exec swaymsg "output DSI-2 scale 2.0"
    bindsym $mod+Shift+z exec swaymsg "output DSI-2 scale 1.0"

    bindsym $mod+1 workspace 1
    bindsym $mod+2 workspace 2
    bindsym $mod+3 workspace 3
    bindsym $mod+4 workspace 4
    bindsym $mod+5 workspace 5
    bindsym $mod+Shift+1 move container to workspace 1
    bindsym $mod+Shift+2 move container to workspace 2
    bindsym $mod+Shift+3 move container to workspace 3
    bindsym $mod+Shift+4 move container to workspace 4
    bindsym $mod+Shift+5 move container to workspace 5

    bindsym XF86MonBrightnessDown exec brightnessctl set 1-
    bindsym XF86MonBrightnessUp exec brightnessctl set +1
    bindsym XF86AudioRaiseVolume exec pactl set-sink-volume @DEFAULT_SINK@ +5%
    bindsym XF86AudioLowerVolume exec pactl set-sink-volume @DEFAULT_SINK@ -5%
    bindsym XF86AudioMute exec pactl set-sink-mute @DEFAULT_SINK@ toggle

    default_border pixel 2
    gaps inner 4
    smart_gaps on
    smart_borders on
    focus_follows_mouse no

    bar {
      position top
      status_command sh /etc/sway/status
      font pango:monospace 10
      colors {
        background #0d0d0d
        statusline #ff2a6d
        separator #ff00ff
        focused_workspace #ff2a6d #0d0d0d #ffb8d0
        active_workspace #1a0a1e #1a0a1e #ff66ff
        inactive_workspace #0d0d0d #0d0d0d #404040
        urgent_workspace #ff0066 #0d0d0d #ffffff
        binding_mode #ff00ff #0d0d0d #ffffff
      }
    }

    client.focused #ff0066 #ff0066 #ffffff #ff00ff
    client.focused_inactive #1a0a1e #1a0a1e #ff66ff #ff00ff
    client.unfocused #0d0d0d #0d0d0d #404040 #0d0d0d
    client.urgent #ff0066 #ff0066 #ffffff #ff0066
    client.placeholder #0d0d0d #0d0d0d #404040 #0d0d0d
    client.background #0d0d0d

    output * bg #0d0d0d solid_color

    exec swayidle -w \
      timeout 300 'swaylock -f -c 0d0d0d' \
      timeout 600 'swaymsg "output * dpms off"' \
      resume 'swaymsg "output * dpms on"'
    exec mako
    exec wayvnc 0.0.0.0 5900
  '';

  # === greetd Login Manager ===
  # Choose ONE of the two approaches below:

  # OPTION A: Direct auto-login to Sway (no greeter, no password)
  services.greetd = {
    enable = true;
    settings = {
      default_session = {
        command = "${pkgs.sway}/bin/sway";
        user = "silly82";
      };
    };
  };

  # OPTION B: Full greeter with session selection (comment out Option A, uncomment this)
  # services.greetd = {
  #   enable = true;
  #   settings = {
  #     default_session = {
  #       command = "${pkgs.tuigreet}/bin/tuigreet \
  #         --greeting 'uConsole CM5 - waehle Session' \
  #         --sessions /etc/greetd/sessions \
  #         --user-menu --remember --time";
  #       user = "greeter";
  #     };
  #   };
  # };
  # environment.etc."greetd/sessions/sway.desktop".text = ''
  #   [Desktop Entry]
  #   Name=Sway
  #   Comment=Wayland Compositor
  #   Exec=sway
  #   Type=Application
  # '';
  # environment.etc."greetd/sessions/bash.desktop".text = ''
  #   [Desktop Entry]
  #   Name=Bash (CLI)
  #   Comment=Terminal only
  #   Exec=foot
  #   Type=Application
  # '';

  services.getty.autologinUser = lib.mkForce null;

  system.stateVersion = "25.11";
}