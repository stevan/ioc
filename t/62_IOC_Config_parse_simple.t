#!/usr/bin/perl

use strict;
use warnings;

use Test::More tests => 12;

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

my $s2 = $r->locateService( '/Cont1/Serv2' );
isa_ok( $s2, 'Foo' );
is( $s2->getVal, 2 );

my $s3 = $r->locateService( '/Cont1/Serv3' );
isa_ok( $s3, 'Bar' );
is( $s3->getVal, 'some_value' );

my $s4 = $r->locateService( '/Cont1/Serv4' );
isa_ok( $s4, 'Foo' );
is( $s4->getVal, 2 );

__DATA__
<Registry IOC>
  <Container Cont1>
    Literal Literal1 some_value
    <Service Serv1>
      Type ConstructorInjection
      Class Foo
      Constructor new
    </Service>
    <Service Serv2>
      Type ConstructorInjection
      Class Foo
      Constructor new
      Parameter 2
    </Service>
    <Service Serv3>
      Type SetterInjection
      Class Bar
      Constructor new
      Setter setVal Literal1
    </Service>
    <Service Serv4>
      Type BlockInjection
      subroutine \
    my $c = shift;\
    Foo->new( 2 );
    </Service>
  </Container>
</Registry>