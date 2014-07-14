package Net::OpenNebula::RPC;

use strict;
use warnings;

use Data::Dumper;

use constant ONERPC => 'rpc';

sub new {
   my $that = shift;
   my $proto = ref($that) || $that;
   my $self = { @_ };

   $self->{ONERPC} = $proto->ONERPC; 
   
   bless($self, $proto);

   return $self;
}

sub _onerpc {
    my ($self, $method, @args) = @_;

    return $self->{rpc}->_rpc("one.$self->{ONERPC}.$method", @args);
}

sub _onerpc_simple {
    my ($self, $method, $arg) = @_;
    return $self->_onerpc($method,
                            [ string => "$arg" ],
                            [ int => $self->id ],
                         );
};

1;
