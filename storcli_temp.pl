#!/usr/bin/perl

use strict;
use warnings;
use JSON;

# Munin plugin for monitoring MegaRAID controller temperatures

my $STORCLI;

sub find_storcli {
    if (-x '/usr/bin/storcli64') {
        return '/usr/bin/storcli64';
    } elsif (-x '/opt/MegaRAID/storcli/storcli64') {
        return '/opt/MegaRAID/storcli/storcli64';
    }
    return undef;
}

sub autoconf {
    $STORCLI = find_storcli();
    if ($STORCLI) {
        print "yes\n";
    } else {
        print "no (storcli64 not found)\n";
    }
}

sub config {
    print "graph_title MegaRAID Controller Temperatures\n";
    print "graph_vlabel Temperature (°C)\n";
    print "graph_category raid\n";
    print "graph_info This graph shows the temperature of MegaRAID controllers\n";
    
    my @controllers = get_controllers();
    foreach my $ctrl (@controllers) {
        my $ctl_id = $ctrl->{ctl};
        my $model = $ctrl->{model};
        my $adapter = $ctrl->{adapter};
        print "temp_ctl$ctl_id.label Controller $ctl_id: $model ($adapter)\n";
        print "temp_ctl$ctl_id.type GAUGE\n";
        print "temp_ctl$ctl_id.warning 70\n";
        print "temp_ctl$ctl_id.critical 80\n";
    }
}

sub get_controllers {
    $STORCLI = find_storcli() unless $STORCLI;
    return unless $STORCLI;
    
    my $output = `$STORCLI show J 2>/dev/null`;
    return unless $output;
    
    my $data = eval { decode_json($output) };
    return unless $data;
    
    my @controllers;
    if (ref $data->{Controllers} eq 'ARRAY') {
        foreach my $ctrl (@{$data->{Controllers}}) {
            my $response = $ctrl->{Response Data} or next;
            my $overview = $response->{IT System Overview} or next;
            
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
    $STORCLI = find_storcli() unless $STORCLI;
    return unless $STORCLI;
    
    my %temps;
    
    my $output = `$STORCLI /call show temperature J 2>/dev/null`;
    return unless $output;
    
    my $data = eval { decode_json($output) };
    return unless $data;
    
    if (ref $data->{Controllers} eq 'ARRAY') {
        foreach my $ctrl (@{$data->{Controllers}}) {
            my $response = $ctrl->{Response Data} or next;
            my $props = $response->{Controller Properties} or next;
            
            my $ctl_id = $ctrl->{Command Status}->{Controller};
            
            foreach my $prop (@{$props}) {
                if ($prop->{Ctrl_Prop} =~ /temperature/i) {
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

sub dirtyconfig {
    config();
    fetch();
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