#!/pro/bin/perl

use strict;
use warnings;

use DBI;
use Data::Peek;

my $dbh = DBI->connect ("dbi:CSV:", undef, undef, {
    f_ext		=> ".csv/r",
    f_dir		=> "sandbox",
    f_schema		=> undef,

    csv_quote_char	=> "'",

    RaiseError		=> 1,
    PrintError		=> 1,
    AutoCommit		=> 1,
    ChopBlanks		=> 1,
    ShowErrorStatement	=> 1,
    FetchHashKeyName	=> "NAME_lc",
    });

print STDERR "using DBI-$DBI::VERSION + DBD::CSV-$DBD::CSV::VERSION\n";
my $sth = $dbh->prepare ("select distinct applname from test where nodename = 'byjk01'");
$sth->execute;
DDumper $sth->fetchall_arrayref;
