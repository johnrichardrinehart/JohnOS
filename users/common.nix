args @ { pkgs, lib, config, nixpkgs, options, specialArgs, nixosConfig, ... }:
{
  xsession = {
    enable = true;
    # https://discourse.nixos.org/t/opening-i3-from-home-manager-automatically/4849/8
    scriptPath = ".hm-xsession";

    windowManager.xmonad = (import ../wm args).xmonad;
    initExtra = (import ../wm args).initExtra;

  };

  programs = lib.recursiveUpdate
    {
      git = {
        enable = true;
        userName = "John Rinehart";
        userEmail = "johnrichardrinehart@gmail.com";
        extraConfig = {
          init.defaultBranch = "main";
          core.editor = "vim";
          url."git@github.com:".insteadOf = "https://github.com";
          core.excludesFile = "~/.gitignore";
        };
      };

      #    alacritty = {
      #      enable = true;
      #    };

      kitty = {
        enable = true;
        extraConfig = ''
          enable_audio_bell no
          scrollback_lines 50000
        '';
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
        plugins = let p = pkgs.vimPlugins; in
          [
            p.vim-airline
            p.vim-plug
            p.julia-vim
          ];
      };

      zsh = {
        enable = true;

        plugins = [
          {
            name = "zsh-nix-shell";
            file = "nix-shell.plugin.zsh";
            src = pkgs.fetchFromGitHub {
              owner = "chisui";
              repo = "zsh-nix-shell";
              rev = "v0.2.0";
              sha256 = "1gfyrgn23zpwv1vj37gf28hf5z0ka0w5qm6286a7qixwv7ijnrx9";
            };
          }
        ];

        enableAutosuggestions = true;

        shellAliases = {
          chess = "scid";
          sudo-nixos-rebuild-flake = "sudo nixos-rebuild switch --flake $HOME/code/repos/mine/nix"; # https://askubuntu.com/questions/22037/aliases-not-available-when-using-sudo
        };

        oh-my-zsh = {
          enable = true;
          plugins = [ "git" "sudo" "docker" "kubectl" ];
          theme = "agnoster";
        };

        initExtra =
          let
            base = ''
              export BGIMG="${args.photo}/bin/ocean.jpg"
              if [ ! -f $BGIMG ]; then
                curl -o $BGIMG "https://images.wallpapersden.com/image/download/ocean-sea-horizon_ZmpraG2UmZqaraWkpJRnamtlrWZpaWU.jpg"
              fi

              # Put the line below in ~/.zshrc:
              #
              eval "$(jump shell zsh)"
              #
              # The following lines are autogenerated:

              __jump_chpwd() {
                jump chdir
              }

              jump_completion() {
                reply="'$(jump hint "$@")'"
              }

              j() {
              local dir="$(jump cd $@)"
                test -d "$dir" && cd "$dir"
              }

              typeset -gaU chpwd_functions
              chpwd_functions+=__jump_chpwd

              compctl -U -K jump_completion j

              alias ssh="kitty +kitten ssh"

              # https://github.com/nix-community/nix-direnv
              eval "$(direnv hook zsh)"

              # https://blog.vghaisas.com/zsh-beep-sound/
              unsetopt BEEP

              prompt() {
                pwr="$(powerline-rs --modules time,ssh,cwd,perms,git,gitstage,nix-shell,root,virtualenv --theme ~/.config/powerline-rs/themes/gruvbox.theme --shell zsh $?)"
                PS1=$(printf "%s\n$ " "$pwr")
              }
              precmd_functions+=(prompt)
            ''; in
          if builtins.hasAttr "zshInitExtra" args
          then base + args.zshInitExtra
          else base;
      };

      direnv = {
        enable = true;
        nix-direnv.enable = true;
      };

      gpg.enable = true;
    }
    args.programs;

  services.flameshot.enable = true;

  services.gpg-agent.enable = true;

  nixpkgs.config.allowUnfree = true;

  services.polybar =
    let
      bars = builtins.readFile ./polybar/bars.ini;
      colors = builtins.readFile ./polybar/colors.ini;
      modules = builtins.readFile ./polybar/modules.ini;
      user_modules = builtins.readFile ./polybar/user_modules.ini;
      module_xmonad = ''
        [module/xmonad]
        type = custom/script
        exec = ${pkgs.xmonad-log}/bin/xmonad-log

        tail = true
      '';
      module_nyc_time = ''
        [module/time-nyc]
        type = custom/script
        exec = TZ=America/New_York ${pkgs.coreutils}/bin/date +"(NYC: %H:%M)"
        interval = 59
      '';
    in
    {
      enable = true;
      package = pkgs.polybar.override {
        alsaSupport = true;
        pulseSupport = true;
        githubSupport = true;
      };
      config = ./polybar/config.ini;
      script = ''
        polybar main &
      '';
      extraConfig = bars + colors + modules + user_modules + module_xmonad + module_nyc_time;
    };


  home.packages =
    let
      p = pkgs;
      base = [
        p.feh
        p.multilockscreen
        # gui apps
        p.rofi
        p.slack
        p.vscodium
        p.brave
        p.flameshot
        # shell tools
        p.powerline-rs
        p.oil
        p.ranger
        p.jump
        p.tmux
        p.xdg-utils # `open`
        # language tools
        p.jq
        p.nixpkgs-fmt
        # os tools
        p.htop
        p.tree
        p.killall
        p.lsof
        p.pstree
        # archive tools
        p.zip
        p.unzip
      ];
    in
    if args ? extraPackages then base ++ args.extraPackages else base;

  home.file = {
    ".config/i3status/net-speed.sh" = {
      source = ../wm/net-speed.sh;
      executable = true;
    };
  };

  home.sessionVariables = {
    EDITOR = "vim";
  };

  home.stateVersion = "21.05";
}
