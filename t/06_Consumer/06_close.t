#!/usr/bin/perl -w

use 5.010;
use strict;
use warnings;

# NAME: Test of the method Kafka::Consumer::close

use lib 'lib';

use Test::More tests => 6;

BEGIN {
    eval "use Test::Exception";
    plan skip_all => "because Test::Exception required for testing" if $@;
}

# PRECONDITIONS ----------------------------------------------------------------

use Kafka::Mock;
use Kafka::IO;

# options for testing arguments: ( undef, 0, 0.5, 1, -1, -3, "", "0", "0.5", "1", 9999999999999999, \"scalar", [] )

# -- declaration of variables to test
my ( $server, $io, $consumer );

sub my_io {
    my $io      = shift;

    $$io = Kafka::IO->new(
        host        => "localhost",
        port        => $server->port,
        );
}

# -- verification of the objects creation

$server = Kafka::Mock->new(
    requests    => {},
    responses   => {},
    );
isa_ok( $server, 'Kafka::Mock');

my_io( \$io );
isa_ok( $io, 'Kafka::IO');

# INSTRUCTIONS -----------------------------------------------------------------

# -- verify load the module

BEGIN { use_ok 'Kafka::Consumer' }

$consumer = Kafka::Consumer->new(
    IO          => $io,
    );
isa_ok( $consumer, 'Kafka::Consumer');

# -- verify close the object
ok( scalar( keys %$consumer ) > 0,  "is not an empty" );
$consumer->close;
ok( scalar( keys %$consumer ) == 0, "is an empty" );

# POSTCONDITIONS ---------------------------------------------------------------

# -- Closes and cleans up
$server->close;
