# Copy to /etc/nixos/ on the uConsole, then:
#   nixos-rebuild switch --flake /etc/nixos#uconsole

# flake.nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";
    nixos-uconsole.url = "github:nixos-uconsole/nixos-uconsole";
  };
  outputs = { nixpkgs, nixos-uconsole, ... }: {
    nixosConfigurations.uconsole = nixos-uconsole.lib.mkUConsoleSystem {
      variant = "cm5";  # change to "cm4" for CM4
      modules = [ ./configuration.nix ];
    };
  };
}

# configuration.nix
{
  config,
  pkgs,
  lib,
  ...
}: {
  # Overlay parameters per README
  hardware.raspberry-pi.config.cm5."dt-overlays".clockworkpi-uconsole-cm5.params = {
    no_rp1eth.enable = true;
    no_sound_switch.enable = true;
    energy_full_design_uwh.enable = true;
    energy_full_design_uwh.value = "24790000";
    charge_full_design_uah.enable = true;
    charge_full_design_uah.value = "6700000";
  };

  networking.hostName = "uconsole-cm5";

  # Non-root user
  users.users.myuser = {
    isNormalUser = true;
    description = "Your Name";
    extraGroups = ["wheel" "networkmanager" "dialout"];
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3... your-public-key"
    ];
    initialPassword = "changeme";
  };

  # Root fallback
  users.users.root.openssh.authorizedKeys.keys = [
    "ssh-ed25519 AAAAC3... your-public-key"
  ];

  # NOPASSWD sudo for wheel
  security.sudo.extraRules = [
    {
      groups = ["wheel"];
      commands = [{command = "ALL"; options = ["NOPASSWD"];}];
    }
  ];

  system.stateVersion = "25.11";
}