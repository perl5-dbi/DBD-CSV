# -*- perl -*-

require 5.004;
use strict;
use vars qw($DBI_INC_DIR);

require ExtUtils::MakeMaker;


my %prereq;
sub CheckModule ($$;$) {
    my($module, $version, $package) = @_;
    $package ||= $module;
    $prereq{$module} = $version || 0;
    if ($version) {
	print "Checking for $package, $version or later ... ";
	eval "use $module $version";
	if ($@) {
	    print("\nYou don't have installed the $package package,",
		  " version $version or later.\n");
	    return 0;
	}
    } else {
	print "Checking for $package ... ";
	eval "use $module";
	if ($@) {
	    print("\nYou don't have installed the $package package.\n");
	    return 0;
	}
    }
    print "ok\n";
    return 1;
}


my $ok = 1;
$ok &&= CheckModule('DBI', '1.00');
$ok &&= CheckModule('Text::CSV_XS', '0.16');
$ok &&= CheckModule('SQL::Statement', '0.1006');

if (!$ok) {
    print("\n",
	  "Missing modules are available from any CPAN mirror, for example\n",
	  "\tftp://ftp.funet.fi/pub/languages/perl/CPAN/modules/by-module\n",
	  "\n");
}

my $dir;
eval { require DBI::DBD };
foreach $dir (@INC) {
    if (-f "$dir/auto/DBI/DBIXS.h") {
	$DBI_INC_DIR = "-I$dir/auto/DBI";
	last;
    }
}
if (!defined($DBI_INC_DIR)) {
    print "Unable to locate auto/DBI/DBIXS.h in the following directories:\n";
    print "\n";
    foreach $dir (@INC) {
	print "    $dir\n";
    }
    print "\nDoesn't look like a correct DBI installation.\n";
    $ok = 0;
}

if (!$ok) {
    exit(0);
}


eval {
    require DBD::CSV;
    if ($DBD::CSV::VERSION < 0.1010) {
	print <<END_OF_WARNING;

WARNING! You seem to have installed a recent version of the DBD::CSV module.
Note that the API (in particular attribute names) has changed, to conform
to the DBI specifications. For example \$dbh->{directory} has been renamed
to \$dbh->{f_dir} and \$dbh->{eol}, \$dbh->{quote_char}, ... are gone in
favour of \$dbh->{tables}->{\$table}->{csv}, which is used for storing
meta information. You might need to modify existing sources before doing a
"make install". See the README for details.

END_OF_WARNING
    }
};


my %opts =
    ('NAME' => 'DBD::CSV',
     'VERSION_FROM' => 'lib/DBD/CSV.pm',
     'dist'         => { 'SUFFIX'       => ".gz",
			 'DIST_DEFAULT' => 'all tardist',
			 'COMPRESS'     => "gzip -9vf" }
     );

if ($ExtUtils::MakeMaker::VERSION >= 5.43) {
    $opts{'ABSTRACT_FROM'} = 'lib/DBD/CSV.pm';
    $opts{'AUTHOR'} = 'Jochen Wiedmann (joe@ispsoft.de)';
    $opts{'PREREQ_PM'} = \%prereq;
}

ExtUtils::MakeMaker::WriteMakefile(%opts);


package MY;

sub postamble {
    "\npm_to_blib: README\n" .
    "\nREADME: lib/DBD/CSV.pm" .
    "\n\tperldoc -t lib/DBD/CSV.pm >README\n\n"
}

sub libscan {
    my($self, $path) = @_;
    ($path =~ /\~$/) ? undef : $path;
}
