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

  Currently a module which handles interactions to the kong cluster.  There
  should be no need to use this module on your own.  Possibily it should be
  made it's own module.

  Methods call kong asyncrounsly using Mojo::UserAgent, all methods pass the
  following to callbacks ($kong, $data, $err), and it is up to the caller to
  check and handle the err.

=head1 METHODS

=head2 kong_host

  $kong->kong_host('http://localhost:8001');
  my $kong_host = $kong->kong_host();

setter and getter for kong host, which this module will use to make calls to a
Kong cluster.  Defaults to https://localhost:8001

=head2 fetch_plugins

  $kong->fetch_plugins({name => 'request-transformer'}, sub {
    my ($kong, $plugins, $err) = @_;
    if($err){
      #weep
    }else{
      #dance
    }
  });

Fetches a list of plugins from the kong cluster.  Filter results by passing in
a hash which gets turned into query params for the call.

=cut
