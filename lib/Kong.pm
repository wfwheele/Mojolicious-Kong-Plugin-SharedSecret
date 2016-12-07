package Kong;
use Mojo::Base -base;
use Mojo::UserAgent;
use JSON::XS;

has '_kong_host' => sub {
    return Mojo::URL->new('http://localhost:8001');
};

sub kong_host {
    my ( $self, $arg ) = @_;
    if ($arg) {
        return $self->_kong_host( Mojo::URL->new($arg) );
    }
    return $self->_kong_host();
}

has 'ua' => sub {
    return Mojo::UserAgent->new();
};

sub fetch_plugins {
    my ( $self, $filters, $cb ) = @_;
    my $url
        = $self->_kong_host()->query( Mojo::Parameters->new( %{$filters} ) );
    $self->ua()->get(
        $url => sub {
            my ( $ua, $tx ) = @_;
            my $err     = $tx->error();
            my $plugins = decode_json( $tx->res->body )->{data}
                if $tx->res->body;
            $cb->( $self, $plugins, $err );
        }
    );
}

1;
__END__

=encoding utf8

=head1 NAME

Kong

=head1 SYNOPSIS

  use Kong;
  my $kong = Kong->new();
  $kong->kong_host('http://localhost:8001');
  $kong->fetch_plugins({name => 'request-transformer'}, sub{
    my ($kong, $plugins, $err) = @_;
    # handle yo stuff
  });

=head1 DESCRIPTION

=head1 METHODS

=head2 kong_host

  my $kong = Kong->new();
  $kong->kong_host('http://localhost:8001');
  my $kong_host = $kong->kong_host();

setter and getter for kong host, which this module will use to make calls to a
Kong cluster
