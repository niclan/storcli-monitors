#!/usr/bin/perl

use strict;
use warnings;

# Munin plugin for monitoring MegaRAID controller temperatures

sub autoconf {
    print "yes\n";
}

sub config {
    print "graph_title MegaRAID Controller Temperatures\n";
    print "graph_vlabel Temperature (°C)\n";
    print "graph_category raid\n";
    print "graph_info This graph shows the temperature of MegaRAID controllers\n";
    print "temp.label Controller Temperature\n";
}

sub fetch {
    my $output = `storcli /call/eall/show all`;  # command to retrieve data from MegaRAID
    my @lines = split /\n/, $output;
    my $temp;

    foreach my $line (@lines) {
        if ($line =~ /Temperature (\d+)C/) {
            $temp = $1;
            last;
        }
    }

    print "temp.value $temp\n";
}

sub dirtyconfig {
    print "config\n";
}

my $mode = shift || die "Usage: $0 <autoconf|config|fetch|dirtyconfig>\n";

if ($mode eq 'autoconf') {
    autoconf();
} elsif ($mode eq 'config') {
    config();
} elsif ($mode eq 'fetch') {
    fetch();
} elsif ($mode eq 'dirtyconfig') {
    dirtyconfig();
} else {
    die "Unknown mode: $mode\n";
}