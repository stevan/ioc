#!/usr/bin/perl

use strict;
use warnings;

use Test::More;

my %options = (
    autoload_support    => 0,
    case_sensitive      => 0,
    duplicate_directives=> 'combine',
    expand_vars         => 0,
    fix_booleans        => 1,
    hash_directives     => [ 'Setter', 'Literal' ],
    include_directives  => [ 'Include' ],
    include_support     => 1,
    inheritance_support => 0,
    root_directive      => undef,
    setenv_vars         => 0,
    valid_blocks        => undef,
    valid_directives    => undef,
);

plan tests => (keys %options) + 3;

my $CLASS = 'IOC::Config';
use_ok( $CLASS );

my $object = $CLASS->new;
isa_ok( $object, $CLASS );

my $config = $object->getConfig;
isa_ok( $config, 'Config::ApacheFormat' );

while ( my ($opt,$val) = each %options ) {
    if ( ref $val ) {
        is_deeply( $config->$opt, $val, "'$opt' is correctly set." );
    }
    else {
        is( $config->$opt, $val, "'$opt' correctly set." );
    }
}
