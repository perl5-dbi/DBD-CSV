#!/usr/bin/perl

# Test that our META.yml file matches the specification
use strict;
BEGIN {
    $|  = 1;
    $^W = 1;
    }

my @MODULES = (
    "Test::CPAN::Meta 0.12",
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

meta_yaml_ok ();

1;
