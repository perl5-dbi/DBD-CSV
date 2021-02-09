use strict;
use warnings;
use DBI;

my $tbl = shift || "foo";

# See "Creating database handle" below
my $dbh = DBI->connect ("dbi:CSV:", undef, undef, {
    f_ext      => ".csv/r",
    RaiseError => 1,
    PrintError => 1,
    csv_class  => "Text::CSV",
    }) or die "Cannot connect: $DBI::errstr";
$dbh->do ("CREATE TABLE $tbl (id INTEGER, name CHAR (10))");
