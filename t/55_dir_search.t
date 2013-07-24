#!/pro/bin/perl

use strict;
use warnings;

use Cwd;
use Test::More;

my $pwd = getcwd;

BEGIN { use_ok ("DBI") }
require "t/lib.pl";

my $root_temp = $^O eq "MSWin32" ? "C:/" : "/tmp";
my $dbh = DBI->connect ("dbi:CSV:", undef, undef, {
    f_schema         => undef,
    f_dir            => DbDir (),
    f_dir_search     => [ "t", $root_temp ],
    f_ext            => ".csv/r",
    f_lock           => 2,
    f_encoding       => "utf8",

    RaiseError       => 1,
    PrintError       => 1,
    FetchHashKeyName => "NAME_lc",
    }) or die "$DBI::errstr\n";

my @dsn = $dbh->data_sources;
my %dir = map {
    m{^dbi:CSV:.*\bf_dir=([^;]+)}i;
    my $folder = $1;
    # Unixify Windows paths
    $folder =~ s{^([A-Z])\\?:}{$1:};
    $folder =~ s{\\+}{/}g;
    ($folder => 1);
    } @dsn;

# Use $test_dir
$dbh->do ("create table foo (c_foo integer, foo char (1))");
$dbh->do ("insert into foo values ($_, $_)") for 1, 2, 3;

my @test_dirs = ($pwd."/output", "t");
$^O eq "VMS" or push @test_dirs, $root_temp;
is ($dir{$_}, 1, "DSN for $_") for @test_dirs;

my %tbl = map { $_ => 1 } $dbh->tables (undef, undef, undef, undef);

is ($tbl{$_}, 1, "Table $_ found") for qw( tmp foo );

my %data = (
    tmp => {		# t/tmp.csv
	1 => "ape",
	2 => "monkey",
	3 => "gorilla",
	},
    foo => {		# output/foo.csv
	1 => 1,
	2 => 2,
	3 => 3,
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
