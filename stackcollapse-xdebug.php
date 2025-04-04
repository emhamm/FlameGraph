#!/usr/bin/env -S php
<?php
#
# Copyright 2018 Miriam Lauter (lauter.miriam@gmail.com).  All rights reserved.
#
#  This program is free software; you can redistribute it and/or
#  modify it under the terms of the GNU General Public License
#  as published by the Free Software Foundation; either version 2
#  of the License, or (at your option) any later version.
#
#  This program is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#  GNU General Public License for more details.
#
#  You should have received a copy of the GNU General Public License
#  along with this program; if not, write to the Free Software Foundation,
#  Inc., 59 Temple Place - Suite 330, Boston, MA  02111-1307, USA.
#
#  (http://www.gnu.org/copyleft/gpl.html)
#
# 13-Apr-2018   Miriam Lauter   Created this.

ini_set('error_log', null);
$optind = null;
$args = getopt("htc", ["help"], $optind);
if (isset($args['h']) || isset($args['help'])) {
    usage();
}

function usage($exit = 0) {
    echo <<<EOT
stackcollapse-xdebug.php  collapse php function traces into single lines.

Parses php samples generated by xdebug with xdebug.trace_format = 1
and outputs stacks as single lines, with methods separated by semicolons,
and then a space and an occurrence count. For use with flamegraph.pl.
See https://github.com/brendangregg/FlameGraph.

USAGE: ./stackcollapse-xdebug.php [OPTIONS] infile > outfile
    -h --help    Show this message
    -t           Weight stack counts by duration using the time index in the trace (default)
    -c           Invocation counts only. Simply count stacks in the trace and sum duplicates, don't weight by duration.

Example input:
For more info on xdebug and generating traces see
https://xdebug.org/docs/execution_trace.

Version: 2.0.0RC4-dev
TRACE START [2007-05-06 18:29:01]
1    0    0    0.010870    114112    {main}    1    ../trace.php    0
2    1    0    0.032009    114272    str_split    0    ../trace.php    8
2    1    1    0.032073    116632
2    2    0    0.033505    117424    ret_ord    1    ../trace.php    10
3    3    0    0.033531    117584    ord    0    ../trace.php    5
3    3    1    0.033551    117584
...
TRACE END   [2007-05-06 18:29:01]

Example output:

- c
{main};str_split 1
{main};ret_ord;ord 6

-t
{main} 23381
{main};str_split 64
{main};ret_ord 215
{main};ret_ord;ord 106

EOT;

    exit($exit);
}

function collapseStack(array $stack, string $func_name_key): string {
    return implode(';', array_column($stack, $func_name_key));
}

function addCurrentStackToStacks(array $stack, float $dur, array &$stacks) {
    $collapsed      = implode(';', $stack);
    $duration       = SCALE_FACTOR * $dur;

    if (array_key_exists($collapsed, $stacks)) {
        $stacks[$collapsed] += $duration;
    } else {
        $stacks[$collapsed] = $duration;
    }
}

function isEOTrace(string $l) {
    $pattern = "/^(\\t|TRACE END)/";
    return preg_match($pattern, $l);
}

$filename = $argv[$optind] ?? null;
if ($filename === null) {
    usage(1);
}

$do_time = !isset($args['c']);

// First make sure our file is consistently formatted with only one \t delimiting each field
$out = [];
$retval = null;
exec("sed -in 's/\t\+/\t/g' " . escapeshellarg($filename), $out, $retval);
if ($retval !== 0) {
    usage(1);
}

$handle = fopen($filename, 'r');

if ($handle === false) {
    echo "Unable to open $filename \n\n";
    usage(1);
}

// Loop till we find TRACE START
while ($l = fgets($handle)) {
    if (strpos($l, "TRACE START") === 0) {
        break;
    }
}

const SCALE_FACTOR = 1000000;
$stacks = [];
$current_stack = [];
$was_exit = false;
$prev_start_time = 0;

if ($do_time) {
    // Weight counts by duration
    // Xdebug trace time indices have 6 sigfigs of precision
    // We have a perfect trace, but let's instead pretend that
    // this was collected by sampling at 10^6 Hz
    // then each millionth of a second this stack took to execute is 1 count
    while ($l = fgets($handle)) {
        if (isEOTrace($l)) {
            break;
        }

        $parts = explode("\t", $l);
        list($level, $fn_no, $is_exit, $time) = $parts;

        if ($is_exit) {
            if (empty($current_stack)) {
                echo "[WARNING] Found function exit without corresponding entrance. Discarding line. Check your input.\n";
                continue;
            }

            addCurrentStackToStacks($current_stack, $time - $prev_start_time, $stacks);
            array_pop($current_stack);
        } else {
            $func_name = $parts[5];

            if (!empty($current_stack)) {
                addCurrentStackToStacks($current_stack, $time - $prev_start_time, $stacks);
            }

            $current_stack[] = $func_name;
        }
        $prev_start_time = $time;
    }
} else {
    // Counts only
    while ($l = fgets($handle)) {
        if (isEOTrace($l)) {
            break;
        }

        $parts = explode("\t", $l);
        list($level, $fn_no, $is_exit) = $parts;

        if ($is_exit === "1") {
            if (!$was_exit) {
                $collapsed = implode(";", $current_stack);
                if (array_key_exists($collapsed, $stacks)) {
                    $stacks[$collapsed]++;
                } else {
                    $stacks[$collapsed] = 1;
                }
            }

            array_pop($current_stack);
            $was_exit = true;
        } else {
            $func_name = $parts[5];
            $current_stack[] = $func_name;
            $was_exit = false;
        }
    }
}

foreach ($stacks as $stack => $count) {
    echo "$stack $count\n";
}
