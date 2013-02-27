# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl tsheets.t'

#########################

# change 'tests => 1' to 'tests => last_test_to_print';

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

#########################

# Insert your test code below, the Test::More module is use()ed here so read
# its man page ( perldoc Test::More ) for help writing this test script.

