package DBI::Test::DBD::CSV::DSN::Provider::CSV;

use strict;
use warnings;

use parent qw(DBI::Test::DSN::Provider::Dir);

my %cvs_class_abbrev = (
    "Text::CSV_XS" => "x",
    "Text::CSV" => "p",
);

sub dsn_conf
{
    my ( $self, $test_case_ns ) = @_;

    my ( %variants, @csv_classes );
    # the following part only applies to tests which require extended tests
    # 
    # XXX maybe there should be additional restrictions, because it should be
    # possible to remove Text::CSV_XS variants in case of $ENV{DBI_PUREPERL}
    # or PUREPERL_ONLY on Makefile.PL/Build.PL.
    # 
    if ( $test_case_ns->can("requires_extended") and $test_case_ns->requires_extended )
    {
        # Potential CSV parser modules in preference order
        my @cvs_parsers = qw(Text::CSV_XS Text::CSV);
	my @use_cvs_parsers = qw(all);
	$ENV{DBD_CSV_TEST_CLASSES} and @use_cvs_parsers = split ' ', $ENV{DBD_CSV_TEST_CLASSES};

        if ( lc "@use_cvs_parsers" eq "all" )
        {
            @csv_classes = grep {
                eval { local $^W; (my $pm = $_) =~ s|::|/|g; require "${pm}.pm" }
            } @cvs_parsers;
        }
        else
        {
            @csv_classes = @use_cvs_parsers;
        }

        scalar(@csv_classes)
          and %{ $variants{variants}->{parser} } =
          map { $cvs_class_abbrev{$_} => { cvs_class => $_ } } @csv_classes;
    }

    "CSV" => {
               category   => "driver",
               cat_abbrev => "c",
               abbrev     => "c",
               driver     => "dbi:CSV:",
               name       => "DSN for DBD::CSV",
               %variants,
             };
}

1;
