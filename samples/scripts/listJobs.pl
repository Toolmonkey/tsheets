#!/usr/bin/perl -w

####################################################################################
### listJobs.pl lists jobs that are set up in the TSheets system.  It accepts    ###
### a list of parent Job IDs as arguments (As many as you want).  If no parent   ###
### IDs are specified on the command line, it uses the default '0', which will   ###
### list all top-level jobs.                                                     ###
####################################################################################

use strict;
use tsheets;
use Data::Dumper;
use Scalar::Util qw(looks_like_number);

my @parentIDs;

if (@ARGV) { 
	foreach my $arg (@ARGV) { 
		if (looks_like_number($arg)) { 
			push @parentIDs, $arg;
		}
	}
} else { 
	push @parentIDs, '0';
}

my $ts = new tsheets({
	"username"		=>	$ENV{TSHEETS_USERNAME},
	"password"		=>	$ENV{TSHEETS_PASSWORD},
	"api_key"		=>	$ENV{TSHEETS_API_KEY},
	"client_url"	=>	$ENV{TSHEETS_CLIENT_URL}
});

my $jobs = $ts->listJobs({'parent_ids'=>\@parentIDs,'method'=>'get'});

my $counter = 0;

print "+------------------------------------------------------------------------------------------------------------------+\n";
print "| ####### | Job ID     | Parent ID | Job Type   |                Job Name                                          |\n";
print "|---------|------------|-----------|------------|------------------------------------------------------------------|\n";
foreach my $job (@{$jobs}) { 
	$counter++;
	format STDOUT=
| @<<<<<< | @<<<<<<<<< | @<<<<<<<< | @<<<<<<<<< | @<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<< |
$counter,$$job{id},$$job{parent_id},$$job{type},$$job{name}
.
write(STDOUT);

}
print "+------------------------------------------------------------------------------------------------------------------+\n";

$ts->logout();
