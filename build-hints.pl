#!/usr/bin/perl

open(FH, "memory.inc") || die;
while (<FH>) {
    next
	unless (/^\#define (\w+)\s+(0x\w+)/);
    print "$1 $2\n";
}
