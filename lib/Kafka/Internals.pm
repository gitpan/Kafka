package Kafka::Internals;

=head1 NAME

Kafka::Internals - Constants and functions used internally.

=head1 VERSION

This documentation refers to C<Kafka::Internals> version 0.8008_1 .

=cut

#-- Pragmas --------------------------------------------------------------------

use 5.010;
use strict;
use warnings;

# ENVIRONMENT ------------------------------------------------------------------

our $VERSION = '0.8008_1';

use Exporter qw(
    import
);

our @EXPORT_OK = qw(
    $APIKEY_PRODUCE
    $APIKEY_FETCH
    $APIKEY_OFFSET
    $APIKEY_METADATA
    $DEFAULT_RAISE_ERROR
    $MAX_CORRELATIONID
    $MAX_INT16
    $MAX_INT32
    $MAX_SOCKET_REQUEST_BYTES
    $PRODUCER_ANY_OFFSET
    debug_level
    _isbig
    _get_CorrelationId
);

#-- load the modules -----------------------------------------------------------

use Carp;
use Const::Fast;
use Params::Util qw(
    _INSTANCE
);
use Try::Tiny;

use Kafka qw(
    %ERROR
    $ERROR_MISMATCH_ARGUMENT
);

#-- declarations ---------------------------------------------------------------

=head1 SYNOPSIS

    use 5.010;
    use strict;
    use warnings;

    use Kafka::Internals qw(
        $MAX_SOCKET_REQUEST_BYTES
    );

    my $bin_stream_size = $MAX_SOCKET_REQUEST_BYTES;

=head1 DESCRIPTION

This module is private and should not be used directly.

In order to achieve better performance, functions of this module do
not perform arguments validation.

=head2 EXPORT

The following constants are available for export

=cut

#-- Api Keys

=head3 C<$APIKEY_PRODUCE>

The numeric code that the C<ApiKey> in the request take for the C<ProduceRequest> request type.

=cut
const our $APIKEY_PRODUCE                       => 0;

=head3 C<$APIKEY_FETCH>

The numeric code that the C<ApiKey> in the request take for the C<FetchRequest> request type.

=cut
const our $APIKEY_FETCH                         => 1;

=head3 C<$APIKEY_OFFSET>

The numeric code that the C<ApiKey> in the request take for the C<OffsetRequest> request type.

=cut
const our $APIKEY_OFFSET                        => 2;

=head3 C<$APIKEY_METADATA>

The numeric code that the C<ApiKey> in the request take for the C<MetadataRequest> request type.

=cut
const our $APIKEY_METADATA                      => 3;
# The numeric code that the ApiKey in the request take for the C<LeaderAndIsrRequest> request type.
const our $APIKEY_LEADERANDISR                  => 4;   # Not used now
# The numeric code that the ApiKey in the request take for the C<StopReplicaRequest> request type.
const our $APIKEY_STOPREPLICA                   => 5;   # Not used now
# The numeric code that the ApiKey in the request take for the C<OffsetCommitRequest> request type.
const our $APIKEY_OFFSETCOMMIT                  => 6;   # Not used now
# The numeric code that the ApiKey in the request take for the C<OffsetFetchRequest> request type.
const our $APIKEY_OFFSETFETCH                   => 7;   # Not used now

# Important configuration properties

=head3 C<$MAX_SOCKET_REQUEST_BYTES>

The maximum number of bytes in a socket request.

The maximum size of a request that the socket server will accept.
Default limit (as configured in F<server.properties>) is 104857600.

=cut
const our $MAX_SOCKET_REQUEST_BYTES             => 100 * 1024 * 1024;

=head3 C<$PRODUCER_ANY_OFFSET>

According to Apache Kafka documentation: 'When the producer is sending messages it doesn't actually know the offset and can fill in any
value here it likes.'

=cut
const our $PRODUCER_ANY_OFFSET                  => 0;

=head3 C<$MAX_CORRELATIONID>

Largest positive integer on 32-bit machines.

=cut
const our $MAX_CORRELATIONID                    => 0x7fffffff;

=head3 C<$MAX_INT32>

Largest positive integer on 32-bit machines.

=cut
const our $MAX_INT32                            => 0x7fffffff;

=head3 C<$MAX_INT16>

Largest positive int16 value.

=cut
const our $MAX_INT16                            => 0x7fff;

#-- public functions -----------------------------------------------------------

#-- private functions ----------------------------------------------------------

# Used to generate a CorrelationId.
sub _get_CorrelationId {
    return( -int( rand( $MAX_CORRELATIONID ) ) );
}

# Verifies that the argument is of Math::BigInt type
sub _isbig {
    my ( $num ) = @_;

    return defined _INSTANCE( $num, 'Math::BigInt' );
}

#-- public attributes ----------------------------------------------------------

=head2 METHODS

The following methods are defined in the C<Kafka::Internals>:

=cut

#-- public methods -------------------------------------------------------------

=head3 C<debug_level( $flags )>

Gets or sets debug level for a particular L<Kafka|Kafka> module, based on environment variable C<PERL_KAFKA_DEBUG> or flags.

$flags - (string) argument that can be used to pass coma delimited module names (omit C<Kafka::>).

Returns C<$DEBUG> level for the module from which C<debug_level> was called.

=cut
sub debug_level {
    no strict 'refs';                                               ## no critic

    my $class = ref( $_[0] ) || $_[0];
    my $flags = $_[1] // $ENV{PERL_KAFKA_DEBUG}
        // return( ${ "${class}::DEBUG" } );                        ## no critic

    my ( $result, @elements, $module_name, $level );
    foreach my $spec ( split /\s*,\s*/, $flags ) {
        @elements = split /\s*:\s*/, $spec;
        if ( scalar( @elements ) > 1 ) {
            ( $module_name, $level ) = @elements;
        } else {
            $module_name = ( $class =~ /([^:]+)$/ )[0];
            $level = $spec;
        }

        if ( eval( "exists \$Kafka::${module_name}::{DEBUG}" ) ) {  ## no critic
            $result = ${ "Kafka::${module_name}::DEBUG" } = $level;
        } else {
            $result = undef;
        }
    }

    return ${ "${class}::DEBUG" };
}

#-- private attributes ---------------------------------------------------------

#-- private methods ------------------------------------------------------------

1;

__END__

=head1 SEE ALSO

The basic operation of the Kafka package modules:

L<Kafka|Kafka> - constants and messages used by the Kafka package modules.

L<Kafka::Connection|Kafka::Connection> - interface to connect to a Kafka cluster.

L<Kafka::Producer|Kafka::Producer> - interface for producing client.

L<Kafka::Consumer|Kafka::Consumer> - interface for consuming client.

L<Kafka::Message|Kafka::Message> - interface to access Kafka message
properties.

L<Kafka::Int64|Kafka::Int64> - functions to work with 64 bit elements of the
protocol on 32 bit systems.

L<Kafka::Protocol|Kafka::Protocol> - functions to process messages in the
Apache Kafka's Protocol.

L<Kafka::IO|Kafka::IO> - low-level interface for communication with Kafka server.

L<Kafka::Exceptions|Kafka::Exceptions> - module designated to handle Kafka exceptions.

L<Kafka::Internals|Kafka::Internals> - internal constants and functions used
by several package modules.

A wealth of detail about the Apache Kafka and the Kafka Protocol:

Main page at L<http://kafka.apache.org/>

Kafka Protocol at L<https://cwiki.apache.org/confluence/display/KAFKA/A+Guide+To+The+Kafka+Protocol>

=head1 SOURCE CODE

Kafka package is hosted on GitHub:
L<https://github.com/TrackingSoft/Kafka>

=head1 AUTHOR

Sergey Gladkov, E<lt>sgladkov@trackingsoft.comE<gt>

=head1 CONTRIBUTORS

Alexander Solovey

Jeremy Jordan

Sergiy Zuban

Vlad Marchenko

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2012-2013 by TrackingSoft LLC.

This package is free software; you can redistribute it and/or modify it under
the same terms as Perl itself. See I<perlartistic> at
L<http://dev.perl.org/licenses/artistic.html>.

This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY;
without even the implied warranty of MERCHANTABILITY or FITNESS FOR A
PARTICULAR PURPOSE.

=cut
