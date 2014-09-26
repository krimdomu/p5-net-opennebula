#
# (c) Jan Gehring <jan.gehring@gmail.com>
# 
# vim: set ts=3 sw=3 tw=0:
# vim: set expandtab:
#
   

package Net::OpenNebula::User;

use strict;
use warnings;

use Net::OpenNebula::RPC;
push our @ISA , qw(Net::OpenNebula::RPC);

use constant ONERPC => 'user';

sub name {
   my ($self) = @_;
   $self->_get_info();
   
   # if user NAME is set, use that instead of template NAME
   return $self->{data}->{NAME}->[0] || $self->{data}->{TEMPLATE}->[0]->{NAME}->[0];
}

sub create {
   my ($self, $name, $password, $driver) = @_;
   if (! defined $driver) {
       $driver = "core";
   }
   return $self->_allocate([ string => $name ],
                           [ string => $password ],
                           [ string => $driver ],     
                          );
}


1;
