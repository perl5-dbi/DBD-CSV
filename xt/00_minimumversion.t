#!/usr/bin/perl

# Test that our declared minimum Perl version matches our syntax
use strict;
$^W = 1;

my @MODULES = (
    "Perl::MinimumVersion 1.20",
    "Test::MinimumVersion 0.008",
    );

my $has_meta = -f "META.yml";

# Don't run tests during end-user installs
use Test::More;

# Load the testing modules
foreach my $MODULE (@MODULES) {
    eval "use $MODULE";
    $@ or next;
    $ENV{RELEASE_TESTING}
	? die "Failed to load required release-testing module $MODULE"
	: plan skip_all => "$MODULE not available for testing";
    }

!$has_meta && -x "sandbox/genMETA.pl" and
    qx{ perl sandbox/genMETA.pl -v > META.yml };

all_minimum_version_from_metayml_ok ();

$has_meta or unlink "META.yml";

1;
