#!/bin/bash

# vasm IntelHEX output module produces broken output under
# some alignmet rules. Here we go via an intermediate format
# before using a common utility to convert to Intel HEX.

if [ $# == 0 ] ; then
	echo usage: $0 asm-file [vasm-args]
	exit 1
fi

if ! which srec_cat ; then
	echo Needed srec_cat command from deb package srecord.
	exit 1
fi

if [ ! -f $1 ] ; then
	echo Cannot find file $1
	exit 1
fi

filename=$1
filename_sans_ext=${filename%.*}
shift

./vasmm68k_mot $@ -align -Fsrec -o tmp.srec $filename
srec_cat tmp.srec -o $filename_sans_ext.hex -intel
