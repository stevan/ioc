#!/usr/bin/perl

use strict;
use warnings;

use Test::More tests => 15;
use Test::Exception;

BEGIN {
    use_ok('IOC::Config');
    use_ok('t::Classes');
}

{
    my $config = IOC::Config->new();
    isa_ok($config, 'IOC::Config');
    
    lives_ok {
        $config->read('t/confs/73_IOC_Config_prototype.conf');
    } '... read file correctly';
}

my $r = IOC::Registry->new;
isa_ok( $r, 'IOC::Registry' );

my $s1 = $r->locateService( '/Cont1/Serv1' );
isa_ok( $s1, 'Foo' );
is( $s1->getVal, undef, '... got the correct value' );

my $s1a = $r->locateService( '/Cont1/Serv1' );
isa_ok( $s1a, 'Foo' );
is( $s1a->getVal, undef, '... got the correct value' );

is( $s1, $s1a );

my $s2 = $r->locateService( '/Cont1/Serv2' );
isa_ok( $s2, 'Foo' );
is( $s2->getVal, 2, '... got the correct value' );

my $s2a = $r->locateService( '/Cont1/Serv2' );
isa_ok( $s2a, 'Foo' );
is( $s2a->getVal, 2, '... got the correct value' );

isnt( $s2, $s2a );
