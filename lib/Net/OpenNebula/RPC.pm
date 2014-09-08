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

	my $onemethod = "one.$self->{ONERPC}.$method";
		
    return $self->{rpc}->_rpc($onemethod, @args);
}

sub _onerpc_id {
    my ($self, $method) = @_;
    
    $self->has_id("_onerpc_id") || return;

    return $self->_onerpc($method,
                            [ int => $self->id ],
                          );
    
};

sub _onerpc_simple {
    my ($self, $method, $arg) = @_;

    $self->has_id("_onerpc_simple") || return;

    return $self->_onerpc($method,
                          [ string => "$arg" ],
                          [ int => $self->id ],
                         );
};


# return info call
# opts
#   clearcache: if set to 1, clears the cache and queries again
#   id: get info for other id (if missing, use $self->id) 
sub _get_info {
    my ($self, %option) = @_;

    my $id;
    if (exists $option{id}) {
        $id = $option{id} ;  
    } else {
        $self->has_id("_get_info") || return;
        $id = $self->id;
    }

    if(! exists $self->{extended_data} || (exists $option{clearcache} && $option{clearcache} == 1)) {
        $self->{extended_data} = $self->_onerpc("info", [ int => $id ]);
    }
}

sub id {
   my ($self) = @_;
   return $self->{data}->{ID}->[0];
}

# just check if the id is valid or not (returned result to be used as boolean)
sub has_id {
    my ($self, $msg) = @_;
    my $id = $self->id;

    if (defined($id)) {
        return 1;
    } else {
        $self->error("$self->{ONERPC}: no valid id ($msg)");
        return 0;
    }
};

sub dump {
    my $self = shift;
    return Dumper($self);
}

sub _allocate {
    my ($self, @args) = @_;
    my $id = $self->_onerpc("allocate", @args);

    my $args_txt = $self->{rpc}->_rpc_args_to_txt(@args);
    
    if (! defined($id)) {
        $self->error("$self->{ONERPC}: _allocate failed, no id returned (arguments $args_txt).");
        return;        
    }

    $self->debug(1, "$self->{ONERPC} allocate returned id $id");
    
    my $data = $self->_get_info(id => $id);
    if (defined($data)) {
        $self->{data} = $data;
        $self->debug(3, "$self->{ONERPC} allocate updated data for id $id");
        return $id;
    } else {
        $self->error("$self->{ONERPC} allocate updated data failed for id $id");
        return;
    }
}

sub delete {
    my ($self) = @_;

    $self->has_id("delete") || return;

    $self->debug(1, "$self->{ONERPC} delete self->id $self->id");
    return $self->_onerpc_id("delete");
}

sub update {
    my ($self, $tpl, $merge) = @_;

    # reset $merge to integer value; undef implies merge = 0
    if ($merge) {
        $merge = 1;
    } else {
        $merge = 0;
    }

    $self->has_id("update") || return;

    return $self->_onerpc("update",
                          [ int => $self->id ],
                          [ string => $tpl ],
                          [ int => $merge ]
                          );
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

# state: the state (in text) to wait for
# opts
#    sleep: sleep per interval
#    max_iter: maximum iterations (if 0, no sleep)
sub wait_for_state {
    my ($self, $state, %opts) = @_;
    
    my $sleep = 5; # in seconds
    my $max_iter = 200; # approx 15 minutes with default sleep 
    $sleep = $opts{sleep} if defined($opts{sleep});
    $max_iter = $opts{max_iter} if defined($opts{max_iter});

    my $currentstate = $state eq $self->state;
    my $ind = 1; # first state fetched, no sleep involved
    while ($ind < $max_iter && ! $currentstate) {
        sleep($sleep);
        $currentstate = $state eq $self->state;
        $ind +=1;
    }
    
    return $currentstate;
   
}

# add logging shortcuts
no strict 'refs';
foreach my $i (qw(error warn info verbose debug)) {
    *{$i} = sub {
        my ($self, @args) = @_;
        return $self->{rpc}->{log}->$i(@args);
    }
}
use strict 'refs';

1;
