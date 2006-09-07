package CommandLineController;
use strict;
use TTConfig;
use Recording;
$|++;
my $home = $main::home;

# The configuration options that are used to customize these command lines...
my $c = $TTConfig::config; 
my $home = $ENV{'HOME'};
my $tivoserver = $c->tivoserver();
my $mplex = $c->mplex();
my $out = $c->outputdir();
my $mfs_ue = $c->uber();
my $dvdauthor = $c->dvdauthor();
my $hdx = $c->hdemux();
my $vsp = $c->vsplit(); 	
my $hole = $c->tc_hole(); 	
my $ffmpeg = $c->ffmpeg();
my $me_s = $c->mencoders();
my $me = $c->mencoder();
my $br = $c->bitrate();
my $width = $c->resize_w();	
my $height = $c->resize_h();

# 
# Constructor
#
sub new {
	my $class = shift;
	my $self = {};
	
	# All of these command lines are built using a recording object passed to them
	$self->{tycommand} = undef;
	$self->{tmfcommand} = undef;
	$self->{mp4command} = undef;
	$self->{avicommand} = undef;
	$self->{streamcommand} = undef;	
	$self->{mpg2command_v} = undef;
	$self->{vobcommand_v} = undef;
	$self->{m2vcommand_h} = undef;
	$self->{m2vcommand_v} = undef;
	$self->{tivoservercommand} = undef;
	$self->{itunesmove} = undef;

	# These commands are special in that they need to be run after one of the above commands
	# because they assume a file is on the disk in the location specified by the passed recording object ($r->filename())
	$self->{muxcommand} = undef;
	$self->{wavcommand} = undef;
	$self->{freqcommand} = undef;
	$self->{imagecommand} = undef;
	
	bless($self, $class);
	return $self;
}


###		VIDEO COMMAND LINES BELOW	 	### 
#group of .vobs -> .dmg
#-----------------------
#system("");
#system("");
#open (DVDA,  2>&1 |") or die("couldnt open dvdauthor");
#open (DVDA, $c->DVDAUTHOR." -T -o \'$out/$dvdname\' 2>&1 |") or die("couldnt open dvdauthor");
#check size of VTS_01_1.VOB here...
#system("rm -f \'$out/$dvdname/.DS_Store\'");
#system("rm -f \'$out/$dvdname/VIDEO_TS/.DS_Store\'");
#open (MKISO, $c->MKISOFS." -dvd-video -v -V $dvdname -o \'".$c->OUTPUTDIR."/$dvdname.dmg\' \'".$c->OUTPUTDIR."/$dvdname\' 2>&1 |") or die("couldnt open mkisofs");
#check size of dmg here...

sub build_itunesmove
{
	my ($self, $r, $it) = @_;
	$self->{itunesmove} = "mv \'$out"."/".$r->filename().".mp4\' \'$it\'";
	return $self->{itunesmove};
}

### Command to start tivoserver ###
sub build_tivoservercommand
{
	my $self = shift;
	
	$self->{tivoservercommand} = "$tivoserver";
	
	return $self->{tivoservercommand};
}


### Command to download .ty to user's selected output directory ### 
sub build_imagecommand 
{
	my ($self, $dvdname, @r) = @_; 

	$self->{imagecommand} = "mkdir -p \'$out/$dvdname/AUDIO_TS\'; ".
						 "mkdir \'$out/$dvdname/VIDEO_TS\'; ".
						 "$dvdauthor -o \'$out/$dvdname\'";
	
	foreach (@r) { $self->{imagecommand} .= " -f \'$out/".$_->filename().".vob\'"; }
	
	$self->{imagecommand} .= ";";
	$self->{imagecommand} .= " $dvdauthor -T -o \'$out/$dvdname\';";
		
	$self->{imagecommand} .= "rm -f \'$out/$dvdname/.DS_Store\'; rm -f \'$out/$dvdname/VIDEO_TS/.DS_Store\'; ";
	
	$self->{imagecommand} .= $c->MKISOFS." -dvd-video -v -V $dvdname -o \'$out/$dvdname.dmg\' \'$out/$dvdname\'; ";
	
	return $self->{imagecommand};
}


### Command to download .ty to user's selected output directory ### 
sub build_tycommand 
{
	my ($self, $r) = @_; 
	my $fn = $r->filename();

	$self->{tycommand} = "export MFS_DEVLIST=:".$c->tivoip().
				  " && $mfs_ue -n 2048 -R ".
				  $r->fsid().
				  " -o \'$out/$fn.ty\'";
	
	return $self->{tycommand};
}

### Command to download TMF to user's selected output directory ### 
sub build_tmfcommand 
{
	my ($self, $r) = @_; 
	my $fn = $r->filename();

	$self->{tmfcommand} = "export MFS_DEVLIST=:".$c->tivoip().
				  " && $mfs_ue -t -x -n 2048 -R ".
				  $r->fsid().
				  " -o \'$out/$fn.tmf\'";
	
	return $self->{tmfcommand};
}

### Command to mux two streams of a show together ###
### parses config for a few options ###
sub build_muxcommand_mpg 
{
	my ($self, $r) = @_; 
	my $fn = $r->filename();
	my $fn2 = $r->filename().".mpg";
	
	$self->{muxcommand} = "$mplex -f 8 ".
						  "-o \'$out/$fn2\' \'$out/$fn.m2v\' \'$out/$fn.m2a\' 2>&1";
						  
	return $self->{muxcommand};
}

### Command to mux two streams of a show together ###
### parses config for a few options ###
sub build_muxcommand_vob 
{
	my ($self, $r) = @_; 
	my $fn = $r->filename();
	my $fn2 = $r->filename().".vob";
	
	$self->{muxcommand} = "$mplex -f 8 ".
						  "-o \'$out/$fn2\' \'$out/$fn.m2v\' \'$out/$fn.m2a\' 2>&1";
						  
	return $self->{muxcommand};
}

### Build M2V/M2A hdemux command line from user options ###
sub build_m2vcommand_h 
{
	my ($self, $r) = @_;
	my $fn = $r->filename();

	$self->{m2vcommand_h} = "export MFS_DEVLIST=:".$c->tivoip()." && ($mfs_ue -n 2048 -R ".$r->fsid().
		                    " -o \'$home/.tivotool/tydemux\' &) && ".
		                    "$hdx -i \'$home/.tivotool/tydemux\' ".
		                    "-v \'$out/$fn.m2v\' -a \'$out/$fn.m2a\'";

	return $self->{m2vcommand_h};
}

### Build M2V/M2A vsplit command line from user options ###
sub build_m2vcommand_v 
{
	my ($self, $r) = @_;
	my $fn = $r->filename();
	
	$self->{m2vcommand_v} = "export MFS_DEVLIST=:".$c->tivoip()." && ($mfs_ue -n 2048 -R ".$r->fsid().
					  " -o \'$home/.tivotool/tydemux\' &) && $vsp \'$home/.tivotool/tydemux\' ".
					  "\'$out/$fn\' \'$out/$fn\' 2>&1";

	return $self->{m2vcommand_v};
}

### Build MPEG2 vsplit command line from user options ###
sub build_mpg2command_v 
{
	my ($self, $r) = @_;

	$self->{mpg2command_v} = "export MFS_DEVLIST=:".$c->tivoip()." && ($mfs_ue -n 2048 -R ".
							 $r->fsid()." -o $home/.tivotool/tydemux &) && $vsp ";
	$self->{mpg2command_v} .= "-a " if ($hole>0);
	$self->{mpg2command_v} .= "-m '$home/.tivotool/tydemux' \'$out/".$r->filename()."\' \'$out/".$r->filename()."\' 2>&1";

	return $self->{mpg2command_v};
}

### Build VOB vsplit command line from user options ###
sub build_vobcommand_v 
{
	my ($self, $r) = @_;

	$self->{vobcommand_v} = "export MFS_DEVLIST=:".$c->tivoip()." && ($mfs_ue -n 2048 -R ".
							 $r->fsid()." -o $home/.tivotool/tydemux &) && $vsp ";
	$self->{vobcommand_v} .= "-a " if ($hole>0);
	$self->{vobcommand_v} .= "-b '$home/.tivotool/tydemux' \'$out/".$r->filename()."\' \'$out/".$r->filename()."\' 2>&1";

	return $self->{vobcommand_v};
}

### Build MP4 command line from user options ###
### passed Recording object ###
sub build_mp4command 
{
	my ($self, $r) = @_;
	if ($width == 0) { $width=320; }
	if ($height == 0) { $height=240; }

	$self->{mp4command} = "$me_s tivo://".$c->tivoip()."/".$r->fsid().
				  " -cache 16384 -oac copy -ovc copy -quiet -of mpeg -o - 2>/dev/null | ".
				  "$ffmpeg -v 1 -f mpeg -i - -vcodec xvid ".
				  "-ab 128 -acodec aac -b $br -f mp4 -aspect 4:3 -s $width"."x"."$height ".
	 			  "-v 1 -async 1000 -benchmark -y \'$out"."/".$r->filename().".mp4\'";

	return $self->{mp4command};
}

### Build Mplayer Stream command ###
### direct tivo:// stream ###
sub build_streamcommand 
{
	my ($self, $r) = @_;

	my $vf = ""; # video filters
	
	if ($c->STREAM_CROP == 1) # crop 
	{
		my $boxw = ($r->width() - ($c->CROP_LEFT + $c->CROP_RIGHT));
		my $boxh = ($r->height() - ($c->CROP_TOP + $c->CROP_BOTTOM));
		my $crop = "crop=$boxw:$boxh:".$c->CROP_LEFT.":".$c->CROP_TOP;
		
		$vf = "-vf $crop";
		$vf .= ",pp=lb" if ($c->STREAM_DEINT == 1); # crop and deint
		$vf .= ",denoise3d=4:2:5" if ($c->STREAM_DENOISE == 1); # crop and deint and denoise
	} 
	elsif ($c->STREAM_DEINT == 1) # no crop, deint
	{ 
		$vf = "-vf pp=lb";
		$vf .= ",denoise3d=4:2:5" if ($c->STREAM_DENOISE == 1); # no crop, deint and denoise
	}		
	elsif ($c->STREAM_DENOISE == 1) # no crop, no deint, only denoise
	{
		$vf = "-vf denoise3d=4:2:5" ; 
	}
	
	# Build command line
	$self->{streamcommand} = $c->mplayer." -slave -demuxer 33 -quiet $vf ";
	$self->{streamcommand} .= "-cache ".(($c->cache()+1)*1024)." -cache-min ".$c->cachemin()." ";
	$self->{streamcommand} .= "-framedrop " if ($c->FRAMEDROP == 1);
	$self->{streamcommand} .= "-aspect 1.7777 " if ($c->STREAM_ASPECT == 2);
	$self->{streamcommand} .= "tivo://".$c->tivoip."/".$r->fsid();
	
	return $self->{streamcommand};
}

### Build AVI command line from user options ###
### is passed Recording object ###
sub build_avicommand 
{
	my ($self, $r) = @_;
	my $videowidth = $r->width();
	my $videoheight = $r->height();

	# Video filters
	my $ddeint = my $scale = my $vf = "";

	my $boxw = ($videowidth - ($c->crop_left() + $c->crop_right()));
	my $boxh = ($videoheight - ($c->crop_top() + $c->crop_bottom()));
	my $crop = "crop=$boxw:$boxh:".$c->crop_left().":".$c->crop_top();

	if ($c->deint() eq "0") 
	 { $ddeint = ",pp=lb"; } # 0 - linear blend
	elsif ($c->deint() eq "1") 
	 { $ddeint = ",pp=ci"; } # 1 - cubic interpolate

	if (($width>0) && ($height>0)) # user resize option
	{	
		$scale = ",scale=$width:$height";
		$vf = "$crop$ddeint$scale"; 
	} else {
		$vf = "$crop$ddeint";
	}
	
	my $lavcopts;
	if ($c->twopass()==0) { $lavcopts = "acodec=mp3:abitrate=128:vcodec=mpeg4:vbitrate=$br:autoaspect"; }
	elsif ($c->twopass()==1) { $lavcopts = "acodec=mp3:abitrate=128:vcodec=mpeg4:vbitrate=$br:autoaspect:vpass=1"; }
	elsif ($c->twopass()==2) { $lavcopts = "acodec=mp3:abitrate=128:vcodec=mpeg4:vbitrate=$br:autoaspect:vpass=2"; }

	$self->{avicommand} = $c->mencoder." -passlogfile $home/Library/Caches/divx2pass.log -cache 32768 -demuxer 33 ".
	"-oac lavc -srate 44100 -af lavcresample=44100 -ovc lavc ".
	"-lavcopts $lavcopts -vf $vf ".
	"tivo://".$c->tivoip()."/".$r->fsid().
	" -ffourcc XVID ".
	"-o \'$out/".$r->filename().".avi\'";

	return $self->{avicommand};
}

### Change audio frequency on a recording to 48000hz ###
### assumed mp2 input ###
sub build_freqcommand 
{
	my ($self, $r) = @_; 
	my $fn = $r->filename();

	$self->{freqcommand} = "$ffmpeg -y -i \'$out/$fn.m2a\' -ar 48000 -ab 192 -acodec mp2 -ac 2 ".
						   "\'$out/$fn.1.m2a\' && mv \'$out/$fn.1.m2a\' \'$out/$fn.m2a\' 2>&1";
						  
	return $self->{freqcommand};
}

### Command line to convert a recording's downloaded M2A to WAV ###
sub build_wavcommand 
{
	my ($self, $r) = @_; 
	my $fn = $r->filename();
	
	$self->{wavcommand} = "$ffmpeg -y -i \'$out/$fn.m2a\' \'$out/$fn.wav\' 2>&1";
						  
	return $self->{wavcommand};
}


### Clean up mfs_uberexport downloads ###
sub CloseTivoConnections 
{
	my @r = `ps -A | grep mfs_uberexpor[t]`;
	foreach(@r) 
	{
		main::TTDebug("Closing stray mfs_uberexport $_\n") if $main::debug==1;
		/(\d+)/;
		kill(9, $1);
	}	
	@r = `ps -A | grep vstream-clien[t]`;
	foreach(@r) 
	{
		main::TTDebug("Closing stray vstream $_\n") if $main::debug==1;
		/(\d+)/;
		kill(9, $1);
	}	
	@r = `ps -A | grep ttmencode[r]`;
	foreach(@r) 
	{
		main::TTDebug("Closing stray ttmencoder $_\n") if $main::debug==1;
		/(\d+)/;
		kill(9, $1);
	}	
}


1;
