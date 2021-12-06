#!/bin/bash

# vasm IntelHEX output module produces broken output under
# some alignmet rules. Here we go via an intermediate format
# before using a common utility to convert to Intel HEX.
# Note that we have to re-specify the load address to the
# utility as our original ORG directive is lost in translation.

if [ $# != 1 ] ; then
	echo usage: $0 file-sans-extension
	exit 1
fi

if ! which srec_cat ; then
	echo Needed srec_cat command from deb package srecord.
	exit 1
fi

./vasmm68k_mot -align -Fbin -o tmp.bin $1.asm
srec_cat tmp.bin -binary -offset 0x20000 -o $1.hex -intel
