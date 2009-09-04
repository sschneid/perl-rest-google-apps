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



sub createUser {
    my $self = shift;

    my ( $arg );
    %{$arg} = @_;

    my $url = qq(https://apps-apis.google.com/a/feeds/$self->{'domain'}/user/2.0);

    my ( $body );

    $body  = $self->_xmlpre();
    $body .= qq(  <atom:category scheme="http://schemas.google.com/g/2005#kind" term="http://schemas.google.com/apps/2006#user" />\n);
    $body .= qq(  <apps:login userName="$arg->{'username'}" password="$arg->{'password'}" suspended="false" />\n);
    $body .= qq(  <apps:login hashFunctionName="$arg->{'passwordHashFunction'}" />\n) if $arg->{'passwordHashFunction'}; 
    $body .= qq(  <apps:quota limit="$arg->{'quotaLimitInMB'}" />\n) if $arg->{'quotaLimitInMB'}; 
    $body .= qq(  <apps:name familyName="$arg->{'familyName'}" givenName="$arg->{'givenName'}" />\n);
    $body .= $self->_xmlpost();

    my $result = $self->_request(
        'method' => 'POST',
        'url'    => $url,
        'body'   => $body
    ) || return( 0 );

    my ( $ref );

    $ref->{$arg->{'username'}} = {
        %{$result->{'apps:name'}},
        %{$result->{'apps:login'}},
        %{$result->{'apps:quota'}}
    };

    return( $ref );
}

sub deleteUser {
    my $self = shift;

    my $user = shift
    || croak qq(A user must be specified);

    my $url = qq(https://apps-apis.google.com/a/feeds/$self->{'domain'}/user/2.0/$user);

    my $result = $self->_request( 'method' => 'DELETE', 'url' => $url ) || return( 0 );

    return( 1 ) if $result;
}

sub getUser {
    my $self = shift;
    my $user = shift;

    my $url = qq(https://apps-apis.google.com/a/feeds/$self->{'domain'}/user/2.0);
    $url .= "/$user" if $user;

    my $result = $self->_request( 'method' => 'GET', 'url' => $url ) || return( 0 );

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

sub updateUser {
    my $self = shift;

    my ( $arg );
    %{$arg} = @_;

    my $user = $self->getUser( $arg->{'username'} );

    my $url = qq(https://apps-apis.google.com/a/feeds/$self->{'domain'}/user/2.0/$arg->{'username'});

    my ( $body );

    $body  = $self->_xmlpre();
    $body .= qq(  <atom:category scheme="http://schemas.google.com/g/2005#kind" term="http://schemas.google.com/apps/2006#user" />\n);

    if ( $arg->{'givenName'} || $arg->{'familyName'} ) {
        $arg->{'givenName'}  ||= $user->{$arg->{'username'}}->{'givenName'};
        $arg->{'familyName'} ||= $user->{$arg->{'username'}}->{'familyName'};
        $body .= qq(  <apps:name familyName="$arg->{'familyName'}" givenName="$arg->{'givenName'}" />\n);
    }

    if ( $arg->{'password'} ) {
        $body .= qq(  <apps:login userName="$arg->{'username'}" password="$arg->{'password'}" />\n);
    }

    if ( $arg->{'suspended'} ) {
        $body .= qq(  <apps:login userName="$arg->{'username'}" suspended="$arg->{'suspended'}" />\n);
    }

    $body .= $self->_xmlpost();

    my $result = $self->_request(
        'method' => 'PUT',
        'url'    => $url,
        'body'   => $body
    ) || return( 0 );

    return( 1 );
}



sub getGroup {
    my $self  = shift;
    my $group = shift;

    my $url = qq(https://apps-apis.google.com/a/feeds/$self->{'domain'}/group/2.0);
    $url .= "/$group" if $group;

    my $result = $self->_request( 'method' => 'GET', 'url' => $url ) || return( 0 );

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



sub createNickname {
    my $self = shift;

    my ( $arg );
    %{$arg} = @_;

    my $url = qq(https://apps-apis.google.com/a/feeds/$self->{'domain'}/nickname/2.0);

    my ( $body );

    $body  = $self->_xmlpre();
    $body .= qq(  <atom:category scheme="http://schemas.google.com/g/2005#kind" term="http://schemas.google.com/apps/2006#nickname" />\n);
    $body .= qq(  <apps:login userName="$arg->{'username'}" />\n);
    $body .= qq(  <apps:nickname name="$arg->{'nickname'}" />\n);
    $body .= $self->_xmlpost();

    my $result = $self->_request(
        'method' => 'POST',
        'url'    => $url,
        'body'   => $body
    ) || return( 0 );

    my ( $ref );

    $ref->{$arg->{'username'}} = {
        %{$result->{'apps:nickname'}}
    };

    return( $ref );
}

sub deleteNickname {
    my $self = shift;

    my $nickname = shift
    || croak qq(A nickname must be specified);

    my $url = qq(https://apps-apis.google.com/a/feeds/$self->{'domain'}/nickname/2.0/$nickname);

    my $result = $self->_request( 'method' => 'DELETE', 'url' => $url ) || return( 0 );

    return( 1 ) if $result;
}

sub getNickname {
    my $self = shift;
    my $nick = shift;

    my $url = qq(https://apps-apis.google.com/a/feeds/$self->{'domain'}/nickname/2.0);
    $url .= "/$nick" if $nick;

    my $result = $self->_request( 'method' => 'GET', 'url' => $url ) || return( 0 );

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

    return( $self->{'xml'}->XMLin( $response->content() ) );
}



sub _xmlpre {
    ( my $xml = << '    END' ) =~ s/^\s+//gm;
        <?xml version="1.0" encoding="UTF-8" ?>
        <atom:entry xmlns:atom="http://www.w3.org/2005/Atom" xmlns:apps="http://schemas.google.com/apps/2006">
    END

    return( $xml );
}

sub _xmlpost {
    ( my $xml = << '    END' ) =~ s/^\s+//gm;
        </atom:entry>
    END

    return( $xml );
}



1;

