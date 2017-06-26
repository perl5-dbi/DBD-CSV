package VariableColumns;

use strict;
use warnings;
use base qw{Exporter};

our @EXPORT_OK = qw{after_parse_combine_cols};

sub combine_cols {
    my ($data, $index, $combine_char) = @_;
    $combine_char ||= "^";
    my $combine_cols = $data->[$index];
    my $next_col = $index + 1;
    splice (@$data, $next_col, $combine_cols, 
	join ($combine_char, @$data[$next_col .. ($index + $combine_cols)]));
    }

sub after_parse_combine_cols { 
    my ($csv, $data) = @_;

    combine_cols ($data, 2);

    return;
    }

1;
