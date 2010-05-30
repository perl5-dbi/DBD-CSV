#!/pro/bin/perl

use strict;
use warnings;
use autodie;
use charnames ":full";

sub usage
{
    my $err = shift and select STDERR;
    print "usage: $0 [--dbi]\n";
    exit $err;
    } # usage

use Getopt::Long qw(:config bundling nopermute);
my $use_dbi = 0;
GetOptions (
    "help|?"		=> sub { usage (0); },

    "d|dbi|use-dbi"	=> \$use_dbi,
    ) or usage (1);

my @data = ("",
    "The \N{SNOWMAN} is melting",
    "U2 should \N{SKULL AND CROSSBONES}",
    "I \N{BLACK HEART SUIT} my wife",
    "Unicode makes me \N{WHITE SMILING FACE}",
    );

unlink "utf8foo.csv";

if ($use_dbi) {
    use DBI;

    my $dbh = DBI->connect ("dbi:CSV:", undef, undef, {
	f_schema	=> undef,
	f_dir		=> ".",
	f_ext		=> ".csv/r",
	f_lock		=> 2,
	f_encoding	=> "utf8",

	csv_null	=> 1,

	RaiseError	=> 1,
	PrintError	=> 1,
	});

    $dbh->do ("create table utf8foo (c_foo integer, foo char (200))");
    my $sth = $dbh->prepare ("insert into utf8foo values (?, ?)");
    $sth->execute ($_, $data[$_]) for 1 .. $#data;
    $sth->finish;
    $dbh->disconnect;
    }
else {
    use Text::CSV_XS;

    my $csv = Text::CSV_XS->new ({
	binary		=> 1,
	eol		=> "\r\n",
	always_quote	=> 1,
	});

    open my $fh, ">:utf8", "utf8foo.csv";
    $csv->print ($fh, [ "c_foo", "foo" ]);
    $csv->print ($fh, [ $_, $data[$_] ]) for 1 .. $#data;
    close $fh
    }
