#!/usr/bin/perl
use strict;
use Tie::File;
use TTConfig;
use Recording;
use CommandLineController;
use Data::Dumper;
$|++;

my $home = $ENV{'HOME'};
my $c = $TTConfig::config;
my $commands = CommandLineController->new();
my $vs = $c->vstream();
my $mode = $c->dlmode_auto(); # ty,tmf,mpg,vob,m2v,avi,mp4

our @toDownload = ();
our @favs = ();
our @newRecordings = ();


# Download listings from tivo
@newRecordings = get_new_recordings();
#print "Here are the new recs:\n".Dumper(@newRecordings);

# Parse new recs to see if there are favs in there
#chomp(@favs = `cat $home/Library/Preferences/tivotool.favs`);
tie @favs, 'Tie::File', "$home/Library/Preferences/tivotool.favs" or die("$! $?");
get_favorites_todownload();

#print "Favs:\n";
#print Dumper(@favs);
#print "Here is the toDownload queue:\n";
#print Dumper(@toDownload);


# Get all the download commands.
# run a code block againt each item in list, return to a new list
my @downCmds = map { build_command($_) } @toDownload;
#print Dumper(@downCmds);

foreach my $cmd (@downCmds)
{
	`$cmd`;
} 


untie @favs;
#print "Done.\n";





sub get_new_recordings
{
	my $seen_file = "$home/Library/Preferences/tivotool.seen";
	my $listings_cmd = "$vs tivo://".$c->tivoip()."/llist";

	my @old_recs = `cat $seen_file`;
	chomp @old_recs;
	my @recs = `$listings_cmd | sort | uniq`;
	chomp @recs;
	my @new = ();
	
	open (SEEN, ">> $seen_file") or die($!);

	foreach (@recs)
	{
		my $rec = $_;
		/^(\d+)\|(\d+)\/(\d+)\/(\d+).*$/;
		my $id = $1.$2.$3.$4; # fsid + date

		print SEEN $id."\n";
	
		my $found = 0;
		foreach (@old_recs)
		{
			if ($id == $_)
			{
				$found++;
			}
		}
	
		if ($found == 0)
		{
			#print "New: $id \n";
			push(@new, $rec)
		}
	}

	close SEEN or die($!);
	
	`sort $seen_file -o $seen_file`;
	`uniq $seen_file > $seen_file.saved`;
	`mv $seen_file.saved $seen_file`;
	
	return @new;
}


sub get_favorites_todownload
{
	foreach (@newRecordings)
	{
		our $newRecording = $_;
		chomp $newRecording;
				
		foreach (@favs)
		{
			our $fav = $_;
	
			my @fields = split(/\|/, $newRecording);
				
			if ($fields[4] eq $fav)
			{
				# the new recording is a favorite
				
				my $alreadyQueued = undef;
				
				foreach (@toDownload)
				{						
					$alreadyQueued = 1 if ($_->fsid() == $fields[0])
				}
	
				unless ($alreadyQueued)
				{
					$newRecording =~ m/^(.*)\|(.*)\|(.*)\|(.*)\|(.*)\|(.*)/;
					next unless ($1);
					my $r = Recording->new();
					$r->fsid($1);
					$r->date($2);
					$r->parts($3);
					$r->station($4);
					$r->show($5);
					$r->episode($6);
					push @toDownload, $r;
				}
						
			}

		}
	}
}



sub build_command
{
	my $rec = shift;
	my $cmd = "";

	if ($mode==0) 
	{
		$cmd = $commands->build_tycommand($rec);
	}
	elsif ($mode==1) 
	{
		$cmd = $commands->build_tmfcommand($rec);
	} 
	elsif ($mode==2) 
	{
		$cmd = $commands->build_mpg2command_v($rec);
	} 
	elsif ($mode==3) 
	{
		$cmd = $commands->build_vobcommand_v($rec);
	} 
	elsif ($mode==4) 
	{
		$cmd = $commands->build_m2vcommand_h($rec);
	} 
	elsif ($mode==5) 
	{
		$cmd = $commands->build_avicommand($rec);
	} 
	elsif ($mode==6) 
	{
		$cmd = $commands->build_mp4command($rec);
	}		

	return $cmd;
}



