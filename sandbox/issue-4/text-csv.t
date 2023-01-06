#!/pro/bin/perl

use 5.018002;
use warnings;

use Test::More;
use Text::CSV_XS;

use lib ".";
use Record;
use VariableColumns qw{after_parse_combine_cols};

my $options = {
    eol         => "\n",
    sep_char    => " ",
    escape_char => "\\",
    callbacks   => {
	after_parse => \&after_parse_combine_cols,
	}
    };

my @cols = qw{a b how_many observations comment};

my $text_csv = new_ok "Text::CSV_XS", [ $options ];

$text_csv->column_names (@cols);

open my $fh, "<:encoding(utf8)", "input.csv" or die "input.csv: $!";

my @rows;
while (my $row = $text_csv->getline_hr ($fh)) {
    is (keys (%$row), @cols, "correct column count");
    push @rows, Record->new (%$row);
    }
close $fh;

diag "Records";
diag $_->to_string for @rows;

done_testing ();
