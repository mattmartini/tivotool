# This is all information pertaining to the original/source ty recording
package Recording;
use strict;
use TTConfig;
$|++;

# Class data, or static data members
my $c = $TTConfig::config; 
my $home = $ENV{'HOME'};
my $mp = $c->mplayer();
my $mfs_ue = $c->uber();
my $mfs_do = $c->dumpobj();
my $hdx = $c->hdemux();
my $vstream = $c->vstream();


# 
# Constructor
#
sub new 
{
	my $class = shift;
	my $self = {};
	
	$self->{host} = $c->tivoip(); # others are class data for performance when creating all the Recording objects
	
	# How the user wants to save this file
	$self->{saveformat} = undef;
	$self->{saveformat_audio} = undef;
	$self->{itunes_download} = undef; # send to itunes after download?
	$self->{mux_after_download} = undef;
	
	# these come from vstream-client
	$self->{fsid} = undef;
	$self->{date} = undef;
	$self->{parts} = undef;
	$self->{station} = undef;
	$self->{show} = undef;
	$self->{episode} = undef;
	$self->{description} = undef;
	$self->{comparable_date} = undef;
	
	# from mplayer
	$self->{format} = undef;
	$self->{bitrate} = undef;
	$self->{bitrate_hdemux_suggested} = undef;
	$self->{width} = undef;
	$self->{height} = undef;
	$self->{fps} = undef;
	$self->{aspect} = undef;
	$self->{acodec} = undef;
	$self->{aformat} = undef;
	$self->{abitrate} = undef;
	$self->{achan} = undef;
	$self->{afreq} = undef;
	$self->{duration} = undef;
	
	# from other programs
	$self->{avoffset} = undef; # hdemux
	$self->{size} = undef; # mfs_dumpobj
		
	bless($self, $class);
	return $self;
}


### Get the extended xml info for a recording ###
sub get_xml 
{
	my $self = shift;
	my @result = ();
	$self->{host} = $c->tivoip();
	
	my $cmd = "export MFS_DEVLIST=:". 
			  $self->{host}. 
		   	  " && $mfs_ue".
		   	  " -R ". 
		      $self->{fsid}.
		      " -X";

	open(CMD, "$cmd 2>&1 |");
	while (<CMD>)
	{
		main::TTDebug("$_");
		push(@result, $_);
	}
	close CMD;

	return @result;
}

### Return description of show ###
sub fill_description
{
	my $self = shift;
	return if ($self->{description}); 
	my @xml = $self->get_xml();	
	foreach (@xml) 
	{
		$self->{description}=$1 if /<Description>(.*)<\/Description>/;
	}
}

### Populate the file size of the recording ###
sub fill_size 
{
	my $self = shift;
	$self->{host} = $c->tivoip();
	
	return if ($self->{size}); 

	my $cmd = "export MFS_DEVLIST=:". 
			  $self->{host}. 
		   	  " && $mfs_do -h ". 
		      $self->{fsid};
	
	open(CMD, "$cmd 2>&1 |");
	
	while (<CMD>) 
	{
		main::TTDebug($_) if $main::debug==1;
		if (/StreamFileSize\[..\]=(\d+)/) 
		{
			$self->{size}=$1;
		}
		#elsif (/Duration\[..\]=(\d+)/) 
		#{
		#	$self->{duration}=$1;
		#}
	}
	
	close CMD;
}

### Fill extended object attributes ###
sub fill_attributes 
{
    my $self = shift;
	$self->{host} = $c->tivoip();
	return if ($self->{width}); 

	my $cmd = "$mp -vo null -ao null -identify -frames 1 -nocache -demuxer 33 tivo://".$self->{host}."/".$self->{fsid};

	open(SIZECHECK, "$cmd 2>&1 |") or die("internal ttmplayer not found");
	while(<SIZECHECK>) 
	{
		main::TTDebug($_) if $main::debug==1;
		/^(ID_.*)=(.*)$/;	# Regular expression to grab keys/values from mplayer output
		if (defined($1))
		{
			if ($1 eq "ID_VIDEO_FORMAT") { $self->{format}=$2; }
			elsif ($1 eq "ID_VIDEO_BITRATE") { $self->{bitrate}=$2/1000; }
			elsif ($1 eq "ID_VIDEO_WIDTH") { $self->{width}=$2; }
			elsif ($1 eq "ID_VIDEO_HEIGHT") { $self->{height}=$2; }
			elsif ($1 eq "ID_VIDEO_FPS") { $self->{fps}=$2; }
			elsif ($1 eq "ID_VIDEO_ASPECT") { $self->{aspect}=$2; }
			elsif ($1 eq "ID_AUDIO_CODEC") { $self->{acodec}=$2; }
			elsif ($1 eq "ID_AUDIO_FORMAT") { $self->{aformat}=$2; }
			elsif ($1 eq "ID_AUDIO_BITRATE") { $self->{abitrate}=$2/1000; }
			elsif ($1 eq "ID_AUDIO_RATE") { $self->{afreq}=$2; }
			elsif ($1 eq "ID_AUDIO_NCH") { $self->{achan}=$2; }
			elsif ($1 eq "ID_LENGTH") { $self->{duration}=$2; } # not accurate on some tivos
		}
	}
	close SIZECHECK or die("problem closing mplayer");
}

### Populate the A/V sync attribute ###
sub fill_avoffset 
{
	my $self = shift;
	$self->{host} = $c->tivoip();
	return if ($self->{avoffset}); 

	my $cmd = "export MFS_DEVLIST=:". 
			  $self->{host}. 
			  " && (". 
			  $mfs_ue. 
			  " -n 2048 -R $self->{fsid} -o $home/.tivotool/tydemux &) && ".
     		  $hdx. 
     		  " -i $home/.tivotool/tydemux -v /dev/null -a /dev/null -n 2 ";

	open(OFFSET, "$cmd |") or die ("couldnt open binaries for offset check\n");

	while(<OFFSET>) 
	{
		main::TTDebug($_) if $main::debug==1;
		if (/mplex -f 8 -O (\d+)ms -r (\d+) /) 
		{
			$self->{avoffset} = $1;
			$self->{bitrate_hdemux_suggested} = $2;
		}
	}

	close OFFSET or die("couldnt close offset check\n");
}

# return a filename with only valid characters
sub filename 
{
	my $self = shift;
	my $s = $self->{show};
	my $e = $self->{episode};
	my $d = $self->{date};
	$s =~ s/[\/,\:,\',\`,\?,\~,\&]//g; # bad '''
	$e =~ s/[\/,\:,\',\`,\?,\~,\&]//g; # characters '''
	$d =~ s/[\/,\:,\',\`,\?,\~,\&]//g; # die '''
	return $s." - ".$e." - ".$d if $e;
	return $s." - ".$d;
}

# for sorting..
sub comparable_date
{
    my $self = shift;
    my $tivodate = $self->{date};
    my ($date, $time) = split /\s+/, $tivodate;
	my ($month, $day, $year) = split '/', $date;    
    my ($hour, $minute) = split '/', $time;
    $self->{comparable_date} = sprintf("%04d%02d%02d%02d%02d%02d", $year+2000, $month, $day, $hour, $minute);
    return $self->{comparable_date};
}

### Get the raw .ty to filehandle ###
### currently unused ###
sub get_ty 
{
	my $self = shift;
	$self->{host} = $c->tivoip();	
	
	my $cmd = "export MFS_DEVLIST=:". 
			  $self->{host}. 
		   	  " && $mfs_ue -n 2048".
		   	  " -R ". 
		      $self->{fsid};

	open(CMD, "$cmd |") or die($!);
	binmode(CMD);
	return *CMD;
}

### Send ty to filehandle from offset in seconds###
### currently unused ###
sub get_ty_offset 
{
	my ($self, $offset) = @_;
	$self->{host} = $c->tivoip();
	
	my $size = $self->{size}/1024;
	my $seconds = $self->{duration};

	die("this requires length of recording in seconds") unless ($seconds > 0); 
	
	my $jump = (($size/$seconds)*$offset);

	my $cmd = "vstream-client ".$self->{host}." ".
				 $self->{fsid}.
				 " -o /dev/stdout".
				 " -a $jump";
				 
	open(CMD, "$cmd |") or die($!);
	binmode(CMD);
	return *CMD;
}

### hybrid accessor/mutator methods (get/set) ###
sub itunes_download 
{
    my $self = shift;
    if (@_) { $self->{itunes_download} = shift }
    return $self->{itunes_download};
}

sub mux_after_download 
{
    my $self = shift;
    if (@_) { $self->{mux_after_download} = shift }
    return $self->{mux_after_download};
}

sub fsid 
{
    my $self = shift;
    if (@_) { $self->{fsid} = shift }
    return $self->{fsid};
}

sub show 
{
    my $self = shift;
    if (@_) { $self->{show} = shift }
    return $self->{show};
}

sub episode 
{
    my $self = shift;
    if (@_) { $self->{episode} = shift }
    return $self->{episode};
}

sub date 
{
    my $self = shift;
    if (@_) { $self->{date} = shift }
    return $self->{date};
}

sub station 
{
    my $self = shift;
    if (@_) { $self->{station} = shift }
    return $self->{station};
}

sub duration 
{
    my $self = shift;
    if (@_) { $self->{duration} = shift }
    return $self->{duration};
}

sub bitrate 
{
    my $self = shift;
    if (@_) { $self->{bitrate} = shift }
    return $self->{bitrate};
}

sub fps 
{
    my $self = shift;
    if (@_) { $self->{fps} = shift }
    return $self->{fps};
}

sub aspect 
{
    my $self = shift;
    if (@_) { $self->{aspect} = shift }
    return $self->{aspect};
}

sub width 
{
    my $self = shift;
    if (@_) { $self->{width} = shift }
    return $self->{width};
}

sub height 
{
    my $self = shift;
    if (@_) { $self->{height} = shift }
    return $self->{height};
}

sub avoffset 
{
    my $self = shift;
    if (@_) { $self->{avoffset} = shift }
    return $self->{avoffset};
}

sub bitrate_hdemux_suggested 
{
    my $self = shift;
    if (@_) { $self->{bitrate_hdemux_suggested} = shift }
    return $self->{bitrate_hdemux_suggested};
}

sub aformat 
{
    my $self = shift;
    if (@_) { $self->{aformat} = shift }
    return $self->{aformat};
}

sub acodec 
{
    my $self = shift;
    if (@_) { $self->{acodec} = shift }
    return $self->{acodec};
}

sub abitrate 
{
    my $self = shift;
    if (@_) { $self->{abitrate} = shift }
    return $self->{abitrate};
}

sub afreq 
{
    my $self = shift;
    if (@_) { $self->{afreq} = shift }
    return $self->{afreq};
}

sub achan 
{
    my $self = shift;
    if (@_) { $self->{achan} = shift }
    return $self->{achan};
}

sub parts 
{
    my $self = shift;
    if (@_) { $self->{parts} = shift }
    return $self->{parts};
}

sub size 
{
    my $self = shift;
    if (@_) { $self->{size} = shift }
    return $self->{size};
}

sub description 
{
    my $self = shift;
    if (@_) { $self->{description} = shift }
    return $self->{description};
}

sub saveformat 
{
    my $self = shift;
    if (@_) { $self->{saveformat} = shift }
    return $self->{saveformat};
}

sub saveformat_audio 
{
    my $self = shift;
    if (@_) { $self->{saveformat_audio} = shift }
    return $self->{saveformat_audio};
}

1;
