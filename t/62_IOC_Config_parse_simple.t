#!/usr/bin/perl

use strict;
use warnings;

use Test::More tests => 12;
use Test::Exception;

BEGIN {
    use_ok('IOC::Config');
    use_ok('t::Classes');
}

{
    my $config = IOC::Config->new();
    isa_ok($config, 'IOC::Config');
    
    lives_ok {
        $config->read('t/confs/62_IOC_Config_parse_simple.conf');
    } '... read file correctly';
}

my $r = IOC::Registry->new;
isa_ok( $r, 'IOC::Registry' );

my $s1 = $r->locateService( '/Cont1/Serv1' );
isa_ok( $s1, 'Foo' );
is( $s1->getVal, undef, '... got the correct value' );

my $s2 = $r->locateService( '/Cont1/Serv2' );
isa_ok( $s2, 'Foo' );
is( $s2->getVal, 2, '... got the correct value' );

my $s3 = $r->locateService( '/Cont1/Serv3' );
isa_ok( $s3, 'Bar' );
is( $s3->getVal, 'some_value', '... got the correct value' );

my $s4 = $r->locateService( '/Cont1/Serv4' );
isa_ok( $s4, 'Foo' );
is( $s4->getVal, 2, '... got the correct value' );
