# -*- perl -*-

require 5.004;
use strict;

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

print "Checking for Text::CSV_XS, 0.10 or later ... ";
$@ = '';
eval "use Text::CSV_XS 0.10 ();";
if ($@) {
    $ok = 0;
    print("\nYou don't have installed the Text::CSV_XS module, version 0.10",
          " or later.\n");
} else {
    print "ok\n";
}

print "Checking for SQL::Statement ... ";
$@ = '';
eval "use SQL::Statement ();";
if ($@) {
    $ok = 0;
    print "\nYou don't have installed the SQL::Statement module.\n";
} else {
    print "ok\n";
}

if (!$ok) {
    print("\n",
	  "Missing modules are available from any CPAN mirror, for example\n",
	  "\tftp://ftp.funet.fi/pub/languages/perl/CPAN/modules/by-module\n",
	  "\n");
}


my($dir, $inc);
foreach $dir (@INC) {
    if (-f "$dir/auto/DBI/DBIXS.h") {
	$inc = "-I$dir/auto/DBI";
    }
}
if (!defined($inc)) {
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


ExtUtils::MakeMaker::WriteMakefile(
    'NAME' => 'DBD::CSV',
    'VERSION_FROM' => 'CSV.pm',
    'INC' => $inc,
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
