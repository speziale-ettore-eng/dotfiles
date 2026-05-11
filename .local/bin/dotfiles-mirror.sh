#!/bin/bash
######################################################################
# This script keeps a mirror of dotfiles.git updated.
#
# The remote to mirror should be named origin.
# The remote storing the mirror should be named mirror.
#######################################################t###############

dir=$HOME/Work/dotfiles-mirror.git                   # dotfiles directory

echo "Fetching from origin ..."
git -C $dir fetch --prune origin

echo "Pushing to mirror ..."
git -C $dir push --mirror mirror
