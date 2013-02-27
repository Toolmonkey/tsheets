#!/usr/bin/perl -w

####################################################################################
### delJob deletes a specified job from the TSheets system			####
####################################################################################

use strict;
use tsheets;
use Data::Dumper;
use Scalar::Util qw(looks_like_number);
use Getopt::Long;

########################################
### CLI Param Storage                ###
########################################
my $jobID			= undef;

########################################
### Storage for processed params     ###
### that are bound for TSheets       ###
########################################

my %params;

my $result		= GetOptions(
					'id=i'		=>	\$jobID,
				);

# Enforce basic data requirements and assemble API params...
# The API requires: job_code_id

if (!$jobID) { 
	&usageError("You must speify a valid ID for the job you're adding.");
} else { 
	$params{job_code_id} = $jobID;
}

my $ts = new tsheets({
    "username"      =>  $ENV{TSHEETS_USERNAME},
    "password"      =>  $ENV{TSHEETS_PASSWORD},
    "api_key"       =>  $ENV{TSHEETS_API_KEY},
    "client_url"    =>  $ENV{TSHEETS_CLIENT_URL}
});

my $response = $ts->delJob(\%params);

if ($$response{status} eq "ok") { 
	print "Successfully deleted Job ID $jobID\n";
} else { 
	print "Unable to delete Job ID $jobID.\n";
	print "ERROR: " . $$response{last_error} . "\n";
}

$ts->logout();

####################################################################################
###								Routines                                         ###
####################################################################################

sub usageError { 
	my $message = shift;
	if ($message) { 
		print "$message\n\n";
	} else { 
		print "\n\n\n";
	}

	print "USAGE: $0 --name=JOB_NAME [--type=(regular|pto)] [--parentid=#######] [--global] [--assigntoall] [--alias=#####]\n";
	print "Parameter Details:\n";
	print "\t--id=##########: \n";
	print "\t\tRequired: YES\n";
	print "\t\tPurpose: Defines the name ID the job that's being deleted.\n\n";
	exit;
}
