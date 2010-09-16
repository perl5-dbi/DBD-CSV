#!/pro/bin/perl

use strict;
use warnings;
use autodie;
use Data::Peek;
use DBI;

my $dbh = DBI->connect ("dbi:CSV:", undef, undef, {
    PrintError	=> 1,
    RaiseError	=> 1,
    f_ext	=> ".csv/r",
    sep_char	=> ";",
    }) or die "Connection failed with error: $DBI::errstr";

DDumper {
    "DBI"		=> $DBI::VERSION,
    "DBD::CSV"		=> $DBD::CSV::VERSION,
    "Text::CSV_XS"	=> $Text::CSV_XS::VERSION,
    "SQL::Statement"	=> $SQL::Statement::VERSION,
    };

$dbh->{csv_tables}{csv_data}{file}		= "/tmp/test.csv";
$dbh->{csv_tables}{csv_data}{csv_sep_char}	= ";";

DDumper $dbh->{csv_tables}{csv_data};

my $sth = $dbh->prepare ("select * from csv_data");
$sth->execute;
while (my $r = $sth->fetchrow_hashref) {
    DDumper $r;
    }
