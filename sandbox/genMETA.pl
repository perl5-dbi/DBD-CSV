#!/pro/bin/perl

use strict;
use warnings;

use Getopt::Long qw(:config bundling nopermute);
my $check = 0;
my $opt_v = 0;
GetOptions (
    "c|check"		=> \$check,
    "v|verbose:1"	=> \$opt_v,
    ) or die "usage: $0 [--check]\n";

use lib "sandbox";
use genMETA;
my $meta = genMETA->new (
    from    => "lib/DBD/CSV.pm",
    verbose => $opt_v,
    );

$meta->from_data (<DATA>);

if ($check) {
    $meta->check_encoding ();
    $meta->check_required ();
    $meta->check_minimum ([ "t", "lib" ]);
    }
elsif ($opt_v) {
    $meta->print_yaml ();
    }
else {
    $meta->fix_meta ();
    }

__END__
--- #YAML:1.0
name:                    DBD-CSV
version:                 VERSION
abstract:                DBI driver for CSV files
license:                 perl
author:
    - Jochen Wiedmann
    - Jeff Zucker
    - H.Merijn Brand <h.m.brand@xs4all.nl>
    - Jens Rehsack
generated_by:            Author
distribution_type:       module
provides:
    DBD::CSV:
        file:            lib/DBD/CSV.pm
        version:         VERSION
requires:
    perl:                5.008001
    DBI:                 1.614
    DBD::File:           0.40
    SQL::Statement:      1.33
    Text::CSV_XS:        0.71
configure_requires:
    ExtUtils::MakeMaker: 0
build_requires:
    Config:              0
test_requires:
    Test::Harness:       0
    Test::More:          0.90
    Encode:              0
    Cwd:                 0
    charnames:           0
recommends:
    perl:                5.014002
    DBI:                 1.617
    Text::CSV_XS:        0.85
    Test::More:          0.98
installdirs:             site
resources:
    license:             http://dev.perl.org/licenses/
    repository:          http://repo.or.cz/w/DBD-CSV.git
meta-spec:
    version:             1.4
    url:                 http://module-build.sourceforge.net/META-spec-v1.4.html
