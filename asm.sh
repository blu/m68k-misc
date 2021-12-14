#!/bin/bash

# vasm IntelHEX output module produces broken output under
# some alignmet rules. Here we go via an intermediate format
# before using a common utility to convert to Intel HEX.
# Note that we have to re-specify the load address to the
# utility as our original ORG directive is lost in translation.

if [ $# == 0 ] ; then
	echo usage: $0 file-sans-extension [vasm-args]
	exit 1
fi

if ! which srec_cat ; then
	echo Needed srec_cat command from deb package srecord.
	exit 1
fi

if [ ! -e $1.asm ] ; then
	echo Cannot find file $1.asm
	exit 1
fi

filename_base=$1
shift

./vasmm68k_mot $@ -align -Fbin -o tmp.bin $filename_base.asm
srec_cat tmp.bin -binary -offset 0x20000 -o $filename_base.hex -intel
