#!/pro/bin/perl

use strict;
use warnings;
use DBI;

my $dir = ".";
my $eol = "\n";
my $sep = ",";

my $dbh_match = DBI->connect ("dbi:CSV:", undef, undef, {
    f_dir        => $dir,
    f_ext        => ".csv/r",
    csv_eol      => $eol,
    csv_sep_char => $sep,
    RaiseError   => 1,
    PrintError   => 1,
    }) or die "Cannot connect: " . $DBI::errstr;

print STDERR "Using perl           version $]\n";
print STDERR "Using DBI            version $DBI::VERSION\n";
print STDERR "Using DBD::File      version $DBD::File::VERSION\n";
print STDERR "Using SQL::Statement version $SQL::Statement::VERSION\n";
print STDERR "Using Text::CSV_XS   version $Text::CSV_XS::VERSION\n";

unlink "new.csv";
my $sth_match = $dbh_match->prepare (qq;
    CREATE TABLE new AS SELECT file_01.Prefix, file_01.NumberRange, 
    file_02.Termination, file_02.Service, file_02.ChargeBand
    FROM file_01 INNER JOIN file_02
    ON file_01.Chargeband = file_02.ChargeBand
    WHERE file_02.Termination = 'end';
    );
$sth_match->execute or die "Cannot execute: " . $sth_match->errstr ();

DBI->trace (1);

$dbh_match->disconnect;
