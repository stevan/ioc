#!/usr/bin/perl

use strict;
use warnings;

use Test::More tests => 9;
use Test::Exception;

BEGIN {
    use_ok('IOC::Config');
    use_ok('t::Classes');    
}

{
    my $config = IOC::Config->new();
    isa_ok($config, 'IOC::Config');
    
    lives_ok {
        $config->read('t/confs/63_IOC_Config_container_recursion.conf')
    } '... file read correctly';
}

my $r = IOC::Registry->new;
isa_ok( $r, 'IOC::Registry' );

my $s1 = $r->locateService( '/Cont1/Serv1' );
isa_ok( $s1, 'Foo' );
is( $s1->getVal, undef, '... got the expected value' );

my $s2 = $r->locateService( '/Cont1/SubCont1/Serv1' );
isa_ok( $s1, 'Foo' );
is( $s1->getVal, undef, '... got the expected value' );
