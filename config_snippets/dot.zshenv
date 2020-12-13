SAVEHIST=10000
HISTFILE=~/.zhist

PROMPT=%m:%~%(#.#.\>)
[ "$USERNAME" != sec -a "$USERNAME" != root ] && PROMPT=%n@$PROMPT
PROMPT2=\(%3_\)%(#.#.\>)
PROMPT3=\(%3_\)\?

PROMPT='${PYBOMBS_PREFIX+[${PYBOMBS_PREFIX##*/}] }'"$PROMPT"
setopt PROMPT_SUBST

setopt INTERACTIVE_COMMENTS  #way coool
setopt CDABLE_VARS AUTO_NAME_DIRS #even better!
setopt LIST_TYPES LIST_AMBIGUOUS AUTO_LIST AUTO_MENU NO_LIST_BEEP 
setopt APPEND_HISTORY #sounds useful
setopt HIST_IGNORE_DUPS HIST_NO_STORE HIST_IGNORE_SPACE EXTENDED_HISTORY
setopt NO_HUP NO_BG_NICE
setopt NO_ALWAYS_LAST_PROMPT NO_AUTO_REMOVE_SLASH # Evil new zsh defaults
#PRINT_EXIT_VALUE

alias X='chmod ugo+x '
alias j='jobs -l'
alias l.='l *(.)'       # Files
alias l/='l -d *(/)'    # Directorys
alias l@='l -d *(@)'    # Symlinks
l () {
        ls -lF "$@"
}

p() { ps auxwww| awk "NR==1;/${*:-$USER}/" }
WORDCHARS='*?_-.[]~=&;!#$%^(){}<>'
bindkey '^i' expand-or-complete-prefix
bindkey '^[#' pound-insert
alias ..='cd ..'
alias cnt="sort|uniq -c|sort -n"
alias zless='LESSOPEN="|zcat %s" less'
alias cwd='cd "`/bin/pwd`"' 

alias avg='perl -ne '\''$a+=$_;END{print $a / $.,"\n";}'\'
alias add='perl -ne '\''$a+=$_;END{print $a,"\n";}'\'



PATH=~/bin:~/.local/bin:~/iridium-toolkit:${PATH}

pp () {
        awk '{print $'$1'}'
}

ren () {
        if [ "$1" = "-d" ]
        then
                do=(echo mv) 
                shift
        else
                do=(mv) 
        fi
        reg="$1" 
        shift
        [ -z "$1" ] && echo "$0 [-d] regex files" && return
        for a in $*
        do
                fo=`echo "$a"|perl -pe "$reg"` 
                if [ "$fo" = "$a" ]
                then
                        echo $a unchanged....
                else
                        $do $a $fo
                fi
        done
}

