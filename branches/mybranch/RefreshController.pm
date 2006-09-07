# Perform work on refreshing listings without blocking GUI
package RefreshController;
use strict;
use warnings;
use TTConfig;
use Recording;
use Net::Ping;

$|++;
my @recordings = ();

my $c = $TTConfig::config; 

sub new 
{
	my $class = shift;
	my $self = {};
	$self->{refreshing} = undef;
	bless($self, $class);
	return $self;
}


### Download recordings to temp file ###
sub DownloadRecordings 
{
	my $self = shift;
	my $host = $c->tivoip();
	my $vs = $c->vstream();
	
	main::TTDebug("Unlinking old listings");
	
	unlink("$main::home/Library/Caches/listings");	
	
	my $cmd = "$vs tivo://$host/llist > $main::home/Library/Caches/listings.tmp ".
					"&& mv $main::home/Library/Caches/listings.tmp $main::home/Library/Caches/listings";

	main::TTDebug("Download command:\n$cmd");
	
	my $pid = open(VSTREAM, "$cmd |") or die("$!");
	
	$self->{refreshing} = 1; # informs OnIdle to begin watching for finished listings file 
	return $pid;
}


### Create recording objects ###
sub PopulateRecordings 
{
	my $self = shift;
	my %seen = ();
	my @raw_recordings = ();
	
	main::TTDebug("Opening listings file");
	
	open (LISTINGS, "$main::home/Library/Caches/listings") or print("Looking for listings cache: $!");
	while (<LISTINGS>)
	{
		/^(.*)\|(.*)\|(.*)\|(.*)\|(.*)\|(.*)/;
		next unless ($1);
		my $rec = Recording->new();
		$rec->fsid($1);
		$rec->date($2);
		$rec->parts($3);
		$rec->station($4);
		$rec->show($5);
		$rec->episode($6);
		push @raw_recordings, $rec;
	}
	close LISTINGS;

	# Remove dupes
	@recordings = map { exists($seen{$_->fsid}) ? () : ($seen{$_->fsid} = $_) } @raw_recordings;
	return @recordings;
}


### Refreshing listings? ###
sub Refreshing 
{
    my $self = shift;
    if (@_) 
    { 
    	$self->{refreshing} = shift; 
    	if ($self->{refreshing}==0) 
    	{
    		close VSTREAM or die("$!");
    	}
    }
    return $self->{refreshing};
}

1;
