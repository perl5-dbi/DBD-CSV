#!/pro/bin/perl

use strict;
use warnings;

use DBI;
my $dbh=DBI->connect ("dbi:CSV:", undef, undef, {
    f_ext		=> ".csv/r",
    f_dir		=> ".",
    f_schema		=> undef,
    RaiseError		=> 1,
    PrintError		=> 1,
    AutoCommit		=> 1,
    ChopBlanks		=> 1,
    ShowErrorStatement	=> 1,
    FetchHashKeyName	=> "NAME_lc",
    });
my $AoA =[
    [ "number", "name", "sex", "age" ],
    [ 0,        "Jack",  "M",   28   ],
    [ 1,        "Marry", "F",   29   ],
    ];
$dbh->do ("CREATE TABLE worksheet AS IMPORT(?)", {}, $AoA);
