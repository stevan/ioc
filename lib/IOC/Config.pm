package IOC::Config;

use strict;
use warnings;

our $VERSION = '0.02';

use Config::ApacheFormat;

use IOC::Exceptions;
use IOC::Registry;

use IOC::Container;

use IOC::Service;
use IOC::Service::Prototype;
use IOC::Service::Literal;
use IOC::Service::ConstructorInjection;
use IOC::Service::Prototype::ConstructorInjection;
use IOC::Service::SetterInjection;
use IOC::Service::Prototype::SetterInjection;

my %ServiceTypes;

sub new {
    bless {
        _config => Config::ApacheFormat->new(
            duplicate_directives => 'combine',
            fix_booleans         => 1,
            hash_directives      => [qw(
                Setter Literal
            )],
            inheritance_support => 0,
        ),
    }, shift;
}

sub read {
    my $self = shift;

    my $config = $self->getConfig;

    $config->read( @_ );

    foreach my $type ( qw( Container Service Literal ) ) {
        throw IOC::InitializationError
            if $config->get( $type );
    }

    my $r = IOC::Registry->new;
    foreach my $registry ($config->get( 'Registry' )) {
        $registry = $config->block( $registry );

        foreach my $type ( qw( Registry Service Literal ) ) {
            throw IOC::InitializationError
                if $registry->get( $type );
        }

        foreach my $container ($registry->get( 'Container' )) {
            my $c = IOC::Container->new( $container->[1] );
            $r->registerContainer( $c );

            $self->_read( $r, $c, $registry, $container, "/$container->[1]" );
        }
    }

    return ~~1;
}

sub _read {
    my $self = shift;
    my ($r, $c, $parent, $container, $curr_path) = @_;

    $container = $parent->block( $container );

    foreach my $type ( qw( Registry ) ) {
        throw IOC::InitializationError
            if $container->get( $type );
    }

    $c->register(
        IOC::Service::Literal->new(
            $_ => $container->get( 'Literal', $_ )
        )
    ) for $container->get( 'Literal' );

    foreach my $child ($container->get( 'Container' )) {
        my $c2 = IOC::Container->new( $child->[1] );
        $c->addSubContainer( $c2 );

        $self->_read( $r, $c2, $container, $child, "${curr_path}/$child->[1]" );
    }

    foreach my $service ($container->get( 'Service' )) {
        my $name = $service->[1];
        $service = $container->block( $service );

        foreach my $type ( qw( Registry Container Service Literal ) ) {
            throw IOC::InitializationError
                if $service->get( $type );
        }

        my $service_type = lc $service->get( 'Type' );

        ((defined $service_type) && (length $service_type))
            || throw IOC::InsufficientArguments;

        (exists $ServiceTypes{ $service_type })
            || throw IOC::InvalidArgument;

        my $service_map = $ServiceTypes{ $service_type };

        my %values;
        my %legal_options;
        foreach my $req_opt ( map { lc } @{$service_map->{ required }} )
        {
            my @values = $service->get( $req_opt )
                || throw IOC::InsufficientArguments "$req_opt is required";

            $legal_options{ $req_opt } = ~~1;
        }

        @legal_options{ map { lc } @{$service_map->{ optional }} } =
            (~~1) x @{$service_map->{optional}};

        foreach my $parm ( map { lc } $service->get())
        {
            ( exists $legal_options{ $parm } )
                || throw IOC::InvalidArgument "$parm is not a legal option";
        }

        my $is_singleton = ~~1;
        if (defined( my $sing = $service->get( 'Singleton' ) )) {
            $is_singleton = $sing;
        }
        elsif (defined( my $val = $service->get( 'Prototype' ) )) {
            $is_singleton = $sing;
        }

        $c->register(
            $service_map->{subroutine}->( $name, $service, $is_singleton ),
        );

        foreach my $alias ( $service->get( 'Alias' ) )
        {
            $r->aliasService( "$curr_path/$name", $alias );
        }
    }
}

sub getConfig {
    (shift)->{_config}
}

my @standard_options = qw(
    type alias singleton prototype
);

sub addServiceType {
    my $class = shift;
    my %options = @_;

    $options{lc $_} = delete $options{$_}
        for keys %options;

    ((exists $options{name}) && (defined $options{name}) && (length $options{name}))
        || throw IOC::InsufficientArguments;

    ((exists $options{required}) && (ref $options{required} eq 'ARRAY'))
        || throw IOC::InsufficientArguments;
    @{$options{required}} = map { lc } @{$options{required}};

    ((!exists $options{optional}) || (ref $options{optional} eq 'ARRAY'))
        || throw IOC::InsufficientArguments;
    $options{optional} ||= [];
    @{$options{optional}} = map { lc } @{$options{optional}}, @standard_options;

    ((exists $options{subroutine}) && (ref $options{subroutine} eq 'CODE'))
        || throw IOC::InsufficientArguments;

    my $name = lc delete $options{name};

    (exists $ServiceTypes{ $name })
        && throw IOC::InvalidArgument;

    $ServiceTypes{ $name } = \%options;

    return ~~1;
}

sub removeServiceType {
    my $class = shift;
    my %options = @_;

    $options{lc $_} = delete $options{$_}
        for keys %options;

    ((exists $options{name}) && (defined $options{name}) && (length $options{name}))
        || throw IOC::InsufficientArguments;

    my $name = lc delete $options{name};

    (exists $ServiceTypes{ $name })
        || throw IOC::InvalidArgument;

    delete $ServiceTypes{ $name };

    return ~~1;
}

package IOC::Config::DefaultServiceTypes;

IOC::Config->addServiceType(
    name => 'BlockInjection',
    required => [ qw(
        Subroutine
    )],
    optional => [qw(
    )],
    subroutine => sub {
        my ($name, $block, $is_singleton) = @_;

        my @sub_text = $block->get( 'Subroutine' );
        my $sub = eval "sub { @sub_text };";

        (ref $sub eq 'CODE')
            || throw IOC::InvalidArgument "BlockInjection subroutine did not compile";

        my $class = $is_singleton
            ? 'IOC::Service'
            : 'IOC::Service::Prototype';

        return $class->new(
            $name => $sub,
        );
    },
);

IOC::Config->addServiceType(
    name => 'ConstructorInjection',
    required => [ qw(
        Class
    )],
    optional => [qw(
        Constructor Parameter
    )],
    subroutine => sub {
        my ($name, $block, $is_singleton) = @_;

        my $constructor = $block->get( 'Constructor' )
            || 'new';

        my $class = $is_singleton
            ? 'IOC::Service::ConstructorInjection'
            : 'IOC::Service::Prototype::ConstructorInjection';

        return $class->new(
            $name => (
                $block->get( 'Class' ),
                $constructor, [
                    $class->ComponentParameter($block->get( 'Parameter' )),
                ],
            ),
        );
    },
);

IOC::Config->addServiceType(
    name => 'SetterInjection',
    required => [ qw(
        Class
    )],
    optional => [qw(
        Constructor Setter
    )],
    subroutine => sub {
        my ($name, $block, $is_singleton) = @_;

        my $constructor = $block->get( 'Constructor' )
            || 'new';

        my $class = $is_singleton
            ? 'IOC::Service::SetterInjection'
            : 'IOC::Service::Prototype::SetterInjection';

        return $class->new(
            $name => (
                $block->get( 'Class' ),
                $constructor, [
                    (map {
                        { $_ => $block->get( 'Setter', $_ ) }
                    } $block->get( 'Setter' )),
                ],
            ),
        );
    },
);

1;

__END__

=head1 NAME

IOC::Config - Configuration files for IOC

=head1 SYNOPSIS

  use IOC::Config;

=head1 DESCRIPTION

This is the configuration file class for IOC. It uses
L<Config::ApacheFormat> as the actual configuration file reader. There
are several directives to the IOC configfile organization. When done,
the L<IOC::Registry> will be ready for use.

=head1 CLASS METHODS

=over 4

=item new()

This is the constructor. It takes a filename to the configuration
file. It returns a IOC::Config object. If it finds any REGISTRY
blocks, it will handle those and create the appropriate
L<IOC::Registry> calls.

=item addServiceType()

This will add a new service type. q.v. Subclassing for more info as to why you
might want to do this.

The parameters are:

=over 4

=item * name

This is the value for 'Type' in the block.

=item * required

This is an arrayref of case-insensitive parameter names that must exist for this
service type. If any of these parameters aren't there, then
IOC::InsufficientArguments is thrown.

=item * optional

This is an arrayref of case-insensitive parameter names that may exist for this
service type.

=item * subroutine

If this service type is found, this subroutine will be called. It will be passed
the following positional parameters:

=over 4

=item 1

This is the name of the block.

=item 2

The block object from Config::ApacheFormat.

=item 3

A boolean as to whether a singleton is expected or not.

=back

You expected to return an L<IOC::Service> object.

=back

=item removeServiceType()

=over 4

=item * name

This is the value for 'Type' in the block.

=back

=back

=head1 INSTANCE METHODS

=over 4

=item read()

This will hand off reading of the file to L<Config::ApacheFormat> and then make
the appropriate calls to L<IOC::Registry> based on the values in the config
file. For various reasons, this may throw any one of several IOC exceptions.

=item getConfig()

This will return the L<Config::ApacheFormat> object. IOC::Config delegates the
actual configuration file handling to L<Config::ApacheFormat>.

=back

=head1 DIRECTIVES

These are the legal directives that can be placed in an IOC config file.

=head2 REGISTRY

This is the registry. Everything within this will go into the
L<IOC::Registry> singleton.

Anything outside of a REGISTRY block will be parsed, but ignored by
the IOC hierarchy. This allows you to subclass the IOC::Config class
and add your own behaviors.

=head2 CONTAINER

This is the basic container for IOC. It takes a name and the name must
be unique among all siblings of this directive.

=over 4

=item Literal (optional)

This is the definition of some literal value at some point in the IOC
hierarchy. This option takes two values - the first is the name of the
literal and the second is its value.

=item Alias (optional)

This provides an alternate name instead of the name provided for in the block
definition.

=back

Example

 <Container Empty>
 </Container>

 <Container Foo>
   Literal some_name some_value
   <Service Bar1>
     ...
   </Service>
   <Container Bar2>
     ...
   </Container>
 </Container>

This will create a container called "Empty" with nothing in it. An
empty container may be useful if you intend on adding to it later on.

It will also create a container named "Foo" which contains two
children - Bar1 and Bar2. Bar1, which is a service, will follow the options for
L<SERVICE> below. Bar2, which is a container, will follow the options above. It
also contains a literal named "some_name" with a value of "some_value".

=head2 SERVICE

This is the meat and potatoes directive. With this, you will create
all your actual I<things>. There are various service types. Each type has its
own set of required and optional parameters, which may be combined with the
basic required and optional parameters.

=head3 Standard Parameters

=over 4

=item Type (required)

This specifies which type of service this block is building. If this parameter
is missing, a IOC::InsufficientArguments exception will be thrown.

=item Alias (optional)

This provides an alternate name instead of the name provided for in the block
definition.

=item Singleton (optional)

This determines whether or not the component will return a singleton.
It takes a boolean. This defaults to "yes".  (This is the inverse of
the I<prototype> option. It will override the value of I<prototype> if
both are set.)

=item Prototype (optional)

This determines whether or not the component will return a singleton.
It takes a boolean. This defaults to "no". (This is the inverse of the
I<singleton> option. It will be ignored if I<singleton> is set.)

=back

=head3 ConstructorInjection Type

The value for Type must be "ConstructorInjection".

=over 4

=item Class (required)

This is the class the component will instantiate from. It takes a string.

=item Constructor (optional)

This is the name of the constructor to use. This defaults to "new".

=item Parameter (optional)

This is a parameter value to be passed to the constructor. It may be either a
literal value or the pathname of some component.

Any legal IOC pathname can be given. The component does not have to be
defined before (and may not be defined within the configuration file), but
must be defined before the first time this SERVICE is requested.

This parameter may be set multiple times. The values will be put in a list in
the order that they are seen in the configuration file.

=back

=head3 SetterInjection Type

The value for Type must be "SetterInjection".

=over 4

=item Class (required)

This is the class the component will instantiate from. It takes a string.

=item Constructor (optional)

This is the name of the constructor to use. This defaults to "new".

=item Setter (optional)

This the name of the Setter as well as the legal IOC pathname that is
to be passed in.

This parameter may be set multiple times. The values will be put in a list in
the order that they are seen in the configuration file.

=back

=head3 BlockInjection type

The value for Type must be "BlockInjection".

=over 4

=item Subroutine (required)

This is the actual code to be used in the constructor. It will be
eval'ed when the component is requested. The subroutine will be passed
in, as the only parameter, the parent container. (This is just like the
behavior for the CODE reference required in the constructor for <IOC::Service>.)

It is recommended that this option be used as sparingly as possible.
Instead, the user should subclass this class and add service types as needed.

Note the backslashes used in the example below.

=back

Examples

 <Service Foo>
   Type ConstructorInjection
   Class Foo::Bar
   Constructor not_new
   Parameter /some/component
   Parameter literal1
 </Service>

 <Service Foo>
   Type SetterInjection
   Class Foo::Bar
   Constructor not_new
   Setter setSomeValue /some/component
   Setter setSomeOtherValue  literal1
 </Service>

 <Service Foo>
   Type BlockInjection
   subroutine \
my $c = shift; \
my $app = My::Application->new($c->get('authenticator')); \
$app->setLogger($c->get('logger')); \
$app->setDatabaseConnection($c->get('db_conn')); \
return $app;
 </Service>

=head1 SUBCLASSING

This class only implements a very basic IOC configuration file
handler. In many cases, it will be necessary to subclass this in order
to full realize the ideas behind creating a configuration file.

If you find yourself using the I<subroutine> parameter a lot and the
subroutines look very similar, that's a good sign you should be
subclassing and adding options, as needed.

Subclassing is very simple.

=over 4

=item 1

You need to identify a style that you will be creating.
Remember - ConstructorInjection and SetterInjection are just specific
types of BlockInjection. You, too, will be creating a specific type of
BlockInjection.

=item 2

Once you have your name, you will need to identify the options
that are required and optional. You can reuse option names - it is the Type that
determines exactly what's gonig on.

=item 3

You then create a subclass as so

 package My::IOC::Config;

 use strict;

 use base 'IOC::Config';

 __PACKAGE__->addServiceType(
   name => 'MyType',
   required => [ qw(
       Option1 Option2
   )],
   optional => [ qw(
       Option3 Option4
   )],
   subroutine => sub {
       my ($name, $block, $is_singleton) = @_;

       my $value = $block->get( 'Option1' );

       # Do some more stuff here
   },
 );

You may add as many service types as you'd like. You may even remove
predefined service types with
C<__PACKAGE__->removeServiceType()>.

In addition, this entire process is subclass-friendly. This means that
you can subclass your subclasses, as you need.

=item 4

Use your subclass instead of IOC::Config to read your configuration
file.

=back

=head1 BUGS

None that I am aware of. Of course, if you find a bug, let me know, and I will be sure to fix it. 

=head1 CODE COVERAGE

I use B<Devel::Cover> to test the code coverage of my tests, see the CODE COVERAGE section of L<IOC> for more information.

=head1 AUTHOR

Rob Kinyon, E<lt>rob@iinteractive.comE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright 2004 by Infinity Interactive, Inc.

L<http://www.iinteractive.com>

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself. 

=cut
