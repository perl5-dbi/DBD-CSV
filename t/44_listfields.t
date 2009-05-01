#!/usr/bin/perl

use strict;
use Test::More "no_plan";

# This is a test for statement attributes being present appropriately.
$^W = 1;

BEGIN { use_ok ("DBI") }
do "t/lib.pl";

defined &SQL_VARCHAR or *SQL_VARCHAR = sub { 12 };
defined &SQL_INTEGER or *SQL_INTEGER = sub {  4 };

my @tbl_def = (
    [ "id",   "INTEGER",  4, &COL_KEY		],
    [ "name", "CHAR",    64, &COL_NULLABLE	],
    );

ok (my $dbh = Connect (),			"connect");

ok (my $tbl = FindNewTable ($dbh),		"find new test table");

like (my $def = TableDefinition ($tbl, @tbl_def),
	qr{^create table $tbl}i,		"table definition");
ok ($dbh->do ($def),				"create table");

ok (my $sth = $dbh->prepare ("select * from $tbl"), "prepare");
ok ($sth->execute,				"execute");

is ($sth->{NUM_OF_FIELDS}, scalar @tbl_def,	"NUM_OF_FIELDS");
is ($sth->{NUM_OF_PARAMS}, 0,			"NUM_OF_PARAMS");
is ($sth->{NAME_lc}[0], lc $tbl_def[0][0],	"NAME_lc");
is ($sth->{NAME_uc}[1], uc $tbl_def[1][0],	"NAME_uc");
is_deeply ($sth->{NAME_lc_hash},
    { map { ( lc $tbl_def[$_][0] => $_ ) } 0 .. $#tbl_def }, "NAME_lc_hash");
# TODO tests
#s ($sth->{TYPE}[0], &SQL_INTEGER,		"TYPE 1");
#s ($sth->{TYPE}[1], &SQL_VARCHAR,		"TYPE 2");
is ($sth->{PRECISION}[0],	0,		"PRECISION 1");
is ($sth->{PRECISION}[1], 	4,		"PRECISION 2");
is ($sth->{NULLABLE}[0],	0,		"NULLABLE 1");
is ($sth->{NULLABLE}[1],	1,		"NULLABLE 2");

ok ($sth->finish,				"finish");
#s ($sth->{NUM_OF_FIELDS}, 0,			"NUM_OF_FIELDS");
undef $sth;

ok ($dbh->do ("drop table $tbl"),		"drop table");
ok ($dbh->disconnect,				"disconnect");
