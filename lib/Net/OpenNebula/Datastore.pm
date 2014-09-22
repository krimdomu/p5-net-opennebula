#
# (c) Jan Gehring <jan.gehring@gmail.com>
# 
# vim: set ts=3 sw=3 tw=0:
# vim: set expandtab:
#
   

package Net::OpenNebula::Datastore;

use strict;
use warnings;

use Net::OpenNebula::RPC;
push our @ISA , qw(Net::OpenNebula::RPC);

use constant ONERPC => 'datastore';

sub name {
   my ($self) = @_;
   $self->_get_info();
   
   # if datastore NAME is set, use that instead of template NAME
   return $self->{data}->{NAME}->[0] || $self->{data}->{TEMPLATE}->[0]->{NAME}->[0];
}

sub create {
   my ($self, $tpl_txt, %option) = @_;
   return $self->_allocate([ string => $tpl_txt ],
                           [ int => (exists $option{cluster} ? $option{cluster} : -1) ],
                           );
}

sub used {
   my ($self) = @_;
   $self->_get_info();
   if ($self->{extended_data}->{IMAGES}->[0]->{ID}->[0]) {
       return 1;
   } else {
       return;
   }
};

1;
