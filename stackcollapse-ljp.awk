#!/usr/bin/env -S awk -f
#
# stackcollapse-ljp.awk	collapse lightweight java profile reports
#				into single lines stacks.
#
# Parses a list of multiline stacks generated by:
#
#  https://code.google.com/p/lightweight-java-profiler
#
# and outputs a semicolon separated stack followed by a space and a count.
#
# USAGE: ./stackcollapse-ljp.pl infile > outfile
#
# Example input:
#
#  42 3  my_func_b(prog.java:455)
#        my_func_a(prog.java:123)
#        java.lang.Thread.run(Thread.java:744)
#  [...]
#
# Example output:
#
#  java.lang.Thread.run;my_func_a;my_func_b 42
#
# The unused number is the number of frames in each stack.
#
# Copyright 2014 Brendan Gregg.  All rights reserved.
#
# CDDL HEADER START
#
# The contents of this file are subject to the terms of the
# Common Development and Distribution License (the "License").
# You may not use this file except in compliance with the License.
#
# You can obtain a copy of the license at docs/cddl1.txt or
# http://opensource.org/licenses/CDDL-1.0.
# See the License for the specific language governing permissions
# and limitations under the License.
#
# When distributing Covered Code, include this CDDL HEADER in each
# file and include the License file at docs/cddl1.txt.
# If applicable, add the following below this CDDL HEADER, with the
# fields enclosed by brackets "[]" replaced with your own identifying
# information: Portions Copyright [yyyy] [name of copyright owner]
#
# CDDL HEADER END
#
# 12-Jun-2014	Brendan Gregg	Created this.

$1 == "Total" {
	# We're done. Print last stack and exit.
	print stack, count
	exit
}

{
	# Strip file location. Comment this out to keep.
	gsub(/\(.*\)/, "")
}

NF == 3 {
	# New stack begins. Print previous buffered stack.
	if (count)
		print stack, count

	# Begin a new stack.
	count = $1
	stack = $3
}

NF == 1 {
	# Build stack.
	stack = $1 ";" stack
}
