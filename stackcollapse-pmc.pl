#!/usr/bin/env -S env perl
#
# Copyright (c) 2014 Ed Maste.  All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions
# are met:
#
# 1. Redistributions of source code must retain the above copyright
#    notice, this list of conditions and the following disclaimer.
# 2. Redistributions in binary form must reproduce the above copyright
#    notice, this list of conditions and the following disclaimer in the
#    documentation and/or other materials provided with the distribution.
#
# THIS SOFTWARE IS PROVIDED BY THE AUTHOR AND CONTRIBUTORS "AS IS" AND
# ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
# ARE DISCLAIMED.  IN NO EVENT SHALL THE AUTHOR OR CONTRIBUTORS BE LIABLE
# FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
# DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
# OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
# HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
# LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
# OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
# SUCH DAMAGE.
#
# stackcollapse-pmc.pl		collapse hwpmc samples into single lines.
#
# Parses a list of multiline stacks generated by "hwpmc -G", and outputs a
# semicolon-separated stack followed by a space and a count.
#
# Usage:
#   pmcstat -S unhalted-cycles -O pmc.out
#   pmcstat -R pmc.out -z16 -G pmc.graph
#   stackcollapse-pmc.pl pmc.graph > pmc.stack
#
# Example input:
#
# 03.07%  [17]       witness_unlock @ /boot/kernel/kernel
#  70.59%  [12]        __mtx_unlock_flags
#   16.67%  [2]          selfdfree
#    100.0%  [2]           sys_poll
#     100.0%  [2]            amd64_syscall
#   08.33%  [1]          pmap_ts_referenced
#    100.0%  [1]           vm_pageout
#     100.0%  [1]            fork_exit
# ...
#
# Example output:
#
# amd64_syscall;sys_poll;selfdfree;__mtx_unlock_flags;witness_unlock 2
# amd64_syscall;sys_poll;pmap_ts_referenced;__mtx_unlock_flagsgeout;fork_exit 1
# ...

use warnings;
use strict;

my @stack;
my $prev_count;
my $prev_indent = -1;

while (defined($_ = <>)) {
	if (m/^( *)[0-9.]+%  \[([0-9]+)\]\s*(\S+)/) {
		my $indent = length($1);
		if ($indent <= $prev_indent) {
			print join(';', reverse(@stack[0 .. $prev_indent])) .
			    " $prev_count\n";
		}
		$stack[$indent] = $3;
		$prev_count = $2;
		$prev_indent = $indent;
	}
}
print join(';', reverse(@stack[0 .. $prev_indent])) .  " $prev_count\n";
