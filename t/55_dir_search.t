#!/pro/bin/perl

use strict;
use warnings;

use Cwd;
use Test::More;

my $pwd = getcwd;

use DBI;
use Data::Peek;

my $dbh = DBI->connect ("dbi:CSV:", undef, undef, {
    f_schema         => undef,
    f_dir            => "tmp",
    f_dir_search     => [ "sandbox", "/tmp" ],
    f_ext            => ".csv/r",
    f_lock           => 2,
    f_encoding       => "utf8",

    RaiseError       => 1,
    PrintError       => 1,
    FetchHashKeyName => "NAME_lc",
    }) or die "$DBI::errstr\n";

my @dsn = $dbh->data_sources;
my %dir = map { m{^dbi:CSV:.*\bf_dir=([^;]+)}i; ($1 => 1) } @dsn;

is ($dir{$_}, 1, "DSN for $_") for $pwd."/tmp", qw( sandbox /tmp );

my %tbl = map { $_ => 1 } $dbh->tables (undef, undef, undef, undef);

is ($tbl{$_}, 1, "Table $_ found") for qw( tmp foo test rt50788 rt31395 rt51090 );

my %data = (
    tmp => {		# tmp/tmp.csv
	1 => "ape",
	2 => "monkey",
	3 => "gorilla",
	},
    foo => {		# sandbox/foo.csv
	1 => "boo",
	2 => 1,
	3 => 1,
	},
    );
foreach my $tbl ("tmp", "foo") {
    my $sth = $dbh->prepare ("select * from $tbl");
    $sth->execute;
    while (my $row = $sth->fetch) {
	is ($row->[1], $data{$tbl}{$row->[0]}, "$tbl ($row->[0], ...)");
	}
    }

done_testing;
