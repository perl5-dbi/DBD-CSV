#!/usr/bin/perl

# This driver should check if 'ChopBlanks' works.

# Make -w happy
use vars qw( $verbose $state );
use vars qw( $COL_NULLABLE $COL_KEY );

# Include lib.pl
use DBI;
use strict;
do "t/lib.pl";

#   Main loop; leave this untouched, put tests after creating
#   the new table.
#
while (Testing()) {
    my ($dbh, $sth, $query);

    #
    #   Connect to the database
    Test($state or $dbh = Connect (), "connect") or
	   ServerError();

    #
    #   Find a possible new table name
    #
    my $table = '';
    Test($state or $table = FindNewTable($dbh))
	   or ErrMsgF("Cannot determine a legal table name: Error %s.\n",
		      $dbh->errstr);

    #
    #   Create a new table; EDIT THIS!
    #
    Test($state or ($query = TableDefinition($table,
				      ["id",   "INTEGER",  4, $COL_NULLABLE],
				      ["name", "CHAR",    64, $COL_NULLABLE]),
		    $dbh->do($query)))
	or ErrMsgF("Cannot create table: Error %s.\n",
		      $dbh->errstr);


    #
    #   and here's the right place for inserting new tests:
    #
    my @rows;
#    if ($SVERSION > 1) {
        @rows = ([1, 'NULL'],
	 	 [2, ' '],
		 [3, ' a b c ']);
#    }
#    else {
#        @rows = ([1, ''],
#	 	 [2, ' '],
#		 [3, ' a b c ']);
#    }
    my $ref;
    foreach $ref (@rows) {
	my ($id, $name) = @$ref;
	if (!$state) {
	    $query = sprintf("INSERT INTO $table (id, name) VALUES ($id, %s)",
			     $dbh->quote($name));
	}
	Test($state or $dbh->do($query))
	    or ErrMsgF("INSERT failed: query $query, error %s.\n",
		       $dbh->errstr);
        $query = "SELECT id, name FROM $table WHERE id = $id\n";
	Test($state or ($sth = $dbh->prepare($query)))
	    or ErrMsgF("prepare failed: query $query, error %s.\n",
		       $dbh->errstr);

	# First try to retreive without chopping blanks.
	$sth->{'ChopBlanks'} = 0;
	Test($state or $sth->execute)
	    or ErrMsgF("execute failed: query %s, error %s.\n", $query,
		       $sth->errstr);
	Test($state or defined($ref = $sth->fetchrow_arrayref))
	    or ErrMsgF("fetch failed: query $query, error %s.\n",
		       $sth->errstr);
	Test($state or $$ref[1] eq $name)
	    or ErrMsgF("problems with ChopBlanks = 0:"
		       . " expected '%s', got '%s'.\n",
		       $name, $$ref[1]);
	Test($state or $sth->finish());

	# Now try to retreive with chopping blanks.
	$sth->{'ChopBlanks'} = 1;
	Test($state or $sth->execute)
	    or ErrMsg("execute failed: query $query, error %s.\n",
		      $sth->errstr);
	my $n = $name;
	$n =~ s/\s+$//;
	Test($state or ($ref = $sth->fetchrow_arrayref))
	    or ErrMsgF("fetch failed: query $query, error %s.\n",
		       $sth->errstr);
	Test($state or ($$ref[1] eq $n))
	    or ErrMsgF("problems with ChopBlanks = 1:"
		       . " expected '%s', got '%s'.\n",
		       $n, $$ref[1]);

	Test($state or $sth->finish)
	    or ErrMsgF("Cannot finish: %s.\n", $sth->errstr);
    }

    #
    #   Finally drop the test table.
    #
    Test($state or $dbh->do("DROP TABLE $table"))
	   or ErrMsgF("Cannot DROP test table $table: %s.\n",
		      $dbh->errstr);

    #   ... and disconnect
    Test($state or $dbh->disconnect)
	or ErrMsgF("Cannot disconnect: %s.\n", $dbh->errmsg);
}



