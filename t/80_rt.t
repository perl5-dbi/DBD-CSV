#!perl

use strict;
$^W = 1;

use Test::More "no_plan";
do "t/lib.pl";

my ($rt, %input, %desc);
while (<DATA>) {
    if (s/^�(\d+)�\s*-?\s*//) {
	chomp;
	$rt = $1;
	$desc {$rt} = $_;
	$input{$rt} = [];
	next;
	}
    s/\\([0-7]{1,3})/chr oct $1/ge;
    push @{$input{$rt}}, $_;
    }

{   $rt = 18477;
    ok ($rt, "RT-$rt - $desc{$rt}");
    my @lines = @{$input{$rt}};

    open  FILE, ">output/rt$rt";
    print FILE @lines;
    close FILE;

    ok (my $dbh = Connect (),					"connect");
    ok (my $sth = $dbh->prepare ("select * from rt$rt"),	"prepare");
    ok ($sth->execute,						"execute");

    ok ($sth = $dbh->prepare (qq;
	select SEGNO, OWNER, TYPE, NAMESPACE, EXPERIMENT, STREAM, UPDATED, SIZE
	from   rt18477
	where  NAMESPACE  =    ?
	   and EXPERIMENT LIKE ?
	   and STREAM     LIKE ?
	   ;),							"prepare");
    ok ($sth->execute ("RT", "%", "%"),				"execute");
    ok (my $row = $sth->fetch,					"fetch");
    is_deeply ($row, [ 14, "root", "bug", "RT", "not really",
		       "fast", 20090501, 42 ],			"content");
    ok ($sth->finish,						"finish");
    ok ($dbh->do ("drop table rt$rt"),				"drop table");
    ok ($dbh->disconnect,					"disconnect");
    }

{   $rt = 33764;
    ok ($rt, "RT-$rt - $desc{$rt}");
    my @lines = @{$input{$rt}};

    open  FILE, ">output/rt$rt";
    print FILE @lines;
    close FILE;

    ok (my $dbh = Connect (),					"connect");
    ok (my $sth = $dbh->prepare ("select * from rt$rt"),	"prepare");

    eval {
	local $dbh->{PrintError} = 0;
	local $SIG{__WARN__} = sub { };
	is   ($sth->execute, undef,				"execute");
	like ($dbh->errstr, qr{Error 2034 while reading},	"error message");
	is   (my $row = $sth->fetch, undef,			"fetch");
	like ($dbh->errstr,
	      qr{fetch row without a preceeding execute},	"error message");
	};
    ok ($sth->finish,						"finish");
    ok ($dbh->do ("drop table rt$rt"),				"drop table");
    ok ($dbh->disconnect,					"disconnect");
    }

__END__
�357�	- build failure of DBD::CSV
�2193�	- DBD::File fails on create
�5392�	- No way to process Unicode CSVs
�6040�	- Implementing "Active" attribute for driver
�7214�	- error with perl-5.8.5
�7877�	- make test says "t/40bindparam......FAILED test 14"
�8525�	- Build failure due to output files in DBD-CSV-0.21.tar.gz
�11094�	- hint in docs about unix eol
�11763�	- dependency revision incompatibility
�14280�	- wish: detect typo'ed connect strings
�17340�	- Update statements does not work properly
�17744�	- Using placeholder in update statement causes error
�18477�	- use of prepare/execute with placeholders fails
segno,owner,type,namespace,experiment,stream,updated,size
14,root,bug,RT,"not really",fast,20090501,42
�20340�	- csv_eol
�20550�	- Using "Primary key" leads to error
�31395�	- eat memory
�33764�	- $! is not an indicator of failure
c_tab,s_tab
1,correct
2,Fal"se
�33767�	- (No subject)
�43010�	- treatment of nulls scrambles joins
�44583�	- DBD::CSV cannot read CSV files with dots on the first line
