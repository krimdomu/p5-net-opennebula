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


# options
#    user: user to connect
#    password: password for user
#    url: the RPC url to use
#    log: optional log4perl-like instance
#    fail_on_rpc_fail: die on RPC error or not
sub new {
    my $that = shift;
    my $proto = ref($that) || $that;
    my $self = { @_ };

    if (! exists($self->{log})) {
        $self->{log} = Net::OpenNebula::DummyLogger->new();
    }

    # legacy behaviour
    if (! exists($self->{fail_on_rpc_fail})) {
        $self->{fail_on_rpc_fail} = 1;
    }

    bless($self, $proto);

    $self->{log}->debug(2, "Initialised with user $self->{user} and url $self->{url}.");

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
    
    my $reqstring = $req->as_string();
    my $password = XMLout($self->{password}, rootname => "x");
    if ($password =~ m!^\s*<x>(.*)</x>\s*$!) {
        $password = quotemeta $1;
        $reqstring =~ s/$password/PASSWORD/g;
        $self->debug(5, "_rpc RPC request $reqstring");
    } else {
        $self->debug(5, "_rpc RPC request not shown, failed to convert and replace password");
    }
    
    my $resp = $cli->send_request($req);
    my $ret = $resp->value;

    if($ret->[0] == 1) {
        $self->debug(5, "_rpc RPC answer $ret->[1]");
        if($ret->[1] =~ m/^\d+$/) {
            return $ret->[1];
        }
        else {
            return XMLin($ret->[1], ForceArray => 1);
        }
    }   

    else {
        $self->error("Error sending request: $ret->[1] (code $ret->[2])");
        if( $self->{fail_on_rpc_fail}) {
            die("error sending request.");
        } else {
            return undef;
        }
    }   

}

# add logging shortcuts
no strict 'refs';
foreach my $i (qw(error warn info verbose debug)) {
    *{$i} = sub {
        my ($self, @args) = @_;
        return $self->{log}->$i(@args);
    }
}
use strict 'refs';

1;