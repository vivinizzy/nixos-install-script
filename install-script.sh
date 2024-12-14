if [ $(whoami) != 'root' ]; then
    echo "You are not root (use sudo -i)"
    exit 0
fi
echo "welcome to auto-install by cyekaivy"
echo "quick install. you can at all point use ^C to exit the program"
echo "fill in the information then press enter to continue"
read a
lsblk
echo -n "> Which device? "
read device
echo -n "How much swap? (i.e. 16GB) "
read swap
echo "!!! EVERYTHING WILL BE LOST ON $device !!!"
echo -m "Confirm? GPT UEFI SYSTEM with $swap swap on $device as $(whoami)? --> ^C to cancel, Enter to confirm"
read b
umount "$device"*
echo set label gpt
parted $device -- mklabel gpt
parted $device -- mkpart root ext4 512MB -$swap
parted $device -- mkpart swap linux-swap -$swap 100%
parted $device -- mkpart ESP fat32 1MB 512MB
parted $device -- set 3 esp on
echo -n "Continue?"
read c
echo "formatting"
dev=$device'1'
mkfs.ext4 -L nixos $dev
dev=$device'2'
mkswap -L swap $dev
dev=$device'3'
mkfs.fat -F 32 -n boot $dev
echo "installing nixos"
mount /dev/disk/by-label/nixos /mnt
mkdir -p /mnt/boot
mount -o umask=077 /dev/disk/by-label/boot /mnt/boot
echo "enabling swap"
dev=$device'2'
swapon $dev
echo "generating hardware configuration"
nixos-generate-config --root /mnt
cat > /mnt/etc/nixos/configuration.nix << EOF
{ config, lib, pkgs, ... }:
# For quick navigation:
# ^F   @<whatever> :: services, userpackages, systempackages, networking
#                     programs
let
  username = "defaultUser"; # username for the main user
  hostname = "nixos";
  useNetworkManager = true;
  wireless = false; # enable wireless ability (conflicts with NetworkManager)
  printing = false; # enable printing ability
  pipewire = false; # if set to false, will use pulseaudio
  timezone = "America/Toronto";
  allowUnfree = true;
  ssh = false; # enable ssh connections with fail2ban enabled
  firewall = true;
  mullvad = true; # enable mullvad vpn client
  # Skip this part
  home-manager = builtins.fetchTarball "https://github.com/nix-community/home-manager/archive/release-24.11.tar.gz";
in
{
  imports = [ ./hardware-configuration.nix (import "\${home-manager}/nixos") ];
  nixpkgs.config.allowUnfree = allowUnfree;
  users.users."\${username}" = {
    isNormalUser = true;
    extraGroups = [ "wheel" "networkmanager" ];
    description = "nix user"; # your display name
  }; # User packages are managed by home-manager
  home-manager.users."\${username}" = {
    home.username = "\${username}";
    home.homeDirectory = "/home/\${username}";
    home.packages = with pkgs; [ # @userpackages

    ];
    programs = {
      firefox = {
        enable = true;
        profiles.user = {
          id = 0;
          isDefault = true;
          search.engines = {
            "Google".metaData.hidden = true;
            "Bing".metaData.hidden = true;
            "Wikipedia (en)".metaData.hidden = true;
            "DuckDuckGo" = {
              definedAliases = [ "@ddg" ];
              urls = [ { template = "https://duckduckgo.com"; params = [ { name = "q"; value = "{searchTerms}"; } ]; } ];
            };
            "NixOptions" = {
              definedAliases = [ "@options" "@nixoptions" ];
              urls = [ { template = "https://search.nixos.org/options"; params = [ { name = "query"; value = "{searchTerms}"; } ]; } ];
            };
            "NixPackages" = {
              definedAliases = [ "@packages" "@nixpkgs" "@pkgs" ];
              urls = [ { template = "https://search.nixos.org/packages"; params = [ { name = "query"; value = "{searchTerms}"; } ]; } ];
            };
          };
          search.force = true;
          search.default = "DuckDuckGo";
          search.privateDefault = "DuckDuckGo";
          settings = {
            "browser.newtabpage.pinned" = [
              { title = "YouTube"; url = "https://youtube.com/"; }
            ];
            "general.useragent.locale" = "en-US";
            "browser.search.region" = "US";
            "widget.disable-workspace-management" = false;
            "browser.aboutConfig.showWarning" = false;
            "browser.newtabpage.activity-stream.feeds.section.topstories" = false;
            "browser.newtabpage.activity-stream.showSponsored" = false;
          };
        };
        policies = {
          DefaultDownloadDirectory = "/home/\${username}/Downloads";
          TranslateEnabled = false;
          DisablePocket = true;
          FirefoxSuggest = false;
          AutofillAddressEnabled = false;
          AutofillCreditCardEnabled = false;
          DisableFirefoxAccounts = true;
          DisableFirefoxStudies = true;
          DisableFormHistory = true;
          DisableAppUpdate = true;
          DisableTelemetry = true;
          OfferToSaveLogins = false;
          PasswordManagerEnabled = false;
          DontCheckDefaultBrowser = true;
          HardwareAcceleration = true;
          NoDefaultBookmarks = true;
          DisplayBookmarksToolbar = "newtab";
          FirefoxHome = {
            Search = true;
            TopSites = false;
            SponsoredTopSites = false;
            Highlights = false;
            Snippets = false;
            Locked = false;
          };
          Extensions = {
            Install = [
              "https://addons.mozilla.org/firefox/downloads/latest/ublock-origin/latest.xpi" # ublock origin
              "https://addons.mozilla.org/firefox/downloads/latest/sponsorblock/latest.xpi" # sponsorblock
              "https://addons.mozilla.org/firefox/downloads/latest/enhancer-for-youtube/latest.xpi" # enhancer for youtube
            ];
          };
        };
      };
      home-manager.enable = true; # @programs

    };
    home.stateVersion = "24.11";
  };
  programs = { # don't use this programs. use your home-manager
     nano.nanorc = ''
      set mouse
      set linenumbers
      set tabstospaces
      set tabsize 2
    '';
    # don't use this programs. use your home-manager.
  };
  environment.systemPackages = with pkgs; [ # @systempackages
    btop xclip tldr luau
  ];
  services = {
    flatpak.enable = true;
    printing.enable = if printing then true else false; # Managed by let .. in at the top of the script
    pipewire.enable = if pipewire then true else false;
    pipewire.pulse.enable = if pipewire then true else false;
    openssh.enable = if ssh then true else false;
    fail2ban.enable = if ssh then true else false;
    mullvad-vpn.enable = if mullvad then true else false;
    displayManager.defaultSession = "cinnamon"; # default value
    # @services
    xserver = {
      enable = true;
      xkb.layout = "us";
      displayManager.lightdm.enable = true; # default value
      desktopManager.cinnamon.enable = true; # default value
    };
  };
  networking = {
    hostName = hostname; # defined at the top of the file
    networkmanager.enable = lib.mkIf useNetworkManager true;
    wireless.enable = lib.mkIf wireless true;
    firewall.enable = lib.mkIf firewall true;
    # @networking
  };
  xdg.portal = {
    enable = true;
    extraPortals = with pkgs; [ xdg-desktop-portal-gtk ];
  };
  time.timeZone = timezone;
  boot.loader = {
    systemd-boot.enable = true;
    efi.canTouchEfiVariables = true;
  };
  nix = {
    settings.auto-optimise-store = true;
    gc = {
      automatic = true;
      dates = "daily";
      options = "--delete-older-than 2d";
      persistent = true;
    };
  };
  i18n = {
    defaultLocale = "en_US.UTF-8";
    extraLocaleSettings = {
      LC_ADDRESS = "en_US.UTF-8";
      LC_IDENTIFICATION = "en_US.UTF-8";
      LC_MEASUREMENT = "en_US.UTF-8";
      LC_MONETARY = "en_US.UTF-8";
      LC_NAME = "en_US.UTF-8";
      LC_NUMERIC = "en_US.UTF-8";
      LC_PAPER = "en_US.UTF-8";
      LC_TELEPHONE = "en_US.UTF-8";
      LC_TIME = "en_US.UTF-8";
    };
  };
  hardware = {
    pulseaudio.enable = if pipewire then false else true;
  };
  security.rtkit.enable = true;
  fonts.packages = with pkgs; [];
  system.copySystemConfiguration = true;
  system.stateVersion = "24.11";
}
EOF
echo "Now you have to edit this file to look like your config"
echo -n "Continue?"
read d
sudoedit /mnt/etc/nixos/configuration.nix
echo "to edit any further do sudoedit /mnt/etc/nixos/configuration.nix"
echo
echo -n "Ready to install NixOS? ^C to abort"
read e
echo "now downloading packages and building setup..."
nixos-install --no-root-passwd
echo -n
echo "set root password"
nixos-enter --root /mnt -c 'passwd'
echo -n "what is your username? "
read username
echo "set your password"
nixos-enter --root /mnt -c "passwd $username"
echo "done! press enter to reboot. ^C to stay."
read f
reboot
