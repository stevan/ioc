#!/usr/bin/perl

use strict;
use warnings;

use Test::More tests => 8;
use Test::Exception;
use File::Spec;

my $CLASS = 'IOC::Config';
use_ok( $CLASS );
use_ok( 't::Classes' );

{
    my $config = IOC::Config->new();
    isa_ok($config, 'IOC::Config');
    
    my $filename = File::Spec->catfile(
        't', 'confs', '69_IOC_Config_alias.conf',
    );

    lives_ok {
        $config->read( $filename );
    } '... read file correctly';
}

my $r = IOC::Registry->new;
isa_ok( $r, 'IOC::Registry' );

my $s_master = $r->locateService( '/Bar/Baz' );
isa_ok( $s_master, 'Foo' );

my $s_alias = $r->locateService( '/blarg/Baz2' );
isa_ok( $s_alias, 'Foo' );

is( $s_alias, $s_master );
