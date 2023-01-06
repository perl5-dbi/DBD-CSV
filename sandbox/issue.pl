#!/pro/bin/perl

use 5.018002;
use warnings;
use Text::CSV_XS qw( csv );
use DBI;

my $tbl = "issue$$";

csv (out => "$tbl.csv", in => [
    [qw( c_issue issue color size )],
    [1,234,"Black",4],
    [2,345,"Red",8],
    [3,345,"Pink",8],
    [4,456,"White",16]]);

my $dbh = DBI->connect ("dbi:CSV:", undef, undef, {
    RaiseError		=> 1,
    PrintError		=> 1,
    ShowErrorStatement	=> 1,
    f_ext		=> ".csv/r",
    }) or die DBI->errstr;
my $sth = $dbh->prepare (qq;
    select   issue, count (*)
    from     $tbl
    group by issue
    having   count (*) > 1;
    );
$sth->execute;
while (my @row = $sth->fetchrow) {
    say "@row";
    }

END { unlink "$tbl.csv"; }
