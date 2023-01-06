#!/pro/bin/perl

# Problem
#   UPDATE statement returns NUM_OF_FIELDS > 0 instead of 0
#   This means NUM_OF_FIELDS cannot be used to tell the difference between an
#   UPDATE statement and a SELECT statement that returns one column.
#
# http://search.cpan.org/~timb/DBI-1.639/DBI.pm#Statement_Handle_Attributes
#   Statements that don't return rows of data, like DELETE and CREATE 
#   set NUM_OF_FIELDS to 0 (though it may be undef in some drivers).

use 5.018002;
use DBI;

use Data::Peek;
use Getopt::Long qw(:config bundling);
GetOptions (
    "p|pg|postgres!"	=> \my $opt_p,
    ) or die "usage: $0 [--pg]\n";

my $dbh = $opt_p
    ? DBI->connect ("dbi:Pg:")
    : DBI->connect ("dbi:CSV:", undef, undef, {
	RaiseError => 1,
	PrintError => 1,
	f_dir      => ".",
	f_ext      => ".csv",
	f_lock     => 2,
	f_encoding => "utf8",
	csv_eol    => "\r\n",
	csv_null   => 1,
	}) or die "$DBI::errstr\n";

my $DBD = $dbh->{ImplementorClass} =~ s/::db$//r;
my $v = $DBD->VERSION;
$DBD =~ m/CSV/ and $v .= " + SQL::Statement-$SQL::Statement::VERSION + Text::CSV_XS-$Text::CSV_XS::VERSION";
say "Using DBI-$DBI::VERSION + $DBD-$v";

unlink "irc_001.csv";
$dbh->do ("CREATE TABLE irc_001 (id INTEGER, name CHAR (10))");
$dbh->do ("INSERT INTO  irc_001 (id, name) VALUES (100, 'aaa')");
$dbh->do ("INSERT INTO  irc_001 (id, name) VALUES (200, 'bbb')");
$dbh->do ("INSERT INTO  irc_001 (id, name) VALUES (300, 'ccc')");

print "\tRows\tNOF\n";

# ----- SELECT tests
#         Expected      Actual
#   Rows: true          1
#   NOF:  2             2
my $select = $dbh->prepare ("SELECT * FROM irc_001 WHERE id = 100");
my $snum = $select->execute;
print "Select1\t$snum\t$select->{NUM_OF_FIELDS}\n";

#         Expected      Actual
#   Rows: true          0E0
#   NOF:  2             2
my $select = $dbh->prepare ("SELECT * FROM irc_001 WHERE id = 999");
my $snum = $select->execute;
print "Select2\t$snum\t$select->{NUM_OF_FIELDS}\n";

# ----- UPDATE tests
#         Expected      Actual
#   Rows: 1             1
#   NOF:  0             1
my $update = $dbh->prepare ("UPDATE irc_001 SET name = 'ddd' WHERE id = 200");
my $unum = $update->execute;
print "Update1\t$unum\t$update->{NUM_OF_FIELDS}\n";

#         Expected      Actual
#   Rows: 0E0           OEO
#   NOF:  0             1
my $update = $dbh->prepare ("UPDATE irc_001 SET name = 'ddd' WHERE id = 999");
my $unum = $update->execute;
print "Update2\t$unum\t$update->{NUM_OF_FIELDS}\n";

# ----- DELETE tests
#         Expected      Actual
#   Rows: 1             1
#   NOF:  0             0
my $delete = $dbh->prepare ("DELETE FROM irc_001 WHERE id = 300");
my $dnum = $delete->execute;
print "Delete1\t$dnum\t$delete->{NUM_OF_FIELDS}\n";

#         Expected      Actual
#   Rows: 0E0           0E0
#   NOF:  0             0
my $delete = $dbh->prepare ("DELETE FROM irc_001 WHERE id = 999");
my $dnum = $delete->execute;
print "Delete2\t$dnum\t$delete->{NUM_OF_FIELDS}\n";

$dbh->do ("DROP TABLE irc_001");
