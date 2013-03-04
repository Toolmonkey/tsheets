use strict;
use warnings;

use Test::More tests => 6;

BEGIN { 
	use_ok('tsheets');
	use_ok('Moose');
	use_ok('JSON::XS');
	use_ok('LWP::UserAgent');
	use_ok('LWP::Protocol::https');
	use_ok('XML::Simple'); 
};

