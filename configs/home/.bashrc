#
# ~/.bashrc
#

# If not running interactively, don't do anything
[[ $- != *i* ]] && return

alias ls='ls --color=auto'
alias grep='grep --color=auto'
# Prompt: Caelestia Blush (dusty rose accent, greyscale like the kitty theme)
#   ~/projects/foo  main*  ❯
source /usr/share/git/completion/git-prompt.sh
GIT_PS1_SHOWDIRTYSTATE=1
GIT_PS1_SHOWUNTRACKEDFILES=1
__blush_prompt() {
  local st=$?
  local rose='\[\e[38;2;216;160;180m\]' dim='\[\e[38;2;142;142;147m\]'
  local fail='\[\e[38;2;232;112;128m\]' bold='\[\e[1m\]' r='\[\e[0m\]'
  local arrow=$rose; (( st != 0 )) && arrow=$fail
  local git; git=$(__git_ps1 ' %s')
  [[ -n $git ]] && git=" ${dim}${git}${r}"
  PS1="${bold}${rose}\w${r}${git} ${arrow}❯${r} "
}
PROMPT_COMMAND=__blush_prompt

# xfetch path
export PATH="/home/vymnkoo/.local/bin:$PATH"

# Shortcuts (ported from the old fish abbrs)
alias gd='git diff' ga='git add .' gc='git commit -am' gl='git log' gs='git status'
alias gst='git stash' gsp='git stash pop' gp='git push' gpl='git pull'
alias gsw='git switch' gsm='git switch main' gb='git branch' gbd='git branch -d'
alias gco='git checkout' gsh='git show'
command -v lazygit &>/dev/null && alias lg='lazygit'
command -v eza &>/dev/null && alias ls='eza --icons --group-directories-first -1'
alias l='ls' ll='ls -l' la='ls -a' lla='ls -la'

# Greeting (same as the old fish_greeting)
command -v fastfetch &>/dev/null && { fastfetch --key-padding-left 5; echo; }
