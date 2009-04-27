#!/usr/bin/perl

# This is a test for correctly handling NULL values.

# Include lib.pl
use DBI;
use vars qw($COL_NULLABLE);
do "t/lib.pl";

# Main loop; leave this untouched, put tests after creating
# the new table.
#
while (Testing ()) {
    # Connect to the database
    Test ($state or $dbh = Connect ()) or
	ServerError ();

    # Find a possible new table name
    Test ($state or $table = FindNewTable ($dbh)) or
	DbiError ($dbh->err, $dbh->errstr);

    # Create a new table; EDIT THIS!
    Test ($state or (
	  $def = TableDefinition ($table,
		["id",   "INTEGER", 4,  $COL_NULLABLE],
		["name", "CHAR",    64, 0]
		),
	  $dbh->do ($def))) or
	DbiError ($dbh->err, $dbh->errstr);

    # Test whether or not a field containing a NULL is returned correctly
    # as undef, or something much more bizarre
    Test ($state or
	  $dbh->do ("INSERT INTO $table VALUES (NULL, 'NULL-valued id')")) or
	DbiError ($dbh->err, $dbh->errstr);

    Test ($state or
	  $cursor = $dbh->prepare ("SELECT * FROM $table WHERE ".IsNull ("id"))) or
	DbiError ($dbh->err, $dbh->errstr);

    Test ($state or $cursor->execute) or
	DbiError ($dbh->err, $dbh->errstr);

    Test ($state or $cursor->finish) or
	DbiError ($dbh->err, $dbh->errstr);

    Test ($state or undef $cursor || 1);

    # Finally drop the test table.
    Test ($state or $dbh->do ("DROP TABLE $table")) or
	DbiError ($dbh->err, $dbh->errstr);
    }
