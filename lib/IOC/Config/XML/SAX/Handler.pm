
package IOC::Config::XML::SAX::Handler;

use strict;
use warnings;

our $VERSION = '0.01';

#use Data::Dumper;

use IOC::Exceptions;

use IOC::Registry;

use IOC::Container;

use IOC::Service::Literal;

use IOC::Service;
use IOC::Service::ConstructorInjection;
use IOC::Service::SetterInjection;

#### NOTE:
#### does not handle prototypes yet !!!
#### FIXME
use IOC::Service::Prototype;
use IOC::Service::Prototype::ConstructorInjection;
use IOC::Service::Prototype::SetterInjection;

use base qw(XML::SAX::Base);

sub new {
    my $class = shift;
    my $self = $class->SUPER::new(@_);
    $self->{registry} = undef;
    $self->{current}  = undef;
    $self->{current_service} = undef;
    return $self;
}

sub _getName { 
    my ($self, $el) = @_;
    return $el->{Attributes}->{'{}name'}->{Value};
}

sub _getValue {
    my ($self, $el, $key) = @_;
    return undef unless exists $el->{Attributes}->{'{}' . $key};
    return $el->{Attributes}->{'{}' . $key}->{Value};        
}

sub _createService {
    my ($self) = @_;
    my $service_desc = $self->{current_service};
    if (! defined $service_desc->{type}) {
        # we have a plain Service
        my $sub = eval "sub { " . $service_desc->{data} . " }";
        throw IOC::ConfigurationError "could not compile : " . $service_desc->{data}, $@ if $@;
        $self->{current}->register(
            IOC::Service->new(
                $service_desc->{name} => $sub
            )
        );
    }
    elsif ($service_desc->{type} eq 'Literal') {          
        $self->{current}->register(
            IOC::Service::Literal->new($service_desc->{name} => $service_desc->{data})
        );               
    } 
    elsif ($service_desc->{type} eq 'ConstructorInjection') {  
        (exists $service_desc->{class}) 
            || throw IOC::ConfigurationError "Cant make a ConstructorInjection without a class";
        my @parameters;
        @parameters = map {
            if ($_->{type}) {
                if ($_->{type} eq 'component') {
                    IOC::Service::ConstructorInjection->ComponentParameter($_->{data})
                }
                elsif ($_->{type} eq 'perl') {
                    my $perl = $_->{data};
                    my $value = eval $perl;
                    throw IOC::OperationFailed "Could not compile '$perl'", $@ if $@;
                    $value;                    
                }                    
                else {
                    throw IOC::ConfigurationError "Unknown Type: " . $_->{type};
                }
            }
            else {
                $_->{data}
            }
        } @{$service_desc->{parameters}}
            if exists $service_desc->{parameters};
        $self->{current}->register(
            IOC::Service::ConstructorInjection->new($service_desc->{name} => (
                $service_desc->{class}->{name},
                $service_desc->{class}->{constructor},
                \@parameters
            ))
        );               
    }         
    elsif ($service_desc->{type} eq 'SetterInjection') {  
        (exists $service_desc->{class}) 
            || throw IOC::ConfigurationError "Cant make a ConstructorInjection without a class";                       
        my @setters;
        @setters = map {
            $_->{name} => $_->{data}
        } @{$service_desc->{setters}} 
            if exists $service_desc->{setters};            
        $self->{current}->register(
            IOC::Service::SetterInjection->new($service_desc->{name} => (
                $service_desc->{class}->{name},
                $service_desc->{class}->{constructor},
                \@setters
            ))
        );               
    }         
    $self->{current_service} = undef;     
}

sub start_element {
    my ($self, $el) = @_;
    my $type = lc($el->{Name});
    if ($type eq 'registry') {
        (!defined($self->{registry})) ||
            throw IOC::ConfigurationError "We already have a registry";
        $self->{registry} = IOC::Registry->new();
        $self->{current}  = $self->{registry};
    }
    elsif (defined($self->{registry})) {
        if ($type eq 'container') {
            my $c;
            if ($self->{current}->isa('IOC::Registry')) {
                $c = IOC::Container->new($self->_getName($el));
                $self->{current}->registerContainer($c);
            }
            elsif ($self->{current}->isa('IOC::Container')) {
                $c = IOC::Container->new($self->_getName($el));                
                $self->{current}->addSubContainer($c);
            }
            else {
                throw IOC::ConfigurationError "Containers only allowed within Registry and other Containers";                    
            }
            $self->{current} = $c;
        }
        elsif ($type eq 'service') {
            (!$self->{current}->isa('IOC::Registry')) ||
                throw IOC::ConfigurationError "Services must be within containers";  
            if ($self->{current_service}) {
                print Dumper $self->{current_service};
            }
            $self->{current_service} = {
                name => $self->_getName($el),
                type => $self->_getValue($el, 'type'),
            };                
        }
        elsif ($type eq 'class') {
            ($self->{current_service}) ||
                throw IOC::ConfigurationError "Class must be within Services";  
            $self->{current_service}->{class} = {
                name        => $self->_getName($el),
                constructor => $self->_getValue($el, 'constructor')
            };
        }
        elsif ($type eq 'parameter') {
            ($self->{current_service} && 
                ($self->{current_service}->{type} eq 'ConstructorInjection' && 
                    exists $self->{current_service}->{class})) ||
                    throw IOC::ConfigurationError "Paramter must be after Class and must be within Services";
            unless (exists $self->{current_service}->{parameters}) {
                $self->{current_service}->{parameters} = [];
            }
            push @{$self->{current_service}->{parameters}} => {
                type => $self->_getValue($el, 'type')
            };
        }            
        elsif ($type eq 'setter') {
            ($self->{current_service} && 
                ($self->{current_service}->{type} eq 'SetterInjection' && 
                    exists $self->{current_service}->{class})) ||
                    throw IOC::ConfigurationError "Paramter must be after Class and must be within Services";              
            unless (exists $self->{current_service}->{setters}) {
                $self->{current_service}->{setters} = [];
            }
            push @{$self->{current_service}->{setters}} => {
                name => $self->_getName($el)
            };                         
        }
    }
    else {
        throw IOC::ConfigurationError "$type is not allowed unless a Registry is created first";
    }
}  

sub end_element {
    my ($self, $el) = @_;	
    if (lc($el->{Name}) eq 'service') {
        #print Dumper $self->{current_service};
        $self->_createService();    
    }
}

sub characters {
    my ($self, $el) = @_;
    my $data = $el->{Data};
    return if $data =~ /^\s+$/;
    if ($self->{current_service}) {
        if ($self->{current_service}->{parameters}) {
            $self->{current_service}->{parameters}->[-1]->{data} = $data;
        }
        if ($self->{current_service}->{setters}) {
            $self->{current_service}->{setters}->[-1]->{data} = $data;                
        }
        else {
            $self->{current_service}->{data} = $data;
        }
    }
} 	

1;

__END__

=head1 NAME

IOC::Config::XML::SAX::Handler - An XML::SAX handler to read IOC Config files

=head1 SYNOPSIS

    use IOC::Config::XML::SAX::Handler;
    # used internally by IOC::Config::XML    

=head1 DESCRIPTION

=head1 METHODS

=over 4

=item B<>

=back

=head1 BUGS

None that I am aware of. Of course, if you find a bug, let me know, and I will be sure to fix it. 

=head1 CODE COVERAGE

I use B<Devel::Cover> to test the code coverage of my tests, see the CODE COVERAGE section of L<IOC> for more information.

=head1 SEE ALSO

=over 4

=item L<XML::SAX>

=back

=head1 AUTHOR

stevan little, E<lt>stevan@iinteractive.comE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright 2004 by Infinity Interactive, Inc.

L<http://www.iinteractive.com>

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself. 

=cut

