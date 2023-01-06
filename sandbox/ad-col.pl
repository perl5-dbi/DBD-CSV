#!/pro/bin/perl

use 5.012000;
use warnings;
use autodie;

use DBI;

my $dbh = DBI->connect ("dbi:CSV:", undef, undef, {
    f_ext       => ".csv/r",
    f_dir       => ".",
    f_schema    => undef,

    PrintError  => 1,
    RaiseError  => 1,
    });

my $sth;
$sth = $dbh->prepare ("select * from foo");
say for @{$sth->{NAME_lc}};

$dbh->do ("alter table foo add column (test numeric (7))");

$sth = $dbh->prepare ("select * from foo");
say for @{$sth->{NAME_lc}};
