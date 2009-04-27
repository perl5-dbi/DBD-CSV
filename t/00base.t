#!/usr/bin/perl
#
#   This is the base test, tries to install the drivers. Should be
#   executed as the very first test.

use strict;

use Test::More tests => 8;
use vars qw( $mdriver );

BEGIN {
    use_ok ("SQL::Statement");
    use_ok ("DBI");
    }

ok ($SQL::Statement::VERSION, "SQL::Statement::Version $SQL::Statement::VERSION");

$mdriver = "";
foreach my $file ("lib.pl", "t/lib.pl") {
    do $file;
    if ($@) {
	print STDERR "Error while executing lib.pl: $@\n";
	exit 10;
	}
    $mdriver ne "" and last;
    }

ok (my $switch = DBI->internal, "DBI->internal");
is (ref $switch, "DBI::dr", "Driver class");

# This is a special case. install_driver should not normally be used.
ok (my $drh = DBI->install_driver ($mdriver), "Install driver");

is (ref $drh, "DBI::dr", "Driver class installed");

ok ($drh->{Version}, "Driver version $drh->{Version}");
