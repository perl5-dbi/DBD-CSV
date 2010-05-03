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
    print STDERR "Check required and recommended module versions ...\n";
    BEGIN { $V::NO_EXIT = $V::NO_EXIT = 1 } require V;
    my %vsn = map { m/^\s*([\w:]+):\s+([0-9.]+)$/ ? ($1, $2) : () } @yml;
    delete @vsn{qw( perl version )};
    for (sort keys %vsn) {
	$vsn{$_} eq "0" and next;
	my $v = V::get_version ($_);
	$v eq $vsn{$_} and next;
	printf STDERR "%-35s %-6s => %s\n", $_, $vsn{$_}, $v;
	}
    if (open my $bh, "<", "lib/Bundle/DBD/CSV.pm") {
	print STDERR "Check bundle module versions ...\n";
	while (<$bh>) {
	    my ($m, $dv) = m/^([A-Za-z_:]+)\s+([0-9.]+)\s*$/ or next;
	    my $v = $m eq "DBD::CSV" ? $version : V::get_version ($m);
	    $v eq $dv and next;
	    printf STDERR "%-35s %-6s => %s\n", $m, $dv, $v;
	    }
	}

    print STDERR "Checking generated YAML ...\n";
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

    my $reqvsn = $h->{requires}{perl};
    print "Checking if $reqvsn is still OK as minimal version for examples\n";
    use Test::MinimumVersion;
    # All other minimum version checks done in xt
    all_minimum_version_ok ($reqvsn, { paths => [ "t", "lib" ]});
    }
elsif ($opt_v) {
    print @yml;
    }
else {
    my @my = glob <*/META.yml>;
    @my == 1 && open my $my, ">", $my[0] or die "Cannot update META.yml\n";
    print $my @yml;
    close $my;
    chmod 0644, glob <*/META.yml>;
    }

__END__
--- #YAML:1.0
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
    perl:                5.008001
    DBI:                 1.00
    DBD::File:           0.38
    SQL::Statement:      1.25
    Text::CSV_XS:        0.71
configure_requires:
    ExtUtils::MakeMaker: 0
build_requires:
    perl:                5.008001
    Config:              0
    Test::Harness:       0
    Test::More:          0
    Encode:              0
    charnames:           0
recommends:     
    perl:                5.012000
    Text::CSV_XS:        0.73
    SQL::Statement:      1.26
    DBI:                 1.611
installdirs:             site
resources:
    license:             http://dev.perl.org/licenses/
    repository:          http://repo.or.cz/r/DBD-CSV.git
meta-spec:
    version:             1.4
    url:                 http://module-build.sourceforge.net/META-spec-v1.4.html
