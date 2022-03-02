args @ { pkgs, lib, config, nixpkgs, options, specialArgs, nixosConfig, ... }:
let
  overlays = [
    #    (final: prev:
    #      {
    #        flameshot = prev.flameshot.overrideAttrs (old: rec {
    #          version = "11.0.0";
    #
    #          src = final.fetchFromGitHub {
    #            owner = "flameshot-org";
    #            repo = "flameshot";
    #            rev = "v${version}";
    #            sha256 = "SlnEXW3Uhdgl0icwYyYsKQOcYkAtHpAvL6LMXBF2gWM=";
    #          };
    #
    #          patches = [];
    #        });
    #      }
    #    )

    (self: super: {
      # TODO: remove once https://github.com/NixOS/nixpkgs/pull/158654 lands
      # in nixos-unstable
      dbeaver = super.dbeaver.overrideAttrs (old: {
        fetchedMavenDeps = old.fetchedMavenDeps.overrideAttrs (_: {
          outputHash = "sha256-fJs/XM8PZqm/CrhShtcy4R/4s8dCc1WdXIvYSCYZ4dw=";
        });
      });
    })

  ];

  stalonetrayrc = pkgs.writeText "stalonetrayrc" ''
    background "#3B4252"
    decorations "none"
    dockapp_mode "none"
    geometry "5x1-150+0"
    grow_gravity "NE"
    icon_gravity "NE"
    icon_size "48"
    kludges "force_icons_size"
    skip_taskbar "true"
    sticky true
    transparent "false"
    window_strut "none"
    window_type "dock"
  '';
in
{

  services.network-manager-applet.enable = true;

  home.file =
    {
      ".config/powerline-rs/themes/gruvbox.theme" = {
        source = ./gruvbox.theme; # powerline-rs
        target = ".config/powerline-rs/themes/gruvbox.theme";
      };

      ".config/i3status/net-speed.sh" = {
        source = ../wm/net-speed.sh;
        executable = true;
      };
    };


  xsession = {
    enable = true;
    # https://discourse.nixos.org/t/opening-i3-from-home-manager-automatically/4849/8
    scriptPath = ".hm-xsession";

    windowManager.xmonad = (import ../wm args).xmonad;
    initExtra = (import ../wm args).initExtra;

    profileExtra = ''
      eval $(${pkgs.gnome3.gnome-keyring}/bin/gnome-keyring-daemon --daemonize --components=ssh,secrets)
      export SSH_AUTH_SOCK
    '';
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
          # TODO: commented for cargo-tarpaulin, remove line if nothing breaks
          url."git@github.com:".insteadOf = "https://github.com";
          core.excludesFile = "~/.gitignore";
          pull.rebase = true;
        };
      };

      #    alacritty = {
      #      enable = true;
      #    };

      kitty = {
        enable = true;
        extraConfig = ''
          enable_audio_bell no
          scrollback_lines 250000
          map kitty_mod+f5 change_font_size all 12.0
          map kitty_mod+f6 change_font_size all 18.0
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
          modi = "window,windowcd,run,ssh,drun,combi,keys,filebrowser";
        };
      };

      vim = {
        enable = true;
        extraConfig = ''
          set autochdir
          set number
          syntax on
          filetype on

          autocmd BufNewFile,BufRead *.svelte set filetype=html
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

              # from https://stackoverflow.com/a/47285611
              alias gbbd="git for-each-ref --sort=committerdate refs/heads/ --format='%(color: red)%(committerdate:short) %(color: cyan)%(refname:short)'"
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
  nixpkgs.overlays = overlays;

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
        # The below script has a weird structure, mostly owing to the long
        # delay introduced by `xrandr` detecting and setting the display
        # settings (when the window manager starts up). We basically need
        # to wait a few seconds until the window manager has established 
        # which screens are on and what their resolutions are before we
        # start polybar, otherwise it starts on the first detected screen
        # and then may jump to a later-activated screen (which may have a
        # different resolution). The end result being a poylbar that is either
        # either too short or too long. 3 seconds seems to be a kind of sweet
        # spot for my hardware. However, stalonetray starts up faster than
        # polybar so we need to add an additional delay to its startup so that
        # we don't hide stalonetray behind polybar when polybar finishes
        # loading.

        startPolybar() {
           ${pkgs.coreutils}/bin/sleep 4
           ${pkgs.polybar}/bin/polybar $1
        }

        startStalonetray() {
           ${pkgs.coreutils}/bin/sleep 5
           ${pkgs.stalonetray}/bin/stalonetray --config ${stalonetrayrc}
        }

        startPolybar main &
        startStalonetray &
      '';
      extraConfig = bars + colors + modules + user_modules + module_xmonad + module_nyc_time;
    };


  home.packages =
    let
      p = pkgs;
      base = [
        # gui configuration
        p.feh
        p.multilockscreen
        p.dconf
        p.dunst
        p.libnotify
        p.gnome-icon-theme
        # gui apps
        p.rofi
        p.slack
        p.vscodium
        p.brave
        p.flameshot
        p.keepassxc
        p.dbeaver
        p.stalonetray
        p.peek # GIF/webp screen recording
        p.mpv # mplayer replacement
        p.simplescreenrecorder
        # shell tools
        p.powerline-rs
        p.oil
        p.ranger
        p.jump
        p.tmux
        p.xdg-utils # `open`
        p.xclip
        p.fd
        p.bc # needed for adjusting screen brightness
        p.libqalculate
        p.ncdu # ncurses disk usage (tree+du, basically)
        p.dive # docker image analyzer
        # language tools
        p.jq
        p.nixpkgs-fmt
        # os tools
        p.htop
        p.tree
        p.killall
        p.lsof
        p.pstree
        p.nethogs
        p.pavucontrol
        p.autorandr
        p.file
        p.pv # useful for dd operations (e.g. `dd if=infile | pv | sudo dd of=outfile bs=512`)
        # archive tools
        p.zip
        p.unzip
        # programming languages
        p.go_1_17
        p.gcc
        # communication tools
        p.droidcam
        # multimedia tools
        p.playerctl
      ];
    in
    if args ? extraPackages then base ++ args.extraPackages else base;

  gtk = {
    enable = true;
    theme = {
      package = pkgs.gnome-themes-extra;
      name = "Adawaita-dark";
    };
  };

  home.sessionVariables = {
    EDITOR = "vim";
  };

  home.stateVersion = "21.05";
}
