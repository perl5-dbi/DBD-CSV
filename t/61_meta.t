#!/usr/bin/perl

use strict;
use warnings;
use version;

use Test::More;
use DBI qw(:sql_types);
use Cwd qw(abs_path);
do "t/lib.pl";

my $dbdfv = version->parse (DBD::File->VERSION);
$dbdfv >= version->parse ("0.41") or
    plan skip_all => "DBD::File 0.41 required. You only have $dbdfv";

my $cnt = join "" => <DATA>;
my $tbl;

my $expect = [
    [ 1, "Knut",    "white"	],
    [ 2, "Inge",    "black"	],
    [ 3, "Beowulf", "CCEE00"	],
    ];

SKIP: {
    open my $data, "<", \$cnt;
    my $dbh = Connect ();
    ok ($tbl = FindNewTable ($dbh),		"find new test table");

    skip "memory i/o currently unsupported by DBD::File", 1;

    $dbh->{csv_tables}->{data} = {
	f_file    => $data,
	skip_rows => 4,
	};
    my $sth = $dbh->prepare ("SELECT * FROM data");
    $sth->execute ();
    my $rows = $sth->fetchall_arrayref ();
    is_deeply ($rows, $expect, "all rows found - mem-io w/o col_names");
    }

SKIP: {
    open my $data, "<", \$cnt;
    my $dbh = Connect ();

    skip "memory i/o currently unsupported by DBD::File", 1;

    $dbh->{csv_tables}->{data} = {
	f_file    => $data,
	skip_rows => 4,
	col_names => [qw(id name color)],
	};
    my $sth = $dbh->prepare ("SELECT * FROM data");
    $sth->execute ();
    my $rows = $sth->fetchall_arrayref ();
    is_deeply ($rows, $expect, "all rows found - mem-io w col_names");
    }

my $fn = abs_path (DbFile ($tbl));
open my $fh, ">", $fn or die "Can't open $fn for writing: $!";
print $fh $cnt;
close $fh;

END { defined $fn and unlink $fn; }

{   open my $data, "<", $fn;
    my $dbh = Connect ();
    $dbh->{csv_tables}->{data} = {
	f_file    => $data,
	skip_rows => 4,
	};
    my $sth = $dbh->prepare ("SELECT * FROM data");
    $sth->execute ();
    my $rows = $sth->fetchall_arrayref ();
    is_deeply ($rows, $expect, "all rows found - file-handle w/o col_names");
    is_deeply ($sth->{NAME_lc}, [qw(id name color)],
	"column names - file-handle w/o col_names");
    }

{   open my $data, "<", $fn;
    my $dbh = Connect ();
    $dbh->{csv_tables}->{data} = {
	f_file    => $data,
	skip_rows => 4,
	col_names => [qw(foo bar baz)],
	};
    my $sth = $dbh->prepare ("SELECT * FROM data");
    $sth->execute ();
    my $rows = $sth->fetchall_arrayref ();
    is_deeply ($rows, $expect, "all rows found - file-handle w col_names");
    is_deeply ($sth->{NAME_lc}, [qw(foo bar baz)], "column names - file-handle w col_names");
    }

{   my $dbh = Connect ();
    $dbh->{csv_tables}->{data} = {
	f_file    => $fn,
	skip_rows => 4,
	};
    my $sth = $dbh->prepare ("SELECT * FROM data");
    $sth->execute ();
    my $rows = $sth->fetchall_arrayref ();
    is_deeply ($rows, $expect, "all rows found - file-name w/o col_names");
    is_deeply ($sth->{NAME_lc}, [qw(id name color)],
	"column names - file-name w/o col_names");
    }

{   my $dbh = Connect ({ RaiseError => 1 });
    $dbh->{csv_tables}->{data} = {
	f_file    => $fn,
	skip_rows => 4,
	col_names => [qw(foo bar baz)],
	};
    my $sth = $dbh->prepare ("SELECT * FROM data");
    $sth->execute ();
    my $rows = $sth->fetchall_arrayref ();
    is_deeply ($rows, $expect, "all rows found - file-name w col_names" );
    is_deeply ($sth->{NAME_lc}, [qw(foo bar baz)],
	"column names - file-name w col_names" );
    }

done_testing();

__END__
id,name,color
stupid content
only for skipping
followed by column names
1,Knut,white
2,Inge,black
3,Beowulf,"CCEE00"
