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

my $version;
open my $pm, "<", "lib/DBD/CSV.pm" or die "Cannot read CSV.pm";
while (<$pm>) {
    m/^.VERSION\s*=\s*"?([-0-9._]+)"?\s*;\s*$/ or next;
    $version = $1;
    last;
    }
close $pm;

my @yml;
while (<DATA>) {
    s/VERSION/$version/o;
    push @yml, $_;
    }

if ($check) {
    use YAML::Syck;
    use Test::YAML::Meta::Version;
    my $h;
    my $yml = join "", @yml;
    eval { $h = Load ($yml) };
    $@ and die "$@\n";
    $opt_v and print Dump $h;
    my $t = Test::YAML::Meta::Version->new (yaml => $h);
    $t->parse () and die join "\n", $t->errors, "";

    use Parse::CPAN::Meta;
    eval { Parse::CPAN::Meta::Load ($yml) };
    $@ and die "$@\n";

    print "Checking if 5.005 is still OK as minimal version for examples\n";
    use Test::MinimumVersion;
    # All other minimum version checks done in xt
    all_minimum_version_ok ("5.005", { paths => [ "t", "lib" ]});
    }
elsif ($opt_v) {
    print @yml;
    }
else {
    my @my = glob <*/META.yml>;
    @my == 1 && open my $my, ">", $my[0] or die "Cannot update META.yml|n";
    print $my @yml;
    close $my;
    chmod 0644, glob <*/META.yml>;
    }

__END__
--- #YAML:1.1
name:                    DBD::CSV
version:                 VERSION
abstract:                DBI driver for CSV files
license:                 perl
author:              
    - Jochen Wiedmann
    - Jeff Zucker
    - H.Merijn Brand <h.m.brand@xs4all.nl>
generated_by:            Author
distribution_type:       module
provides:
    DBD::CSV:
        file:            lib/DBD/CSV.pm
        version:         VERSION
requires:     
    perl:                5.005
    DBI:                 1.00
    DBD::File:           0.36
    SQL::Statement:      0.1011
    Text::CSV_XS:        0.43
recommends:     
    perl:                5.008005
    Text::CSV_XS:        0.64
configure_requires:
    ExtUtils::MakeMaker: 0
build_requires:
    perl:                5.005
    Config:              0
    Test::Harness:       0
    Test::More:          0
installdirs:             site
resources:
    license:             http://dev.perl.org/licenses/
    repository:          http://repo.or.cz/w/DBD-CSV.git
meta-spec:
    version:             1.4
    url:                 http://module-build.sourceforge.net/META-spec-v1.4.html
