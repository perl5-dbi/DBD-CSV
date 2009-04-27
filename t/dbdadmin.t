#!/usr/local/bin/perl

# Test suite for the admin functions

# Make -w happy
$test_dsn = $test_user = $test_password = $verbose = '';
$| = 1;

# Include lib.pl
$DBI::errstr = ''; # Make -w happy
require DBI;
foreach $file ("lib.pl", "t/lib.pl", "DBD-~DBD_DRIVER~/t/lib.pl") {
    do $file;
    if ($@) {
	print STDERR "Error while executing lib.pl: $@\n";
	exit 10;
	}
    }

sub ServerError ()
{
    print STDERR ("Cannot connect: ", $DBI::errstr, "\n",
	"\tEither your server is not up and running or you have no\n",
	"\tpermissions for acessing the DSN $test_dsn.\n",
	"\tThis test requires a running server and write permissions.\n",
	"\tPlease make sure your server is running and you have\n",
	"\tpermissions, then retry.\n");
    exit 10;
    }

sub InDsnList($@) {
    my($dsn, @dsnList) = @_;
    my($d);
    foreach $d (@dsnList) {
	if ($d =~ /^dbi:[^:]+:$dsn\b/i) {
	    return 1;
	}
    }
    0;
}


#
#   Main loop; leave this untouched, put tests after creating
#   the new table.
#
while (Testing()) {
    # Check if the server is awake.
    $dbh = undef;
    Test($state or ($dbh = DBI->connect($test_dsn, $test_user,
					$test_password)))
	or ServerError();

    Test($state or (@dsn = DBI->data_sources ("CSV")) >= 0);
    if (!$state  &&  $verbose) {
	my $d;
	print "List of CSV data sources:\n";
	foreach $d (@dsn) {
	    print "    $d\n";
	}
	print "List ends.\n";
    }

    my $drh;
    Test($state or ($drh = DBI->install_driver("CSV")))
	or print STDERR ("Cannot obtain drh: " . $DBI::errstr);

    #
    #   Check the ping method.
    #
    Test($state or $dbh->ping())
	or ErrMsgF("Ping failed: %s.\n", $dbh->errstr);

}
