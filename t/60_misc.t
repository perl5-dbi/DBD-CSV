#!/usr/bin/perl

use strict;
use Test::More "no_plan";

# Misc tests
$^W = 1;

BEGIN { use_ok ("DBI"); }
do "t/lib.pl";

my @tbl_def = (
    [ "id",   "INTEGER",  4, &COL_NULLABLE ],
    [ "name", "CHAR",    64, &COL_NULLABLE ],
    );

ok (my $dbh = Connect (),		"connect");

ok (my $tbl = FindNewTable ($dbh),	"find new test table");

like (my $def = TableDefinition ($tbl, @tbl_def),
	qr{^create table $tbl}i,	"table definition");
ok ($dbh->do ($def),			"create table");

is ($dbh->quote ("tast1"), "'tast1'",	"quote");

ok (my $sth = $dbh->prepare ("select * from $tbl where id = 1"), "prepare");
{   local $dbh->{PrintError} = 0;
    my @warn;
    local $SIG{__WARN__} = sub { push @warn, @_ };
    eval { is ($sth->fetch, undef,	"fetch w/o execute"); };
    is (scalar @warn, 1,		"one error");
    like ($warn[0],
	qr/fetch row without a preceeding execute/,	"error message");
    }
ok ($sth->execute,			"execute");
is ($sth->fetch, undef,			"fetch no rows");
ok ($sth->finish,			"finish");
undef $sth;

ok ($dbh->do ("drop table $tbl"),	"drop table");
ok ($dbh->disconnect,			"disconnect");
__END__

### This section should exercise the sth->func( '_NumRows' ) private
###  method by preparing a statement, then finding the number of rows
###  within it. Prior to execution, this should fail. After execution,
###  the number of rows affected by the statement will be returned.
Test($state or ($dbh->do($query = "INSERT INTO $test_table VALUES"
				   . " (1, 'Alligator Descartes' )")))
    or ErrMsgF("INSERT failed: query $query, error %s.\n", $dbh->errstr);
Test($state or ($sth = $dbh->prepare($query = "SELECT * FROM $test_table"
					      . " WHERE id = 1")))
    or ErrMsgF("prepare failed: query $query, error %s.\n", $dbh->errstr);

if (!$state) {
    print "Test 19: Setting \$debug_me to TRUE\n"; $::debug_me = 1;
}
Test($state or $sth->execute)
    or ErrMsgF("execute failed: query $query, error %s.\n", $sth->errstr);
Test($state  or  ($sth->rows == 1)  or  ($sth->rows == -1))
    or ErrMsgF("sth->rows returned wrong result %s after 'execute'.\n",
	       $sth->rows);
Test($state or $sth->finish)
    or ErrMsgF("finish failed: %s.\n", $sth->errstr);
Test($state or (undef $sth or 1));

### Test whether or not a field containing a NULL is returned correctly
### as undef, or something much more bizarre
$query = "INSERT INTO $test_table VALUES ( NULL, 'NULL-valued id' )";
Test($state or $dbh->do($query))
    or ErrMsgF("INSERT failed: query $query, error %s.\n", $dbh->errstr);
$query = "SELECT id FROM $test_table WHERE id IS NULL";
Test($state or ($sth = $dbh->prepare($query)))
    or ErrMsgF("Cannot prepare, query = $query, error %s.\n",
	       $dbh->errstr);
if (!$state) {
    print "Test 25: Setting \$debug_me to TRUE\n"; $::debug_me = 1;
}
Test($state or $sth->execute)
    or ErrMsgF("Cannot execute, query = $query, error %s.\n",
	       $dbh->errstr);
my $rv;
#    Test($state or !defined($$rv[0]))
#	or ErrMsgF("Expected NULL value, got %s.\n", $$rv[0]);
Test($state or $sth->finish)
    or ErrMsgF("finish failed: %s.\n", $sth->errstr);
Test($state or undef $sth or 1);

### Delete the test row from the table
$query = "DELETE FROM $test_table WHERE id = NULL AND"
    . " name = 'NULL-valued id'";
Test($state or ($rv = $dbh->do($query)))
    or ErrMsg("DELETE failed: query $query, error %s.\n", $dbh->errstr);

### Test whether or not a char field containing a blank is returned
###  correctly as blank, or something much more bizarre

#    if ($SVERSION > 1) {
###      $query = "INSERT INTO $test_table VALUES (2, NULL)";
#    }
#    else {
  $query = "INSERT INTO $test_table VALUES (2, '')";
#    }

Test($state or $dbh->do($query))
    or ErrMsg("INSERT failed: query $query, error %s.\n", $dbh->errstr);
#    if ($SVERSION > 1) {
###     $query = "SELECT name FROM $test_table WHERE id = 2 AND name IS NULL";
#    }
#    else {
    $query = "SELECT name FROM $test_table WHERE id = 2 AND name = ''";
#      }

Test($state or ($sth = $dbh->prepare($query)))
    or ErrMsg("prepare failed: query $query, error %s.\n", $dbh->errstr);
Test($state or $sth->execute)
    or ErrMsg("execute failed: query $query, error %s.\n", $dbh->errstr);
$rv = undef;
###    Test($state or defined($ref = $sth->fetch))
###        or ErrMsgF("fetchrow failed: query $query, error %s.\n", $sth->errstr);
#    if ($SVERSION > 1) {
    Test($state or !defined($$ref[0]) )
	or ErrMsgF("blank value returned as [%s].\n", $$ref[0]);
#    }
#    else {
#        Test($state or (defined($$ref[0])  &&  ($$ref[0] eq '')))
#            or ErrMsgF("blank value returned as %s.\n", $$ref[0]);
#    }
Test($state or $sth->finish)
    or ErrMsg("finish failed: $sth->errmsg.\n");
Test($state or undef $sth or 1);

### Delete the test row from the table
#    if ($SVERSION > 1) {
    $query = "DELETE FROM $test_table WHERE id = 2 AND name IS NULL";
#    }
#    else {
#        $query = "DELETE FROM $test_table WHERE id = 2 AND name = ''";
#    }
Test($state or $dbh->do($query))
    or ErrMsg("DELETE failed: query $query, error $dbh->errstr.\n");

### Test the new funky routines to list the fields applicable to a SELECT
### statement, and not necessarily just those in a table...
$query = "SELECT * FROM $test_table";
Test($state or ($sth = $dbh->prepare($query)))
    or ErrMsg("prepare failed: query $query, error $dbh->errstr.\n");
Test($state or $sth->execute)
    or ErrMsg("execute failed: query $query, error $dbh->errstr.\n");
#    if ($SVERSION > 1) {
  Test($state or $sth->execute, 'execute 284')
     or ErrMsg("re-execute failed: query $query, error $dbh->errstr.\n");
#    }
#    else {
#        Test($state or $sth->execute, 'execute 284')
#           or ErrMsg("re-execute failed: query $query, error $dbh->errstr.\n");
#    }
Test($state or (@row = $sth->fetchrow_array), 'fetchrow 286')
    or ErrMsg("Query returned no result, query $query,",
	      " error $sth->errstr.\n");
Test($state or $sth->finish)
    or ErrMsg("finish failed: $sth->errmsg.\n");
Test($state or undef $sth or 1);

### Insert some more data into the test table.........
$query = "INSERT INTO $test_table VALUES( 2, 'Gary Shea' )";
Test($state or $dbh->do($query))
    or ErrMsg("INSERT failed: query $query, error $dbh->errstr.\n");
$query = "UPDATE $test_table SET id = 3 WHERE name = 'Gary Shea'";
Test($state or ($sth = $dbh->prepare($query)))
    or ErrMsg("prepare failed: query $query, error $sth->errmsg.\n");
Test($state or undef $sth or 1);

### Drop the test table out of our database to clean up.........
$query = "DROP TABLE $test_table";
Test($state or $dbh->do($query))
    or ErrMsg("DROP failed: query $query, error $dbh->errstr.\n");

Test($state or $dbh->disconnect)
    or ErrMsg("disconnect failed: $dbh->errstr.\n");
