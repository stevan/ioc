#!/usr/bin/perl

use strict;
use warnings;

use Test::More;
use Test::Exception;

my @tests;

push @tests, [ <<X, 'IOC::InsufficientArguments' ];
<Registry Foo>
  <Container Bar>
    <Service Baz>
      Type ConstructorInjection
    </Service>
  </Container>
</Registry>
X

push @tests, [ <<X, 'IOC::InsufficientArguments' ];
<Registry Foo>
  <Container Bar>
    <Service Baz>
      Type ConstructorInjection
      Class Foo
      Unrecognized Parameter
    </Service>
  </Container>
</Registry>
X

plan tests => 2 + 3 * @tests;

use IO::Scalar;

my $CLASS = 'IOC::Config';
use_ok( $CLASS );

use_ok( 't::Classes' );

foreach my $test (@tests) {
    my ($config, $error) = @$test;

    my $fh = IO::Scalar->new( \$config );
    isa_ok( $fh, 'IO::Scalar' );

    my $object = $CLASS->new;
    isa_ok( $object, $CLASS );

    throws_ok {
        $object->read( $fh );
    } $error, "File failed to read:\n$@";

    my $r = IOC::Registry->new;
    $r->unregisterContainer('Bar') if $r->hasRegisteredContainer( 'Bar');
}
