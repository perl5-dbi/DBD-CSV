package Record;

use Mojo::Base -base;

has [qw{a b how_many observations comment}];

sub to_string {
    my $self = shift;
    my $str = "a: $self->{a}, b: $self->{b} has $self->{how_many} observations\n";
    $str .= "\t". join (" " => split (m/\^/, $self->observations)) . "\n";
    $str .= "\tcomment: $self->{comment}\n";
    return $str;
    } # to_string

1;
