package REST::Google::Apps::Reporting;

use Carp;
use LWP::UserAgent;
use XML::Simple;

use strict;
use warnings;

our $VERSION = '1.1.10';



sub new {
    my $self = bless {}, shift;

    my ( $arg );
    %{$arg} = @_;

    map { $arg->{lc($_)} = $arg->{$_} } keys %{$arg};

    $self->{'domain'} = $arg->{'domain'} || croak( "Missing required 'domain' argument" );

    $self->{'date'} = sub {
        sprintf '%04d-%02d-%02d',
        $_[5]+1900, $_[4]+1, $_[3]
    }->(localtime);

    $self->{'lwp'} = LWP::UserAgent->new();
    $self->{'lwp'}->agent( 'RESTGoogleAppsReporting/' . $VERSION );

    if ( $arg->{'username'} && $arg->{'password'} ) {
        $self->authenticate(
            'username' => $arg->{'username'},
            'password' => $arg->{'password'}
        )
        || croak qq(Unable to retrieve authentication token);
    }

    $self->{'xml'} = XML::Simple->new();

    return( $self );
}



sub authenticate {
    my $self = shift;

    return( 1 ) if $self->{'token'};

    my ( $arg );
    %{$arg} = @_;

    map { $arg->{lc($_)} = $arg->{$_} } keys %{$arg};

    foreach my $param ( qw/ username password / ) {
        $arg->{$param} || croak( "Missing required '$param' argument" );
    }

    my $response = $self->{'lwp'}->post(
        'https://www.google.com/accounts/ClientLogin',
        [
            'accountType' => 'HOSTED',
            'Email'       => $arg->{'username'} . '@' . $self->{'domain'},
            'Passwd'      => $arg->{'password'}
        ]
    );

    $response->is_success() || return( 0 );

    foreach ( split( /\n/, $response->content() ) ) {
        $self->{'token'} = $1 if /^SID=(.+)$/;
        last if $self->{'token'};
    }

    return( 1 ) if $self->{'token'} || return( 0 );
}



sub getReport {
    my $self = shift;

    my ( $arg );
    %{$arg} = @_;

    map { $arg->{lc($_)} = $arg->{$_} } keys %{$arg};

    my $url = qq(https://www.google.com/hosted/services/v1.0/reports/ReportingData);

    my ( $body, $report );

    $body  = $self->_xmlpre();

    $body .= qq(  <reportType>daily</reportType>);
    $body .= qq(  <reportName>accounts</reportName>);

    $body .= $self->_xmlpost();

    my ( $result ) = $self->_request(
        'method' => 'POST',
        'url'    => $url,
        'body'   => $body
    ) || return( 0 );

    my @keys = split( ',', shift @{$result} );

    my ( $index, $i );

    $i = 0;

    foreach my $key ( @keys ) { $index = $i if $key eq 'account_name'; $i++ }

    foreach my $account ( @{$result} ) {
        my @fields = split( ',', $account );

        my ( $a ) = $1 if $fields[$index] =~ /(.*)\@/;

        $i = 0;

        foreach my $key ( @keys ) {
            $report->{$a}->{$key} = $fields[$i];
            $i++;
        }
    }

    if ( $arg->{'username'} ) {
        if ( $report->{$arg->{'username'}} ) {
            return( { $arg->{'username'} => $report->{$arg->{'username'}} } );
        }
        else {
            return( 0 );
        }
    }
    else {
        return( $report );
    }
}



sub _request {
    my $self = shift;

    $self->{'token'}
    || croak qq(Authenticate first!);

    my ( $arg );
    %{$arg} = @_;

    my $request = HTTP::Request->new( $arg->{'method'} => $arg->{'url'} );

    $request->header( 'Content-Type'  => 'application/atom+xml' );
    $request->header( 'Authorization' => 'GoogleLogin auth=' . $self->{'token'} );

    if ( $arg->{'body'} ) {
        $request->header( 'Content-Length' => length( $arg->{'body'} ) );
        $request->content( $arg->{'body'} );
    }

    my $response = $self->{'lwp'}->request( $request );

    $response->is_success() || return( 0 );
    $response->content()    || return( 1 );

    my ( $results );

    @{ $results } = split( "\n", $response->content() );

    return( $results );
}



sub _xmlpre {
    my $self = shift;

    ( my $xml = << "    END" ) =~ s/^\s+//gm;
       <?xml version="1.0" encoding="UTF-8" ?>
       <rest xmlns="google:accounts:rest:protocol"
           xmlns:xsi=" http://www.w3.org/2001/XMLSchema-instance ">
           <type>Report</type>
           <domain>$self->{'domain'}</domain>
           <token>$self->{'token'}</token>
           <date>$self->{'date'}</date>
           <page>1</page>
    END

    return( $xml );
}

sub _xmlpost {
    ( my $xml = << '    END' ) =~ s/^\s+//gm;
        </rest>
    END

    return( $xml );
}



1;

