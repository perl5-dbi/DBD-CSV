#!/pro/bin/perl

use strict;
use DBI;

my $dbh = DBI->connect ($ENV{DBI_DSN}, undef, undef, {
    RaiseError => 1,
    PrintError => 1,
#   AutoCommit => 0,
    }) or die;

$dbh->do ("create table type_123 (i integer, c char (1), v varchar (2))");
$dbh->commit;

my $sth = $dbh->prepare ("select i, c, v from type_123");
$sth->execute;

sub type {
    my $type = shift;
    my $tpi = $dbh->type_info ($type) or return ($type, "-");
    return ($type, $tpi->{TYPE_NAME});
    } # type

printf "INTEGER TYPE : %-10s - %s\n", type ($sth->{TYPE}[0]);
printf "CHAR    TYPE : %-10s - %s\n", type ($sth->{TYPE}[1]);
printf "VARCHAR TYPE : %-10s - %s\n", type ($sth->{TYPE}[2]);

$sth->finish;
undef $sth;

$dbh->do ("drop table type_123");
$dbh->commit;

__END__

$ env DBI_DSN=dbi:Unify:  perl type.pl
INTEGER TYPE : 2          - NUMERIC
CHAR    TYPE : 1          - CHAR
$ env DBI_DSN=dbi:Pg:     perl type.pl
INTEGER TYPE : 4          - int4
CHAR    TYPE : 1          - bpchar
VARCHAR TYPE : 12         - text
$ env DBI_DSN=dbi:mysql:  perl type.pl
INTEGER TYPE : 4          - integer
CHAR    TYPE : 1          - char
VARCHAR TYPE : 12         - varchar
$ env DBI_DSN=dbi:SQLite: perl type.pl
INTEGER TYPE : integer    - -
CHAR    TYPE : char (1)   - -
VARCHAR TYPE : varchar (2) - -
$ env DBI_DSN=dbi:CSV:    perl type.pl
INTEGER TYPE : 4          - INTEGER
CHAR    TYPE : 1          - CHAR
VARCHAR TYPE : 12         - VARCHAR
$ env DBI_DSN=dbi:Oracle: perl type.pl
INTEGER TYPE : 3          - DECIMAL
CHAR    TYPE : 1          - CHAR
VARCHAR TYPE : 12         - VARCHAR2

