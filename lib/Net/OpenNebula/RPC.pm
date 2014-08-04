package Net::OpenNebula::RPC;

use strict;
use warnings;

use Data::Dumper;

use constant ONERPC => 'rpc';
use constant ONEPOOLKEY => undef;


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

sub _onerpc_id {
    my ($self, $method) = @_;
    return $self->_onerpc($method,
                            [ int => $self->id ],
                         );
};

sub _onerpc_simple {
    my ($self, $method, $arg) = @_;
    return $self->_onerpc($method,
                            [ string => "$arg" ],
                            [ int => $self->id ],
                         );
};

sub _get_info {
   my ($self, %option) = @_;

   my $id = $self->id;
   $id = $option{id} if (exists $option{id});  

   if(! exists $self->{extended_data} || (exists $option{clearcache} && $option{clearcache} == 1)) {
      $self->{extended_data} = $self->_onerpc("info", [ int => $id ]);
   }
}

sub id {
   my ($self) = @_;
   return $self->{data}->{ID}->[0];
}

sub dump {
    my $self = shift;
    return Dumper($self);
}

# When C<nameregex> is defined, only instances with name matching 
# the regular expression are returned (if any).
# C<nameregex> is a compiled regular expression (e.g. qr{^somename$}).
sub _get_instances {
    my ($self, $nameregex, @args) = @_;

    my $class = ref $self;
    my $pool = $class->ONERPC . "pool";
    my $key = $class->ONEPOOLKEY || uc($class->ONERPC);

    my @ret = ();

    my $reply = $self->{rpc}->_rpc("one.$pool.info", @args);
   
    for my $data (@{ $reply->{$key} }) {
        my $inst = $self->new(rpc => $self->{rpc}, data => $data); 
        if (! defined($nameregex) || ($inst->name && $inst->name =~ $nameregex) ) { 
            push(@ret, $inst);
        }   
    }
    
    return @ret;
}


1;
