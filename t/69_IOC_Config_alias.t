#!/usr/bin/perl

use strict;
use warnings;

use Test::More;
use Test::Exception;

my $file = <<__END_FILE__;
<Registry Foo>
  <Container Bar>
    <Service Baz>
      Alias /blarg/Baz2
      Type ConstructorInjection
      Class Foo
    </Service>
  </Container>
</Registry>
__END_FILE__

plan tests => 8;

my $CLASS = 'IOC::Config';
use_ok( $CLASS );
use_ok( 't::Classes' );

{
    my $config = IOC::Config->new();
    isa_ok($config, 'IOC::Config');
    
    open my $fh, '<:scalar', \$file;

    lives_ok {
        $config->read( $fh );
    } '... read file correctly';
}

my $r = IOC::Registry->new;
isa_ok( $r, 'IOC::Registry' );

my $s_master = $r->locateService( '/Bar/Baz' );
isa_ok( $s_master, 'Foo' );

my $s_alias = $r->locateService( '/blarg/Baz2' );
isa_ok( $s_alias, 'Foo' );

is( $s_alias, $s_master );
