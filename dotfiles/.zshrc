HISTFILE=~/.config/zsh/.histfile
HISTSIZE=500
SAVEHIST=10000

setopt autocd extendedglob
unsetopt beep
bindkey -v

[[ -o interactive ]] && stty -ixon

source $HOMEBREW_PREFIX/share/zsh-autocomplete/zsh-autocomplete.plugin.zsh

export EDITOR="nvim"
export VISUAL="nvim"

export CLICOLOR=1
export LSCOLORS="ExFxCxDxBxegedabagacad"

if command -v rg >/dev/null 2>&1; then
    alias grep='rg'
else
    alias grep="/usr/bin/grep"
fi

export LESS_TERMCAP_mb=$'\E[1;31m'
export LESS_TERMCAP_md=$'\E[1;31m'
export LESS_TERMCAP_me=$'\E[0m'
export LESS_TERMCAP_se=$'\E[0m'
export LESS_TERMCAP_so=$'\E[1;44;33m'
export LESS_TERMCAP_ue=$'\E[0m'
export LESS_TERMCAP_us=$'\E[1;32m'

alias da='date "+%Y-%m-%d %A %T %Z"'

if command -v trash >/dev/null 2>&1; then
    alias rm='trash -v'
else
    alias rm='rm -i'
fi

alias cp='cp -i'
alias mv='mv -i'
alias mkdir='mkdir -p'
alias ping='ping -c 10'
alias less='less -R'
alias cls='clear'
alias vi='nvim'
alias svi='sudo nvim'
alias o='open .'

if command -v bat >/dev/null 2>&1; then
    alias cat='bat'
else
    alias cat='/usr/bin/cat'
fi
alias flushdns='sudo dscacheutil -flushcache; sudo killall -HUP mDNSResponder'

alias gaa='git add .'
alias gcm='git commit -m'
alias gpsh='git push'
alias gss='git status -s'
alias gs='echo ""; echo "*********************************************"; echo -e "   DO NOT FORGET TO PULL BEFORE COMMITTING"; echo "*********************************************"; echo ""; git status'

alias rmd='/bin/rm -rfv '

alias ls='ls -aFGh'
alias la='ls -Alh'
alias lla='ls -Al'
alias las='ls -A'
alias lls='ls -l'
alias ll='ls -lah'
alias lt='ls -ltrh'
alias lr='ls -lR'
alias lm='ls -alh | more'

alias h='history | grep'
alias p='ps aux | grep'
alias f='find . | grep'

alias topcpu="/bin/ps -eo pcpu,pid,user,args | sort -k 1 -r | head -10"

alias folders='du -h -d 1'
alias mountedinfo='df -h'

if command -v tree >/dev/null 2>&1; then
    alias tree='tree -CAhF --dirsfirst'
    alias treed='tree -CAFd'
fi

alias mktar='tar -cvf'
alias mkbz2='tar -cvjf'
alias mkgz='tar -cvzf'
alias untar='tar -xvf'
alias unbz2='tar -xvjf'
alias ungz='tar -xvzf'

alias docker-clean='
docker container prune -f &&
docker image prune -f &&
docker network prune -f &&
docker volume prune -f
'

# Extract archives

extract() {
    for archive in "$@"; do
        if [[ -f "$archive" ]]; then
            case "$archive" in
            *.tar.bz2) tar xvjf "$archive" ;;
            *.tar.gz) tar xvzf "$archive" ;;
            *.bz2) bunzip2 "$archive" ;;
            *.rar) unrar x "$archive" ;;
            *.gz) gunzip "$archive" ;;
            *.tar) tar xvf "$archive" ;;
            *.tbz2) tar xvjf "$archive" ;;
            *.tgz) tar xvzf "$archive" ;;
            *.zip) unzip "$archive" ;;
            *.Z) uncompress "$archive" ;;
            *.7z) 7z x "$archive" ;;
            *) echo "don't know how to extract '$archive'" ;;
            esac
        else
            echo "'$archive' is not a valid file"
        fi
    done
}

# Search text in files

ftext() {
    grep -iIHrn --color=always "$1" . | less -R
}

# Copy and go

cpg() {
    if [[ -d "$2" ]]; then
        cp "$1" "$2" && cd "$2"
    else
        cp "$1" "$2"
    fi
}

# Move and go

mvg() {
    if [[ -d "$2" ]]; then
        mv "$1" "$2" && cd "$2"
    else
        mv "$1" "$2"
    fi
}

# Make and go

mkdirg() {
    mkdir -p "$1"
    cd "$1"
}

# up 4 dirs

up() {
    local d=""
    local limit="$1"

    for ((i = 1; i <= limit; i++)); do
        d+="../"
    done

    [[ -z "$d" ]] && d="../"
    cd "$d"
}

# Trim whitespace

trim() {
    local var="$*"
    var="${var#"${var%%[![:space:]]*}"}"
    var="${var%"${var##*[![:space:]]}"}"
    echo -n "$var"
}

# Automatic ls after cd

cd() {
    if [ -n "$1" ]; then
        builtin cd "$@" && ls
    else
        builtin cd ~ && ls
    fi
}

if command -v starship >/dev/null 2>&1; then
    eval "$(starship init zsh)"
fi
