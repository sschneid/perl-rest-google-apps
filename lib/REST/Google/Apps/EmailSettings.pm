package REST::Google::Apps::EmailSettings;

use Carp;
use LWP::UserAgent;
use XML::Simple;

use strict;
use warnings;

our $VERSION = '1.1.1';



sub new {
    my $self = bless {}, shift;

    my ( $arg );
    %{$arg} = @_;

    $self->{'domain'} = $arg->{'domain'}
    || croak qq(Missing required 'domain' argument);

    $self->{'lwp'} = LWP::UserAgent->new();
    $self->{'lwp'}->agent( 'RESTGoogleAppsEmailSettings/' . $VERSION );

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



sub createLabel {
    my $self = shift;

    my ( $arg );
    %{$arg} = @_;

    my $url = qq(https://apps-apis.google.com/a/feeds/emailsettings/2.0/$self->{'domain'}/$arg->{'username'}/label);

    my ( $body );

    $body  = $self->_xmlpre();
    $body .= qq(  <apps:property name="label" value="$arg->{'label'}" />\n);
    $body .= $self->_xmlpost();

    my $result = $self->_request(
        'method' => 'POST',
        'url'    => $url,
        'body'   => $body
    ) || return( 0 );

    return( 1 );
}


sub enableWebClips {
    my $self = shift;
    my $user = shift;

    my $url = qq(https://apps-apis.google.com/a/feeds/emailsettings/2.0/$self->{'domain'}/$user/webclip);

    my ( $body );

    $body  = $self->_xmlpre();
    $body .= qq(  <apps:property name="enable" value="true" />\n);
    $body .= $self->_xmlpost();

    my $result = $self->_request(
        'method' => 'PUT',
        'url'    => $url,
        'body'   => $body
    ) || return( 0 );

    return( 1 );
}

sub disableWebClips {
    my $self = shift;
    my $user = shift;

    my $url = qq(https://apps-apis.google.com/a/feeds/emailsettings/2.0/$self->{'domain'}/$user/webclip);

    my ( $body );

    $body  = $self->_xmlpre();
    $body .= qq(  <apps:property name="enable" value="false" />\n);
    $body .= $self->_xmlpost();

    my $result = $self->_request(
        'method' => 'PUT',
        'url'    => $url,
        'body'   => $body
    ) || return( 0 );

    return( 1 );
}



sub enableForwarding {
    my $self = shift;

    my ( $arg );
    %{$arg} = @_;

    my $url = qq(https://apps-apis.google.com/a/feeds/emailsettings/2.0/$self->{'domain'}/$arg->{'username'}/forwarding);

    my ( $body );

    $body  = $self->_xmlpre();

    $body .= qq(  <apps:property name="enable" value="true" />\n);
    $body .= qq(  <apps:property name="forwardTo" value="$arg->{'forwardTo'}" />\n);

    if ( $arg->{'action'} ) {
        $arg->{'action'} = uc( $arg->{'action'} );

        $body .= qq(  <apps:property name="action" value="$arg->{'action'}" />\n);
    }
    else {
        $body .= qq(  <apps:property name="action" value="KEEP" />\n);
    }

    $body .= $self->_xmlpost();

    my $result = $self->_request(
        'method' => 'PUT',
        'url'    => $url,
        'body'   => $body
    ) || return( 0 );

    return( 1 );
}

sub disableForwarding {
    my $self = shift;
    my $user = shift;

    my $url = qq(https://apps-apis.google.com/a/feeds/emailsettings/2.0/$self->{'domain'}/$user/forwarding);

    my ( $body );

    $body  = $self->_xmlpre();
    $body .= qq(  <apps:property name="enable" value="false" />\n);
    $body .= $self->_xmlpost();

    my $result = $self->_request(
        'method' => 'PUT',
        'url'    => $url,
        'body'   => $body
    ) || return( 0 );

    return( 1 );
}



sub enablePOP {
    my $self = shift;

    my ( $arg );
    %{$arg} = @_;

    my $url = qq(https://apps-apis.google.com/a/feeds/emailsettings/2.0/$self->{'domain'}/$arg->{'username'}/pop);

    my ( $body );

    $body  = $self->_xmlpre();

    $body .= qq(  <apps:property name="enable" value="true" />\n);

    if ( $arg->{'enableFor'} ) {
        if ( $arg->{'enableFor'} eq 'all' ) { $arg->{'enableFor'} = 'ALL_MAIL'; }
        if ( $arg->{'enableFor'} eq 'now' ) { $arg->{'enableFor'} = 'MAIL_FROM_NOW_ON'; }

        $body .= qq( <apps:property name="enableFor" value="$arg->{'enableFor'}" />\n);
    }
    else {
        $body .= qq( <apps:property name="enableFor" value="MAIL_FROM_NOW_ON" />\n);
    }

    if ( $arg->{'action'} ) {
        $arg->{'action'} = uc( $arg->{'action'};

        $body .= qq(  <apps:property name="action" value="$arg->{'action'}" />\n);
    }
    else {
        $body .= qq(  <apps:property name="action" value="KEEP" />\n);
    }

    $body .= $self->_xmlpost();

    my $result = $self->_request(
        'method' => 'PUT',
        'url'    => $url,
        'body'   => $body
    ) || return( 0 );

    return( 1 );

}

sub disablePOP {
    my $self = shift;
    my $user = shift;

    my $url = qq(https://apps-apis.google.com/a/feeds/emailsettings/2.0/$self->{'domain'}/$user/pop);

    my ( $body );

    $body  = $self->_xmlpre();
    $body .= qq(  <apps:property name="enable" value="false" />\n);
    $body .= $self->_xmlpost();

    my $result = $self->_request(
        'method' => 'PUT',
        'url'    => $url,
        'body'   => $body
    ) || return( 0 );

    return( 1 );
}


sub enableIMAP {
    my $self = shift;
    my $user = shift;

    my $url = qq(https://apps-apis.google.com/a/feeds/emailsettings/2.0/$self->{'domain'}/$user/imap);

    my ( $body );

    $body  = $self->_xmlpre();
    $body .= qq(  <apps:property name="enable" value="true" />\n);
    $body .= $self->_xmlpost();

    my $result = $self->_request(
        'method' => 'PUT',
        'url'    => $url,
        'body'   => $body
    ) || return( 0 );

    return( 1 );
}

sub disableIMAP {
    my $self = shift;
    my $user = shift;

    my $url = qq(https://apps-apis.google.com/a/feeds/emailsettings/2.0/$self->{'domain'}/$user/imap);

    my ( $body );

    $body  = $self->_xmlpre();
    $body .= qq(  <apps:property name="enable" value="false" />\n);
    $body .= $self->_xmlpost();

    my $result = $self->_request(
        'method' => 'PUT',
        'url'    => $url,
        'body'   => $body
    ) || return( 0 );

    return( 1 );
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

