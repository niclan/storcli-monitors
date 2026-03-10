#!/usr/bin/perl

use strict;
use warnings;

# Munin Plugin for monitoring MegaRAID controller temperatures

sub get_temp {
    my @temps;
    my $output = `storcli /cx/gtemp`;  # Example command, replace with the correct command
    foreach my $line (split /\n/, $output) {
        if ($line =~ /Temperature\s+:(\s*\d+)/) {
            push @temps, $1;
        }
    }
    return @temps;
}

sub munin_config {
    print "graph_title MegaRAID Controller Temperature\n";
    print "graph_vlabel Temperature (C)\n";
    print "graph_category hardware\n";
    print "graph_info This plugin monitors the temperatures of MegaRAID controllers.\n";

    for my $i (0..$#{$temps}) {
        print "temp$i.label Controller $i\n";
    }
}

sub munin_value {
    my @temps = get_temp();
    for my $i (0..$#temps) {
        print "temp$i.value $temps[$i]\n";
    }
}

my $mode = shift;
if ($mode eq 'config') {
    munin_config();
} elsif ($mode eq 'value') {
    munin_value();
} else {
    die "Unknown mode: $mode\n";
}