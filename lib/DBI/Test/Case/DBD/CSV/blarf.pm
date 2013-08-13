package DBI::Test::Case::DBD::CSV::blarf;

use strict;
use warnings;

use parent qw( DBI::Test::DBD::CSV::Case);

use Test::More;
use DBI::Test;
use DBI;

sub supported_variant
{
    my ($self,    $test_case, $cfg_pfx, $test_confs,
	$dsn_pfx, $dsn_cred,  $options) = @_;

    #use DP;DDumper$test_confs;
    #use DP;DDumper{tc=>$test_case,cp=>$cfg_pfx,dp=>$dsn_pfx,op=>$options};
    $cfg_pfx =~ m/mvb/ and return;

    #scalar grep { $_->{abbrev} eq "g" } @$test_confs and return;
    return $self->SUPER::supported_variant ($test_case, $cfg_pfx, $test_confs,
	$dsn_pfx, $dsn_cred, $options);
    } # supported_variant

#foreach my $test_dbd (@test_dbds)
sub run_test
{
    my @DB_CREDS = @{$_[1]};

    # note ("Running tests for $test_dbd");

    do "t/lib.pl";

    my $nano = $ENV{DBI_SQL_NANO};
    unless (defined $nano) {
	$nano = "not set";
	eval "use SQL::Statement;";
	ok ($SQL::Statement::VERSION, "SQL::Statement::Version $SQL::Statement::VERSION");
	}
    diag ("Showing relevant versions (DBI_SQL_NANO = $nano)");
    diag ("Using DBI            version $DBI::VERSION");
    diag ("Using DBD::File      version $DBD::File::VERSION");
    diag ("Using SQL::Statement version $SQL::Statement::VERSION");
    diag ("Using Text::CSV_XS   version $Text::CSV_XS::VERSION");

    ok (my $switch = DBI->internal, "DBI->internal");
    is (ref $switch, "DBI::dr", "Driver class");

    # This is a special case. install_driver should not normally be used.
    ok (my $drh = DBI->install_driver ("CSV"), "Install driver");

    is (ref $drh, "DBI::dr", "Driver class installed");

    ok ($drh->{Version}, "Driver version $drh->{Version}");

    # Test RaiseError for prepare errors
    $DB_CREDS[3]->{PrintError} = 0;
    $DB_CREDS[3]->{RaiseError} = 0;
    my $dbh = connect_ok (@DB_CREDS, "Connect with dbi:CSV:");

    ok ($dbh, "DBH created");


    my $csv_version_info = $dbh->csv_versions ();
    ok ($csv_version_info, "csv_versions");
    diag ($csv_version_info);

    done_testing ();
    }

1;
