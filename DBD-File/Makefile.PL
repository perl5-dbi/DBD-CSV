# -*- perl -*-

require 5.004;
use strict;
use vars qw($DBI_INC_DIR);


require ExtUtils::MakeMaker;

if (!defined($DBI_INC_DIR)) {
    my $dir;
    foreach $dir (@INC) {
	if (-f "$dir/auto/DBI/DBIXS.h") {
	    $DBI_INC_DIR = "-I$dir/auto/DBI";
	}
    }
    if (!defined($DBI_INC_DIR)) {
	die "Unable to determine location of DBI headers.";
    }
}

ExtUtils::MakeMaker::WriteMakefile(
    'NAME' => 'DBD::File',
    'VERSION_FROM' => 'File.pm',
    'INC' => $DBI_INC_DIR,
);
