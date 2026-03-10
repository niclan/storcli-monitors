#!/usr/bin/perl

use strict;
use warnings;
use JSON;

# Munin plugin for monitoring MegaRAID controller temperatures

my $STORCLI = find_storcli();
    
sub find_storcli {
    my @bin = qw[/usr/bin/storcli64 /opt/MegaRAID/storcli/storcli64];

    for my $b (@bin) {
	return "sudo $b" if -x $b;
    }
    return undef;
}

sub autoconf {
    if (!$STORCLI) {
        print "no (storcli64 not found, are we running as root?)\n";
	exit 1;
    }
    my @c = get_controllers();
    if (scalar(@c) == 0) {
	print "no (no controllers found)\n";
	exit 1;
    }
    print "yes\n";
    exit 0;
}

sub config {
    if (!$STORCLI) {
	print "graph_title No storcli64 found\n";
	exit 0;
    }
	    
    print "graph_title MegaRAID Controller Temperatures\n";
    print "graph_vlabel Temperature (°C)\n";
    print "graph_category raid\n";
    print "graph_info This graph shows the temperature of MegaRAID controllers\n";
    
    my @controllers = get_controllers();
    foreach my $ctrl (@controllers) {
        my $ctl_id = $ctrl->{ctl};
        my $model = $ctrl->{model};
        my $adapter = $ctrl->{adapter};
	$adapter =~ s/^\s+//;
	print "temp_ctl$ctl_id.label Controller $ctl_id\n";
        print "temp_ctl$ctl_id.extinfo Controller $ctl_id: $model $adapter\n";
        print "temp_ctl$ctl_id.type GAUGE\n";
        print "temp_ctl$ctl_id.warning 80\n";
        print "temp_ctl$ctl_id.critical 90\n";
    }
}

sub get_controllers {
    my $output = `$STORCLI show J 2>/dev/null`;
    return unless $output;
    
    my $data = eval { decode_json($output) };
    return unless $data;
    
    my @controllers;
    if (ref $data->{Controllers} eq 'ARRAY') {
        foreach my $ctrl (@{$data->{Controllers}}) {
            my $response = $ctrl->{'Response Data'} or next;
            my $overview = $response->{'IT System Overview'} or next;
            
            foreach my $item (@{$overview}) {
                push @controllers, {
                    ctl => $item->{Ctl},
                    model => $item->{Model},
                    adapter => $item->{AdapterType}
                };
            }
        }
    }
    
    return @controllers;
}

sub get_temperatures {
    return unless $STORCLI;
    
    my %temps;
    
    my $output = `$STORCLI /call show temperature J 2>/dev/null`;
    return unless $output;
    
    my $data = eval { decode_json($output) };
    return unless $data;
    
    if (ref $data->{Controllers} eq 'ARRAY') {
        foreach my $ctrl (@{$data->{Controllers}}) {
            my $response = $ctrl->{'Response Data'} or next;
            my $props = $response->{'Controller Properties'} or next;
            
            my $ctl_id = $ctrl->{'Command Status'}->{Controller};
            
            foreach my $prop (@{$props}) {
                if ($prop->{'Ctrl_Prop'} =~ /temperature/i) {
                    $temps{$ctl_id} = $prop->{Value};
                }
            }
        }
    }
    
    return %temps;
}

sub fetch {
    my %temps = get_temperatures();
    
    foreach my $ctl_id (sort keys %temps) {
        print "temp_ctl$ctl_id.value $temps{$ctl_id}\n";
    }
}

my $mode = shift || 'fetch';

if ($mode eq 'autoconf') {
    autoconf();
} elsif ($mode eq 'config') {
    config();
} elsif ($mode eq 'fetch') {
    fetch();
} else {
    die "Usage: $0 <autoconf|config|fetch>\n";
}
