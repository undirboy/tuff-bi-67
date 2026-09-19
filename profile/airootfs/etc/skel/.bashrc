# ~/.bashrc - UndraByte defaults
[[ $- != *i* ]] && return

alias ls='ls --color=auto'
alias grep='grep --color=auto'
alias ll='ls -lah'
alias ..='cd ..'
command -v eza  &>/dev/null && alias ls='eza --icons --group-directories-first'
command -v bat  &>/dev/null && alias cat='bat --paging=never'
command -v btop &>/dev/null && alias top='btop'

export EDITOR=nvim
export VISUAL=nvim
export PATH="$HOME/.local/bin:$PATH"

# MangoHud only when asked for, never globally: it breaks some GL apps.
alias mh='mangohud'
alias game='undrabyte-game run'

if command -v starship &>/dev/null; then
    eval "$(starship init bash)"
else
    PS1='\[\033[1;36m\]\u@\h\[\033[0m\]:\[\033[1;34m\]\w\[\033[0m\]\$ '
fi

# One-time greeting per boot, not per shell.
if [[ -z ${UNDRABYTE_GREETED-} && ! -e /run/undrabyte-greeted ]]; then
    export UNDRABYTE_GREETED=1
    command -v undrabyte-welcome &>/dev/null && undrabyte-welcome
    : > /run/undrabyte-greeted 2>/dev/null || true
fi
