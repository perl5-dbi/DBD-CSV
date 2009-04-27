#!/usr/bin/perl

use strict;
use Test::More "no_plan";

# Test if bindparam () works
$^W = 1;

BEGIN {
    use_ok ("DBI");
    }
do "t/lib.pl";

defined &SQL_VARCHAR or *SQL_VARCHAR = sub { 12 };
defined &SQL_INTEGER or *SQL_INTEGER = sub {  4 };

ok (my $dbh = Connect (),			"connect");

ok (my $tbl = FindNewTable ($dbh),		"find new test table");

like (my $def = TableDefinition ($tbl,
		[ "id",   "INTEGER",  4, 0 ],
		[ "name", "CHAR",    64, &COL_NULLABLE ]),
	qr{^create table $tbl}i,		"table definition");
ok ($dbh->do ($def),				"create table");

ok (my $sth = $dbh->prepare ("insert into $tbl values (?, ?)"), "prepare");

# Automatic type detection
my ($int, $chr) = (1, "Alligator Descartes");
ok ($sth->execute ($int, $chr),			"execute insert 1");

# Does the driver remember the automatically detected type?
ok ($sth->execute ("3", "Jochen Wiedman"),	"execute insert 2");

($int, $chr) = (2, "Tim Bunce");
ok ($sth->execute ($int, $chr),			"execute insert 3");

# Now try the explicit type settings
ok ($sth->bind_param (1, " 4", &SQL_INTEGER),	"bind 4 int");
ok ($sth->bind_param (2, "Andreas König"),	"bind str");
ok($sth->execute,				"execute");

# Works undef -> NULL?
ok ($sth->bind_param (1, 5, &SQL_INTEGER),	"bind 5 int");
ok ($sth->bind_param (2, undef),		"bind NULL");
ok($sth->execute,				"execute");

ok ($sth->finish,				"finish");
undef $sth;
ok ($dbh->disconnect,				"disconnect");
undef $dbh;


# And now retreive the rows using bind_columns
ok ($dbh = Connect (),				"connect");

ok ($sth = $dbh->prepare ("select * from $tbl order by id"),	"prepare");
ok ($sth->execute,				"execute");

my ($id, $name);
ok ($sth->bind_columns (undef, \$id, \$name),	"bind_columns");
ok ($sth->execute,				"execute");
ok ($sth->fetch,				"fetch");
is ($id,	1,				"id   1");
is ($name,	"Alligator Descartes",		"name 1");
ok ($sth->fetch,				"fetch");
is ($id,	2,				"id   2");
is ($name,	"Tim Bunce",			"name 2");
ok ($sth->fetch,				"fetch");
is ($id,	3,				"id   3");
is ($name,	"Jochen Wiedman",		"name 3");
ok ($sth->fetch,				"fetch");
#is ($id,	4,				"id   4"); # Broken in DBD::File
is ($name,	"Andreas König",		"name 4");
ok ($sth->fetch,				"fetch");
is ($id,	5,				"id   5");
is ($name,	undef,				"name 5");

ok ($sth->finish,				"finish");
undef $sth;

ok ($dbh->do ("drop table $tbl"),		"drop table");
ok ($dbh->disconnect,				"disconnect");
