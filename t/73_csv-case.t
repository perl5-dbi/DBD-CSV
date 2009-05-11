#!/usr/bin/perl

use strict;
use Test::More "no_plan"; #tests => 66;

BEGIN { use_ok ("DBI"); }
do "t/lib.pl";

sub DbFile;

my $dir = DbDir () || "output";

my @tbl_def = (
    [ "id",   "INTEGER",  4, 0 ],
    [ "name", "CHAR",    64, 0 ],
    );

my $tbl = "foo";
ok (my $dbh = Connect (),			"connect");
ok (!-f DbFile ($tbl),				"foo does not exist");

like (my $def = TableDefinition ($tbl, @tbl_def),
	qr{^create table $tbl}i,		"table definition");
ok ($dbh->do ($def),				"create table");
ok (-f DbFile ($tbl),				"does exists");

for (qw( foo foO fOo fOO Foo FoO FOo FOO )) {
    ok (my $sth = $dbh->prepare ("select * from $_"),	"select from $_");
    ok ($sth->execute,				"execute");
    }

TODO: {
    local $TODO = "Quoted table names shouls match case on file name";
    for (qw( foo foO fOo fOO Foo FoO FOo FOO )) {
	my $sth = $dbh->prepare (qq{select * from "$_"});
	if ($_ eq "foo") {
	    ok ($sth,				"quoted table name matches");
	    ok ($sth->execute,			"execute");
	    }
	else {
	    is ($sth, undef,			"doesn't match");
	    }
	}
    }

ok ($dbh->do ("drop table $tbl"),		"drop table");

ok ($dbh->disconnect,				"disconnect");
undef $dbh;
__END__

$dsn = "DBI:CSV:";
ok ($dbh = Connect ($dsn),			"connect");

# Check, whether the csv_tables->{$tbl}{file} attribute works
ok ($dbh->{csv_tables}{$tbl}{file} = DbFile ($tbl), "set table/file");
ok ($dbh->do ($def),				"create table");
ok (-f DbFile ($tbl),				"does exists");

ok ($dbh->do ("drop table $tbl"),		"drop table");

ok ($dbh->disconnect,				"disconnect");
undef $dbh;

ok ($dbh = DBI->connect ("dbi:CSV:", "", "", {
    f_dir		=> DbDir (),
    f_ext		=> ".csv",
    dbd_verbose		=> 8,
    csv_sep_char	=> ";",
    csv_blank_is_undef	=> 1,
    csv_always_quote	=> 1,
    }),						"connect with attr");

is ($dbh->{dbd_verbose},	8,		"dbd_verbose set");
is ($dbh->{f_ext},		".csv",		"f_ext set");
is ($dbh->{csv_sep_char},	";",		"sep_char set");
is ($dbh->{csv_blank_is_undef},	1,		"blank_is_undef set");

ok ($dbh->do ($def),				"create table");
ok (-f DbFile ($tbl).".csv",			"does exists");
ok ($sth = $dbh->prepare ("insert into $tbl values (?, ?, ?)"), "prepare");
#is ($sth->{blank_is_undef},	1,		"blank_is_undef");
eval {
    local $SIG{__WARN__} = sub { };
    is ($sth->execute (1, ""), undef,		"not enough values");
    like ($dbh->errstr, qr/passed 2 parameters where 3 required/, "error message");
    is ($sth->execute (1, "", 1, ""), undef,	"too many values");
    like ($dbh->errstr, qr/passed 4 parameters where 3 required/, "error message");
    };
ok ($sth->execute ($_, undef, "Code $_"),	"insert $_") for 0 .. 9;

ok ($dbh->do ("drop table $tbl"),		"drop table");
ok (!-f DbFile ($tbl),				"does not exist");
ok (!-f DbFile ($tbl).".csv",			"does not exist");

ok ($dbh->disconnect,				"disconnect");
undef $dbh;
