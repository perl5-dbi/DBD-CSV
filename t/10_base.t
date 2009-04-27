#!/usr/bin/perl
#
# Test whether the driver can be installed

use strict;
use Test::More tests => 8;

BEGIN {
    use_ok ("DBI");
    use_ok ("SQL::Statement");
    }

ok ($SQL::Statement::VERSION, "SQL::Statement::Version $SQL::Statement::VERSION");

do "t/lib.pl";

ok (my $switch = DBI->internal, "DBI->internal");
is (ref $switch, "DBI::dr", "Driver class");

# This is a special case. install_driver should not normally be used.
ok (my $drh = DBI->install_driver ("CSV"), "Install driver");

is (ref $drh, "DBI::dr", "Driver class installed");

ok ($drh->{Version}, "Driver version $drh->{Version}");
