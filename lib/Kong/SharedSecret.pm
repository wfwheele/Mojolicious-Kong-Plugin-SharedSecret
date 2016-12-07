package Kong::SharedSecret;
use Mojo::Base -strict;
use Kong;

sub fetch_shared_secret {
    my ( $kong_url, $header_name, $cb ) = @_;
    my $kong = Kong->new();
    $kong->fetch_plugins(
        { name => 'request-transformation' },
        _handle_response( $header_name, $cb )
    );
    return;
}

sub _handle_response {
    my ( $header_name, $cb ) = @_;
    return sub {
        my ( $kong, $plugins, $err ) = @_;
        my $secret;
        if ($err) {
            $cb->( __PACKAGE__, undef, $err );
            return;
        }
        my $headers_map = _map_headers( _extract_headers($plugins) );
        $secret = $headers_map->{$header_name};
        $cb->( __PACKAGE__, $secret );
        return;
    };
}

sub _extract_headers {
    my $plugins = shift;
    my @headers;
    for my $plugin ( @{$plugins} ) {
        push @headers, @{ $plugin->{config}->{add}->{headers} };
    }
    return \@headers;
}

sub _map_headers {
    my $headers = shift;
    my %map;
    for my $header ( @{$headers} ) {
        my ( $key, $value ) = split /:/, $header;
        $map{$key} = $value;
    }
    return \%map;
}

1;
