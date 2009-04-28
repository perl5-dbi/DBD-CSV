#!/usr/bin/perl

# This is a test for correctly handling NULL values.
use strict;
use Test::More tests => 14;

BEGIN { use_ok ("DBI") }
do "t/lib.pl";

my @tbl_def = (
    [ "id",   "INTEGER",  4, &COL_NULLABLE	],
    [ "name", "CHAR",    64, 0			],
    );

ok (my $dbh = Connect (),		"connect");

ok (my $tbl = FindNewTable ($dbh),	"find new test table");

like (my $def = TableDefinition ($tbl, @tbl_def),
	qr{^create table $tbl}i,	"table definition");
ok ($dbh->do ($def),			"create table");

ok ($dbh->do ("insert into $tbl values (NULL, 'NULL-id')"), "insert");

ok (my $sth = $dbh->prepare ("select * from $tbl where id is NULL"), "prepare");
ok ($sth->execute,			"execute");
ok (my $row = $sth->fetch,		"fetch");

is_deeply ($row, [ "", "NULL-id" ],	"default content");
ok ($sth->finish,			"finish");

# By default, CSV has no NULL concept, so ,, returns the same as ,"",
# But Text::CSV_XS has an option to allow ,, to be undef, so lets cheat!
#ok ($dbh->{csv_csv_in}->blank_is_undef (1),"CSV blank_is_undef");
#ok ($sth->execute,			"execute");
#ok (my $row = $sth->fetch,		"fetch");
#is_deeply ($row, [ undef, "NULL-id" ],	"default content");

ok ($sth->finish,			"finish");
undef $sth;

ok ($dbh->do ("drop table $tbl"),	"drop table");
ok ($dbh->disconnect,			"disconnect");
