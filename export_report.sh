#!/usr/bin/env bash
F=$1
RES_DEST_DIR=res
RES_DEST_DIR_ABS=${PWD}/$RES_DEST_DIR
RES_SRC_DIR=$HOME/.gnucash
RES_FILES="normalize.css statement-table.css"
sed -i "s%${RES_SRC_DIR}%res%g" "$F"
mkdir -p $RES_DEST_DIR
cd $RES_SRC_DIR
cp $RES_FILES $RES_DEST_DIR_ABS
