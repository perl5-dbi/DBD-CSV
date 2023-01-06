#!/pro/bin/perl

use 5.014002;
use warnings;

use DBI;
use Data::Peek;

binmode STDERR, ":encoding(utf-8)";

my $dir = -d "sandbox" ? "sandbox" : ".";

my $dbh = DBI->connect ("dbi:CSV:", undef, undef, {
    f_ext		=> ".csv/r",
    f_dir		=> $dir,
    csv_null		=> 1,
    csv_sep_char	=> "|",
    csv_quote_char	=> undef,
    });

my $sth = $dbh->prepare (<<";");
select   *
from     rt121127
where    entry IS NOT NULL
    and  entry NOT LIKE '#%'
    and  band  LIKE ?
order by entry
;

$sth->execute ("Canberra Brass");
while (my $row = $sth->fetch) {
    DDumper $row;
    }
