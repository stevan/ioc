
package IOC::Container::Parameterized;

use strict;
use warnings;

our $VERSION = '0.01';

use Scalar::Util qw(blessed);

use IOC::Exceptions;

use base 'IOC::Container';

# TODO:
# refactor IOC::Container so that 
# this is not just cut-n-paste.
sub get {
    my ($self, $name, %params) = @_;
    (defined($name)) || throw IOC::InsufficientArguments "You must provide a name of the service";
    (exists ${$self->{services}}{$name}) 
        || throw IOC::ServiceNotFound "Unknown Service '${name}'";
    # a literal object can have no dependencies, 
    # and therefore can have no circular refs, so
    # we can optimize their usage there as well
    return $self->{services}->{$name}->instance() 
        if $self->{services}->{$name}->isa('IOC::Service::Literal');
    if ($self->_isServiceLocked($name)) {
        # NOTE:
        # if the service is parameterized
        # then we cannot defer it - SL
        ($self->{services}->{$name}->isa('IOC::Service::Parameterized')) 
            || throw IOC::IllegalOperation "The service '$name' is locked, cannot defer a parameterized instance";
        # otherwise ...    
        return $self->{services}->{$name}->deferred();
    }
    $self->_lockService($name);   
    my $instance = $self->{services}->{$name}->instance(%params);
    $self->_unlockService($name);      
    if (blessed($instance) && ref($instance) !~ /\:\:\_\:\:Proxy$/) {
        return $self->{proxies}->{$name}->wrap($instance) if exists ${$self->{proxies}}{$name};
    }
    return $instance;
}

1;

__END__

=head1 NAME

IOC::Container::Parameterized - An IOC Container object which supports parameterized services

=head1 DESCRIPTION

This is just like IOC::Container, expect that it will accepts a set of key/value parameters 
to the C<get> method. It is used to support IOC::Service::Parameterized.

=head1 METHODS

=over 4

=item B<get ($name, %params)>

=back

=head1 BUGS

None that I am aware of. Of course, if you find a bug, let me know, and I will be sure to fix it. 

=head1 CODE COVERAGE

I use B<Devel::Cover> to test the code coverage of my tests, see the CODE COVERAGE section of L<IOC> for more information.

=head1 SEE ALSO

=head1 AUTHOR

stevan little, E<lt>stevan@iinteractive.comE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright 2004-2007 by Infinity Interactive, Inc.

L<http://www.iinteractive.com>

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself. 

=cut

