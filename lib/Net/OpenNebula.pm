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

To inspect the return values of the methods we suggest to use Data::Dumper.

=head1 SYNOPSIS

 use Net::OpenNebula;
 use Data::Dumper; # for the Dumper() function.
    
 my $one = Net::OpenNebula->new(
    url      => "http://server:2633/RPC2",
    user     => "oneadmin",
    password => "onepass",
 );
    
 my @vms = $one->get_vms();
     
 print Dumper(@vms);


=head1 METHODS

=over 4

=cut

package Net::OpenNebula;

use strict;
use warnings;

use XML::Simple;
use RPC::XML;
use RPC::XML::Client;

use Data::Dumper;

use Net::OpenNebula::Host;
use Net::OpenNebula::Cluster;
use Net::OpenNebula::VM;
use Net::OpenNebula::Template;

our $VERSION = "0.1";

=item new(%option)

This is the constructor.

 my $one = Net::OpenNebula->new(
    url      => "http://server:2633/RPC2",
    user     => "oneadmin",
    password => "onepass",
 );
 

=cut

sub new {
   my $that = shift;
   my $proto = ref($that) || $that;
   my $self = { @_ };

   bless($self, $proto);

   return $self;
}

=item get_clusters()

This function calls I<one.clusterpool.info>. This will return information of all clusters in the pool.

 my @clusters = $one->get_clusters;

=cut
sub get_clusters {
   my ($self) = @_;

   my @ret = ();

   my $data = $self->_rpc("one.clusterpool.info");

   for my $cluster (@{ $data->{CLUSTER} }) {
      push(@ret, Net::OpenNebula::Cluster->new(rpc => $self, data => $cluster));
   }

   return @ret;
}

=item get_hosts()

This function calls I<one.hostpool.info>. This will return information of all hosts in the pool.

 my @hosts = $one->get_hosts;

=cut
sub get_hosts {
   my ($self) = @_;

   my @ret = ();

   my $data = $self->_rpc("one.hostpool.info");

   for my $host (@{ $data->{HOST} }) {
      push(@ret, Net::OpenNebula::Host->new(rpc => $self, data => $host));
   }

   return @ret;
}

=item get_host($id)

This function calls I<one.host.info>. This will return information the given host. You need to refer to the host by its OpenNebula id.

 my $host = $one->get_host(5);

=cut
sub get_host {
   my ($self, $id) = @_;

   if(! defined $id) {
      die("You have to define the ID => Usage: \$obj->get_host(\$host_id)");
   }

   my $data = $self->_rpc("one.host.info", [ int => $id ]);
   return Net::OpenNebula::Host->new(rpc => $self, data => $data, extended_data => $data);
}

=item get_vms()

This function calls I<one.vmpool.info>. This will return information of all known virtual machines.

 my @vms = $one->get_vms;

=cut
sub get_vms {
   my ($self) = @_;

   my $data = $self->_rpc("one.vmpool.info", 
                           [ int => -2 ], # always get all resources
                           [ int => -1 ], # range from (begin)
                           [ int => -1 ], # range to (end)
                           [ int => -1 ], # all states, except DONE
                         ); 

   my @ret = ();

   for my $vm (@{ $data->{VM} }) {
      push(@ret, Net::OpenNebula::VM->new(rpc => $self, data => $vm));
   }

   return @ret;
}

=item get_vm()

This function calls I<one.vm.info>. This will return information of the given virtual machine.

 my $vm = $one->get_vm(8);

You can also use the virtual machine's name.

 my $vm = $one->get_vm('myvm');

=cut
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

=item get_templates()

This function calls I<one.templatepool.info>. This will return information of all the templates available in OpenNebula.

 my @templates = $one->get_templates;

=cut
sub get_templates {
   my ($self) = @_;

   my $data = $self->_rpc("one.templatepool.info",
                           [ int => -2 ], # all templates
                           [ int => -1 ], # range start
                           [ int => -1 ], # range end
                         );

   my @ret = ();

   for my $tpl (@{ $data->{VMTEMPLATE} } ) {
      push(@ret, Net::OpenNebula::Template->new(rpc => $self, data => $tpl));
   }

   return @ret;
}

=item create_vm(%option)

This function will call I<one.vm.allocate> and create a new virtual machine.

 my $vm = $one->create_vm(
    template => 7,
    name     => 'vmname',
 );

You can also use the template name.

 my $vm = $one->create_vm(
    template => 'centos',
    name     => 'vmname',
 );

=cut
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

=item create_host(%option)

This function will call I<one.host.allocate> and register a new host into OpenNebula.

 my $host = $one->create_host(
    name    => 'my-computenode',
    im_mad  => 'im_mad_name',  # optional
    vmm_mad => 'vmm_mad_name', # optional
    vnm_mad => 'vnm_mad_name', # optional
    cluster => 'my-computenode',
 );

The I<cluster> option is optional. All other options are mandatory.

=cut
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

=back

=cut

1;
