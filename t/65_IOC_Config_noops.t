#!/usr/bin/perl

use strict;
use warnings;

use Test::More;

my @tests = (
    [
        '',
    ],
    [
        '<foo>
        </foo>',
    ],
);

plan tests => 1 + 3 * @tests;

use IO::Scalar;

my $CLASS = 'IOC::Config';
use_ok( $CLASS );

foreach my $test (@tests) {
    my $fh = IO::Scalar->new( \$test->[0] );
    isa_ok( $fh, 'IO::Scalar' );

    my $object = $CLASS->new;
    isa_ok( $object, $CLASS );

    eval {
        $object->read( $fh );
    };
    ok( !$@, 'File read successfully, if with no point' );
}
