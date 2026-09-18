# ~/.zshrc - HexForge defaults
# grml's zsh config does the heavy lifting; this layers our bits on top.
[[ -r /etc/zsh/zshrc ]] && source /etc/zsh/zshrc

setopt HIST_IGNORE_ALL_DUPS SHARE_HISTORY EXTENDED_HISTORY
HISTFILE=~/.zsh_history
HISTSIZE=50000
SAVEHIST=50000

alias ll='ls -lah'
alias ..='cd ..'
command -v eza  &>/dev/null && alias ls='eza --icons --group-directories-first'
command -v bat  &>/dev/null && alias cat='bat --paging=never'
command -v btop &>/dev/null && alias top='btop'
alias game='hexforge-game run'

export EDITOR=nvim
export VISUAL=nvim
export PATH="$HOME/.local/bin:$PATH"

command -v starship &>/dev/null && eval "$(starship init zsh)"
command -v direnv   &>/dev/null && eval "$(direnv hook zsh)"

if [[ -z ${HEXFORGE_GREETED-} && ! -e /run/hexforge-greeted ]]; then
    export HEXFORGE_GREETED=1
    command -v hexforge-welcome &>/dev/null && hexforge-welcome
    : > /run/hexforge-greeted 2>/dev/null || true
fi
