#!/usr/bin/perl

use strict;
use warnings;

use Test::More tests => 6;
use Test::Exception;
use File::Spec;

my $CLASS = 'IOC::Config';
use_ok( $CLASS );

use_ok( 't::Classes' );

{
    my $filename = File::Spec->catfile(
        't', 'confs', '67_IOC_Config_constructor_injection_errors_01.conf',
    );

    my $object = IOC::Config->new();
    isa_ok( $object, 'IOC::Config' );

    throws_ok {
        $object->read( $filename );
    } "IOC::InsufficientArguments", '... file failed to read (as expected)';

    my $r = IOC::Registry->new;
    $r->unregisterContainer('Bar') if $r->hasRegisteredContainer( 'Bar');
}

{
    my $filename = File::Spec->catfile(
        't', 'confs', '67_IOC_Config_constructor_injection_errors_02.conf',
    );

    my $object = IOC::Config->new();
    isa_ok( $object, 'IOC::Config' );

    throws_ok {
        $object->read( $filename );
    } "IOC::InvalidArgument", '... file failed to read (as expected)';

    my $r = IOC::Registry->new;
    $r->unregisterContainer('Bar') if $r->hasRegisteredContainer( 'Bar');
}
