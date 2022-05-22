#!/bin/bash

if [ $# == 0 ] ; then
	echo usage: $0 asm-file [as68k-args]
	exit 1
fi

if [ ! -f $1 ] ; then
	echo Cannot find file $1
	exit 1
fi

filename=$1
filename_sans_ext=${filename%.*}
shift

as68k --target foenix ${filename} $@
ln68k --output-format raw ${filename_sans_ext}.o ./a2560u.scm -o ${filename_sans_ext}.elf
