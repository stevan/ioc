#!/usr/bin/perl

use strict;
use warnings;

use Test::More tests => 27;
use Test::Exception;
use File::Spec;

BEGIN {
    use_ok('IOC::Config');
}

foreach my $test_number (1 .. 11) {
    my $object = IOC::Config->new();
    isa_ok( $object, 'IOC::Config' );

    my $filename = File::Spec->catfile(
        't', 'confs', '64_IOC_Config_errors_' . sprintf("%02d", $test_number) . '.conf'
    );

    throws_ok {
        $object->read( $filename );
    } "IOC::InitializationError", '... file failed to read (as expected)';

    my $r = IOC::Registry->new;
    $r->unregisterContainer('Bar') if $r->hasRegisteredContainer( 'Bar');
}

{
    my $object = IOC::Config->new();
    isa_ok( $object, 'IOC::Config' );

    throws_ok {
        $object->read('t/confs/64_IOC_Config_errors_12.conf' );
    } "IOC::InsufficientArguments", '... file failed to read (as expected)';

    my $r = IOC::Registry->new;
    $r->unregisterContainer('Bar') if $r->hasRegisteredContainer( 'Bar');
}

{
    my $object = IOC::Config->new();
    isa_ok( $object, 'IOC::Config' );

    throws_ok {
        $object->read('t/confs/64_IOC_Config_errors_13.conf' );
    } "IOC::InvalidArgument", '... file failed to read (as expected)';

    my $r = IOC::Registry->new;
    $r->unregisterContainer('Bar') if $r->hasRegisteredContainer( 'Bar');
}
