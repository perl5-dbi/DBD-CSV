#!/pro/bin/perl

use strict;
use warnings;

use DBI;

my $dbh = DBI->connect ("dbi:CSV:", undef, undef, {
    PrintError		=> 1,
    RaiseError		=> 1,

    f_ext		=> ".csv/r",

    csv_sep_char	=> "|",
    }) or die $DBI::errstr;

my $sth = $dbh->prepare ("select * from pipes");
   $sth->execute;
   $sth->bind_columns (\my ($status, $quant));
while ($sth->fetch) {
    print "$status - $quant\n";
    }
