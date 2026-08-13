# ~/.profile: executed by the command interpreter for login shells.
# This file is not read by bash(1), if ~/.bash_profile or ~/.bash_login
# exists.
# see /usr/share/doc/bash/examples/startup-files for examples.
# the files are located in the bash-doc package.

# the default umask is set in /etc/profile; for setting the umask
# for ssh logins, install and configure the libpam-umask package.
#umask 022

# if running bash
if [ -n "$BASH_VERSION" ]; then
    # For macos (see https://support.apple.com/en-us/102360)
    export BASH_SILENCE_DEPRECATION_WARNING=1
    # include .bashrc if it exists
    if [ -f "$HOME/.bashrc" ]; then
	. "$HOME/.bashrc"
    fi
fi

if [[ -d "/opt/homebrew/" ]]; then
    export HOMEBREW_PREFIX="/opt/homebrew";
    export HOMEBREW_CELLAR="/opt/homebrew/Cellar";
    export HOMEBREW_REPOSITORY="/opt/homebrew";
    export PATH="/opt/homebrew/bin:/opt/homebrew/sbin${PATH+:$PATH}";
    export MANPATH="/opt/homebrew/share/man${MANPATH+:$MANPATH}:";
    export INFOPATH="/opt/homebrew/share/info:${INFOPATH:-}";
fi

# set PATH so it includes user's private bin if it exists
if [ -d "$HOME/.bin" ] ; then
    PATH="$HOME/.bin:$PATH"
fi

# set PATH so it includes user's private bin if it exists
if [ -d "$HOME/bin" ] ; then
    PATH="$HOME/bin:$PATH"
fi

# set PATH so it includes user's private bin if it exists
if [ -d "$HOME/.local/bin" ] ; then
    PATH="$HOME/.local/bin:$PATH"
fi

if [ -d "$HOME/.pyenv" ]; then
    # If installed through the bash script
    if [ -d "$HOME/.pyenv/bin" ]; then
        export PATH="$HOME/.pyenv/bin:$PATH"
    fi
    eval "$(pyenv init --path)"
fi

if [ -d "$HOME/n" ]; then
    export N_PREFIX="$HOME/n"; [[ :$PATH: == *":$N_PREFIX/bin:"* ]] || PATH+=":$N_PREFIX/bin"
fi

if [ -d "/usr/local/bin" ]; then
    export PATH="/usr/local/bin:$PATH"
fi

if [[ -z $DISPLAY ]] && [[ $(tty) = /dev/tty1 ]]; then
    startx
fi

# ASDF depending on system and installation means <> in order
# Git install => arch && macos
# Pacman install => arch
# Homebrew => macos
if [ -f "$HOME/.asdf/asdf.sh" ]; then
    . "$HOME/.asdf/asdf.sh"
    if [ -f "$HOME/.asdf/completions/asdf.bash" ]; then
        . "$HOME/.asdf/completions/asdf.bash"
    fi
elif [ -d "/opt/asdf-vm/" ]; then
    . "/opt/asdf-vm/asdf.sh"
elif brew list asdf &> /dev/null; then
    . "$(brew --prefix asdf)/libexec/asdf.sh"
fi

if [[ -z $DISPLAY ]] && [[ $(tty) = /dev/tty1 ]]; then
    startx
fi
