package DBI::Test::Case::DBD::CSV::blarf;

use strict;
use warnings;

use parent qw( DBI::Test::DBD::CSV::Case);

use Test::More;
use DBI::Test;

sub supported_variant
{
    my ($self,    $test_case, $cfg_pfx, $test_confs,
	$dsn_pfx, $dsn_cred,  $options) = @_;

    #use DP;DDumper$test_confs;
    #scalar grep { $_->{abbrev} eq "g" } @$test_confs and return;
    return $self->SUPER::supported_variant ($test_case, $cfg_pfx, $test_confs,
	$dsn_pfx, $dsn_cred, $options);
    } # supported_variant

#foreach my $test_dbd (@test_dbds)
sub run_test
{
    my @DB_CREDS = @{$_[1]};

    # note ("Running tests for $test_dbd");

    # Test RaiseError for prepare errors
    #
    $DB_CREDS[3]->{PrintError} = 0;
    $DB_CREDS[3]->{RaiseError} = 0;
    my $dbh = connect_ok (@DB_CREDS, "Connect with dbi:CSV:");

    ok ($dbh, "DBH created");

    done_testing ();
    }

1;
