#!/usr/bin/perl

# test if delete from shrinks table

use strict;
use warnings;
use Test::More;

BEGIN { use_ok ("DBI"); }
do "t/lib.pl";

my @tbl_def = (
    [ "id",   "INTEGER",  4, &COL_NULLABLE ],
    [ "name", "CHAR",    64, &COL_NULLABLE ],
    );

ok (my $dbh = Connect (),				"connect");

ok (my $tbl = FindNewTable ($dbh),			"find new test table");

like (my $def = TableDefinition ($tbl, @tbl_def),
	qr{^create table $tbl}i,			"table definition");
ok ($dbh->do ($def),					"create table");

my $sz = 0;
my $tbl_file = DbFile ($tbl);
ok ($sz = -s $tbl_file,					"file exists");

ok ($dbh->do ("insert into $tbl values (1, 'Foo')"),	"insert");
ok ($sz < -s $tbl_file,					"file grew");
$sz = -s $tbl_file;

ok ($dbh->do ("delete from $tbl where id = 1"),		"delete single");
ok ($sz > -s $tbl_file,					"file shrank");
$sz = -s $tbl_file;

ok ($dbh->do ("insert into $tbl (id) values ($_)"),	"insert $_") for 1 .. 10;
ok ($sz < -s $tbl_file,					"file grew");

{   local $dbh->{PrintWarn}  = 0;
    local $dbh->{PrintError} = 0;
    is ($dbh->do ("delete from wxyz where id = 99"), undef,	"delete non-existing tbl");
    }
cmp_ok ($dbh->do ("delete from $tbl where id = 99"), "==", 0,	"delete non-existing row");
is ($dbh->do ("delete from $tbl where id =  9"), 1,	"delete single (count)");
is ($dbh->do ("delete from $tbl where id >  7"), 2,	"delete more (count)");

ok ($dbh->do ("delete from $tbl"),			"delete all");
is (-s $tbl_file, $sz,					"file reflects empty table");

ok ($dbh->do ("drop table $tbl"),			"drop table");
ok ($dbh->disconnect,					"disconnect");
ok (!-f $tbl_file,					"file removed");

done_testing ();
