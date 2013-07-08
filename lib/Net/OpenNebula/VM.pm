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

use Net::OpenNebula::VM::NIC;

use Data::Dumper;

sub new {
   my $that = shift;
   my $proto = ref($that) || $that;
   my $self = { @_ };

   bless($self, $proto);

   return $self;
}

sub id {
   my ($self) = @_;
   return $self->{data}->{ID}->[0];
}

sub name {
   my ($self) = @_;
   $self->_get_info();

   return $self->{extended_data}->{TEMPLATE}->[0]->{NAME}->[0];
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

sub shutdown {
   my ($self) = @_;
   $self->{rpc}->_rpc("one.vm.action",
                        [ string => "shutdown" ],
                        [ int => $self->id ],
                     );
}

sub reboot {
   my ($self) = @_;
   $self->{rpc}->_rpc("one.vm.action",
                        [ string => "reboot" ],
                        [ int => $self->id ],
                     );
}

sub reboot_hard {
   my ($self) = @_;
   $self->{rpc}->_rpc("one.vm.action",
                        [ string => "reboot-hard" ],
                        [ int => $self->id ],
                     );
}

sub poweroff {
   my ($self) = @_;
   $self->{rpc}->_rpc("one.vm.action",
                        [ string => "poweroff" ],
                        [ int => $self->id ],
                     );
}

sub poweroff_hard {
   my ($self) = @_;
   $self->{rpc}->_rpc("one.vm.action",
                        [ string => "poweroff-hard" ],
                        [ int => $self->id ],
                     );
}

sub suspend {
   my ($self) = @_;
   $self->{rpc}->_rpc("one.vm.action",
                        [ string => "suspend" ],
                        [ int => $self->id ],
                     );
}

sub resume {
   my ($self) = @_;
   $self->{rpc}->_rpc("one.vm.action",
                        [ string => "resume" ],
                        [ int => $self->id ],
                     );
}

sub restart {
   my ($self) = @_;
   $self->{rpc}->_rpc("one.vm.action",
                        [ string => "restart" ],
                        [ int => $self->id ],
                     );
}

sub stop {
   my ($self) = @_;
   $self->{rpc}->_rpc("one.vm.action",
                        [ string => "stop" ],
                        [ int => $self->id ],
                     );
}

sub start {
   my ($self) = @_;
   $self->_get_info(clearcache => 1);

   if($self->{extended_data}->{STATE}->[0] == 5 || $self->{extended_data}->{STATE}->[0] == 4 || $self->{extended_data}->{STATE}->[0] == 8) {
      $self->resume();
   }
   else {
      $self->{rpc}->_rpc("one.vm.action",
                           [ string => "start" ],
                           [ int => $self->id ],
                        );
   }
}

sub delete {
   my ($self) = @_;
   $self->{rpc}->_rpc("one.vm.action",
                        [ string => "delete" ],
                        [ int => $self->id ],
                     );
}

sub shutdown_hard {
   my ($self) = @_;
   $self->{rpc}->_rpc("one.vm.action",
                        [ string => "shutdown-hard" ],
                        [ int => $self->id ],
                     );
}

sub hold {
   my ($self) = @_;
   $self->{rpc}->_rpc("one.vm.action",
                        [ string => "hold" ],
                        [ int => $self->id ],
                     );
}

sub release {
   my ($self) = @_;
   $self->{rpc}->_rpc("one.vm.action",
                        [ string => "release" ],
                        [ int => $self->id ],
                     );
}

sub boot {
   my ($self) = @_;
   $self->{rpc}->_rpc("one.vm.action",
                        [ string => "boot" ],
                        [ int => $self->id ],
                     );
}

sub resched {
   my ($self) = @_;
   $self->{rpc}->_rpc("one.vm.action",
                        [ string => "resched" ],
                        [ int => $self->id ],
                     );
}

sub unresched {
   my ($self) = @_;
   $self->{rpc}->_rpc("one.vm.action",
                        [ string => "unresched" ],
                        [ int => $self->id ],
                     );
}

sub undeploy {
   my ($self) = @_;
   $self->{rpc}->_rpc("one.vm.action",
                        [ string => "undeploy" ],
                        [ int => $self->id ],
                     );
}

sub undeploy_hard {
   my ($self) = @_;
   $self->{rpc}->_rpc("one.vm.action",
                        [ string => "undeploy-hard" ],
                        [ int => $self->id ],
                     );
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

sub _get_info {
   my ($self, %option) = @_;

   if(! exists $self->{extended_data} || (exists $option{clearcache} && $option{clearcache} == 1)) {
      $self->{extended_data} = $self->{rpc}->_rpc("one.vm.info", [ int => $self->id ]);
   }
}

sub get_data {
   my ($self) = @_;
   $self->_get_info;
   return $self->{extended_data};
}

1;
