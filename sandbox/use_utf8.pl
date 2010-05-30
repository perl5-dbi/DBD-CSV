#!/pro/bin/perl

use strict;
use warnings;
use autodie;
use charnames ":full";

use DBI;
use Encode qw( encode );

foreach my $enc ("", "utf8") {
    print STDERR "Connecting with DBD::CSV $enc\n";
    my $dbh = DBI->connect ("dbi:CSV:", undef, undef, {
	RaiseError	=> 1,
	PrintError	=> 1,

	f_dir		=> ".",
	f_schema	=> undef,
	f_ext		=> ".csv/r",
	f_encoding	=> $enc,
	});

    binmode STDOUT, ":utf8";

    print "Default ...\n";
    {   my $pat = "\N{BLACK HEART SUIT}";
	my $sth = $dbh->prepare ("select * from utf8foo");
	   $sth->execute;
	while (my ($c_foo, $foo) = $sth->fetchrow) {
	    $foo =~ m/$pat/ and print "Default match  - $c_foo: $foo\n";
	    my $pax = encode ("utf8", $pat);
	    $foo =~ m/$pax/ and print "Decoded match  - $c_foo: $foo\n";
	    }
	}

    print "utf8 ...\n";
    {   use utf8;
	my $pat = "☠";
	my $sth = $dbh->prepare ("select * from utf8foo");
	   $sth->execute;
	while (my ($c_foo, $foo) = $sth->fetchrow) {
	    $foo =~ m/$pat/ and print "Default match  - $c_foo: $foo\n";
	    my $pax = encode ("utf8", $pat);
	    $foo =~ m/$pax/ and print "Decoded match  - $c_foo: $foo\n";
	    }
	}
    }
