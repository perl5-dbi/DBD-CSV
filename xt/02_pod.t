#!/usr/bin/perl

use Test::More;
use File::Find;

eval "use Test::Pod::Links";
plan skip_all => "Test::Pod::Links required for testing POD Links" if $@;
eval {
    no warnings "redefine";
    no warnings "once";
    *Test::XTFiles::all_files = sub {
	my @pm;
	find (sub { -f && m/\.pm$/ and push @pm, $File::Find::name }, "lib");
	sort @pm;
	};
    };
Test::Pod::Links->new->all_pod_files_ok;
