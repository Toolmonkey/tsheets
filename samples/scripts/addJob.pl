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
use Getopt::Long;

########################################
### CLI Param Storage                ###
########################################
my $jobName		= undef;
my $jobType		= undef;
my $parentID	= undef;
my $isGlobal	= undef;
my $assignAll	= undef;
my $billable	= undef;
my $alias		= undef;
my $isBillable	= undef;

########################################
### Storage for processed params     ###
### that are bound for TSheets       ###
########################################

my %params;

my $result		= GetOptions(
					'name=s'		=>	\$jobName,
					'type=s'		=>	\$jobType,
					'parentid=i'	=>	\$parentID,
					'global'		=>	\$isGlobal,
					'assigntoall'	=>	\$assignAll,
					'alias=i'		=>	\$alias,
					'billable'		=>	\$isBillable,
				);

# Enforce basic data requirements and assemble API params...
# The API requires: job_code_name

if (!$jobName) { 
	&usageError("You must speify a valid name for the job you're adding.");
} else { 
	if (!$jobType) { $jobType = 'regular'; }

	print "Adding Job '$jobName' with the following parameters:\n";
	printf('%15s',"JOB NAME");
	print ": $jobName\n";
	printf('%15s',"JOB TYPE");
	print ": $jobType\n";

	$params{job_code_name} = $jobName;
	$params{job_code_type} = $jobType;

	if (defined($parentID)) { 
		printf('%15s',"PARENT ID");
		print ": $parentID\n";
		$params{parent_id} 		= $parentID;
	}

	if (defined($isGlobal)) { 
		printf('%15s',"IS GLOBAL");
		print ": Yes\n";
		$params{global} 		= 1;
	}

	if (defined($assignAll)) { 
		printf('%15s',"ASSIGN TO ALL");
		print ": Yes\n";
		$params{assign_all} 	= 1;
	}

	if (defined($alias)) { 
		printf('%15s',"SMS ALIAS");
		print ": $alias\n";
		$params{alias} 			= $alias;
	}

	if (defined($isBillable)) { 
		printf('%15s',"IS BILLABLE");
		print ": Yes\n";
		$params{billable} 		= 1;
	}
}

print "\n";

my $ts = new tsheets({
    "username"      =>  $ENV{TSHEETS_USERNAME},
    "password"      =>  $ENV{TSHEETS_PASSWORD},
    "api_key"       =>  $ENV{TSHEETS_API_KEY},
    "client_url"    =>  $ENV{TSHEETS_CLIENT_URL}
});

my $response = $ts->addJob(\%params);

print Dumper($response);

if ($$response{status} eq "ok") { 
	print "Successfully Added Job '$jobName'\n";
	print "Job Details:\n";
	foreach my $key (sort keys %{$$response{jobcodes}}) { 
		if ($key eq "alias" && ref $$response{jobcodes}{$key} eq "HASH") { 
			$$response{jobcodes}{$key} = "No Alias Assigned";
		}
		printf('%15s',uc($key));
		print ": $$response{jobcodes}{$key}\n";
	}
	print "\n";
} else { 
	print "Failed To Add Job '$jobName'\n";
	print "Failure Details: \n";
	foreach my $key (sort keys %{$response}) { 
		print "\t" . uc($key) . ": $$response{$key}\n";
	}
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
	print "\t--name=JOB_NAME: \n";
	print "\t\tRequired: YES\n";
	print "\t\tPurpose: Defines the name of the job, which will be displayed in the UI.\n\n";
	print "\t--type=(regular|pto):\n";
	print "\t\tRequired: NO\n";
	print "\t\tDefault Value: regular\n";
	print "\t\tPurpose: Defines the job type.  This can be \"regular\" or \"pto\"\n\n";
	print "\t--parentid=########\n";
	print "\t\tRequired: NO\n";
	print "\t\tDefault Value: 0\n";
	print "\t\tPurpose: Sets the new job as a child of the child defined.\n\n";
	print "\t--global\n";
	print "\t\tRequired: NO\n";
	print "\t\tPurpose: Assigns the job to all existing and future users\n\n";
	print "\t--assigntoall\n";
	print "\t\tRequired: NO\n";
	print "\t\tPurpose: Assigns the job to all existing users but not future users.\n\n";
	print "\t--alias=####\n";
	print "\t\tRequired: NO\n";
	print "\t\tPurpose: Defines the SMS short code that can be used for this job.\n\n";
	print "\t--billable\n";
	print "\t\tRequired: NO\n";
	print "\t\tPurpose: Tells the TSheets app that the job is billable\n\n";


	exit;

}
