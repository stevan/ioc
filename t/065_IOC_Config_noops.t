#!/usr/bin/perl

use strict;
use warnings;

use Test::More tests => 5;
use Test::Exception;
use File::Spec;

my $CLASS = 'IOC::Config';
use_ok( $CLASS );

foreach my $test_number (1 .. 2) {
    my $filename = File::Spec->catfile(
        't', 'confs', '065_IOC_Config_noops_' . sprintf("%02d", $test_number) . '.conf'
    );

    my $object = IOC::Config->new();
    isa_ok( $object, 'IOC::Config' );

    lives_ok {
        $object->read( $filename );
    } 'File read successfully, if with no point';
}
