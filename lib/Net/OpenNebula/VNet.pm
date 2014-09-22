#
# (c) Jan Gehring <jan.gehring@gmail.com>
# 
# vim: set ts=3 sw=3 tw=0:
# vim: set expandtab:
#
# !no_doc!
  

package Net::OpenNebula::VNet;

use strict;
use warnings;

use Net::OpenNebula::RPC;
push our @ISA , qw(Net::OpenNebula::RPC);

use constant ONERPC => 'vn';
use constant ONEPOOLKEY => 'VNET';

sub create {
   my ($self, $tpl_txt, %option) = @_;
   return $self->_allocate([ string => $tpl_txt ],
                           [ int => (exists $option{cluster} ? $option{cluster} : -1) ],
                           );
}

sub _leases {
    my ($self, $lease_txt, $mode) = @_;
    $mode = "add" if (! ($mode && $mode =~ m/^(add|rm)$/));
    
    return $self->_onerpc("${mode}leases", 
                          [ int => $self->id ], 
                          [ string => $lease_txt ]
                          );
    
}

sub name {
   my ($self) = @_;
   $self->_get_info();

   return $self->{extended_data}->{NAME}->[0];
}

sub addleases {
    my ($self, $lease_txt) = @_;
    return $self->_leases($lease_txt, "add");
}

sub rmleases {
    my ($self, $lease_txt) = @_;
    return $self->_leases($lease_txt, "rm");
}

# Return the number of leases 
sub used {
   my ($self) = @_;
   $self->_get_info();
   return $self->{extended_data}->{TOTAL_LEASES}->[0];
};

1;
