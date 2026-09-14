{ config, pkgs, inputs, ... }:

{
  imports = [ inputs.noctalia.homeModules.default ];

  home.username = "nonezerone";
  home.homeDirectory = "/home/nonezerone";
  # Keep in sync with system.stateVersion in configuration.nix.
  home.stateVersion = "25.05";

  home.packages = with pkgs; [
    firefox
    zoom-us
    keepassxc
    qbittorrent
    mpv
    gimp
    telegram-desktop
    spotify
    fzf
    bc
    highlight
    gcc
    gnumake
    openssl
    openssl.dev
    readline
    libyaml
    zlib
    zlib.dev
    gdbm
    ncurses
    libffi
    gmp
    libxml2
    libxslt
    sqlite
    libpq
    pkg-config
    autoconf
    automake
    libtool
    tree-sitter
    fastfetch
    wl-clipboard
    htop
    btop
    qview
    zathura
  ];

  xdg.configFile."niri/config.kdl".source = ./niri.kdl;

  xdg.configFile."nvim".source = ./dotfiles/nvim;

  programs.neovim = {
    enable = true;
    defaultEditor = true;
    viAlias = true;
    vimAlias = true;
    withRuby = true;
    withPython3 = true;
  };

  programs.claude-code = {
    enable = true;
    settings = {
      theme = "dark";
      enabledPlugins."ruby-lsp@claude-plugins-official" = true;
    };
  };

  programs.zed-editor = {
    enable = true;
    userSettings = {
      project_panel.dock = "left";
      outline_panel.dock = "left";
      collaboration_panel.dock = "left";
      agent = {
        dock = "right";
        favorite_models = [ ];
        model_parameters = [ ];
      };
      git_panel.dock = "left";
      buffer_font_family = "JetBrains Mono";
      terminal.font_family = "JetBrains Mono";
      git = {
        blame.show_avatar = false;
        inline_blame.enabled = false;
      };
      disable_ai = true;
      telemetry = {
        diagnostics = false;
        metrics = false;
      };
      session.trust_all_worktrees = true;
      vim_mode = true;
      relative_line_numbers = "enabled";
      ui_font_size = 16;
      buffer_font_size = 15;
      theme = {
        mode = "system";
        light = "GitHub Light";
        dark = "Vague";
      };
      languages = {
        Ruby.language_servers = [ "ruby-lsp" "!solargraph" ];
        "HTML+ERB".language_servers = [ "herb" "ruby-lsp" ];
        "JS+ERB".language_servers = [ "ruby-lsp" ];
        "YAML+ERB".language_servers = [ "ruby-lsp" ];
      };
    };
  };

  programs.mise = {
    enable = true;
    enableZshIntegration = true;
    globalConfig = {
      tools = {
        node = "16";
        ruby = [ "latest" "3.4.9"];
        python = [ "latest" "3.9.6" "3.10" ];
        go = "latest";
        yarn = "3";
        uv = "latest";
        rust = "latest";
      };
      settings = {
        idiomatic_version_file_enable_tools = [ "ruby" ];
      };
    };
  };

  programs.git = {
    enable = true;
  };

  programs.git.settings = {
    user.name = "nonezerone";
    user.email = "koremailme@gmail.com";
  };

  programs.ghostty = {
    enable = true;
    enableZshIntegration = true;
    settings = {
      font-family = "JetBrains Mono";
      font-style = "Regular";
      font-feature = "-calt,-liga,-dlig";
      font-size = 11;
      font-thicken = true;
      font-thicken-strength = 255;
      adjust-cell-height = "40%";
      adjust-cell-width = "1%";
      adjust-cursor-height = "30%";
      grapheme-width-method = "unicode";
      selection-invert-fg-bg = true;
      shell-integration-features = "no-cursor";
      cursor-style = "block";
      cursor-style-blink = true;
      scrollback-limit = 100000000;
      window-decoration = false;
      gtk-titlebar = false;
      window-theme = "system";
      theme = "vague";
    };
    themes = {
      vague = {
        background = "#141415";
        foreground = "#cdcdcd";
        cursor-color = "cell-foreground";
        cursor-text = "cell-background";
        selection-background = "#252530";
        selection-foreground = "#cdcdcd";
        split-divider-color = "#878787";
        palette = [
          "0=#252530"
            "1=#d8647e"
            "2=#7fa563"
            "3=#f3be7c"
            "4=#6e94b2"
            "5=#bb9dbd"
            "6=#aeaed1"
            "7=#cdcdcd"
            "8=#606079"
            "9=#e08398"
            "10=#99b782"
            "11=#f5cb96"
            "12=#8ba9c1"
            "13=#c9b1ca"
            "14=#bebeda"
            "15=#d7d7d7"
        ];
      };
    };
  };

  home.shellAliases = {
    cp = "cp -iv";
    mv = "mv -iv";
    bc = "bc -ql";
    mkd = "mkdir -pv";
    diff = "diff --color=auto";
    ccat = "highlight --out-format=ansi";
    ls = "ls -hN --color=auto --group-directories-first";
    la = "ls -la -hN --color=auto --group-directories-first";
    ka = "killall";
    g = "git";
    gs = "git status";
    gp = "git pull";
    graph = "git log --oneline --graph --all";
    e = "$EDITOR";
    v = "$EDITOR";
    be = "bundle exec";
    c = "clear";
    sd = "cd ~ && cd $(find $HOME/dev/* -mindepth 1 -maxdepth 1 -type d | fzf)";
  };

  programs.zsh = {
    enable = true;
    autocd = true;
    defaultKeymap = "viins";

    autosuggestion.enable = true;
    fastSyntaxHighlighting.enable = true;

    history = {
      size = 25000;
      save = 25000;
      path = "${config.xdg.cacheHome}/zsh/history";
      ignoreSpace = true;
    };

    completionInit = ''
      autoload -U compinit
      zstyle ':completion:*' use-cache on
      zstyle ':completion:*' cache-path "$XDG_CACHE_HOME/zsh/.zcompcache"
      zstyle ':completion:*' menu select
      zmodload zsh/complist
      compinit -d "$XDG_CACHE_HOME/zsh/.zcompdump-$HOST"
      _comp_options+=(globdots)
    '';

    initContent = ''
      # Native library/header discovery for building things from source
      # (mainly `mise install ruby`, plus any Rust crate or Ruby/Python
      # native extension that links against openssl/zlib/etc). NixOS has no
      # /usr/include or /usr/lib, so nothing is found there by default;
      # $NIX_PROFILES lists every active profile (system + user + home-manager),
      # so walk them all to expose the libraries added in home.packages above.
      for _p in $NIX_PROFILES; do
        export PKG_CONFIG_PATH="$_p/lib/pkgconfig:$_p/share/pkgconfig:$PKG_CONFIG_PATH"
        export LIBRARY_PATH="$_p/lib:$LIBRARY_PATH"
        export CPATH="$_p/include:$CPATH"
      done
      unset _p

      # vi-mode navigation in the tab-complete menu
      bindkey -M menuselect 'h' vi-backward-char
      bindkey -M menuselect 'k' vi-up-line-or-history
      bindkey -M menuselect 'l' vi-forward-char
      bindkey -M menuselect 'j' vi-down-line-or-history
      bindkey -v '^?' backward-delete-char

      # Edit command line in $EDITOR
      autoload edit-command-line
      zle -N edit-command-line
      bindkey '^e' edit-command-line

      # Accept autosuggestion
      bindkey '^y' autosuggest-execute
    '';
  };

  programs.starship = {
    enable = true;
    enableZshIntegration = true;
    settings = {
      format = "$directory$git_branch$git_state$git_status$line_break$character";
      add_newline = true;

      directory.style = "blue";

      character = {
        success_symbol = "[|>](bold green)";
        error_symbol = "[|>](bold red)";
        vimcmd_symbol = "[<|](purple)";
      };

      git_branch = {
        format = "[$branch]($style)";
        style = "bright-black";
      };

      git_status = {
        format = "[[(*$conflicted$untracked$modified$staged$renamed$deleted)](218) ($ahead_behind$stashed)]($style)";
        style = "cyan";
        conflicted = "​";
        untracked = "​";
        modified = "​";
        staged = "​";
        renamed = "​";
        deleted = "​";
        stashed = "≡";
      };

      git_state = {
        format = "\\([$state( $progress_current/$progress_total)]($style)\\) ";
        style = "bright-black";
      };

      cmd_duration = {
        format = "[$duration]($style) ";
        style = "yellow";
      };

      python = {
        format = "[$virtualenv]($style) ";
        style = "bright-black";
      };

      battery.disabled = true;
    };
  };

  programs.noctalia = {
    enable = true;
    settings = {
      theme = {
        mode = "dark";
        source = "builtin";
        builtin = "Ayu";
      };
    };
  };

  programs.home-manager.enable = true;
}
