{ config, pkgs, ... }:

# Headless counterpart to home.nix for the renegade server: just the shell,
# editor and git setup, none of the desktop (noctalia/niri/ghostty/gtk) bits.
{
  home.username = "nonezerone";
  home.homeDirectory = "/home/nonezerone";
  # Keep in sync with system.stateVersion in configuration.nix.
  home.stateVersion = "25.05";

  home.packages = with pkgs; [
    fzf
    ripgrep
    fd
  ];

  programs.neovim = {
    enable = true;
    defaultEditor = true;
    viAlias = true;
    vimAlias = true;
    withRuby = false;
    withPython3 = false;
  };

  programs.git = {
    enable = true;
  };

  programs.git.settings = {
    user.name = "nonezerone";
    user.email = "koremailme@gmail.com";
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
      # Hostname always shown so a renegade shell can't be mistaken for exorcist.
      format = "$hostname$directory$git_branch$git_state$git_status$line_break$character";
      add_newline = true;

      hostname = {
        ssh_only = false;
        format = "[$hostname]($style) ";
        style = "bold yellow";
      };

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

      git_state = {
        format = "\\([$state( $progress_current/$progress_total)]($style)\\) ";
        style = "bright-black";
      };
    };
  };

  programs.home-manager.enable = true;
}
