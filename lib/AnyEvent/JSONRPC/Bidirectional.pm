package AnyEvent::JSONRPC::Bidirectional;
use strict;
use warnings;
our $VERSION = '0.01';

package AnyEvent::JSONRPC::Bidirectional;

use AnyEvent::Handle;
use Carp;
use Try::Tiny;
use UNIVERSAL qw/isa/;


sub new {
    my ($class, %args) = @_;
    my $callbacks = delete $args{callbacks};
    my $on_error  = delete $args{on_error} || sub{};
    my $self;
    $args{on_error} = sub{
        my ($hdl, $fatal, $msg) = @_;
        $self->destroy  if $fatal;
        $on_error->($hdl, $fatal, $msg);
    };
    $args{on_read} = sub {
        shift->unshift_read(json => sub{ $self->_dispatch($_[1]) });
    };
    $self = bless {
        _hdl       => AnyEvent::Handle->new(%args),
        _on_error  => $on_error,
        _msgid     => 0,
        _callbacks => isa($callbacks, "HASH") ? $callbacks : {},
        _res_cvs   => {},
    }, $class;
    $self;
}

sub destroy {
    my $self = shift;
    delete($self->{_hdl})->destroy  if $self->{_hdl};
    delete($self->{_on_error});
    delete($self->{_callbacls});
    delete($self->{_res_cvs});
}

sub reg_cb {
    my ($self, %cbs) = @_;
    if ( my $callbacks = $self->{_callbacks} ) {
        while ( my ($k, $v) = each %cbs ) {
            $callbacks->{$k} = $v;
        }
    }
}

sub call {
    my ($self, $method, @args) = @_;
    return  unless $self->{_hdl};
    my $id = $self->{_msgid}++;
    my $cv = AE::cv;
    $self->{_res_cvs}{$id} = $cv;
    $self->{_hdl}->push_write(json => {id => $id, method => "$method", params => \@args});
    $cv;
}

sub notify {
    my ($self, $method, @args) = @_;
    return  unless $self->{_hdl};
    $self->{_hdl}->push_write(json => {id => undef, method => "$method", params => \@args});
}

sub _dispatch {
    my ($self, $json) = @_;
    if ( exists $json->{method} ) {
        if ( defined $json->{id} ) {
            $self->_dispatch_request($json);
        } else {
            $self->_dispatch_notification($json);
        }
    } else {
        $self->_dispatch_response($json);
    }
}

sub _dispatch_request {
    my ($self, $json) = @_;
    my ($id, $method, $args) = @{$json}{qw/id method params/};
    my $sub = $self->{_callbacks}{$method}  or return $self->_return_error($id, "unknown method: $method");
    isa($args, 'ARRAY')                     or return $self->_return_error($id, "invalid format message");
    try {
        my $r = $sub->(@$args);
        if ( isa($r, 'CODE') ) {
            my $cv = AE::cv;
            $cv->cb(sub{
                try {
                    $r = $cv->recv;
                    $self->_return_result($id, $r);
                } catch {
                    $self->_return_error($id, $_);
                } finally {
                    undef $cv;
                }
            });
            $r->($cv);
        } else {
            $self->_return_result($id, $r);
        }
    } catch {
        $self->_return_error($id, $_);
    }
}

sub _return_result {
    my ($self, $id, $val) = @_;
    return  unless $self->{_hdl};
    $self->{_hdl}->push_write(json => {id => $id, error => undef, result => $val});
}

sub _return_error {
    my ($self, $id, $err) = @_;
    return  unless $self->{_hdl};
    $self->{_hdl}->push_write(json => {id => $id, error => $err, result => undef});
}

sub _dispatch_response {
    my ($self, $json) = @_;
    my ($id, $error, $result) = @{$json}{qw/id error result/};
    my $cv = delete($self->{_res_cvs}{$id});
    return $self->{_on_error}->(0, "unknown response msgid: $id")  unless $cv;
    if ( defined $error ) {
        $cv->croak($error);
    } else {
        $cv->send($result);
    }
}

sub _dispatch_notification {
    my ($self, $json) = @_;
    my ($method, $args) = @{$json}{qw/method params/};
    my $sub = $self->{_callbacks}{$method}  or return $self->{_on_error}->(0, "unknown method: $method");
    isa($args, 'ARRAY')                     or return $self->{_on_error}->(0, "invalid format message");
    my $r = $sub->(@$args);
    if ( isa($r, 'CODE') ) {
        my $cv = AE::cv;
        $cv->cb(sub{
            undef $cv;
        });
        $r->($cv);
    }
}

1;
__END__

=head1 NAME

AnyEvent::JSONRPC::Bidirectional -

=head1 SYNOPSIS

  use AnyEvent::JSONRPC::Bidirectional;

=head1 DESCRIPTION

AnyEvent::JSONRPC::Bidirectional is

=head1 AUTHOR

Daisuke (yet another) Maki E<lt>yanother@cpan.orgE<gt>

=head1 SEE ALSO

=head1 LICENSE

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
