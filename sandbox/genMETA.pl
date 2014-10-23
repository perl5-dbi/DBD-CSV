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
    $meta->done_testing ();
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
    - Jens Rehsack <rehsack@cpan.org>
generated_by:            Author
distribution_type:       module
provides:
    DBD::CSV:
        file:            lib/DBD/CSV.pm
        version:         VERSION
requires:
    perl:                5.008001
    DBI:                 1.628
    DBD::File:           0.42
    SQL::Statement:      1.405
    Text::CSV_XS:        1.01
recommends:
    perl:                5.020000
    DBI:                 1.631
    Text::CSV_XS:        1.11
configure_requires:
    ExtUtils::MakeMaker: 0
    DBI:                 1.628
build_requires:
    Config:              0
test_requires:
    Test::Harness:       0
    Test::More:          0.90
    Encode:              0
    Cwd:                 0
    charnames:           0
test_recommends:
    Test::More:          1.001008
installdirs:             site
resources:
    license:             http://dev.perl.org/licenses/
    repository:          https://github.com/perl5-dbi/DBD-CSV.git
meta-spec:
    version:             1.4
    url:                 http://module-build.sourceforge.net/META-spec-v1.4.html
