#!/pro/bin/perl

use strict;
use warnings;

use Test::More;
use DBI;

my $dbh = DBI->connect ("dbi:CSV:", undef, undef, {
    f_ext => ".csv/r",
    PrintError	=> 1,
    RaiseError	=> 1,
    });
ok ($dbh, "Connected");

unlink "test.csv";

ok ($dbh->do ("create table test (c_test integer, test char (2))"), "create");
{   local @ARGV = ("test.csv");
    is_deeply ([<>], [
	"c_test,test\r\n",
	], "just a header");
    }

ok ($dbh->do ("insert into test values (0,'0')", "insert 0"));
{   local @ARGV = ("test.csv");
    is_deeply ([<>], [
	"c_test,test\r\n",
	"0,0\r\n",
	], "header + one line");
    }

ok ($dbh->do ("insert into test (c_test) values (1)", "insert 1"));
{   local @ARGV = ("test.csv");
    is_deeply ([<>], [
	"c_test,test\r\n",
	"0,0\r\n",
	"1,\r\n",
	], "header + two lines");
    }

unlink "test.csv";

done_testing ();
