package REST::Google::Apps::Provisioning;

use Carp;
use LWP::UserAgent;
use XML::Simple;

use strict;
use warnings;

our $VERSION = '1.0.0';



sub new {
    my $self = bless {}, shift;

    my ( $arg );
    %{$arg} = @_;

    $self->{'domain'} = $arg->{'domain'}
    || croak qq(Missing required 'domain' argument);

    $self->{'lwp'} = LWP::UserAgent->new();
    $self->{'lwp'}->agent( 'RESTGoogleAppsProvisioning/' . $VERSION );

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

    foreach ( qw/ username password / ) {
        $arg->{$_}
        || croak qq(Missing required $_ argument);
    }

    my $response = $self->{'lwp'}->post(
        'https://www.google.com/accounts/ClientLogin',
        [
            'accountType' => 'HOSTED',
            'service'     => 'apps',
            'Email'       => $arg->{'username'} . '@' . $self->{'domain'},
            'Passwd'      => $arg->{'password'}
        ]
    );

    $response->is_success() || return( 0 );

    foreach ( split( /\n/, $response->content() ) ) {
        $self->{'token'} = $1 if /^Auth=(.+)$/;
        last if $self->{'token'};
    }

    return( 1 ) if $self->{'token'} || return( 0 );
}


sub getGroup {
    my $self  = shift;
    my $group = shift;

    $self->{'token'}
    || croak qq(Can't call getGroup without first authenticating);

    my $url = qq(https://apps-apis.google.com/a/feeds/$self->{'domain'}/group/2.0);
    $url .= "/$group" if $group;

    my $result = $self->_request( $url ) || return( 0 );

    my ( $ref );

    unless ( $group ) {
        foreach ( keys %{$result->{'entry'}} ) {
            $group = $1 if /^.*\/(.+)$/;
            $ref->{$group} = {
                %{$result->{'entry'}->{$_}->{'apps:name'}},
                %{$result->{'entry'}->{$_}->{'apps:login'}}
            }
        }
    }
    else {
        $ref->{$group} = {
            %{$result->{'apps:name'}},
            %{$result->{'apps:login'}}
        };
    }

    return( $ref );
}

sub getAllGroups { return shift->getGroup(); }



sub getNickname {
    my $self = shift;
    my $nick = shift;

    $self->{'token'}
    || croak qq(Can't call getNickname without first authenticating);

    my $url = qq(https://apps-apis.google.com/a/feeds/$self->{'domain'}/nickname/2.0);
    $url .= "/$nick" if $nick;

    my $result = $self->_request( $url ) || return( 0 );

    my ( $ref );

    unless ( $nick ) {
        foreach ( keys %{$result->{'entry'}} ) {
            $nick = $1 if /^.*\/(.+)$/;
            $ref->{$nick} = {
                %{$result->{'entry'}->{$_}->{'apps:login'}},
                %{$result->{'entry'}->{$_}->{'apps:nickname'}}
            }
        }
    }
    else {
        $ref->{$nick} = {
            %{$result->{'apps:login'}},
            %{$result->{'apps:nickname'}}
        };
    }

    return( $ref );
}

sub getAllNicknames { return shift->getNickname(); }



sub getUser {
    my $self = shift;
    my $user = shift;

    $self->{'token'}
    || croak qq(Can't call getUser without first authenticating);

    my $url = qq(https://apps-apis.google.com/a/feeds/$self->{'domain'}/user/2.0);
    $url .= "/$user" if $user;

    my $result = $self->_request( $url ) || return( 0 );

    my ( $ref );

    unless ( $user ) {
        foreach ( keys %{$result->{'entry'}} ) {
            $user = $1 if /^.*\/(.+)$/;
            $ref->{$user} = {
                %{$result->{'entry'}->{$_}->{'apps:name'}},
                %{$result->{'entry'}->{$_}->{'apps:login'}},
                %{$result->{'entry'}->{$_}->{'apps:quota'}}
            }
        }
    }
    else {
        $ref->{$user} = {
            %{$result->{'apps:name'}},
            %{$result->{'apps:login'}},
            %{$result->{'apps:quota'}}
        };
    }

    return( $ref );
}

sub getAllUsers { return shift->getUser(); }



sub _request {
    my $self = shift;
    my $url  = shift;

    my $request = HTTP::Request->new( 'GET' => $url );

    $request->header( 'Content-Type'  => 'application/atom+xml' );
    $request->header( 'Authorization' => 'GoogleLogin auth=' . $self->{'token'} );

    my $response = $self->{'lwp'}->request( $request );

    $response->is_success() || return( 0 );

    return( $self->{'xml'}->XMLin( $response->content() ) );
}



1;

