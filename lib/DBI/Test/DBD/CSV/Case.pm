package DBI::Test::DBD::CSV::Case;

use strict;
use warnings;

use parent qw( DBI::Test::Case );
use Carp   qw( carp );

sub filter_drivers
{
    my ($self, $options, @test_dbds) = @_;
    return grep m{\b CSV \b}x => @test_dbds;
    } # filter_drivers

sub requires_extended { 0 }

sub supported_variant
{
    my ($self,    $test_case, $cfg_pfx, $test_confs,
	$dsn_pfx, $dsn_cred,  $options) = @_;

    if ($self->is_test_for_dbi ($test_confs)) {
	$dsn_cred  && $dsn_cred->[0] or return;
	(my $driver = $dsn_cred->[0]) =~
	    s/^dbi:(\w*?)(?:\((.*?)\))?:.*/DBD::$1/i;
	eval "require $driver;";
	$@ and return carp $@;
	$driver->isa ("DBD::File") and return 1;
	}

    return;
    } # supported_variant

1;
