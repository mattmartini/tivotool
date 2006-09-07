# Representation of a Tivo Unit
package TivoUnit;
#use strict;
use warnings;
use TTConfig;
use Data::Dumper;
use Net::Ping;
use Net::Telnet;
use IO::Socket;
use Net::Rendezvous;
use Wx;

$|++;

my $c = $TTConfig::config; 
my $vs = $c->vstream(); 

sub new 
{
	my $class = shift;
	my $self = {};
		
	bless($self, $class);
	return $self;
}


### Run a shell command on this tivo ###
sub DoTelnet 
{
	my $command = shift;
	my @results = undef;
	
	$host = $c->tivoip();
	
	# If host is up
	#if (IsUp()=="1") 
	#{
		my $t = new Net::Telnet ( Errmode => "return",);
	
		# Try to telnet in
		$t->open("$host");
		my $success = $t->cmd("/bin/touch"); # Sanity check
		
		# If working, run and return command
		if ($success) 
		{
			@results = $t->cmd( String => "$command", Prompt => '/bash-2.02#/');
		}
	#} 
	
	return @results;
}

sub ScanSubnet
{
	my $self = shift;
	my @ips = @_;
	my @alive = ();
	my @serving = ();
	
	main::TTDebug("to scan @ips");
	
    # Like tcp protocol, but with many hosts
    $p = Net::Ping->new("syn");
    $p->{port_num} = 8074;
    
	foreach my $ipaddr (@ips)
	{
		foreach my $block (128..254) 
		{
			$ipaddr =~ m/(\d+)\.(\d+)\.(\d+)\.(\d+)/;
			my $h = "$1.$2.$3.$block";
			$p->ping($h);
		}
		while (my ($host, $rtt, $ip) = $p->ack) 
		{
			main::TTDebug("HOST: $host [$ip] ACKed in $rtt seconds.");
			push(@alive,$ip);
		}

		foreach my $block (1..127) 
		{
			$ipaddr =~ m/(\d+)\.(\d+)\.(\d+)\.(\d+)/;
			my $h = "$1.$2.$3.$block";
			$p->ping($h);
		}
		while (my ($host, $rtt, $ip) = $p->ack) 
		{
			main::TTDebug("HOST: $host [$ip] ACKed in $rtt seconds.");
			push(@alive,$ip);
		}

	}	
	
	foreach my $a (@alive)
	{
		my $sock = new IO::Socket::INET(PeerAddr => "$a", PeerPort => '8074', Proto => 'tcp', Timeout => '4');
		if ($sock)
		{
			main::TTDebug("Vserver up on $a");
			push @serving, $a;
		}
	}
	
	return $serving[0];
}

### Check if vserver is up ###
sub IsVserverUp 
{
	my $self = shift;
	
	$host = $c->tivoip();

	my $sock = new IO::Socket::INET (
	                                  PeerAddr => "$host",
	                                  PeerPort => '8074',
	                                  Proto => 'tcp',
	                                  Timeout => '4',
	                                 );                                 

	if ($sock) # We are able to connect to port 8074, vserver is up
	{
		close($sock);
		return 1;	
	}
	else # vserver is not up
	{ 
		return 0; 
	}
	
}

sub Delete
{
	my ($self, $fsid) = @_;

	# Do some sanity checking on this 
	if ($fsid =~ m/^\d+$/)
	{
		my @r = DoTelnet("echo \'RubbishObjectByFsId $fsid\' | tivosh");
		return @r;
	}
	
	return 0;
}

### Check if Tivo is pingable ###
sub IsUp 
{
	my $self = shift;
	my $p = Net::Ping->new();

	$host = $c->tivoip();

	Wx::SafeYield();

	if ($p->ping($host))
	{ 
		$p->close();
		return 1; 
	} 
	else 
	{ 
		$p->close();
		return 0; 
	}
}


### Discover Series2 SA Tivos using Bonjour ###
sub Discover 
{
	my @ips = ();
	my $res = Net::Rendezvous->new('tivo_videos');
	$res->discover;
	Wx::SafeYield();
	foreach my $entry ( $res->entries) 
	{
		my $i = $entry->address;
	    push(@ips, $i);
	}
	return @ips;
}

1;
