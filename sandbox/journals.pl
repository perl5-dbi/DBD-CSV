#!/usr/bin/env perl
use strict;
use warnings;

use feature qw(switch say);

use DBI; # requires perl-DBD-CSV


sub fetch_metadata_from_journallist {
    my  $arg_ref = shift;
    my ($sth,$tbl_ary_ref,$statement);

    my $dbh = DBI->connect("DBI:CSV:f_dir=/home/bretel/tmp;csv_auto_diag=1")
        or die("Cannot connect: " . $DBI::errstr);

    $dbh->trace(0);

    $dbh->{'csv_tables'}->{'journals'} =
        {
         'file'         => 'journals.csv', # MUST BE IN UTF8 !!
         'eol'          => "\n",
         'sep_char'     => ',',
         'quote_char'   => '"',
         #      'escape_char'  => undef,
         'col_names'    => [ "journal_title","issn","publisher","subject","language" ],
        };


    $statement = <<EOF;
SELECT journal_title, issn, publisher, subject, language
FROM journals
EOF

    if (defined $arg_ref->{'journal_title'} and defined $arg_ref->{'publisher'}
        and $arg_ref->{'journal_title'} and $arg_ref->{'publisher'}) {
        # case-insensitive search
        $sth = $dbh->prepare($statement."WHERE UPPER(journal_title) = ? and UPPER(publisher) = ?");
        $sth->execute(uc $arg_ref->{'journal_title'},uc $arg_ref->{'publisher'})
            or die("Cannot execute: " . $sth->errstr());
        warn "TITLE=", uc $arg_ref->{'journal_title'},
            "; PUBL=", uc $arg_ref->{'publisher'};
        $tbl_ary_ref = $sth->fetchall_arrayref(); # ref to array of array
        $sth->finish();
    }

    # if no results with journal_title+publisher, try on issn
    if ($#{$tbl_ary_ref} < 0) {
        if (defined $arg_ref->{'issn'} and  $arg_ref->{'issn'}) {
            # TODO: possibly format the ISSN (12345678 -> 1234-56789)
            $sth = $dbh->prepare($statement."WHERE issn = ?");
            $sth->execute($arg_ref->{'issn'})
                or die("Cannot execute: " . $sth->errstr());
            $tbl_ary_ref = $sth->fetchall_arrayref(); # ref to array of array
            $sth->finish();
        }
    }

    $dbh->disconnect();

    return $tbl_ary_ref;
}

{
    say "=== try ===";
    use utf8;
    my $journal_title = "Biochimica et Biophysica Acta (BBA) – Molecular Basis of Disease"; # recognized as UTF-8 thank to 'use utf8'
    # NOTE: the special char is the "EN DASH"                ^

    # but is seems we need to turn off the UTF-8 tag to match
    use Encode;
    if (Encode::is_utf8($journal_title)) {
        Encode::_utf8_off($journal_title); # we want byte-to-byte comparison
    }

    my $journal_meta_ref = fetch_metadata_from_journallist
        ({ publisher      => 'Elsevier',
           journal_title  => $journal_title,
         });

    if ($#{$journal_meta_ref} == 0) {
        say "YES";
        for (@{$journal_meta_ref->[0]}) {
            print "$_. ";
        }
        say "";
    }
    else {
        say "NO";
    }
}
