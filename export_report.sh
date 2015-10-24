#!/usr/bin/env bash
F=$1
RES_DEST_DIR=res
RES_DEST_DIR_ABS=${PWD}/$RES_DEST_DIR
RES_SRC_DIR=$HOME/.gnucash
RES_FILES="normalize.css statement-table.css statement-table.js"
JQPLOT_SRC_DIR=$(readlink -m "$(dirname $(which gnucash))/../share/gnucash/jqplot")
JQPLOT_FILES="jquery.min.js"
sed -ri "s%(${RES_SRC_DIR}|${JQPLOT_SRC_DIR})%res%g" "$F"
mkdir -p $RES_DEST_DIR
cd $RES_SRC_DIR
cp $RES_FILES $RES_DEST_DIR_ABS
cd $JQPLOT_SRC_DIR
cp $JQPLOT_FILES $RES_DEST_DIR_ABS
