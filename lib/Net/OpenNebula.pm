#
# (c) Jan Gehring <jan.gehring@gmail.com>
# 
# vim: set ts=3 sw=3 tw=0:
# vim: set expandtab:
# 

=head1 NAME

Net::OpenNebula - Access OpenNebula RPC via Perl.

=head1 DESCRIPTION

With this module you can access the OpenNebula XML-RPC service.

=head1 SYNOPSIS

 use Net::OpenNebula;
 my $one = Net::OpenNebula->new(
    url      => "http://server:2633/RPC2",
    user     => "oneadmin",
    password => "onepass",
 );
    
 my @vms = $one->get_vms();

=cut

package Net::OpenNebula;

use strict;
use warnings;

use XML::Simple;
use RPC::XML;
use RPC::XML::Client;

use Data::Dumper;

use Net::OpenNebula::Cluster;
use Net::OpenNebula::Datastore;
use Net::OpenNebula::Host;
use Net::OpenNebula::Image;
use Net::OpenNebula::Template;
use Net::OpenNebula::VM;

our $VERSION = "0.0.1";

sub new {
   my $that = shift;
   my $proto = ref($that) || $that;
   my $self = { @_ };

   bless($self, $proto);

   return $self;
}

sub get_clusters {
   my ($self, $nameregex) = @_;

   my $new = Net::OpenNebula::Cluster->new(rpc => $self);
   return $new->_get_instances($nameregex);
}

sub get_datastores {
   my ($self, $nameregex) = @_;

   my $new = Net::OpenNebula::Datastore->new(rpc => $self);
   return $new->_get_instances($nameregex);
}

sub get_hosts {
   my ($self, $nameregex) = @_;

   my $new = Net::OpenNebula::Host->new(rpc => $self);
   return $new->_get_instances($nameregex);
}

sub get_host {
   my ($self, $id) = @_;

   if(! defined $id) {
      die("You have to define the ID => Usage: \$obj->get_host(\$host_id)");
   }

   my $data = $self->_rpc("one.host.info", [ int => $id ]);
   return Net::OpenNebula::Host->new(rpc => $self, data => $data, extended_data => $data);
}

sub get_vms {
   my ($self, $nameregex) = @_;

   my $new = Net::OpenNebula::VM->new(rpc => $self);
   return $new->_get_instances($nameregex,
                               [ int => -2 ], # always get all resources
                               [ int => -1 ], # range from (begin)
                               [ int => -1 ], # range to (end)
                               [ int => -1 ], # all states, except DONE
                               ); 
}

sub get_vm {
   my ($self, $id) = @_;

   if(! defined $id) {
      die("You have to define the ID => Usage: \$obj->get_vm(\$vm_id)");
   }


   if($id =~ m/^\d+$/) {
      my $data = $self->_rpc("one.vm.info", [ int => $id ]);
      return Net::OpenNebula::VM->new(rpc => $self, data => $data, extended_data => $data);
   }
   else {
      # try to find vm by name
      my ($vm) = grep { $_->name eq $id } $self->get_vms;
      return $vm;
   }

}


sub get_templates {
   my ($self, $nameregex) = @_;

   my $new = Net::OpenNebula::Template->new(rpc => $self);
   return $new->_get_instances($nameregex,
                               [ int => -2 ], # all templates
                               [ int => -1 ], # range start
                               [ int => -1 ], # range end
                               );
}

sub get_images {
   my ($self, $nameregex) = @_;

   my $new = Net::OpenNebula::Image->new(rpc => $self);
   return $new->_get_instances($nameregex,
                               [ int => -2 ], # all templates
                               [ int => -1 ], # range start
                               [ int => -1 ], # range end
                               );
}

sub create_vm {
   my ($self, %option) = @_;

   my $template;

   if($option{template} =~ m/^\d+$/) {
      ($template) = grep { $_->id == $option{template} } $self->get_templates;   
   }
   else {
      ($template) = grep { $_->name eq $option{template} } $self->get_templates;   
   }

   my $hash_ref = $template->get_template_ref;
   $hash_ref->{TEMPLATE}->[0]->{NAME}->[0] = $option{name};

   my $s = XMLout($hash_ref, RootName => undef, NoIndent => 1 );

   my $res = $self->_rpc("one.vm.allocate", [ string => $s ]);

   return $self->get_vm($res);
}

sub create_host {
   my ($self, %option) = @_;

   my $data = $self->_rpc("one.host.allocate",
                              [ string => $option{name} ],
                              [ string => $option{im_mad} ],
                              [ string => $option{vmm_mad} ],
                              [ string => $option{vnm_mad} ],
                              [ int => (exists $option{cluster} ? $option{cluster} : -1) ] );
   if(ref($data) ne "ARRAY") {
      return;
   }

   return $self->get_host($data->[1]);
}


sub create_template {
   my ($self, $txt) = @_;

   my $new_tmpl = Net::OpenNebula::Template->new(rpc => $self, data => undef);
   $new_tmpl->create($txt);
   
   return $new_tmpl;
}


sub create_image {
   my ($self, $txt, $datastore) = @_;

   my $datastoreid; 
   if($datastore =~ m/^\d+$/) {
      $datastoreid = $datastore;
   }
   else {
      my @datastores = $self->get_datastores(qr{^$datastore$});
      $datastoreid = $datastores[0]->id if (@datastores); # take the first one
   }

   my $new_tmpl = Net::OpenNebula::Image->new(rpc => $self, data => undef);
   $new_tmpl->create($txt, $datastoreid);
   
   return $new_tmpl;
}


sub _rpc {
   my ($self, $meth, @params) = @_;                                                                                

   my @params_o = (RPC::XML::string->new($self->{user} . ":" . $self->{password}));
   for my $p (@params) {
      my $klass = "RPC::XML::" . $p->[0];
      push(@params_o, $klass->new($p->[1]));
   }   

   my $req = RPC::XML::request->new($meth, @params_o);
   my $cli = RPC::XML::Client->new($self->{url});
   my $resp = $cli->send_request($req);
   my $ret = $resp->value;

   if($ret->[0] == 1) {
      if($ret->[1] =~ m/^\d+$/) {
         return $ret->[1];
      }
      else {
         return XMLin($ret->[1], ForceArray => 1);
      }
   }   

   else {
      die("error sending request.");
   }   

}

1;
