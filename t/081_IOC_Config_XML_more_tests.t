#!/usr/bin/perl

use strict;
use warnings;

use Test::More no_plan => 1;
use Test::Exception;

BEGIN {
    use_ok('IOC::Config::XML');
}


# TO DO TESTS:
# - test Container with nothing in it
# - test prototype with Constructor and Setter Injection
# - test Constructor injection without parameter
