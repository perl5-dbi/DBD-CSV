#!/usr/local/bin/perl

use strict;
use Test::More tests => 24;

# Test row insertion and retrieval
$^W = 1;

# Include lib.pl
use DBI;
do "t/lib.pl";

ok (my $dbh = Connect (),		"connect");

ok (my $tbl = FindNewTable ($dbh),	"find new test table");
$tbl ||= "tmp99";
eval {
    local $SIG{__WARN__} = sub {};
    $dbh->do ("drop table $tbl");
    };

like (my $def = TableDefinition ($tbl,
		[ "id",   "INTEGER",  4, 0 ],
		[ "name", "CHAR",    64, 0 ],
		[ "val",  "INTEGER",  4, 0 ],
		[ "txt",  "CHAR",    64, 0 ]),
	qr{^create table $tbl}i,	"table definition");

ok ($dbh->do ($def),			"create table");
my $tbl_file = DbFile ($tbl);
ok (my $sz = -s $tbl_file,		"file exists");

ok ($dbh->do ("insert into $tbl values ".
	      "(1, 'Alligator Descartes', 1111, 'Some Text')"), "insert");
ok ($sz < -s $tbl_file,			"file grew");

ok (my $sth = $dbh->prepare ("select * from $tbl where id = 1"), "prepare");
is (ref $sth, "DBI::st",		"handle type");

ok ($sth->execute,			"execute");

ok (my $row = $sth->fetch,		"fetch");
is (ref $row, "ARRAY",			"returned a list");
is ($sth->errstr, undef,		"no error");

is_deeply ($row, [ 1, "Alligator Descartes", 1111, "Some Text" ], "content");

ok ($sth->finish,			"finish");
undef $sth;

# Try some other capitilization
ok ($dbh->do ("DELETE FROM $tbl WHERE id = 1"),	"delete");

# Now, try SELECT'ing the row out. This should fail.
ok ($sth = $dbh->prepare ("select * from $tbl where id = 1"), "prepare");
is (ref $sth, "DBI::st",		"handle type");

ok ($sth->execute,			"execute");
is ($sth->fetch,  undef,		"fetch");
is ($sth->errstr, undef,		"error");	# ???

ok ($sth->finish,			"finish");
undef $sth;

ok ($dbh->do ("drop table $tbl"),	"drop");
ok ($dbh->disconnect,			"disconnect");
