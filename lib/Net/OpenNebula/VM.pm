#
# (c) Jan Gehring <jan.gehring@gmail.com>
# 
# vim: set ts=3 sw=3 tw=0:
# vim: set expandtab:
#
# !no_doc!
   

package Net::OpenNebula::VM;

use strict;
use warnings;

use Net::OpenNebula::RPC;
push our @ISA , qw(Net::OpenNebula::RPC);

use constant ONERPC => 'vm';

# the VM states as constants
use constant {
    STOPPED => "stopped",
    PENDING => "pending",
    PROLOG => "prolog",
    RUNNING => "running",
    SHUTDOWN => "shutdown",
    DONE => "done"
};

use Net::OpenNebula::VM::NIC;

sub name {
   my ($self) = @_;
   $self->_get_info();
   
   # if vm NAME is set, use that instead of template NAME
   return $self->{data}->{NAME}->[0] || $self->{extended_data}->{TEMPLATE}->[0]->{NAME}->[0];
}

sub nics {
   my ($self) = @_;
   $self->_get_info();

   my @ret = ();

   for my $nic (@{ $self->{extended_data}->{TEMPLATE}->[0]->{NIC} }) {
      push(@ret, Net::OpenNebula::VM::NIC->new(data => $nic));
   }

   return @ret;
}


sub start {
   my ($self) = @_;
   $self->_get_info(clearcache => 1);

   my $state = $self->{extended_data}->{STATE}->[0];  
   if($state == 5 || $state == 4 || $state == 8) {
      return $self->resume();
   }
   else {
      return $self->_onerpc_simple("action", "start");
   }
}

# don't know how to get the state properly. didn't found good docs.
sub state {
   my ($self) = @_;
   $self->_get_info(clearcache => 1);

   my $state = $self->{extended_data}->{STATE}->[0];  
   if($state == 4) {
      return STOPPED;
   }

   if($state == 1) {
      return PENDING;
   }

   my $last_poll = $self->{extended_data}->{LAST_POLL}->[0];
   if($state == 3 && $last_poll == 0) {
      return PROLOG;
   }

   if($state == 3 && $last_poll->[0] && $last_poll > 0) {
      return RUNNING;
   }

   my $lcm_state = $self->{extended_data}->{LCM_STATE}->[0];  
   if($lcm_state == 12) {
      return SHUTDOWN;
   }

   # TODO what is this supposed to mean? it's impossible or a typo 
   if($lcm_state == 0 && $lcm_state == 6) {
      return DONE;
   }


}

sub arch {
   my ($self) = @_;
   $self->_get_info;

   return $self->{extended_data}->{TEMPLATE}->[0]->{OS}->[0]->{ARCH}->[0];
}

sub get_data {
   my ($self) = @_;
   $self->_get_info;
   return $self->{extended_data};
}

# define all generic actions
no strict 'refs';
foreach my $i (qw(shutdown shutdown_hard reboot reboot_hard poweroff poweroff_hard 
                  suspend resume restart stop delete delete_recreate hold release 
                  boot resched unresched undeploy undeploy_hard)) {
    *{$i} = sub {
        my $self = shift;
        return $self->_onerpc_simple("action", $i);
    }
}
use strict 'refs';

1;
