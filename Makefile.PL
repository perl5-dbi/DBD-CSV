# -*- perl -*-

# Copyright (c) 2009-2013 H.Merijn Brand

require 5.008001;

use strict;

use ExtUtils::MakeMaker;

eval { require DBD::CSV; };
if (!$@ && $DBD::CSV::VERSION < 0.1010) {
    print <<'MSG';

WARNING! You seem to have installed a recent version of the DBD::CSV module.
Note that the API (in particular attribute names) has changed, to conform to
the DBI specifications. For example $dbh->{directory} has been renamed to
$dbh->{f_dir} and $dbh->{eol}, $dbh->{quote_char}, ... are gone in favour of
$dbh->{tables}{$table}{csv}, which is used for storing meta information. You
might need to modify existing sources before doing a "make install". See the
README for details.

MSG
    sleep 5;
    };

use vars qw( $DBI_INC_DIR );

my %wm = (
    NAME         => "DBD::CSV",
    DISTNAME     => "DBD-CSV",
    ABSTRACT     => "DBI driver for CSV and similar structured files",
    AUTHOR       => "H.Merijn Brand <h.merijn\@xs4all.nl>",
    VERSION_FROM => "lib/DBD/CSV.pm",
    PREREQ_PM    => {
	"DBI"            => 1.628,
	"DBD::File"      => 0.42,
	"Text::CSV_XS"   => 1.01,
	"SQL::Statement" => 1.405,
	"Test::More"     => 0.90,
	"Encode"         => 0,
	"charnames"      => 0,
	},
    clean        => {
	FILES => join " ", qw(
	    output
	    cover_db
	    valgrind.log
	    )
	},
    macro        => {
	TARFLAGS => "--format=ustar -c -v -f",
	},
    );
$ExtUtils::MakeMaker::VERSION > 6.30 and $wm{LICENSE} = "perl";

eval "use DBI::Test::Conf ();";
if ($@) {
    warn "******\n",
         "******\tDBI::Test is not installed.\n",
         "******\tIt will be required in one of the upcoming releases.\n",
         "******\n";
    }
else {
    local $" = " ";
    $wm{PREREQ_PM}{"DBI::Test"} = "0.001";
    my @new_tests = join " " => DBI::Test::Conf->setup ();
    $wm{test} = { TESTS => join " " =>
	(sort glob "t/*.t"), @new_tests, };
    $wm{clean}{FILES} .= " @new_tests";
    }

my $rv = WriteMakefile (%wm);

1;

package MY;

sub postamble
{
    my $min_vsn = ($] >= 5.010 && -d "xt" && ($ENV{AUTOMATED_TESTING} || 0) != 1)
	? join "\n" =>
	    'test ::',
	    '	-@env DBI_SQL_NANO=1 TEST_FILES="t/[012367]*.t t/4[038]*.t t/5[05]*.t t/85*.t" make -e test_dynamic',
	    '',
	    'test ::',
	    '	-@env TEST_FILES="xt/*.t" make -e test_dynamic',
	    ''
	: "";
    join "\n" =>
	'cover test_cover:',
	'	cover -test',
	'',
	'spellcheck:',
	'	pod-spell-check --aspell',
	'',
	'checkmeta:	spellcheck',
	'	perl sandbox/genMETA.pl -c',
	'',
	'fixmeta:	distmeta',
	'	perl sandbox/genMETA.pl',
	'',
	'tgzdist:	checkmeta fixmeta $(DISTVNAME).tar.gz distcheck',
	'	-@mv -f $(DISTVNAME).tar.gz $(DISTVNAME).tgz',
	'	-@cpants_lint.pl $(DISTVNAME).tgz',
	'	-@rm -f Debian_CPANTS.txt',
	'',
	$min_vsn;
    } # postamble
