#
# (c) Jan Gehring <jan.gehring@gmail.com>
# 
# vim: set ts=3 sw=3 tw=0:
# vim: set expandtab:
#
   

package Net::OpenNebula::Template;

use strict;
use warnings;

use Net::OpenNebula::RPC;
push our @ISA , qw(Net::OpenNebula::RPC);

use constant ONERPC => 'template';

sub name {
   my ($self) = @_;
   $self->_get_info();

   return $self->{extended_data}->{NAME}->[0];
}

sub get_template_ref {
   my ($self) = @_;
   $self->_get_info();

   return { TEMPLATE => $self->{extended_data}->{TEMPLATE} };
}


sub get_data {
   my ($self) = @_;
   $self->_get_info;
   return $self->{extended_data};
}

1;
