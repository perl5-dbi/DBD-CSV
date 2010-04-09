#!/pro/bin/perl

use strict;
use warnings;

use charnames ":alias" => ":pro";
use Text::CSV_XS;
use Data::Peek;
use DBI;

my $csv = Text::CSV_XS->new ({ binary => 1, auto_diag => 1, eol => "\n" });

open my $fh, ">:utf8", "xutf8.csv" or die "xutf8: $!";
$csv->print ($fh, [ "c_foo", "fo\N{o_SLASH}", "r\N{e_ACUTE}mark", "sn\N{SNOWMAN}wman", "tail" ]);
$csv->print ($fh, [ 1, "foo", "remark", "snowman", 1 ]);
close $fh;

my $dbh = DBI->connect ("dbi:CSV:", undef, undef, {
    f_ext	=> ".csv/r",
    f_dir	=> ".",
    f_schema	=> undef,

    PrintError	=> 1,
    RaiseError	=> 1,
    });

my $sth = $dbh->prepare ("select * from xutf8");
   $sth->execute;

binmode STDOUT, ":utf8";
DDumper $sth->{NAME};

unlink "xutf8.csv";
