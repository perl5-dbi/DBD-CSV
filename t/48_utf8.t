#!/usr/bin/perl

# This is a test for correctly handling UTF-8 content
use strict;
use warnings;
use charnames ":full";

use DBI;
use Text::CSV_XS;
use Encode qw( decode encode );

use Test::More tests => 36;

BEGIN { use_ok ("DBI") }
do "t/lib.pl";

ok (my $dbh = Connect ({ f_ext => ".csv/r", f_schema => undef }), "connect");

ok (my $tbl = FindNewTable ($dbh),		"find new test table");

my @data = (
    "The \N{SNOWMAN} is melting",
    "U2 should \N{SKULL AND CROSSBONES}",
    "I \N{BLACK HEART SUIT} my wife",
    "Unicode makes me \N{WHITE SMILING FACE}",
    );
ok ("Creating table with UTF-8 content");
{   ok (my $csv = Text::CSV_XS->new ({ binary => 1, eol => "\n" }), "New csv");
    ok (open (my $fh, ">:utf8", "output/$tbl.csv"), "Open CSV");
    ok ($csv->print ($fh, [ "id", "str" ]), "CSV print header");
    ok ($csv->print ($fh, [ $_, $data[$_ - 1] ]), "CSV row $_") for 1 .. scalar @data;
    ok (close ($fh), "close");
    }

{   $dbh->{f_encoding} = undef;

    my $row;

    ok (my $sth = $dbh->prepare ("select * from $tbl"), "prepare");
    ok ($sth->execute,				"execute");
    foreach my $i (1 .. scalar @data) {
	ok ($row = $sth->fetch,			"fetch $i");
	is_deeply ($row, [ $i , encode ("utf8", $data[$i - 1]) ],	"unencoded content $i");
	}
    ok ($sth->finish,				"finish");
    undef $sth;
    }

{   $dbh->{f_encoding} = "utf8";

    my $row;

    ok (my $sth = $dbh->prepare ("select * from $tbl"), "prepare");
    ok ($sth->execute,				"execute");
    foreach my $i (1 .. scalar @data) {
	ok ($row = $sth->fetch,			"fetch $i");
	is_deeply ($row, [ $i , $data[$i - 1] ],	"encoded content $i");
	}
    ok ($sth->finish,				"finish");
    undef $sth;
    }

ok ($dbh->do ("drop table $tbl"),		"drop table");
ok ($dbh->disconnect,				"disconnect");
