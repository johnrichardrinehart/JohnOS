{
  config,
  lib,
  osConfig,
  pkgs,
  ...
}:
let
  configureKeyboards = ''
    configureKeyboards() {
    ################################################################################
    ########## Useful URLs from research
    ################################################################################
    # https://www.in-ulm.de/~mascheck/X11/xmodmap.html
    # https://wiki.archlinux.org/title/Xorg/Keyboard_configuration#Using_X_configuration_files
    # https://askubuntu.com/a/337431
    #
    ################################################################################
    ########## Helpful commands to find the keyboard map
    ################################################################################
    # setxkbmap -query
    # input list-props $NUMBER_YOURE_INTERESTED_IN
    # localctl list-x11-keymap models
    #
    #  setxkbmap -model sun_type7_usb -layout gb -option ctrl:swapcaps
    #  setxkbmap -model pc104 -layout cz,us -variant ,dvorak -option grp:alt_shift_toggle
    #  localectl [--no-convert] set-x11-keymap layout [model [variant [options]]]

    LAPTOP_KBD="AT Translated Set 2 keyboard";
    LAPTOP_KBD_ID=$(${pkgs.xorg.xinput}/bin/xinput | grep "''${LAPTOP_KBD}" | cut -f 2 | cut -d = -f 2);
    ${pkgs.xorg.setxkbmap}/bin/setxkbmap -device $LAPTOP_KBD_ID -layout us -variant dvorak;
    ${pkgs.xorg.setxkbmap}/bin/setxkbmap -device 8 -layout us
      }

    configureKeyboards;
  '';

  configureMonitors =
    let
      laptopResolution = "2256x1504";
    in
    ''
        configureMonitors() {
        LAP_MONITOR="eDP-1"
        ${pkgs.xorg.xrandr}/bin/xrandr --output "''${LAP_MONITOR}" --mode ${laptopResolution}
        ${pkgs.xorg.xrandr}/bin/xrandr --setprovideroutputsource 1 0

      # looks like: https://bugs.freedesktop.org/show_bug.cgi?id=110830
      # which referencese: https://gist.github.com/szpak/71081b40217fb27c7a565b8c7b972067
      # consider filing a bug at: https://gitlab.freedesktop.org/drm/nouveau/
        for monitor in $(${pkgs.xorg.xrandr}/bin/xrandr | grep " connected" | cut -f1 -d " "); do
        if [[ "''${monitor}" != "''${LAP_MONITOR}" ]]
        then
          ${pkgs.xorg.xrandr}/bin/xrandr --output "''${monitor}" --mode 2560x1440 --right-of "''${LAP_MONITOR}"
        fi
        done
        }

        configureMonitors;
    '';
  stalonetrayrc = pkgs.writeText "stalonetrayrc" ''
    background "#3B4252"
    geometry "3x1+1150-0"
    icon_size "24"
    sticky true
    transparent true
    window_strut bottom
  '';
in
{
  imports = [
    #    ../wm/xmonad
    ./options.nix
  ];

  config = {
    home.packages = [
      # games
      pkgs.gnuchess
      pkgs.stockfish
      pkgs.scid-vs-pc
      # CLI
      pkgs.fzf
      # instant messengers
      pkgs.telegram-desktop
      pkgs.signal-desktop
      #pkgs.discord
      #pkgs.element-desktop
      #pkgs.skypeforlinux
      # development tools
    ];

    # only use flameshot with Xorg
    services.flameshot.enable = osConfig.services.xserver.enable;

    services.gpg-agent = {
      enable = true;
    };

    services.network-manager-applet.enable = true;

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
        module_pt = ''
          [module/time-pt]
          type = custom/script
          exec = TZ=America/Los_Angeles ${pkgs.coreutils}/bin/date +"%a, %d %b %H:%M"
          interval = 59
        '';
        module_nyc_time = ''
          [module/time-nyc]
          type = custom/script
          exec = TZ=America/New_York ${pkgs.coreutils}/bin/date +"(ET: %H:%M)"
          interval = 59
        '';
      in
      {
        # only use polybar with Xorg
        enable = osConfig.services.xserver.enable;
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
             ${pkgs.coreutils}/bin/sleep 2
             ${pkgs.polybar}/bin/polybar $1
          }

          startStalonetray() {
             ${pkgs.coreutils}/bin/sleep 5
             ${pkgs.stalonetray}/bin/stalonetray --config ${stalonetrayrc}
          }

          startPolybar main &
          startStalonetray &
        '';
        extraConfig = bars + colors + modules + user_modules + module_xmonad + module_pt + module_nyc_time;
      };

    home.file = {
      ".config/satty/config.toml".text = ''
        [general]
        initial-tool = "pointer"
      '';
      ".config/powerline/themes/gruvbox.theme".source = ./gruvbox.theme;
      ".config/hypr/hyprlock.conf".source = ./hyprlock.conf;
      ".config/hypr/hypridle.conf".source =
        let
          onIdlePackage = pkgs.callPackage ./on-idle.nix { };
        in
        (pkgs.replaceVars ./hypridle.conf {
          lock_command = lib.getExe pkgs.hyprlock;
          loginctl = lib.getExe' pkgs.systemd "loginctl";
          monitor_off = "${lib.getExe pkgs.niri} msg action power-off-monitors";
          notify_send = lib.getExe' pkgs.libnotify "notify-send";
          on_idle = lib.getExe onIdlePackage;
          on_short_resume = lib.getExe (
            pkgs.callPackage ./kill-idle-group.nix {
              inherit onIdlePackage;
            }
          );
          short_timeout_duration = config.idle.short_timeout_duration;
          medium_timeout_duration = config.idle.medium_timeout_duration;
          long_timeout_duration = config.idle.long_timeout_duration;
          systemctl = lib.getExe' pkgs.systemd "systemctl";
        }).overrideAttrs
          (_: {
            checkPhase = null;
          });
      ".config/hypr/hyprpaper.conf".source =
        (pkgs.replaceVars ./hyprpaper.conf {
          wallpaper = ../../static/ocean.jpg;
        }).overrideAttrs
          (_: {
            checkPhase = null;
          });
    };

    home.sessionVariables.EDITOR = "vim";

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
      config = {
        whitelist = {
          prefix = [ "/home/john/code/repos/sr.ht/fuzzybear3965/" ];
        };
      };
    };

    programs.git = {
      enable = true;
      settings = {
        user = {
          name = "John Rinehart";
          email = "johnrichardrinehart@gmail.com";
        };
        init.defaultBranch = "main";
        core.editor = "vim";
        # TODO: commented for cargo-tarpaulin, remove line if nothing breaks
        url = {
          "git@github.com:" = {
            insteadOf = "https://github.com";
          };
        };
        core.excludesFile = "~/.gitignore";
        pull.rebase = true;
      };
    };

    programs.gpg.enable = true;

    programs.kitty = {
      enable = true;
      font.size = 12;
      font.name = "Fira Mono Medium for Powerline";
      extraConfig = ''
        hide_window_decorations yes
        enable_audio_bell no
        scrollback_lines 250000

        # Send a newline literal for claude-code CLI
        # See: https://github.com/anthropics/claude-code/issues/3853
        map shift+enter send_text all \n

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
      plugins =
        let
          p = pkgs.vimPlugins;
        in
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
            hash = "sha256-IT3wpfw8zhiNQsrw59lbSWYh0NQ1CUdUtFzRzHlURH0=";
          };
        }
      ];

      autosuggestion.enable = true;

      shellAliases =
        let
          fetchLatestKernelVersion =
            release_line:
            let
              kernelOrgXpath =
                release_line:
                let
                  row = release_line: if release_line == "mainline" then "1" else "2";
                in
                ''//table[@id="releases"]/tr[${row release_line}]/td[2]/strong/text()'';
              xpath = kernelOrgXpath release_line;
            in
            "curl --silent 'https://kernel.org' | xmllint -html -xpath '${xpath}' - 2>/dev/null";
        in
        {
          ssh = "kitty +kitten ssh";
          # from https://stackoverflow.com/a/47285611
          gbbd = "git for-each-ref --sort=committerdate refs/heads/ --format='%(color: red)%(committerdate:short) %(color: cyan)%(refname:short)'";
          # latest kernel version
          lskv = fetchLatestKernelVersion "stable";
          lmkv = fetchLatestKernelVersion "mainline";
          clv = "uname -a | cut -f3 -d' ' | cut -f 1 -d'-' ";
          k = "kubectl";
          chess = "scid";
          sudo-nixos-rebuild-flake = "sudo nixos-rebuild switch --flake $HOME/code/repos/mine/nix"; # https://askubuntu.com/questions/22037/aliases-not-available-when-using-sudo
        };

      oh-my-zsh = {
        enable = true;
        plugins = [
          "git"
          "sudo"
          "docker"
          "kubectl"
          "fzf"
        ];
        theme = "agnoster";
      };

      initContent = ''
            export BGIMG="${../../static/ocean.jpg}"
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
            eval $("${lib.getExe pkgs.oh-my-posh}" init zsh --config "${./oh-my-posh.json}");
            }
            precmd_functions+=(prompt)

        # ${pkgs.zellij}/bin/zellij attach --index 0 || ${pkgs.zellij}/bin/zellij
      '';
    };

    home.stateVersion = "24.05";

    manual.manpages.enable = false;
  };
}
