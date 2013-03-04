#!/usr/bin/perl -w

use tsheets::job;
use Data::Dumper;

my $JOB_NUMBER;

my $job = tsheets::job->new(
    "username"      =>  $ENV{TSHEETS_USERNAME},
    "password"      =>  $ENV{TSHEETS_PASSWORD},
    "api_key"       =>  $ENV{TSHEETS_API_KEY},
    "client_url"    =>  $ENV{TSHEETS_CLIENT_URL}
);

if (defined($ARGV[0]) && $ARGV[0] =~ /^\d+$/) {
    $JOB_NUMBER = $ARGV[0];
} else {
    print "USAGE: $0 JOB_NUMBER\n";
    exit;
}

$job->load($JOB_NUMBER);

print "ID:   " . $job->id() . "\n";
print "NAME: " . $job->name() . "\n";

