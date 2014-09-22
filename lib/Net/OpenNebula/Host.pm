#
# (c) Jan Gehring <jan.gehring@gmail.com>
# 
# vim: set ts=3 sw=3 tw=0:
# vim: set expandtab:
#

=head1 NAME

Net::OpenNebula::Host - Access OpenNebula Host Information.

=head1 DESCRIPTION

Query the Hoststatus of an OpenNebula host.

=head1 SYNOPSIS

 use Net::OpenNebula;
 my $one = Net::OpenNebula->new(
    url      => "http://server:2633/RPC2",
    user     => "oneadmin",
    password => "onepass",
 );
    
 my ($host) = grep { $_->name eq "one-sandbox" } $one->get_hosts();
 for my $vm ($host->vms) { ... }

=cut

package Net::OpenNebula::Host;

use strict;
use warnings;

use Net::OpenNebula::RPC;
push our @ISA , qw(Net::OpenNebula::RPC);

use constant ONERPC => 'host';

sub name {
   my ($self) = @_;
   $self->_get_info();

   return $self->{extended_data}->{NAME}->[0];
}

sub vms {
   my ($self) = @_;
   $self->_get_info();
   my @ret;
   for my $vm_id (@{ $self->{extended_data}->{VMS}->[0]->{ID} }) {
      push @ret, $self->{rpc}->get_vm($vm_id);
   }

   return @ret;
}

sub used {
   my ($self) = @_;
   $self->_get_info();
   return $self->{extended_data}->{HOST_SHARE}->[0]->{RUNNING_VMS}->[0];
};

1;
