args @ { pkgs, lib, config, nixpkgs, options, specialArgs, nixosConfig, ... }:
let
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

  overlays = [
    #     (final: prev:
    #       {
    #         flameshot = prev.flameshot.overrideAttrs (old: rec {
    #           version = "11.0.0";
    #
    #           src = final.fetchFromGitHub {
    #             owner = "flameshot-org";
    #             repo = "flameshot";
    #             rev = "v${version}";
    #             sha256 = "SlnEXW3Uhdgl0icwYyYsKQOcYkAtHpAvL6LMXBF2gWM=";
    #           };
    #
    #           patches = [];
    #         });
    #       }
    #     )

    #  needed before https://github.com/NixOS/nixpkgs/pull/158654 had landed in
    #  nixos-unstable
    #  (self: super: {
    #    dbeaver = super.dbeaver.overrideAttrs (old: {
    #      fetchedMavenDeps = old.fetchedMavenDeps.overrideAttrs (_: {
    #        outputHash = "sha256-fJs/XM8PZqm/CrhShtcy4R/4s8dCc1WdXIvYSCYZ4dw=";
    #      });
    #    });
    #  })
  ];
in
{
  services.flameshot.enable = true;
  services.gpg-agent.enable = true;
  services.network-manager-applet.enable = true;

  #services.polybar =
  #  let
  #    bars = builtins.readFile ./polybar/bars.ini;
  #    colors = builtins.readFile ./polybar/colors.ini;
  #    modules = builtins.readFile ./polybar/modules.ini;
  #    user_modules = builtins.readFile ./polybar/user_modules.ini;
  #    module_xmonad = ''
  #      [module/xmonad]
  #      type = custom/script
  #      exec = ${pkgs.xmonad-log}/bin/xmonad-log

  #      tail = true
  #    '';
  #    module_nyc_time = ''
  #      [module/time-nyc]
  #      type = custom/script
  #      exec = TZ=America/New_York ${pkgs.coreutils}/bin/date +"(NYC: %H:%M)"
  #      interval = 59
  #    '';
  #  in
  #  {
  #    enable = true;
  #    package = pkgs.polybar.override {
  #      alsaSupport = true;
  #      pulseSupport = true;
  #      githubSupport = true;
  #    };
  #    config = ./polybar/config.ini;
  #    script = ''
  #      # The below script has a weird structure, mostly owing to the long
  #      # delay introduced by `xrandr` detecting and setting the display
  #      # settings (when the window manager starts up). We basically need
  #      # to wait a few seconds until the window manager has established
  #      # which screens are on and what their resolutions are before we
  #      # start polybar, otherwise it starts on the first detected screen
  #      # and then may jump to a later-activated screen (which may have a
  #      # different resolution). The end result being a poylbar that is either
  #      # either too short or too long. 3 seconds seems to be a kind of sweet
  #      # spot for my hardware. However, stalonetray starts up faster than
  #      # polybar so we need to add an additional delay to its startup so that
  #      # we don't hide stalonetray behind polybar when polybar finishes
  #      # loading.

  #      startPolybar() {
  #         ${pkgs.coreutils}/bin/sleep 2
  #         ${pkgs.polybar}/bin/polybar $1
  #      }

  #      startStalonetray() {
  #         ${pkgs.coreutils}/bin/sleep 5
  #         ${pkgs.stalonetray}/bin/stalonetray --config ${stalonetrayrc}
  #      }

  #      startPolybar main &
  #      startStalonetray &
  #    '';
  #    extraConfig = bars + colors + modules + user_modules + module_xmonad + module_nyc_time;
  #  };


  home.file =
    {
      ".config/powerline-rs/themes/gruvbox.theme" = {
        source = ./gruvbox.theme;
      };

      ".config/i3status/net-speed.sh" = {
        source = ../wm/net-speed.sh;
        executable = true;
      };
    };

  home.sessionVariables = {
    EDITOR = "vim";
  };

  gtk = {
    enable = true;
    theme = {
      package = pkgs.gnome-themes-extra;
      name = "Adawaita-dark";
    };
  };

  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
  };

  programs.git = {
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

  programs.gpg.enable = true;

  programs.i3status = {
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

  programs.kitty = {
    enable = true;
    font.size = 16;
    font.name = "Fira Mono Medium for Powerline";
    extraConfig = ''
      enable_audio_bell no
      scrollback_lines 250000
      map kitty_mod+f5 change_font_size all 12.0
      map kitty_mod+f6 change_font_size all 18.0

      # vim:ft=kitty

      ## name:     Catppuccin Kitty Macchiato
      ## author:   Catppuccin Org
      ## license:  MIT
      ## upstream: https://github.com/catppuccin/kitty/blob/main/macchiato.conf
      ## blurb:    Soothing pastel theme for the high-spirited!



      # The basic colors
      foreground              #CAD3F5
      background              #24273A
      selection_foreground    #24273A
      selection_background    #F4DBD6

      # Cursor colors
      cursor                  #F4DBD6
      cursor_text_color       #24273A

      # URL underline color when hovering with mouse
      url_color               #F4DBD6

      # Kitty window border colors
      active_border_color     #B7BDF8
      inactive_border_color   #6E738D
      bell_border_color       #EED49F

      # OS Window titlebar colors
      wayland_titlebar_color system
      macos_titlebar_color system

      # Tab bar colors
      active_tab_foreground   #181926
      active_tab_background   #C6A0F6
      inactive_tab_foreground #CAD3F5
      inactive_tab_background #1E2030
      tab_bar_background      #181926

      # Colors for marks (marked text in the terminal)
      mark1_foreground #24273A
      mark1_background #B7BDF8
      mark2_foreground #24273A
      mark2_background #C6A0F6
      mark3_foreground #24273A
      mark3_background #7DC4E4

      # The 16 terminal colors

      # black
      color0 #494D64
      color8 #5B6078

      # red
      color1 #ED8796
      color9 #ED8796

      # green
      color2  #A6DA95
      color10 #A6DA95

      # yellow
      color3  #EED49F
      color11 #EED49F

      # blue
      color4  #8AADF4
      color12 #8AADF4

      # magenta
      color5  #F5BDE6
      color13 #F5BDE6

      # cyan
      color6  #8BD5CA
      color14 #8BD5CA

      # white
      color7  #B8C0E0
      color15 #A5ADCB
    '';
  };

  programs.rofi = {
    enable = true;
    extraConfig = {
      modi = "window,windowcd,run,ssh,drun,combi,keys,filebrowser";
    };
  };

  programs.vim = {
    enable = true;
    extraConfig = ''
      set autochdir
      set number
      syntax on
      filetype on

      autocmd BufNewFile,BufRead *.svelte set filetype=html

      " highlight trailing whitespace
      " https://stackoverflow.com/a/4617156/1477586
      :highlight ExtraWhitespace ctermbg=red guibg=red
      :match ExtraWhitespace /\s\+$/
    '';
    plugins = let p = pkgs.vimPlugins; in
      [
        p.vim-airline
        p.vim-plug
        p.julia-vim
      ];
  };

  programs.zsh = {
    enable = true;

    plugins = [
      {
        name = "zsh-nix-shell";
        file = "nix-shell.plugin.zsh";
        src = pkgs.fetchFromGitHub {
          owner = "chisui";
          repo = "zsh-nix-shell";
          rev = "v0.5.0";
          sha256 = "1gfyrgn23zpwv1vj37gf28hf5z0ka0w5qm6286a7qixwv7ijnrx9";
        };
      }
    ];

    enableAutosuggestions = true;

    shellAliases =
      let
        fetchLatestKernelVersion = release_line:
          let
            kernelOrgXpath = release_line:
              let
                row = release_line: if release_line == "mainline" then "1" else "2";
              in
              ''//table[@id="releases"]/tr[${row release_line}]/td[2]/strong/text()'';
            xpath = kernelOrgXpath release_line;
          in
          ''curl --silent 'https://kernel.org' | xmllint -html -xpath '${xpath}' - 2>/dev/null'';
      in
      {
        ssh = "kitty +kitten ssh";
        # from https://stackoverflow.com/a/47285611
        gbbd = "git for-each-ref --sort=committerdate refs/heads/ --format='%(color: red)%(committerdate:short) %(color: cyan)%(refname:short)'";
        # latest kernel version
        lskv = fetchLatestKernelVersion "stable";
        lmkv = fetchLatestKernelVersion "mainline";
        clv = ''uname -a | cut -f3 -d' ' | cut -f 1 -d'-' '';
        k = "kubectl";
        chess = "scid";
        sudo-nixos-rebuild-flake = "sudo nixos-rebuild switch --flake $HOME/code/repos/mine/nix"; # https://askubuntu.com/questions/22037/aliases-not-available-when-using-sudo
      };

    oh-my-zsh = {
      enable = true;
      plugins = [ "git" "sudo" "docker" "kubectl" "fzf" ];
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


          # https://github.com/nix-community/nix-direnv
          eval "$(direnv hook zsh)"

          # https://blog.vghaisas.com/zsh-beep-sound/
          unsetopt BEEP

          prompt() {
            pwr="$(powerline-rs --modules time,ssh,cwd,perms,git,gitstage,nix-shell,root,virtualenv --theme ~/.config/powerline-rs/themes/gruvbox.theme --shell zsh $?)"
            PS1=$(printf "%s\n$ " "$pwr")
          }
          precmd_functions+=(prompt)
        '';
      in
      if builtins.hasAttr "zshInitExtra" args
      then base + args.zshInitExtra
      else base;
  };

  xsession = {
    enable = true;
    # https://discourse.nixos.org/t/opening-i3-from-home-manager-automatically/4849/8
    scriptPath = ".hm-xsession";

  #  #windowManager.xmonad = (import ../wm args).xmonad;
  #  #initExtra = (import ../wm args).initExtra;
  #  #initExtra = ''
  #  #  Hyprland
  #  #'';
  #  #windowManager.hyprland = {
  #  #  enable = true;
  #  #};

  #  profileExtra = ''
  #    eval $(${pkgs.gnome.gnome-keyring}/bin/gnome-keyring-daemon --daemonize --components=ssh,secrets)
  #    export SSH_AUTH_SOCK
  #  '';
};

  home.packages = if builtins.hasAttr "pp" args then args.pp else [ ];

  home.stateVersion = "23.05";

  manual.manpages.enable = false;
}
