#!/usr/bin/perl -w

use tsheets::job;
use Data::Dumper;

my $job = tsheets::job->new(
    "username"      =>  $ENV{TSHEETS_USERNAME},
    "password"      =>  $ENV{TSHEETS_PASSWORD},
    "api_key"       =>  $ENV{TSHEETS_API_KEY},
    "client_url"    =>  $ENV{TSHEETS_CLIENT_URL}
);

$job->load($JOB_NUMBER);

print "ID: " . $job->id() . "\n";
print "NAME: " . $job->name() . "\n";
