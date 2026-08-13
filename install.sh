#!/bin/sh

# This is done so that the .config directory is an actual directory on the file
# system and not a symlink to my awesomewm config which would make all the files
# created under this directory part of this repo.
if [ ! -d "$HOME/.config/" ]; then
    mkdir -p $HOME/.config/
fi

stow bash
stow zsh
stow git
stow x-system
stow awesome

mkdir -p $HOME/.bin
ln -t $HOME/.bin bin/*

# Write git config with env variables
# Needs $NAME and $EMAIL to be set

if [ ! -f "$HOME/.gitconfig" ]; then

    echo "[commit]
    template = ~/.gitmessage
    gpgsign = true
[user]
	name = $NAME
	email = $EMAIL
[core]
    excludesFile = ~/.gitignore
" > $HOME/.gitconfig
fi
