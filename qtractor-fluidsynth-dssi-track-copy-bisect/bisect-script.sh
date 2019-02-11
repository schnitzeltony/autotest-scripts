#!/bin/sh

# (c) Copyright 2019 Andreas Müller <schnitzeltony@gmail.com>
# Licensed under terms of GPLv2

# Helper script to find commit introducing trouble in qtractor 0.9.3 -> 0.9.4:
# Copying a track containing fluidsynth-dssi plugin creates sessions with
# soundfont files set no more.

# Prerequisite:
# * xdotool: (https://github.com/jordansissel/xdotool) - should be part of
#   standard packages on most distros.
#
# Usage:
# * start jack
# * change into qtractor git folder
# * adjust path to soundfont in test.qtr
# * open test.qtr to check / path to test.qtr is set for next runs
# * git bisect start qtractor_0_9_4 qtractor_0_9_3
# * git bisect run <this script>
#
# Session files used:
# * test.qtr: contains one track with fluidsynth-dssi and loads $SOUNDFONT
# * copy.qtr is created automagically and grepped for $SOUNDFONT
#
#
# Running this script is like beeing remote hacked :)

TEST_SESSION="test.qtr"
COPY_SESSION="copy.qtr"
COPY_SESSION_FULL="${HOME}/Music/copy.qtr"
SOUNDFONT="/usr/share/soundfonts/FluidR3_GM.sf2"


# some colour pimps stolen from myself :)
# are we on terrminal?
if [ -t 1 ] ; then
    # tput available?
    if [ ! "x`which tput 2>/dev/null`" = "x" ] ; then
        # supports colors ?
        ncolors=`tput colors`
        if [ -n "$ncolors" -a  $ncolors -ge 8 ] ; then
            style_bold="`tput bold`"
            style_underline="`tput smul`"
            style_standout="`tput smso`"
            style_normal="`tput sgr0`"
            style_black="`tput setaf 0`"
            style_red="`tput setaf 1`"
            style_green="`tput setaf 2`"
            style_yellow="`tput setaf 3`"
            style_blue="`tput setaf 4`"
            style_magenta="`tput setaf 5`"
            style_cyan="`tput setaf 6`"
            style_white="`tput setaf 7`"
        fi
    fi
fi


# build qtractor from scratch and bail out in case of error
make clean > /dev/null 2>&1
make -j6 all > /dev/null 2>&1 || (echo "${style_red}${style_bold}Compile failed!${style_normal}"; exit 125)

# start qtractor
src/qtractor > /dev/null 2>&1 &

# get qtractor PID and check if started
qtractorPID=`pidof qtractor`
if [ -z "${qtractorPID}" ]; then
    echo "${style_red}${style_bold}qtractor was not started!${style_normal}"
    exit 125
fi

# give qtractor some time to settle
sleep 3

# find qtractor window
qtractorWID=`xdotool search -name "Qtractor | head -1"`

# open session
xdotool key --delay 100 --window $qtractorWID --clearmodifiers alt+f o
sleep 0.1
xdotool type  --window $qtractorWID --clearmodifiers $TEST_SESSION
sleep 0.1
xdotool key --window $qtractorWID --clearmodifiers Return
sleep 2

# navigate to first track
xdotool key --delay 100 --window $qtractorWID --clearmodifiers alt+t n f
sleep 0.1

# duplicate track
xdotool key --delay 100 --window $qtractorWID --clearmodifiers alt+t d
sleep 1

# save as
xdotool key --delay 100 --window $qtractorWID --clearmodifiers alt+f a
sleep 0.1
xdotool type  --window $qtractorWID --clearmodifiers $COPY_SESSION
xdotool key --window $qtractorWID --clearmodifiers Return
sleep 0.1
xdotool key --window $qtractorWID --clearmodifiers y
sleep 1

# close
xdotool key --window $qtractorWID --clearmodifiers alt+F4

# check if soundfont is still in session
COMMIT=`git log --pretty=format:'%h' -n 1`
if grep -q ${SOUNDFONT} $COPY_SESSION_FULL ; then
    echo "${style_green}Commit ${COMMIT} GOOD.${style_normal}"
    exit 0
else
    echo "${style_red}${style_bold}Commit ${COMMIT} BAD!${style_normal}"
    exit 1
fi
