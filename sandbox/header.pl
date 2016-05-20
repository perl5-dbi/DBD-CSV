#/pro/bin/perl

use 5.18.2;
use warnings;

use DBI;
use Data::Peek;

my $dbh = DBI->connect ("dbi:CSV:", undef, undef, {
    f_dir      => ".",
    f_ext      => ".csv",
    f_encoding => "utf-8",
    RaiseError => 1,
    }) or die $DBI::errstr;

my $sth = $dbh->prepare (qq(select * from header.csv));
$sth->execute;
say $dbh->{FetchHashKeyName};
DDumper $dbh->{csv_tables}{header}{col_names};
DDumper $sth->{NAME};
while (my $row = $sth->fetchrow_hashref) {
    DDumper $row;
    }
