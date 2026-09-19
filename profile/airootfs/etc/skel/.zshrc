# ~/.zshrc - UndraByte defaults
#
# Self-contained on purpose. grml-zsh-config owns /etc/skel/.zshrc, and the
# overlay is laid down before pacstrap, so shipping both is a file conflict
# that aborts the build. Sourcing a system zshrc if one exists keeps this
# working for anyone who installs grml-zsh-config later.
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
alias game='undrabyte-game run'

export EDITOR=nvim
export VISUAL=nvim
export PATH="$HOME/.local/bin:$PATH"

command -v starship &>/dev/null && eval "$(starship init zsh)"
command -v direnv   &>/dev/null && eval "$(direnv hook zsh)"

if [[ -z ${UNDRABYTE_GREETED-} && ! -e /run/undrabyte-greeted ]]; then
    export UNDRABYTE_GREETED=1
    command -v undrabyte-welcome &>/dev/null && undrabyte-welcome
    : > /run/undrabyte-greeted 2>/dev/null || true
fi
