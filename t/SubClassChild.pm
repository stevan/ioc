package t::SubClassChild;

use base 't::SubClass';

__PACKAGE__->addServiceType(
    name => 'MyChildType',
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

1;
