#!perl -T

use Test::More tests => 1;

BEGIN {
	use_ok( 'REST::Google::Apps::Provisioning' );
}

diag( "Testing REST::Google::Apps::Provisioning $REST::Google::Apps::Provisioning::VERSION, Perl $], $^X" );

