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

   if($self->{extended_data}->{STATE}->[0] == 5 || $self->{extended_data}->{STATE}->[0] == 4 || $self->{extended_data}->{STATE}->[0] == 8) {
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

   if($self->{extended_data}->{STATE}->[0] == 4) {
      return "stopped";
   }

   if($self->{extended_data}->{STATE}->[0] == 1) {
      return "pending";
   }

   if($self->{extended_data}->{STATE}->[0] == 3 
      && $self->{extended_data}->{LAST_POLL}->[0] == 0) {
      return "prolog";
   }

   if($self->{extended_data}->{STATE}->[0] == 3
      && $self->{extended_data}->{LAST_POLL}->[0]
      && $self->{extended_data}->{LAST_POLL}->[0] > 0) {
      return "running";
   }

   if($self->{extended_data}->{LCM_STATE}->[0] == 12) {
      return "shutdown";
   }

   if($self->{extended_data}->{LCM_STATE}->[0] == 0
      && $self->{extended_data}->{LCM_STATE}->[0] == 6) {
      return "done";
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
