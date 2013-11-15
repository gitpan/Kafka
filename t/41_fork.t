#!/usr/bin/perl -w

#-- Pragmas --------------------------------------------------------------------

use 5.010;
use strict;
use warnings;

use lib qw(
    lib
    t/lib
    ../lib
);

# ENVIRONMENT ------------------------------------------------------------------

use Test::More;

BEGIN {
    plan skip_all => 'Unknown base directory of Kafka server'
        unless defined $ENV{KAFKA_BASE_DIR};
}

#-- verify load the module

BEGIN {
    eval 'use Test::NoWarnings';    ## no critic
    plan skip_all => 'because Test::NoWarnings required for testing' if $@;
}

BEGIN {
    eval 'use Test::Exception';     ## no critic
    plan skip_all => "because Test::Exception required for testing" if $@;
}

plan 'no_plan';

#-- load the modules -----------------------------------------------------------

use Clone qw(
    clone
);
use Const::Fast;

use Kafka::Cluster qw(
    $DEFAULT_TOPIC
);
use Kafka::Connection;
use Kafka::MockIO;
use Kafka::Producer;

#-- setting up facilities ------------------------------------------------------

STDOUT->autoflush;

my $cluster = Kafka::Cluster->new(
    kafka_dir           => $ENV{KAFKA_BASE_DIR},    # WARNING: must match the settings of your system
    replication_factor  => 1,
);

#-- declarations ---------------------------------------------------------------

my ( $port, $connection, $topic, $partition, $producer, $response, $is_ready, $pid, $ppid, $success );

sub sending {
    return $producer->send(
        $topic,
        $partition,
        'Single message'
    );
}

sub testing_sending {
    undef $response;
    eval { $response = sending() };
    ++$success unless $@;
}

sub wait_until_ready {
    my ( $level, $pid ) = @_;

    my $count = 0;
    while ( ( $is_ready // 0 ) != $level ) {
        if ( ++$count > 5 ) {
            kill 'KILL' => $pid;
            fail "too long a wait for $pid";
            last;
        }
        sleep 1;
    }
}

$SIG{USR1} = sub { ++$is_ready };
$SIG{USR2} = sub { ++$success };

#-- Global data ----------------------------------------------------------------

$partition  = $Kafka::MockIO::PARTITION;;
$topic      = $DEFAULT_TOPIC;

#-- Connecting to the Kafka server port (for example for node_id = 0)
( $port ) =  $cluster->servers;

# INSTRUCTIONS -----------------------------------------------------------------

# connecting to the Kafka server port
$connection = Kafka::Connection->new(
    host    => 'localhost',
    port    => $port,
);
$producer = Kafka::Producer->new(
    Connection  => $connection,
);

$success = 0;

# simple sending
lives_ok { sending() } 'expecting to live';
ok $success = 1, 'sending OK';

# producer destroyed
my $clone_connection = clone( $connection );
undef $producer;
is_deeply( $connection, $clone_connection, 'connection is not destroyed' );

# recreating producer
$producer = Kafka::Producer->new(
    Connection  => $connection,
);
testing_sending();
ok $success = 2, 'sending OK';

#-- the producer and connection are destroyed in the child

$is_ready = 0;

if ( $pid = fork ) {                # herein the parent
    wait_until_ready( 1, $pid );    # expect readiness of the child process
    # producer destroyed in the child
    testing_sending();
    # $success = 3
    kill 'USR1' => $pid;

    wait_until_ready( 2, $pid );    # expect readiness of the child process
    # connection destroyed in the child
    $producer = Kafka::Producer->new(
        Connection  => $connection, # potentially destroyed connection
    );
    testing_sending();
    # $success = 4
    kill 'USR1' => $pid;

    wait;                           # forward to the completion of a child process
} elsif ( defined $pid ) {          # herein the child process
    $ppid = getppid();

    undef $producer;
    kill 'USR1' => $ppid;

    wait_until_ready( 1, $ppid );   # expect readiness of the parent process
    undef $connection;
    kill 'USR1' => $ppid;

    wait_until_ready( 2, $ppid );   # expect readiness of the parent process
    exit;
} else {
    fail 'An unexpected error (fork 1)';
}

ok $success = 4, 'sending OK';

#-- the producer and connection are destroyed in the parent

$is_ready = 0;

if ( $pid = fork ) {                # herein the parent
    wait_until_ready( 1, $pid );    # expect readiness of the child process
    undef $producer;
    kill 'USR1' => $pid;

    wait_until_ready( 2, $pid );    # expect readiness of the child process
    undef $connection;
    kill 'USR1' => $pid;

    wait;                           # forward to the completion of a child process
} elsif ( defined $pid ) {          # herein the child process
    $ppid = getppid();

    $success = 0;

    testing_sending();
    kill 'USR1' => $ppid;

    wait_until_ready( 1, $ppid );   # expect readiness of the parent process
    # producer destroyed in the parent
    testing_sending();
    # $success = 1
    kill 'USR1' => $ppid;

    wait_until_ready( 2, $ppid );   # expect readiness of the parent process
    # connection destroyed in the parent
    $producer = Kafka::Producer->new(
        Connection  => $connection, # potentially destroyed connection
    );
    testing_sending();
    # $success = 2
    kill 'USR2' => $ppid
        if $success == 2;

    exit;
} else {
    fail 'An unexpected error (fork 2)';
}

ok $success = 5, 'sending OK';

# POSTCONDITIONS ---------------------------------------------------------------

$cluster->close;
