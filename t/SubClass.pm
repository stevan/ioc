package t::SubClass;

use base 'IOC::Config';

__PACKAGE__->addServiceType(
    name => 'MyType',
    required => [qw(
        ClassName
    )],
    optional => [qw(
        ConstrName ConstrParameter
    )],
    subroutine => sub {
        my ($name, $block) = @_;
        
        my $constructor = $block->get( 'ConstrName' )
            || 'new';

        return IOC::Service::ConstructorInjection->new(
            $name => (
                $block->get( 'ClassName' ),
                $constructor, [
                    $block->get( 'ConstrParameter' ),
                ],
            ),
        );
    },
);

__PACKAGE__->removeServiceType(
    name => 'ConstructorInjection',
);

1;
