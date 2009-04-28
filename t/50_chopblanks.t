#!/usr/bin/perl

use strict;
use Test::More tests => 38;

# This driver should check if 'ChopBlanks' works.
$^W = 1;

BEGIN { use_ok ("DBI") }
do "t/lib.pl";

my @tbl_def = (
    [ "id",   "INTEGER",  4, &COL_NULLABLE ],
    [ "name", "CHAR",    64, &COL_NULLABLE ],
    );

ok (my $dbh = Connect (),			"connect");

ok (my $tbl = FindNewTable ($dbh),		"find new test table");

like (my $def = TableDefinition ($tbl, @tbl_def),
	qr{^create table $tbl}i,		"table definition");
ok ($dbh->do ($def),				"create table");

my @rows = (
    [ 1, "NULL",	],
    [ 2, " ",		],
    [ 3, " a b c ",	],
    );
ok (my $sti = $dbh->prepare ("insert into $tbl (id, name) values (?, ?)"), "prepare ins");
ok (my $sth = $dbh->prepare ("select id, name from $tbl where id = ?"),    "prepare sel");
foreach my $row (@rows) {
    ok ($sti->execute (@$row),			"insert $row->[0]");

    $sth->{ChopBlanks} = 0;
    ok (1,					"ChopBlanks 0");
    ok ($sth->execute ($row->[0]),		"execute");
    ok (my $r = $sth->fetch,			"fetch");
    is_deeply ($r, $row,			"content");
    
    $sth->{ChopBlanks} = 1;
    ok (1,					"ChopBlanks 1");
    ok ($sth->execute ($row->[0]),		"execute");
    s/ +$// for @$row;
    ok ($r = $sth->fetch,			"fetch");
    is_deeply ($r, $row,			"content");
    }

ok ($sti->finish,				"finish sti");
undef $sti;
ok ($sth->finish,				"finish sth");
undef $sth;

ok ($dbh->do ("drop table $tbl"),		"drop table");
ok ($dbh->disconnect,				"disconnect");
