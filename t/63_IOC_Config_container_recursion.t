#!/usr/bin/perl

use strict;
use warnings;

use Test::More tests => 8;

my $CLASS = 'IOC::Config';
use_ok( $CLASS );

use_ok( 't::Classes' );

my $object = $CLASS->new;
ok( $object->read( \*DATA ), 'File read correctly' );

my $r = IOC::Registry->new;
isa_ok( $r, 'IOC::Registry' );

my $s1 = $r->locateService( '/Cont1/Serv1' );
isa_ok( $s1, 'Foo' );
is( $s1->getVal, undef );

my $s2 = $r->locateService( '/Cont1/SubCont1/Serv1' );
isa_ok( $s1, 'Foo' );
is( $s1->getVal, undef );

__DATA__
<Registry IOC>
  <Container Cont1>
    Literal Literal1 some_value
    <Service Serv1>
      Type ConstructorInjection
      Class Foo
    </Service>
    <Container SubCont1>
      <Service Serv1>
        Type ConstructorInjection
        Class Foo
      </Service>
      <Container SubCont2>
        Literal Literal1 some_other_value
        <Service Serv1>
          Type ConstructorInjection
          Class Foo
        </Service>
      </Container>
    </Container>
  </Container>
</Registry>