# -*- perl -*-

require 5.004;
use strict;

require Benchmark;

my $v;
eval {
    require DBI;
    $v->{DBI}= $DBI::VERSION;
    require SQL::Statement;
    $v->{SQL}= $SQL::Statement::VERSION;
    require Text::CSV_XS;
    $v->{CSV}= $Text::CSV_XS::VERSION;
    require DBD::CSV;
    $v->{DBD}= $DBD::CSV::VERSION;
};
if ($@) {
    print "\n\nYOU ARE MISSING REQUIRED MODULES:\n\n";
    print "   DBI\n" unless $v->{DBI};
    print "   SQL::Statement\n" unless $v->{SQL};
    print "   Text_CSV\n" unless $v->{CSV};
    exit;
}
print  "USING:\n";
printf " %-20s %s\n",'OS', $^O;
printf " %-20s %s\n",'Perl', $];
printf " %-20s %s\n",'DBD::CSV', $v->{DBD};
printf " %-20s %s\n",'DBI', $v->{DBI};
printf " %-20s %s\n",'SQL::Statement', $v->{SQL};
printf " %-20s %s\n",'Text::CSV_XS', $v->{CSV};

my $haveFileSpec = eval { require File::Spec };
my $table_dir;
if ($haveFileSpec) {
    $table_dir = File::Spec->catdir(File::Spec->curdir(), 'output');
} else {
    $table_dir = "output";
}
if (! -d $table_dir  &&  ! mkdir $table_dir, 0755) {
    die "Cannot create 'output' directory: $!";
}


my($i);
sub TimeMe ($$$$) {
    my($startMsg, $endMsg, $code, $count) = @_;
    printf("\n%s\n", $startMsg);
    my($t1) = Benchmark->new();
    $@ = '';
    eval {
	for ($i = 0;  $i < $count;  $i++) {
	    &$code;
	}
    };
    if ($@) {
	print "Test failed, message: $@\n";
    } else {
	my($td) = Benchmark::timediff(Benchmark->new(), $t1);
	my($dur) = $td->cpu_a;
	printf($endMsg, $count, $dur, $count / $dur);
	print "\n";
    }
}


TimeMe("Testing empty loop speed ...",
       "%d iterations in %.1f cpu+sys seconds (%d per sec)",
       sub {
       },
    100000);


my($dbh);
my($sth);
TimeMe("Testing connect/disconnect speed ...",
       "%d connections in %.1f cpu+sys seconds (%d per sec)",
       sub {
	   $dbh = DBI->connect("DBI:CSV:f_dir=$table_dir", undef, undef,
			       { 'RaiseError' => 1 });
	   $dbh->disconnect();
       },
    2000);

unlink $haveFileSpec ?
    File::Spec->catfile($table_dir, 'bench') : "output/bench";

$dbh = DBI->connect("DBI:CSV:f_dir=$table_dir", undef, undef,
                    { 'RaiseError' => 1 });
TimeMe("Testing CREATE/DROP TABLE speed ...",
       "%d files in %.1f cpu+sys seconds (%d per sec)",
       sub {
	   $dbh->do("CREATE TABLE bench (id INTEGER, name CHAR(40),"
		    . " firstname CHAR(40), address CHAR(40),"
		    . " zip CHAR(10), city CHAR(40), email CHAR(40))");
	   $dbh->do("DROP TABLE bench");
       },
    500);

$dbh->do("CREATE TABLE bench (id INTEGER, name CHAR(40),"
    . " firstname CHAR(40), address CHAR(40),"
    . " zip CHAR(10), city CHAR(40), email CHAR(40))");
my(@vals) = (0 .. 499);
my($num);
$sth = $dbh->prepare("INSERT INTO bench VALUES (?,?,?,?,?,?,?,?,?)");
TimeMe("Testing INSERT speed ...",
       "%d rows in %.1f cpu+sys seconds (%d per sec)",
       sub {
	   ($num) = splice(@vals, int(rand(@vals)), 1);
	   $sth->execute($num, 'Wiedmann', 'Jochen','Am Eisteich 9',
                          '72555','Metzingen','joe\@ispsoft.de', undef, $num);
       },
    500);

$sth = $dbh->prepare("SELECT * FROM bench WHERE id = ?");
TimeMe("Testing SELECT speed ...",
       "%d single rows in %.1f cpu+sys seconds (%.1f per sec)",
       sub {
	   $num = int(rand(500));
	   $sth->execute($num);
	   $sth->fetch() or die "Expected result for id = $num";
       },
    100);


$sth = $dbh->prepare("SELECT * FROM bench WHERE id >=? AND id < ?");
TimeMe("Testing SELECT speed (multiple rows) ...",
       "%d times 100 rows in %.1f cpu+sys seconds (%.1f per sec)",
       sub {
	   $num = int(rand(400));
	   $sth->execute($num,$num+100);
	   ($sth->rows() == 100)
	       or die "Expected 100 rows for id = $num, got " . $sth->rows();
	   while ($sth->fetch()) {
	   }
       },
    100);

