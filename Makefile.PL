# -*- perl -*-

require 5.004;
use strict;
use vars qw($DBI_INC_DIR);

require ExtUtils::MakeMaker;

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
  ( 'NAME' => 'DBD::CSV',
    'VERSION_FROM' => 'lib/DBD/CSV.pm',
    'dist'         => { 'SUFFIX'       => ".gz",
			'DIST_DEFAULT' => 'all tardist',
			'COMPRESS'     => "gzip -9vf" }
  );

if ($ExtUtils::MakeMaker::VERSION >= 5.43) {
  $opts{'ABSTRACT_FROM'} = 'lib/DBD/CSV.pm';
  $opts{'AUTHOR'} = 'Jeff Zucker (jeff@vpservices.com)';
  $opts{'PREREQ_PM'} =
    { 'DBI' => '1.00',
      'Text::CSV_XS' => '0.16',
      'SQL::Statement' => '0.1011'
    };
}

ExtUtils::MakeMaker::WriteMakefile(%opts);


package MY;

#sub postamble {
#    "\npm_to_blib: README\n" .
#    "\nREADME: lib/DBD/CSV.pm" .
#    "\n\tperldoc -t lib/DBD/CSV.pm >README\n\n"
#}

sub libscan {
    my($self, $path) = @_;
    ($path =~ /\~$/) ? undef : $path;
}
