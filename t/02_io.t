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

#-- verify load the module

BEGIN {
    eval 'use Test::NoWarnings';    ## no critic
    plan skip_all => 'because Test::NoWarnings required for testing' if $@;
}

BEGIN {
    eval 'use Test::Exception';     ## no critic
    plan skip_all => "because Test::Exception required for testing" if $@;
}

BEGIN {
    eval 'use Test::TCP';           ## no critic
    plan skip_all => "because Test::TCP required for testing" if $@;
}

plan 'no_plan';

#-- load the modules -----------------------------------------------------------

use IO::Socket::INET;
use POSIX ':signal_h';
use Socket;
use Sub::Install;
use Sys::SigAction qw(
    set_sig_handler
);

use Kafka qw(
    $REQUEST_TIMEOUT
);
use Kafka::IO;
use Kafka::TestInternals qw(
    @not_posint
    @not_posnumber
    @not_string
);

#-- setting up facilities ------------------------------------------------------

$Kafka::IO::DEBUG = 2;

#-- declarations ---------------------------------------------------------------

my $server_code = sub {
    my ( $port ) = @_;

    my $sock = IO::Socket::INET->new(
        LocalPort   => $port,
        LocalAddr   => 'localhost',
        Proto       => 'tcp',
        Listen      => 5,
        Type        => SOCK_STREAM,
        ReuseAddr   => 1,
    ) or die "Cannot open server socket: $!";

    $SIG{TERM} = sub { exit };

    while ( my $remote = $sock->accept ) {
        while ( my $line = <$remote> ) {
            print { $remote } $line;
        }
    }
};

my ( $server, $port, $io, $sig_handler, $marker_signal_handling, $original, $timer, $sent, $resp, $test_message );

#-- Global data ----------------------------------------------------------------

$server = Test::TCP->new( code => $server_code );
$port = $server->port;
ok $port, "server port = $port";
wait_port( $port );

$test_message = "Test message\n";

# INSTRUCTIONS -----------------------------------------------------------------

# NOTE: In the process of Kafka::IO->new we are working with alarm clock internally

#-- ALRM handler

$sig_handler = set_sig_handler( SIGALRM ,sub { ++$marker_signal_handling; } );
ok( !defined( $marker_signal_handling ), 'marker signal handling not defined' );

throws_ok {
    $io = Kafka::IO->new(
        host    => 'something bad',
        port    => $port,
        timeout => $REQUEST_TIMEOUT,
    );
} 'Kafka::Exception::IO', 'error thrown';

$io = Kafka::IO->new(
    host    => 'localhost',
    port    => $port,
    timeout => $REQUEST_TIMEOUT,
);
isa_ok( $io, 'Kafka::IO' );

ok( !defined( $marker_signal_handling ), 'marker signal handling not defined' );
kill ALRM => $$;
is $marker_signal_handling, 1, 'the signal handler to be reset to the previous value';

#-- ALRM timer

# Kafka::IO->new is badly ended before 'timer' and before 'timeout'

alarm 0;
$SIG{ALRM} = sub { ++$marker_signal_handling; };
$timer = $REQUEST_TIMEOUT;

$marker_signal_handling = 0;
eval {
    alarm $timer;
    eval {
        $io = Kafka::IO->new(
            host    => 'something bad',
            port    => $port,
            timeout => $timer,
        );
    };
    alarm 0;
};
ok !$marker_signal_handling, 'signal handler is not triggered';

# Kafka::IO->new is correctly ended before 'timer' and before 'timeout'

alarm 0;
$SIG{ALRM} = sub { ++$marker_signal_handling; };
$timer = $REQUEST_TIMEOUT + 2;

$original = \&Kafka::IO::_gethostbyname;
Sub::Install::reinstall_sub( {
    code    => sub {
        return inet_aton( 'localhost' );
    },
    into    => 'Kafka::IO',
    as      => '_gethostbyname',
} );

$marker_signal_handling = 0;
eval {
    alarm $timer;
    eval {
        $io = Kafka::IO->new(
            host    => 'something bad',
            port    => $port,
            timeout => $timer + 2,
        );

        ok !$marker_signal_handling, 'signal handler is not triggered yet';
        # 'sleep' to be interrupted by an external signal
        sleep $timer + 4;
    };
    alarm 0;
};
is $marker_signal_handling, 1, 'signal handler is triggered';

Sub::Install::reinstall_sub( {
    code    => $original,
    into    => 'Kafka::IO',
    as      => '_gethostbyname',
} );

# Kafka::IO->new is correctly ended after 'timer' and before 'timeout'

Sub::Install::reinstall_sub( {
    code    => sub {
        # 'sleep' should not be interrupted by an external signal
        sleep $timer + 2;
        return inet_aton( 'localhost' );
    },
    into    => 'Kafka::IO',
    as      => '_gethostbyname',
} );

alarm 0;
$SIG{ALRM} = sub { ++$marker_signal_handling; };
$timer = $REQUEST_TIMEOUT;

$marker_signal_handling = 0;
eval {
    alarm $timer;
    eval {
        $io = Kafka::IO->new(
            host    => 'localhost',
            port    => $port,
            timeout => $timer + 4,
        );
    };
    alarm 0;
};
is $marker_signal_handling, 1, 'signal handler is triggered';

Sub::Install::reinstall_sub( {
    code    => $original,
    into    => 'Kafka::IO',
    as      => '_gethostbyname',
} );

#-- is_alive

$io = Kafka::IO->new(
    host    => 'localhost',
    port    => $port,
    timeout => $REQUEST_TIMEOUT,
);

ok $io->is_alive, 'socket alive';

#-- close

ok $io->{socket}, 'socket defined';
$io->close;
ok !$io->{socket}, 'socket not defined';

#-- is_alive

ok !$io->is_alive, 'socket not alive';

#-- send

$io = Kafka::IO->new(
    host    => 'localhost',
    port    => $port,
    timeout => $REQUEST_TIMEOUT,
);

lives_ok { $sent = $io->send( $test_message ); } 'expecting to live';
is $sent, length( $test_message ), 'sent '.length( $test_message ).' bytes';

#-- receive

lives_ok { $resp = $io->receive( length( $test_message ) ); } 'expecting to live';
is( $$resp, $test_message, 'receive OK' );

undef $server;
ok $io, 'IO exists';
throws_ok { $sent = $io->send( $test_message ); } 'Kafka::Exception::IO', 'error thrown';

# POSTCONDITIONS ---------------------------------------------------------------

undef $server;
