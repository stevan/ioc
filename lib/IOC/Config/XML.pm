
package IOC::Config::XML;

use strict;
use warnings;

our $VERSION = '0.01';

use IOC::Exceptions;

use IOC::Registry;

use IOC::Container;

use IOC::Service::Literal;

use IOC::Service;
use IOC::Service::ConstructorInjection;
use IOC::Service::SetterInjection;

use IOC::Service::Prototype;
use IOC::Service::Prototype::ConstructorInjection;
use IOC::Service::Prototype::SetterInjection;

use XML::Simple ();

use Data::Dumper;

sub new {
    my ($_class) = @_;
    my $class = ref($_class) || $_class;
    my $config = {
        _config => undef
    };
    bless($config, $class);
    return $config;
}

sub read {
    my ($self, $source) = @_;
    $self->{_config} = XML::Simple::XMLin($source => (
                keyattr    => { Service => '+name' }, 
                forcearray => [ 'Service', 'Container', 'Parameter', 'Setter' ]
            ));
    my $reg = IOC::Registry->new();
    $self->_parse($reg);
}

sub getConfig { (shift)->{_config} }

sub _parse {
    my ($self, $reg) = @_;
    my $conf = $self->{_config};
    (!exists ${$conf}{Service}) 
        || throw IOC::InitializationError "You cannot have a service in a registry";
        
#     print Dumper $conf->{Container};        
      
    foreach my $container_conf (@{$conf->{Container}}) {
        my $container = $self->_parseContainer($container_conf);
        $reg->registerContainer($container);      
    }
}

sub _parseContainer {
    my ($self, $conf) = @_;    
    
    my $container = IOC::Container->new($conf->{name});      
    
    my @service_keys = keys %{$conf->{Service}};
    
    foreach my $service_key (@service_keys) {
        next if $service_key eq 'name';  

#         print Dumper $conf->{Service};
#         print Dumper $conf->{Service}->{$service_key};
        
        my $service = $self->_parseService($conf->{Service}->{$service_key});
        $container->register($service);
    }   
    
    # if we have sub-containers
    if (exists ${$conf}{Container}) {
        foreach my $container_conf (@{$conf->{Container}}) {
            my $sub_container = $self->_parseContainer($container_conf);
            $container->addSubContainer($sub_container);      
        }    
    }
    
    return $container;
}

sub _parseService {
    my ($self, $conf) = @_;    
    
    unless (exists ${$conf}{type}) {
        my $sub = eval "sub {" . $conf->{CDATA} . "}";
        (!$@ || ref($sub) eq 'CODE') 
            || throw IOC::OperationFailed "Could not compile sub for (" . $conf->{name} . ")"=> $@;
        return IOC::Service->new($conf->{name} => $sub);
    }
    else {
        my $type = $conf->{type};
        my $method = $self->can('_parse' . $type . 'Service');
        (defined($method) && ref($method) eq 'CODE')
            || throw IOC::InitializationError "We have no parser for type '$type'";
        return $self->$method($conf);
    }
}

sub _parseLiteralService {
    my ($self, $conf) = @_;  
    return IOC::Service::Literal->new($conf->{name} => (
        (exists ${$conf}{CDATA}) ? $conf->{CDATA} : $conf->{content}
    ));    
}

sub _parseConstructorInjectionService {
    my ($self, $conf) = @_;  
    my @parameters = map {
        if ($_->{type} eq 'component') {
            IOC::Service::ConstructorInjection->ComponentParameter($_->{content})
        }
        elsif ($_->{type} eq 'perl') {
            my $value = eval $_->{content};
            throw IOC::OperationFailed "Could not compile '" . $_->{content}. "'", $@ if $@;
            $value;
        }
        else {
            (exists ${$_}{CDATA}) ? $_->{CDATA} : $_->{content}
        }
    } @{$conf->{Parameter}};
    return IOC::Service::ConstructorInjection->new($conf->{name} => (
        $conf->{Class}->{name}, $conf->{Class}->{constructor},
        \@parameters
    ));    
}

sub _parseSetterInjectionService {
    my ($self, $conf) = @_;
    my @setters = map { 
        { $_->{name} => $_->{content} }
    } @{$conf->{Setter}};

#     print Dumper $conf;
#     print Dumper \@setters;    
    
    return IOC::Service::SetterInjection->new($conf->{name} => (
        $conf->{Class}->{name}, $conf->{Class}->{constructor}, \@setters
    ));    
}

1;

__END__

=head1 NAME

IOC::Config::XML - An XML Config reader for IOC

=head1 SYNOPSIS

  use IOC::Config::XML;

=head1 DESCRIPTION

=head1 SAMPLE XML CONF

    <Registry>
        <Container name='Application'>
            <Container name='Database'>      
                <Service name='dsn'      type='Literal'>dbi:Mock:</Service>            
                <Service name='username' type='Literal'>user</Service>            
                <Service name='password' type='Literal'>****</Service>                                    
                <Service name='connection' type='ConstructorInjection'>
                    <Class name='DBI' constructor='connect' />
                    <Parameter type='component'>dsn</Parameter>                
                    <Parameter type='component'>username</Parameter>
                    <Parameter type='component'>password</Parameter>                            
                </Service>
            </Container>     
            <Service name='logger_table' type='Literal'>tbl_log</Service>               
            <Service name='logger' type='SetterInjection'>
                <Class name='My::DB::Logger' constructor='new' />
                <Setter name='setDBIConnection'>/Database/connection</Setter>
                <Setter name='setDBTableName'>logger_table</Setter>            
            </Service> 
            <Service name='template_factory' type='ConstructorInjection'>
                <Class name='My::Template::Factory' constructor='new' />
                <Parameter type='perl'>[ path => 'test' ]</Parameter>                          
            </Service> 
            <Service name='app'>
                <CDATA>
                    my $c = shift;
                    my $app = My::Application->new();
                    $app->setLogger($c->get('logger'));
                    return $app;
                </CDATA>
            </Service>           
        </Container>
    </Registry>

=head1 METHODS

=over 4

=item B<new>

=item B<read ($source)>

=item B<getConfig>

=back

=head1 TO DO

=over 4

=item Parse arbitrary perl structures with ConstructorInjection arguments

=item Handle Includes

=item Handle Aliasing

=item Handle any prototype stuff

=item better error checking and handling

=back

=head1 BUGS

None that I am aware of. Of course, if you find a bug, let me know, and I will be sure to fix it. 

=head1 CODE COVERAGE

I use B<Devel::Cover> to test the code coverage of my tests, see the CODE COVERAGE section of L<IOC> for more information.

=head1 SEE ALSO

=over 4

=item L<XML::Simple>

=back

=head1 AUTHOR

stevan little, E<lt>stevan@iinteractive.comE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright 2004 by Infinity Interactive, Inc.

L<http://www.iinteractive.com>

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself. 

=cut

