
package IOC::Config::XML;

use strict;
use warnings;

our $VERSION = '0.02';

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
        _config => {}
    };
    bless($config, $class);
    return $config;
}

sub read {
    my ($self, $source) = @_;
    (defined($source) && $source) 
        || throw IOC::InsufficientArguments "You must provide something to read";
    $self->{_config} = XML::Simple::XMLin($source => (
                forcearray    => [ 'Service', 'Container', 'Parameter', 'Setter' ],
                keyattr       => { 
                                    Service   => '+name',
                                    Container => '+name',
                                    Setter    => '+name'                                                                        
                                 }, 
                forcecontent  => 1,
                keeproot      => 1,
                suppressempty => 1
            ));
    my $reg = IOC::Registry->new();
    $self->_parse($reg);
}

## private methods

sub _parse {
    my ($self, $reg) = @_;
    my $conf = $self->{_config};
    # if we have nothing we do nothing
    return unless keys %{$conf};
    # but if we have something, the Registry must exist
    (exists $conf->{Registry}) 
        || throw IOC::ConfigurationError "Your root element must be a <Registry> tag";    
    (!exists $conf->{Registry}->{Service}) 
        || throw IOC::ConfigurationError "You cannot have a service in a registry";
        
#     print Dumper $conf->{Registry};  
    
    (ref($conf->{Registry}->{Container}) ne 'ARRAY')
        || throw IOC::ConfigurationError "Bad Config, Container missing a 'name' value";                
      
    foreach my $container_key (keys %{$conf->{Registry}->{Container}}) {
        my $container = $self->_parseContainer($conf->{Registry}->{Container}->{$container_key});
        $reg->registerContainer($container);      
    }
}

sub _parseContainer {
    my ($self, $conf) = @_;  

    # this can never be reached
#     (exists $conf->{name}) 
#         || throw IOC::ConfigurationError "Container must have 'name' value";      
    
    my $container = IOC::Container->new($conf->{name});      
    return $container unless exists $conf->{Service};

#         print Dumper $conf;

    (ref($conf->{Service}) ne 'ARRAY')
        || throw IOC::ConfigurationError "Bad Config, Service missing a 'name' value";
    
    foreach my $service_key (keys %{$conf->{Service}}) {

#         print Dumper $conf->{Service};
#         print Dumper $conf->{Service}->{$service_key};
        
        my $service = $self->_parseService($conf->{Service}->{$service_key});
        $container->register($service);
    }   
    
    # if we have sub-containers, then recurse
    if (exists $conf->{Container}) {
        foreach my $container_key (keys %{$conf->{Container}}) {
            my $sub_container = $self->_parseContainer($conf->{Container}->{$container_key});
            $container->addSubContainer($sub_container);      
        }    
    }
    
    return $container;
}

sub _parseService {
    my ($self, $conf) = @_;    
    
#     print Dumper $conf; 

    # apparently this can never be reached
    # because of how we deal with Services
#     (exists $conf->{name}) 
#         || throw IOC::ConfigurationError "Service must have 'name' value";
       
    unless (exists $conf->{type}) {
        my $service_class;
        if (exists $conf->{prototype} && $conf->{prototype} eq 'true') {
            $service_class = 'IOC::Service::Prototype';
        }
        else {
            $service_class = 'IOC::Service';
        }       
        (exists $conf->{content}) 
            || throw IOC::ConfigurationError "IOC::Service '" . $conf->{name} . "' must have a CDATA section";
        my $sub = eval "sub {" . $conf->{content} . "}";
        (!$@ || ref($sub) eq 'CODE') 
            || throw IOC::OperationFailed "Could not compile sub for (" . $conf->{name} . ")"=> $@;
        return $service_class->new($conf->{name} => $sub);
    }
    else {
        my $type = $conf->{type};
        my $method = $self->can('_parse' . $type . 'Service');
        (defined($method) && ref($method) eq 'CODE')
            || throw IOC::ConfigurationError "We have no parser for Service type '$type' named '" . $conf->{name} . "'";
        return $self->$method($conf);
    }
}

sub _parseLiteralService {
    my ($self, $conf) = @_;  
#     print Dumper $conf;     
    (exists $conf->{content}) 
        || throw IOC::ConfigurationError "IOC::Service::Literal '" . $conf->{name} . "' must have CDATA";    
    return IOC::Service::Literal->new($conf->{name} => $conf->{content});    
}

sub _parseConstructorInjectionService {
    my ($self, $conf) = @_;  
    my $service_class;
    if (exists $conf->{prototype} && $conf->{prototype} eq 'true') {
        $service_class = 'IOC::Service::Prototype::ConstructorInjection';
    }
    else {
        $service_class = 'IOC::Service::ConstructorInjection';
    }
#     print Dumper $conf;    
    my @parameters = map {
        if (exists $_->{type}) {
            if ($_->{type} eq 'component') {
                $service_class->ComponentParameter($_->{content});
            }
            elsif ($_->{type} eq 'perl') {
                my $perl = $_->{content};
                my $value = eval $perl;
                throw IOC::OperationFailed "Could not compile '$perl' for '" . $conf->{name} . "'", $@ if $@;
                $value;
            }
            else {
                throw IOC::ConfigurationError "I do not understand the 'type' parameter '" . $_->{type} . "' in Service named '" . $conf->{name} . "'";
            }
        }
        else {
            (exists $_->{content})
                || throw IOC::ConfigurationError "The <Parameter> must have content or a CDATA section in Service named  '" . $conf->{name} . "'";
            $_->{content};
        }
    } @{$conf->{Parameter}};
    (exists $conf->{Class})
        || throw IOC::ConfigurationError "$service_class '" . $conf->{name} . "' must have a <Class> tag";
    my $class = $conf->{Class};
    (exists $class->{name} && exists $class->{constructor}) 
        || throw IOC::ConfigurationError "$service_class '" . $conf->{name} . "' <Class> tag must have a 'name' and a 'constructor' value";
    return $service_class->new($conf->{name} => (
        $class->{name}, $class->{constructor}, \@parameters
    ));    
}

sub _parseSetterInjectionService {
    my ($self, $conf) = @_;
    my $service_class;
    if (exists $conf->{prototype} && $conf->{prototype} eq 'true') {
        $service_class = 'IOC::Service::Prototype::SetterInjection';
    }
    else {
        $service_class = 'IOC::Service::SetterInjection';
    }    
    my $setters = $conf->{Setter};
    my @setters = map { 
        { 
            $setters->{$_}->{name} => $setters->{$_}->{content}
        }
    } keys %{$setters};

#     print Dumper $conf;
#     print Dumper \@setters;    

    (exists $conf->{Class})
        || throw IOC::ConfigurationError "$service_class '" . $conf->{name} . "' must have a <Class> tag";
    my $class = $conf->{Class};
    (exists $class->{name} && exists $class->{constructor}) 
        || throw IOC::ConfigurationError "$service_class '" . $conf->{name} . "' <Class> tag must have a 'name' and a 'constructor' value";    
    return $service_class->new($conf->{name} => (
        $class->{name}, $class->{constructor}, \@setters
    ));    
}

1;

__END__

=head1 NAME

IOC::Config::XML - An XML Config reader for IOC

=head1 SYNOPSIS

  use IOC::Config::XML;
  
  my $conf_reader = IOC::Config::XML->new();
  $conf_reader->read('my_ioc_conf.xml');
  
  # now the IOC::Registry singleton is all configured

=head1 DESCRIPTION

This is the first version of an XML configuration module for IOC. Currently this uses L<XML::Simple>, which is a great module, but not really the best fit for this. I am planning on porting this over to use L<XML::SAX> in the very near future (once I finish my current project, which utilizes this). 

I consider this module to be late-BETA quality (it better be, it will be in production in about a month). As I said I plan on porting it to L<XML::SAX>, but that will in no way change the XML format itself. Since it uses XML::Simple, which in turn uses XML::Parser or XML::SAX whichever is available, the tests here will occasionally emit (mostly harmless) warnings, which will eventually be removed when XML::Simple is removed.

=head1 SAMPLE XML CONF

    E<lt>RegistryE<gt>
        E<lt>Container name='Application'E<gt>
            E<lt>Container name='Database'E<gt>      
                E<lt>Service name='dsn'      type='Literal'E<gt>dbi:Mock:E<lt>/ServiceE<gt>            
                E<lt>Service name='username' type='Literal'E<gt>userE<lt>/ServiceE<gt>            
                E<lt>Service name='password' type='Literal'E<gt>****E<lt>/ServiceE<gt>                                    
                E<lt>Service name='connection' type='ConstructorInjection' prototype='true'E<gt>
                    E<lt>Class name='DBI' constructor='connect' /E<gt>
                    E<lt>Parameter type='component'E<gt>dsnE<lt>/ParameterE<gt>                
                    E<lt>Parameter type='component'E<gt>usernameE<lt>/ParameterE<gt>
                    E<lt>Parameter type='component'E<gt>passwordE<lt>/ParameterE<gt>                            
                E<lt>/ServiceE<gt>
            E<lt>/ContainerE<gt>     
            E<lt>Service name='logger_table' type='Literal'E<gt>tbl_logE<lt>/ServiceE<gt>               
            E<lt>Service name='logger' type='SetterInjection'E<gt>
                E<lt>Class name='My::DB::Logger' constructor='new' /E<gt>
                E<lt>Setter name='setDBIConnection'E<gt>/Database/connectionE<lt>/SetterE<gt>
                E<lt>Setter name='setDBTableName'E<gt>logger_tableE<lt>/SetterE<gt>            
            E<lt>/ServiceE<gt> 
            E<lt>Service name='template_factory' type='ConstructorInjection'E<gt>
                E<lt>Class name='My::Template::Factory' constructor='new' /E<gt>
                E<lt>Parameter type='perl'E<gt>[ path =E<gt> 'test' ]E<lt>/ParameterE<gt>                          
            E<lt>/ServiceE<gt> 
            E<lt>Service name='app'E<gt>
                E<lt>![CDATA[
                    my $c = shift;
                    my $app = My::Application-E<gt>new();
                    $app-E<gt>setLogger($c-E<gt>get('logger'));
                    return $app;
                ]]E<gt>
            E<lt>/ServiceE<gt>           
        E<lt>/ContainerE<gt>
    E<lt>/RegistryE<gt>

=head1 METHODS

=over 4

=item B<new>

Create a new XML::Config::XML object to read a configuration and intialize the L<IOC::Registry>.

=item B<read ($source)>

Given an XML C<$source> file or string, this will read the XML in it and intialize the L<IOC::Registry> singleton.

=back

=head1 TO DO

=over 4

=item Convert this from XML::Simple to XML::SAX

This is my first prority, however I do not currently have enough time to do it, and XML::Simple is solid and working fine for now.

=item Handle Includes

This will be implemented when I move to XML::SAX.

=item Handle Aliasing

This is a minor feature of IOC::Registry, but I want to support it in here eventually. It shouldn't be a problem really, just don't currently have a need to get it in place.

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

