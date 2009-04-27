#!/usr/bin/perl

# lib.pl is the file where database specific things should live,
# whereever possible. For example, you define certain constants
# here and the like.

#use strict;

use vars qw( $childPid );
use File::Spec;

my $test_dir      = File::Spec->catdir (File::Spec->curdir (), "output");
my $test_dsn      = $ENV{DBI_DSN}  || "DBI:CSV:f_dir=$test_dir";
my $test_user     = $ENV{DBI_USER} || "";
my $test_password = $ENV{DBI_PASS} || "";

sub COL_NULLABLE () { 1 }
sub COL_KEY      () { 2 }

my %v;
eval "require $_; \$v->{'$_'} = \$_::VERSION;" for qw(
    DBI SQL::Statement Text::CSV_XS DBD::CSV );

if ($@) {
    my @missing = grep { exists $v->{$_} } qw( DBI SQL CSV );
    print STDERR "\n\nYOU ARE MISSING REQUIRED MODULES: [ @missing ]\n\n";
    exit 0;
    }

sub AnsiTypeToDb
{
    my ($type, $size) = @_;
    my $uctype = uc $type;

    if ($uctype eq "CHAR" || $uctype eq "VARCHAR") {
	$size ||= 1;
	return "$uctype ($size)";
	}

    $uctype eq "BLOB" || $uctype eq "REAL" || $uctype eq "INTEGER" and
	return $uctype;
    
    $uctype eq "INT" and
	return "INTEGER";

    warn "Unknown type $type\n";
    return $type;
    } # AnsiTypeToDb

# This function generates a table definition based on an
# input list. The input list consists of references, each
# reference referring to a single column. The column
# reference consists of column name, type, size and a bitmask of
# certain flags, namely
#
#     COL_NULLABLE - true, if this column may contain NULL's
#     COL_KEY      - true, if this column is part of the table's
#                     primary key
#
# Hopefully there's no big need for you to modify this function,
# if your database conforms to ANSI specifications.

sub TableDefinition
{
    my ($tablename, @cols) = @_;

    my @keys = ();
    foreach my $col (@cols) {
	$col->[2] & COL_KEY and push @keys, $col->[0];
	}

    my @colDefs;
    foreach my $col (@cols) {
	my $colDef = $col->[0] . " " . AnsiTypeToDb ($col->[1], $col->[2]);
	$col->[3] & COL_NULLABLE or $colDef .= " NOT NULL";
	push @colDefs, $colDef;
	}
    my $keyDef = @keys ? ", PRIMARY KEY (" . join (", ", @keys) . ")" : "";
    return sprintf "CREATE TABLE %s (%s%s)", $tablename, join (", ", @colDefs), $keyDef;
    } # TableDefinition

# This function generates a list of tables associated to a given DSN.
sub ListTables
{
    my $dbh = shift;

    my @tables = $dbh->func ("list_tables");
    $dbh->errstr and die "Cannot create table list: " . $dbh->errstr;
    @tables;
    } # ListTables

-d "output"or mkdir "output", 0755;

# This should be removed once we're done converting to Test::More
open STDERR, ">&STDOUT" or die "Cannot redirect stderr";
select STDERR; $| = 1;
select STDOUT; $| = 1;

# The Testing() function builds the frame of the test; it can be called
# in many ways, see below.
#
# Usually there's no need for you to modify this function.
#
#     Testing() (without arguments) indicates the beginning of the
#         main loop; it will return, if the main loop should be
#         entered (which will happen twice, once with $state = 1 and
#         once with $state = 0)
#     Testing("off") disables any further tests until the loop ends
#     Testing("group") indicates the begin of a group of tests; you
#         may use this, for example, if there's a certain test within
#         the group that should make all other tests fail.
#     Testing("disable") disables further tests within the group; must
#         not be called without a preceding Testing("group"); by default
#         tests are enabled
#     Testing("enabled") reenables tests after calling Testing("disable")
#     Testing("finish") terminates a group; any Testing("group") must
#         be paired with Testing("finish")
#
# You may nest test groups.
{   my (@stateStack, $count, $off);

    $count = 0;

    sub Testing (;$)
    {
	my $command = shift;
	if (!defined $command) {
	    @stateStack = ();
	    $off        = 0;
	    if ($count == 0) {
		++$count;
		$::state = 1;
		}
	    elsif ($count == 1) {
		my ($d);
		if ($off) {
		    print "1..0\n";
		    exit 0;
		    }
		++$count;
		$::state = 0;
		print "1..$::numTests\n";
		}
	    else {
		return 0;
		}
	    $off and $::state = 1;
	    $::numTests = 0;
	    }
	elsif ($command eq "off") {
	    $off     = 1;
	    $::state = 0;
	    }
	elsif ($command eq "group") {
	    push @stateStack, $::state;
	    }
	elsif ($command eq "disable") {
	    $::state = 0;
	    }
	elsif ($command eq "enable") {
	    if ($off) {
		$::state = 0;
		}
	    else {
		my $s;
		$::state = 1;
		foreach $s (@stateStack) {
		    unless ($s) {
			$::state = 0;
			last;
			}
		    }
		}
	    return;
	    }
	elsif ($command eq "finish") {
	    $::state = pop @stateStack;
	    }
	else {
	    die "Testing: Unknown argument\n";
	    }
	return 1;
	} # Testing

    # Read a single test result
    sub Test
    {
	my ($result, $error, $diag) = @_;

	++$::numTests;
	$count == 2 or return 1;

	defined $diag and printf "$diag%s", $diag =~ m/\n$/ ? "" : "\n";

	defined $error or $error = "";
	if ($::state || $result) {
	    print "ok $::numTests $error\n";
	    return 1;
	    }
	print "not ok $::numTests - $error\n";
	print STDERR "FAILED Test $::numTests - $error\n";
	return 0;
	} # Test
    }

# Print a DBI error message
sub DbiError ($$)
{
    my ($rc, $err) = @_;
    $rc  ||= 0;
    $err ||= "";
    print "Test $::numTests: DBI error $rc, $err\n";
    } # DbiError

# This functions generates a list of possible DSN's aka
# databases and returns a possible table name for a new
# table being created.
#
# Problem is, we have two different situations here: Test scripts
# call us by pasing a dbh, which is fine for most situations.
{   use vars qw($listTablesHook);

    my $testtable = "testaa";
    my $listed    = 0;

    my @tables;

    sub FindNewTable
    {
	my $dbh = shift;

	unless ($listed) {
	       if (defined $listTablesHook) {
		@tables = $listTablesHook->($dbh);
		}
	    elsif (defined &ListTables) {
		@tables = ListTables ($dbh);
		}
	    else {
		die "Fatal: ListTables not implemented.\n";
		}
	    $listed = 1;
	    }

	# A small loop to find a free test table we can use to mangle stuff in
	# and out of. This starts at testaa and loops until testaz, then testba
	# - testbz and so on until testzz.
	my $foundtesttable = 1;
	my $table;
	while ($foundtesttable) {
	    $foundtesttable = 0;
	    foreach $table (@tables) {
		if ($table eq $testtable) {
		    $testtable++;
		    $foundtesttable = 1;
		    }
		}
	    }
	$table = $testtable;
	$testtable++;
	return $table;
	} # FindNewTable
    }

sub ServerError
{
    die "# Cannot connect: $DBI::errstr\n";
    } # ServerError

sub Connect
{
    # either pass nothing: use defaults, just the dsn or all three
    my ($dsn, $usr, $pass) = @_;
    $dsn  ||= $test_dsn;
    $usr  ||= $test_user;
    $pass ||= $test_pass;
    my $dbh = DBI->connect ($dsn, $usr, $pass) or ServerError;
    $dbh;
    } # Connect

sub DbFile
{
    my $file = shift or return;
    return File::Spec->catdir ($test_dir, $file);
    } # DbFile

sub ErrMsg  (\@) { print  (@_); }
sub ErrMsgF (\@) { printf (@_); }

1;
