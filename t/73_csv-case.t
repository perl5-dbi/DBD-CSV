#!/usr/bin/perl

use strict;
use warnings;
use Test::More;

BEGIN { use_ok ("DBI"); }
do "t/lib.pl";

sub DbFile;

my $dir = DbDir ();

my @tbl_def = (
    [ "id",   "INTEGER",  4, 0 ],
    [ "name", "CHAR",    64, 0 ],
    );

my $tbl = "foo";
ok (my $dbh = Connect (),			"connect");
ok (!-f DbFile ($tbl),				"foo does not exist");
ok ($dbh->{ignore_missing_table} = 1,		"ignore missing tables");

like (my $def = TableDefinition ($tbl, @tbl_def),
	qr{^create table $tbl}i,		"table definition");
ok ($dbh->do ($def),				"create table");
ok (-f DbFile ($tbl),				"does exists");

for (qw( foo foO fOo fOO Foo FoO FOo FOO )) {
    ok (my $sth = $dbh->prepare ("select * from $_"),	"select from $_");
    ok ($sth->execute,				"execute");
    }
ok ($dbh->disconnect,				"disconnect");
undef $dbh;

ok ($dbh = Connect (),				"connect");
ok ($dbh->{ignore_missing_table} = 1,		"ignore missing tables");

# I have not yet found an *easy* way to test the case sensitivity of
# the target FS, which might not prove at all that things will work
# on all folders, as case in-sensitive and case-sensitive FS's might
# co-exist.
for (qw( foo foO fOo fOO Foo FoO FOo FOO )) {
    ok (my $sth = $dbh->prepare (qq{select * from "$_"}), "prepare \"$_\"");

    if ($_ eq "foo") {
	ok ( $sth->execute,			"execute ok");
	}
    else {
	TODO: {
	    local $TODO = "Filesystem has to be case-aware" if $^O =~ m/win32|darwin/i;
	    local $sth->{PrintError} = 0;
	    ok (!$sth->execute,			"table name '$_' should not match 'foo'");
	    }
	}
    }

ok ($dbh->do ("drop table $tbl"),		"drop table");

ok ($dbh->disconnect,				"disconnect");
undef $dbh;

done_testing ();
