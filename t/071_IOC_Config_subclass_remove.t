#!/usr/bin/perl

use strict;
use warnings;

use Test::More tests => 3;
use Test::Exception;
use File::Spec;

my $CLASS = 't::SubClass';
use_ok( $CLASS );

{
    my $filename = File::Spec->catfile(
        't', 'confs', '071_IOC_Config_subclass_remove.conf',
    );

    my $object = IOC::Config->new();
    isa_ok( $object, 'IOC::Config' );

    throws_ok {
        $object->read( $filename );
    } "IOC::InvalidArgument", '... file failed to read (as expected)';

    my $r = IOC::Registry->new;
    $r->unregisterContainer('Bar') if $r->hasRegisteredContainer( 'Bar');
}
