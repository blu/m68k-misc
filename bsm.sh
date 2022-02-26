#!/bin/bash

# assemblt to PGX 

if [ $# == 0 ] ; then
	echo usage: $0 asm-file [vasm-args]
	exit 1
fi

if [ ! -f $1 ] ; then
	echo Cannot find file $1
	exit 1
fi

filename=$1
filename_sans_ext=${filename%.*}
shift

./vasmm68k_mot $@ -align -Fbin -o $filename_sans_ext.pgx $filename
