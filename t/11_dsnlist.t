#!/usr/bin/perl
#
# Test whether data_sources () returns something useful

# Include lib.pl
require DBI;
foreach $file ("lib.pl", "t/lib.pl", "DBD-~DBD_DRIVER~/t/lib.pl") {
    do $file;
    if ($@) {
	print STDERR "Error while executing lib.pl: $@\n";
	exit 10;
	}
    }

print "Driver is CSV\n";

sub ServerError() {
    print STDERR ("Cannot connect: ", $DBI::errstr, "\n",
	"\tEither your server is not up and running or you have no\n",
	"\tpermissions for acessing the DSN $test_dsn.\n",
	"\tThis test requires a running server and write permissions.\n",
	"\tPlease make sure your server is running and you have\n",
	"\tpermissions, then retry.\n");
    exit 10;
}

#
#   Main loop; leave this untouched, put tests into the loop
#
while (Testing()) {
    # Check if the server is awake.
    $dbh = undef;
    Test($state or ($dbh = DBI->connect($test_dsn, $test_user,
					$test_password)))
	or ServerError();

    Test($state or (@dsn = DBI->data_sources ("CSV")) >= 0);
    if (!$state) {
	my $d;
	print "List of CSV data sources:\n";
	foreach $d (@dsn) {
	    print "    $d\n";
	}
	print "List ends.\n";
    }
    Test($state or $dbh->disconnect());

    #
    #   Try different DSN's
    #
    my(@dsnList);
    my($dsn);
    foreach $dsn (@dsnList) {
	Test($state or ($dbh = DBI->connect($dsn, $test_user,
					    $test_password)))
	    or print "Cannot connect to DSN $dsn: ${DBI::errstr}\n";
	Test($state or $dbh->disconnect());
    }
}

exit 0;

# Hate -w :-)
$test_dsn = $test_user = $test_password = $DBI::errstr;
