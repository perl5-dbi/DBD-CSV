#!/usr/bin/perl

package DBI::Test::DBD::CSV::Conf;

use strict;
use warnings;

sub test_case
{
    my %conf = (
	gofer => {
	    category   => "Gofer",
	    cat_abbrev => "g",
	    abbrev     => "b",
	    init_stub  =>
		qq{\$ENV{DBI_AUTOPROXY} = "dbi:Gofer:transport=null;policy=pedantic";},
	    match      => sub {
		my ($self, $test_case, $namespace, $category, $variant) = @_;
		},
	    name       => "Gofer Transport",
	    },
	);
    } # test_cases

1;
