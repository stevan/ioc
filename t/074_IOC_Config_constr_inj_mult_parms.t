#!/usr/bin/perl

use strict;
use warnings;

use Test::More tests => 10;
use Test::Exception;
use File::Spec;

BEGIN {
    use_ok('IOC::Config');
    use_ok('t::Classes');
}

{
    my $config = IOC::Config->new();
    isa_ok($config, 'IOC::Config');
    
    my $filename = File::Spec->catfile(
        't', 'confs', '074_IOC_Config_constr_inj_mult_parms.conf'
    );

    lives_ok {
        $config->read( $filename );
    } '... read file correctly';
}

my $r = IOC::Registry->new;
isa_ok( $r, 'IOC::Registry' );

my $s1 = $r->locateService( '/Cont1/Serv1' );
isa_ok( $s1, 'Baz' );
is( $s1->getVal(0), 2, '... got the correct value' );
is( $s1->getVal(1), 2, '... got the correct value' );
is( $s1->getVal(2), 'some_value', '... got the correct value' );
is_deeply( $s1->getVal(3), [ 'val' ], '... got the correct value' );
