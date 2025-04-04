#!/usr/bin/env -S perl -ws
#
# stackcollapse-wcp  Collapse wallClockProfiler backtraces
#
# Parse a list of GDB backtraces as generated by https://github.com/jasonrohrer/wallClockProfiler
#
# Copyright 2014 Gabriel Corona. All rights reserved.
# Portions Copyright 2020 Ștefan Talpalaru <stefantalpalaru@yahoo.com>
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

use strict;

my $current = "";
my $start_processing = 0;
my $samples = 0;
my %stacks;

while(<>) {
  s/^\s+|\s+$//g;

  if (m/^Full stacks/) {
    $start_processing = 1;
    next;
  }

  if (not $start_processing) {
      next;
  }

  if(m/^\d+\.\d+% =+ \((\d+) samples\)/) {
    # 99.791% ===================================== (17194 samples)
    $samples = $1;
    next;
  } elsif (m/^\d+: (.*)$/) {
    # 1: poll__YNjd8fE6xG8CRNwfLnrx0g_2   (at /mnt/sde1/storage/nim-beacon-chain-clean/vendor/nim-chronos/chronos/asyncloop.nim:343)
    my $function = $1;
    if ($current eq "") {
      $current = $function;
    } else {
      $current = $function . ";" . $current;
    }
  } elsif (m/^$/ and $current ne "") {
    $stacks{$current} += $samples;
    $current = "";
  }
}

foreach my $k (sort { $a cmp $b } keys %stacks) {
  print "$k $stacks{$k}\n";
}

