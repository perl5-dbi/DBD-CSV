#!/usr/bin/perl

# This is a test for correct handling of BLOBS and $dbh->quote ()
$^W = 1;

# Include lib.pl
use DBI;
do "t/lib.pl";

sub ShowBlob($) {
    my ($blob) = @_;
    for($i = 0;  $i < 8;  $i++) {
	if (defined($blob)  &&  length($blob) > $i) {
	    $b = substr($blob, $i*32);
	} else {
	    $b = "";
	}
	printf("%08lx %s\n", $i*32, unpack("H64", $b));
    }
}


#
#   Main loop; leave this untouched, put tests after creating
#   the new table.
#
while (Testing()) {
    #
    #   Connect to the database
    Test($state or $dbh = Connect (), "connect") or
	ServerError();

    #
    #   Find a possible new table name
    #
    Test($state or $table = FindNewTable($dbh))
	   or DbiError($dbh->error, $dbh->errstr);

    my($def);
    foreach $size (128) {
	#
	#   Create a new table
	#
	if (!$state) {
	    $def = TableDefinition($table,
				   ["id",   "INTEGER",      4, 0],
				   ["name", "BLOB",     $size, 0]);
	    print "Creating table:\n$def\n";
	}
	Test($state or $dbh->do($def))
	    or DbiError($dbh->err, $dbh->errstr);


	#
	#  Create a blob
	#
	my ($blob, $qblob) = "";
	if (!$state) {
	    my $b = "";
	    for ($j = 0;  $j < 256;  $j++) {
		$b .= chr($j);
	    }
	    for ($i = 0;  $i < $size;  $i++) {
		$blob .= $b;
	    }
	    $qblob = $dbh->quote ($blob);
	}

	#
	#   Insert a row into the test table.......
	#
	my($query);
	if (!$state) {
#	  if ($SVERSION > 1) {
     	     $query = "INSERT INTO $table VALUES(1, ?)";
#	  }
#          else {
#     	     $query = "INSERT INTO $table VALUES(1, $qblob)";
#	  }
	    if ($ENV{'SHOW_BLOBS'}  &&  open(OUT, ">" . $ENV{'SHOW_BLOBS'})) {
		print OUT $query;
		close(OUT);
	    }
	}
#        if ($SVERSION > 1) {
            Test($state or $dbh->do($query,undef,$blob))
  	        or DbiError($dbh->err, $dbh->errstr);
#        }
#	else {
#            Test($state or $dbh->do($query))
#  	        or DbiError($dbh->err, $dbh->errstr);
#	}

	#
	#   Now, try SELECT'ing the row out.
	#
	Test($state or $cursor = $dbh->prepare("SELECT * FROM $table"
					       . " WHERE id = 1"))
	       or DbiError($dbh->err, $dbh->errstr);

	Test($state or $cursor->execute)
	       or DbiError($dbh->err, $dbh->errstr);

	Test($state or (defined($row = $cursor->fetchrow_arrayref)))
	    or DbiError($cursor->err, $cursor->errstr);

	Test($state or (@$row == 2  &&  $$row[0] == 1  &&  $$row[1] eq $blob))
	    or (ShowBlob($blob),
		ShowBlob(defined($$row[1]) ? $$row[1] : ""));

	Test($state or $cursor->finish)
	    or DbiError($cursor->err, $cursor->errstr);

	Test($state or undef $cursor || 1)
	    or DbiError($cursor->err, $cursor->errstr);

	#
	#   Finally drop the test table.
	#
	Test($state or $dbh->do("DROP TABLE $table"))
	    or DbiError($dbh->err, $dbh->errstr);
    }
}
