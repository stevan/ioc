#!/usr/bin/perl

use strict;
use warnings;

use Test::More;

my @methods = qw(
    new
    read
    getConfig
    addServiceType
    removeServiceType
);

plan tests => 1 + @methods;

my $CLASS = 'IOC::Config';
use_ok( $CLASS );

foreach my $method (@methods) {
    can_ok( $CLASS, $method );
}
