#!/usr/bin/perl

use strict;
use Test::More "no_plan";

BEGIN { use_ok ("DBI"); }
do "t/lib.pl";

my @tbl_def = (
    [ "id",   "INTEGER",  4, 0 ],
    [ "name", "CHAR",    64, 0 ],
    );

sub DbFile;

my $dir = DbDir () || "output";

ok (my $dbh = Connect (),			"connect");

is ($dbh->{f_dir},  $dir,			"default dir");
ok ($dbh->{f_dir} = $dir,			"set f_dir");

ok (my $tbl = FindNewTable ($dbh),		"find new test table");
ok (!-f DbFile ($tbl),				"does not exist");

ok (my $tbl2 = FindNewTable ($dbh),		"find new test table");
ok (!-f DbFile ($tbl2),				"does not exist");

ok (my $tbl3 = FindNewTable ($dbh),		"find new test table");
ok (!-f DbFile ($tbl3),				"does not exist");

isnt ($tbl,  $tbl2,				"different 1 2");
isnt ($tbl,  $tbl3,				"different 1 3");
isnt ($tbl2, $tbl3,				"different 2 3");

like (my $def = TableDefinition ($tbl, @tbl_def),
	qr{^create table $tbl}i,		"table definition");
ok ($dbh->do ($def),				"create table 1");
ok (-f DbFile ($tbl),				"does exists");

ok ($dbh->do ("drop table $tbl"),		"drop table");
ok (!-f DbFile ($tbl),				"does not exist");

ok ($dbh->disconnect,				"disconnect");
undef $dbh;

my $dsn = "DBI:CSV:f_dir=$dir;csv_eol=\015\012;csv_sep_char=\\;;";
ok ($dbh = Connect ($dsn),			"connect");

ok ($dbh->do ($def),				"create table");
ok (-f DbFile ($tbl),				"does exists");

ok ($dbh->do ("insert into $tbl values (1, ?)", undef, "joe"),     "insert 1");
ok ($dbh->do ("insert into $tbl values (2, ?)", undef, "Jochen;"), "insert 2");

ok (my $sth = $dbh->prepare ("select * from $tbl"),	"prepare");
ok ($sth->execute,				"execute");
ok (my $row = $sth->fetch,			"fetch 1");
is_deeply ($row, [ 1, "joe" ],			"content");
ok (   $row = $sth->fetch,			"fetch 2");
is_deeply ($row, [ 2, "Jochen;" ],		"content");
ok ($sth->finish,				"finish");
undef $sth;

ok ($dbh->do ("drop table $tbl"),		"drop table");
ok (!-f DbFile ($tbl),				"does not exist");

ok ($dbh->disconnect,				"disconnect");
undef $dbh;

$dsn = "DBI:CSV:";
ok ($dbh = Connect ($dsn),			"connect");

# Check, whether the csv_tables->{$tbl}{file} attribute works
ok ($dbh->{csv_tables}{$tbl}{file} = DbFile ($tbl), "set table/file");
ok ($dbh->do ($def),				"create table");
ok (-f DbFile ($tbl),				"does exists");

ok ($dbh->do ("drop table $tbl"),		"drop table");

ok ($dbh->disconnect,				"disconnect");
undef $dbh;
