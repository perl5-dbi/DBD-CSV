#!/usr/bin/perl

# Test that our declared minimum Perl version matches our syntax
use strict;
BEGIN {
    $|  = 1;
    $^W = 1;
    }

my @MODULES = (
    "Perl::MinimumVersion 1.20",
    "Test::MinimumVersion 0.008",
    );

# Don't run tests during end-user installs
use Test::More;
$ENV{AUTOMATED_TESTING} || $ENV{RELEASE_TESTING} or
    plan skip_all => "Author tests not required for installation";

# Load the testing modules
foreach my $MODULE (@MODULES) {
    eval "use $MODULE";
    $@ or next;
    $ENV{RELEASE_TESTING}
	? die "Failed to load required release-testing module $MODULE"
	: plan skip_all => "$MODULE not available for testing";
    }

all_minimum_version_from_metayml_ok ();

1;
