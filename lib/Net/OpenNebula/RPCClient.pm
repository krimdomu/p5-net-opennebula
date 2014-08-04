package Net::OpenNebula::DummyLogger;

use strict;
use warnings;

sub new {
    my $that = shift;
    my $proto = ref($that) || $that;
    my $self = { @_ };

    bless($self, $proto);
    
    return $self;
}

# Mock basic methods of Log4Perl getLogger instance
no strict 'refs';
foreach my $i (qw(error warn info verbose debug)) {
    *{$i} = sub {}
}
use strict 'refs';


package Net::OpenNebula::RPCClient;

use strict;
use warnings;

use XML::Simple;
use RPC::XML;
use RPC::XML::Client;

sub new {
    my $that = shift;
    my $proto = ref($that) || $that;
    my $self = { @_ };

    if (! exists($self->{log})) {
        $self->{log} = Net::OpenNebula::DummyLogger->new();
    }

    bless($self, $proto);

    return $self;
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
    
    $self->log->debug(5, "RPC request ".$req->as_string());
    my $resp = $cli->send_request($req);
    my $ret = $resp->value;

    if($ret->[0] == 1) {
        $self->log->debug(5, "RPC answer $ret->[1]");
        if($ret->[1] =~ m/^\d+$/) {
            return $ret->[1];
        }
        else {
            return XMLin($ret->[1], ForceArray => 1);
        }
    }   

    else {
        $self->log->error("Error sending request: $ret->[1] (code $ret->[2])");
        die("error sending request.");
    }   

}

1;