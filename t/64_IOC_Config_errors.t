#!/usr/bin/perl

use strict;
use warnings;

use Test::More;
use Test::Exception;

my @tests;

push @tests, [ <<X, 'IOC::InitializationError' ];
<Container Foo>
</Container>
X

push @tests, [ <<X, 'IOC::InitializationError' ];
<Service Foo>
</Service>
X

push @tests, [ <<X, 'IOC::InitializationError' ];
Literal q r
X

push @tests, [ <<X, 'IOC::InitializationError' ];
<Registry Foo>
  <Registry Bar>
  </Registry>
</Registry>
X

push @tests, [ <<X, 'IOC::InitializationError' ];
<Registry Foo>
  <Service Bar>
  </Service>
</Registry>
X

push @tests, [ <<X, 'IOC::InitializationError' ];
<Registry Foo>
  Literal q r
</Registry>
X

push @tests, [ <<X, 'IOC::InitializationError' ];
<Registry Foo>
  <Container Bar>
    <Registry Baz>
    </Registry>
  </Container>
</Registry>
X

push @tests, [ <<X, 'IOC::InitializationError' ];
<Registry Foo>
  <Container Bar>
    <Service Baz>
      <Registry Bif>
      </Registry>
    </Service>
  </Container>
</Registry>
X

push @tests, [ <<X, 'IOC::InitializationError' ];
<Registry Foo>
  <Container Bar>
    <Service Baz>
      <Container Bif>
      </Container>
    </Service>
  </Container>
</Registry>
X

push @tests, [ <<X, 'IOC::InitializationError' ];
<Registry Foo>
  <Container Bar>
    <Service Baz>
      <Service Bif>
      </Service>
    </Service>
  </Container>
</Registry>
X

push @tests, [ <<X, 'IOC::InitializationError' ];
<Registry Foo>
  <Container Bar>
    <Service Baz>
      Literal q r
    </Service>
  </Container>
</Registry>
X

push @tests, [ <<X, 'IOC::InsufficientArguments' ];
<Registry Foo>
  <Container Bar>
    <Service Baz>
    </Service>
  </Container>
</Registry>
X

push @tests, [ <<X, 'IOC::InsufficientArguments' ];
<Registry Foo>
  <Container Bar>
    <Service Baz>
      Type UnknownType
    </Service>
  </Container>
</Registry>
X

plan tests => 1 + 3 * @tests;

use IO::Scalar;

my $CLASS = 'IOC::Config';
use_ok( $CLASS );

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
