args @ { pkgs, lib, config, nixpkgs, options, specialArgs, nixosConfig, ... }:
{
  xsession.windowManager.i3 = {
    enable = true;
    config = null;
    extraConfig = builtins.readFile ../wm/i3.conf;
  };

  programs = {
    git = {
      enable = true;
      userName = "John Rinehart";
      userEmail = "john.rinehart@ardanlabs.com";
      extraConfig = {
        init.defaultBranch = "main";
        core.editor = "vim";
        core.excludesFile = "~/.gitignore";
      };
    };

    alacritty = {
      enable = true;
    };

    i3status = {
      enable = true;
      enableDefault = false;

      general = {
        output_format = "i3bar";
        colors = false;
        interval = 5;
      };

      modules = {
        "ethernet enp0s3" = {
          position = 1;
          settings = { format_up = "I: %ip"; };
        };
        "load" = {
          position = 2;
          settings = { format = "%5min"; };
        };
        "disk /" = {
          position = 3;
          settings = { format = "%free/%total"; };
        };
        "memory" = {
          position = 4;
          settings = {
            format = "%used/%total";
            threshold_degraded = "10%";
            format_degraded = "MEMORY: %free";
          };
        };
        "tztime local" = {
          position = 5;
          settings = {
            format = "(L) %Y-%m-%d %H:%M:%S";
          };
        };
        "tztime nyc" = {
          position = 6;
          settings = {
            format = "(NYC) %Y-%m-%d %H:%M:%S %Z";
            timezone = "America/New_York";
          };
        };
        "battery 0" = {
          position = 7;
          settings = {
            format = "%status %percentage %remaining %emptytime";
            format_down = "No battery";
            status_chr = "⚡ CHR";
            status_bat = "🔋 BAT";
            status_unk = "? UNK";
            status_full = "☻ FULL";
            path = "/sys/class/power_supply/BAT%d/uevent";
            low_threshold = 10;
          };
        };
      };

    };

    rofi = {
      enable = true;
      extraConfig = {
        modi = "window,windowcd,run,ssh,drun,combi,keys,file-browser";
      };
    };

    vim = {
      enable = true;
      extraConfig = ''
        set autochdir
        set number
      '';
      plugins = let p = pkgs.vimPlugins; in [ p.vim-airline ];
    };

  };

  nixpkgs.config.allowUnfree = true;

  home.packages =
    let
      p = pkgs;
      base = [
        p.slack
        p.vscodium
        p.brave
        p.rofi
        p.oil
        p.htop
        p.powerline-rs
        p.nixpkgs-fmt
        p.tmux
        p.ranger
        p.feh
      ];
    in
    if args ? extraPackages then base ++ args.extraPackages else base;

  home.file = {
    ".config/i3status/net-speed.sh" = {
      source = ../wm/net-speed.sh;
      executable = true;
    };
  };

  home.sessionVariables.EDITOR = "vim";

  home.stateVersion = "21.05";

}
