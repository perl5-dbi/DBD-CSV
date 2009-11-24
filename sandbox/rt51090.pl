#!/pro/bin/perl

use strict;
use warnings;

local $\ = "\n";

use DBI qw(:sql_types);

my $dbh = DBI->connect ("dbi:CSV:", undef, undef, {
    f_schema		=> undef,
    f_ext		=> ".csv/r",
    csv_sep_char	=> "\t",
    });

my $sth = $dbh->prepare (q{SELECT * FROM rt51090});

$dbh->{csv_tables}{rt51090}{types} = [SQL_INTEGER, SQL_LONGVARCHAR, SQL_NUMERIC];
print join "\t", @{$dbh->{csv_tables}{rt51090}{types}};

$sth->execute ();
print join "\t", @{$dbh->{csv_tables}{rt51090}{types}};

$dbh->disconnect ();
