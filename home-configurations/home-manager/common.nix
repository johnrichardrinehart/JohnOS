{
  config,
  lib,
  osConfig,
  pkgs,
  ...
}:
let
  stalonetrayrc = pkgs.writeText "stalonetrayrc" ''
    background "#3B4252"
    geometry "3x1+1150-0"
    icon_size "24"
    sticky true
    transparent true
    window_strut bottom
  '';
  agentToolsGitignoreEntries = lib.optionalString osConfig.dev.johnrinehart.agentTools.enable ''
    .codex/
    .codex
    .omx/
  '';
  agentDeckConfig = ''
    # Agent Deck Configuration
    # Managed by Home Manager

    default_tool = "my-codex"
    theme = "dark"

    [tools.my-codex]
    command = "${lib.getExe pkgs.dev.johnrinehart.codex-cli-nix}"
    compatible_with = "codex"

    [tools.my-claude]
    command = "${lib.getExe pkgs.dev.johnrinehart.claude-code-nix}"
    compatible_with = "claude"

    # OMX currently runs Codex inside the existing tmux pane and may also mutate the
    # outer tmux window (for example by creating a HUD split and enforcing tmux
    # ownership checks). These wrappers normalize agent-deck's appended
    # `resume <session-id>` shape into the OMX argv order that preserves the
    # intended flags on resumed sessions.
    [tools.omx-high]
    command = "${lib.getExe' pkgs.dev.johnrinehart.omx-agent-tools "omx-high"}"
    compatible_with = "codex"

    [tools.omx-high-sandboxed-ralph]
    command = "${lib.getExe' pkgs.dev.johnrinehart.omx-agent-tools "omx-high-sandboxed-ralph"}"
    compatible_with = "codex"

    [worktree]
    default_location = "sibling"
    auto_cleanup = true
    path_template = "{repo-root}/{branch-escaped}"

    [global_search]
    recent_days = 90
  '';
in
{
  imports = [
    #    ../wm/xmonad
    ./options.nix
  ];

  config = {
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
        inherit (osConfig.services.xserver) enable;
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
      ".gitignore".text = ''
        result
        .claude/
      ''
      + agentToolsGitignoreEntries;
      ".config/satty/config.toml".text = ''
        [general]
        initial-tool = "pointer"
      '';
      ".config/fuzzel/fuzzel.ini".text = ''
        [main]
        width=60

        [colors]
        background=20242df2
        text=d8dee9ff
        prompt=8fbcbbff
        input=e5e9f0ff
        match=a3be8cff
        selection=3b4252ff
        selection-text=eceff4ff
        selection-match=bfdb9dff
        border=5e81acff
      '';
      ".config/powerline/themes/gruvbox.theme".source = ./gruvbox.theme;
      ".config/hypr/hyprlock.conf".source = ./hyprlock.conf;
      ".codex/skills/usage-status".source = ./skills/usage-status;
      ".config/hypr/hyprpaper.conf".source =
        let
          wallpaper = builtins.path {
            path = ../../static/full-moon-forest-night-dark-starry-sky-5k-8k-7952x5304-1684.jpg;
            name = "wallpaper.jpg";
          };
        in
        (pkgs.replaceVars ./hyprpaper.conf {
          inherit wallpaper;
        }).overrideAttrs
          (_: {
            checkPhase = null;
          });
    }
    // lib.optionalAttrs osConfig.dev.johnrinehart.agentTools.enable {
      ".agent-deck/config.toml".text = agentDeckConfig;
    }
    // lib.optionalAttrs osConfig.dev.johnrinehart.desktop.greetd_niri.hypridle.enable {
      ".config/hypr/hypridle.conf".source =
        let
          sshSessionLockCfg = osConfig.dev.johnrinehart.sshSessionLock;
          confirmSshActivityPackage = pkgs.dev.johnrinehart.confirm-ssh-activity-before-suspend.override {
            promptTimeoutSeconds = sshSessionLockCfg.suspendPromptTimeoutSeconds;
          };
          lockIdleSshPackage = pkgs.dev.johnrinehart.lock-idle-ssh-sessions.override {
            idleTimeoutSeconds = sshSessionLockCfg.timeoutSeconds;
            inherit (sshSessionLockCfg) terminalMultiplexer;
            tmux = pkgs.dev.johnrinehart.tmux;
          };
          onIdlePackage = pkgs.dev.johnrinehart.on-idle.override {
            idleTimeoutSeconds = config.idle.short_timeout_duration;
            idleSshActionCommand = lib.optionalString sshSessionLockCfg.enable (lib.getExe lockIdleSshPackage);
          };
          onLongIdlePackage = pkgs.dev.johnrinehart.suspend-if-no-active-ssh.override {
            confirmSshActivityCommand = lib.optionalString sshSessionLockCfg.enable (
              lib.getExe confirmSshActivityPackage
            );
          };
        in
        (pkgs.replaceVars ./hypridle.conf {
          lock_command = lib.getExe pkgs.hyprlock;
          loginctl = lib.getExe' pkgs.systemd "loginctl";
          monitor_off = "${lib.getExe pkgs.niri} msg action power-off-monitors";
          notify_send = lib.getExe' pkgs.libnotify "notify-send";
          on_idle = lib.getExe onIdlePackage;
          on_long_idle = lib.getExe onLongIdlePackage;
          on_long_resume = lib.getExe (
            pkgs.dev.johnrinehart.kill-idle-group.override {
              onIdlePackage = onLongIdlePackage;
            }
          );
          on_short_resume = lib.getExe (
            pkgs.dev.johnrinehart.kill-idle-group.override {
              inherit onIdlePackage;
            }
          );
          inherit (config.idle) short_timeout_duration;
          inherit (config.idle) medium_timeout_duration;
          inherit (config.idle) long_timeout_duration;
        }).overrideAttrs
          (_: {
            checkPhase = null;
          });
    };

    programs.tmux =
      lib.mkIf
        (
          osConfig.dev.johnrinehart.sshSessionLock.enable
          && osConfig.dev.johnrinehart.sshSessionLock.terminalMultiplexer == "tmux"
        )
        {
          enable = true;
          extraConfig =
            let
              tmuxAuthLock = pkgs.dev.johnrinehart.tmux-auth-lock;
            in
            ''
              set -g lock-command "${lib.getExe tmuxAuthLock}"
            '';
        };

    home.sessionVariables = {
      EDITOR = "vim";
      TMUX_TMPDIR = lib.mkForce osConfig.dev.johnrinehart.tmux.socketDir;
    };

    dconf.settings = {
      "org/gnome/nautilus/preferences" = {
        default-sort-order = "mtime";
        default-sort-in-reverse-order = true;
      };
    };

    gtk = {
      enable = true;
      theme = {
        package = pkgs.adw-gtk3;
        name = "adw-gtk3-dark";
      };
      gtk3.extraConfig = {
        gtk-application-prefer-dark-theme = 1;
      };
      gtk4.extraConfig = {
        gtk-application-prefer-dark-theme = 1;
      };
      gtk4.theme = config.gtk.theme;
    };

    programs.direnv = {
      enable = true;
      nix-direnv = {
        enable = true;
        package = pkgs.nix-direnv.override {
          nix = osConfig.nix.package;
        };
      };
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

        # Use -r instead of default -R so less passes all escape sequences through,
        # preventing oh-my-posh prompt garbling in scrollback.
        scrollback_pager less --raw-control-chars +INPUT_LINE_NUMBER

        # Send a newline literal for claude-code CLI
        # See: https://github.com/anthropics/claude-code/issues/3853
        map shift+enter send_text all \n

        # Send legacy Ctrl+Z for claude-code suspend (kitty protocol workaround)
        # See: https://github.com/anthropics/claude-code/issues/16895#issuecomment-3735957440
        # TODO: Remove once https://github.com/anthropics/claude-code/issues/17377 is fixed
        map ctrl+z send_text all \x1a

        # vim:ft=kitty

        ## name:     Catppuccin Kitty Macchiato
        ## author:   Catppuccin Org
        ## license:  MIT
        ## upstream: https://github.com/catppuccin/kitty/blob/main/macchiato.conf
        ## blurb:    Soothing pastel theme for the high-spirited!



        # The basic colors
        foreground              #CAD3F5
        background              #000000
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
            rev = "v0.8.0";
            hash = "sha256-Z6EYQdasvpl1P78poj9efnnLj7QQg13Me8x1Ryyw+dM=";
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
          lt = "ls -lhrtc";
          # from https://stackoverflow.com/a/47285611
          gbbd = "git for-each-ref --sort=committerdate refs/heads/ --format='%(color: red)%(committerdate:short) %(color: cyan)%(refname:short)'";
          # latest kernel version
          lskv = fetchLatestKernelVersion "stable";
          lmkv = fetchLatestKernelVersion "mainline";
          clv = "uname -a | cut -f3 -d' ' | cut -f 1 -d'-' ";
          k = "kubectl";
          claude = lib.getExe pkgs.dev.johnrinehart.claude-code-nix;
          codex = lib.getExe pkgs.dev.johnrinehart.codex-cli-nix;
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

      initContent =
        let
          bgimg = builtins.path {
            path = ../../static/full-moon-forest-night-dark-starry-sky-5k-8k-7952x5304-1684.jpg;
            name = "wallpaper.jpg";
          };
          sshSessionLockCfg = osConfig.dev.johnrinehart.sshSessionLock;
          tmuxSocketCfg = osConfig.dev.johnrinehart.tmux;
          multiplexerAutoAttach =
            lib.optionalString
              (
                sshSessionLockCfg.enable
                && sshSessionLockCfg.forceInteractiveShellsIntoMultiplexer
                && sshSessionLockCfg.terminalMultiplexer == "tmux"
              )
              ''
                if [[ -n "$SSH_TTY" && -z "$TMUX" ]]; then
                  tmux_socket_dir=${lib.escapeShellArg tmuxSocketCfg.socketDir}
                  tmux_socket_name=${lib.escapeShellArg tmuxSocketCfg.socketName}
                  tmux_session_prefix=${lib.escapeShellArg sshSessionLockCfg.multiplexerSessionName}
                  tmux_uid="$(${lib.getExe' pkgs.coreutils "id"} -u)"
                  tmux_session_stamp="$(${lib.getExe' pkgs.coreutils "date"} +%Y%m%dT%H%M%S)"
                  tmux_socket="$tmux_socket_dir/tmux-$tmux_uid/$tmux_socket_name"
                  tmux_session="$tmux_session_prefix-$tmux_session_stamp-$$"
                  exec ${lib.getExe pkgs.dev.johnrinehart.tmux} -S "$tmux_socket" new-session -s "$tmux_session"
                fi
              '';
        in
        ''
          ${multiplexerAutoAttach}

          # Use a function instead of an alias so zsh uses _ssh completion
          # rather than expanding to "kitty +kitten ssh" and hitting kitty's
          # broken anchor-based matcher handling.
          ssh() { kitty +kitten ssh "$@" }

              export BGIMG="${bgimg}"
              if [ ! -f $BGIMG ]; then
              curl -o $BGIMG "https://images.wallpapersden.com/image/download/ocean-sea-horizon_ZmpraG2UmZqaraWkpJRnamtlrWZpaWU.jpg"
              fi

          # zoxide - smarter cd (uses 'j' command like jump did)
              command -v zoxide &>/dev/null && eval "$(zoxide init zsh --cmd j)"


          # https://github.com/nix-community/nix-direnv
              eval "$(direnv hook zsh)"

          # https://blog.vghaisas.com/zsh-beep-sound/
              unsetopt BEEP

              prompt() {
              eval $("${lib.getExe pkgs.oh-my-posh}" init zsh --config "${./oh-my-posh.json}");
              }
              precmd_functions+=(prompt)
        '';
    };

    home.stateVersion = "24.05";

    manual.manpages.enable = false;
  };
}
