# -*- perl -*-

require 5.004;
use strict;
use vars qw($DBI_INC_DIR);

require ExtUtils::MakeMaker;


my($ok) = 1;
print "Checking for DBI, 0.93 or later ... ";
$@ = '';
eval "use DBI 0.93 (); require DBI::DBD;";
if ($@) {
    $ok = 0;
    print("\nYou don't have installed the DBI module, version 0.93 or",
	  "later.\n");
} else {
    print "ok\n";
}

print "Checking for Text::CSV_XS, 0.12 or later ... ";
$@ = '';
eval "use Text::CSV_XS 0.12 ();";
if ($@) {
    $ok = 0;
    print("\nYou don't have installed the Text::CSV_XS module, version 0.10",
          " or later.\n");
} else {
    print "ok\n";
}

print "Checking for SQL::Statement, 0.1003 or later ... ";
$@ = '';
eval "use SQL::Statement 0.1003 ();";
if ($@) {
    $ok = 0;
    print("\nYou don't have installed the SQL::Statement module, version",
	  " 0.1003 or later.\n");
} else {
    print "ok\n";
}

if (!$ok) {
    print("\n",
	  "Missing modules are available from any CPAN mirror, for example\n",
	  "\tftp://ftp.funet.fi/pub/languages/perl/CPAN/modules/by-module\n",
	  "\n");
}


my($dir);
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


ExtUtils::MakeMaker::WriteMakefile(
    'NAME' => 'DBD::CSV',
    'VERSION_FROM' => 'CSV.pm',
     'dist'         => { 'SUFFIX'       => ".gz",
			 'DIST_DEFAULT' => 'all tardist',
			 'COMPRESS'     => "gzip -9f" },
);


package MY;

sub postamble {
    "\npm_to_blib: README\n" .
    "\nREADME: CSV.pm" .
    "\n\tperldoc -t CSV.pm >README\n\n"
}
