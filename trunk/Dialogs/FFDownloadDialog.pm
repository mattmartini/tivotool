package FFDownloadDialog;
use strict;
use warnings;
use base 'Wx::ProgressDialog';
use Wx;
use Wx qw(:everything);
use Wx::Event qw(EVT_BUTTON EVT_IDLE);
use IO::File;
use Data::Dumper;
use CommandLineController;

my $con = CommandLineController->new();
my $startup = 1;
my $txtTotal; # estimated total size
our ($class, $caller, $rec);

sub new 
{
	($class, $caller, $rec) = @_;
	
	$startup = 1;		
	
	my $max = $rec->duration(); # duration in seconds
	my $show = $rec->show(); # name of show
	my $episode = $rec->episode(); # episode title
	my $desc = $rec->description(); # episode description

	my $self = $class->SUPER::new('Downloading (ffmpeg)...', 'Please Wait...                  ', $max, $caller, 
		wxPD_CAN_ABORT|wxPD_ELAPSED_TIME|wxPD_REMAINING_TIME|wxPD_AUTO_HIDE);	
	
	my @c = $self->GetChildren();
	my $fontsm = Wx::Font->new(11,wxDEFAULT,wxNORMAL,wxNORMAL,0,'Lucida Grande');
	for (my $i=0; $i<6; $i++) { $c[$i]->SetFont($fontsm); }

#	my $file = IO::File->new("../../go-down.png") or die("need icon!\n$! $?");
#	binmode $file;
#	my $handler = Wx::PNGHandler->new();
#	my $image = Wx::Image->new();
#	$handler->LoadFile($image, $file);
#	my $bmp = Wx::Bitmap->new($image);
#	my $bitmap = Wx::StaticBitmap->new($self, -1, $bmp, [-1,-1], [-1,-1]);
#	$bitmap->Lower();

	# My labels
	my $txtShow = Wx::StaticText->new($self, -1, "$show");	
	my $txtEpisode = Wx::StaticText->new($self, -1, "$episode");	
	$txtEpisode->SetToolTip($desc);
	$txtShow->SetToolTip($desc);
	my $txtQueue = Wx::StaticText->new($self, -1, "Downloading ".($Frame::cur+1)." of ".@Frame::recs);	
	$txtQueue->SetFont($fontsm);
	
	# Layout
	my $sizer = Wx::FlexGridSizer->new(3,3,0,0);
	$sizer->AddGrowableCol(1);
	$sizer->AddGrowableRow(1);
	$sizer->AddSpace(10,10,0,wxBOTTOM,5);	$sizer->AddSpace(10,10,0,wxBOTTOM,5);	$sizer->AddSpace(10,10,0,wxBOTTOM,5);
	$sizer->AddSpace(14, 20, 0, wxALIGN_CENTER|wxALL, 5);
		
	# Text and gauge
	my $msizer = Wx::BoxSizer->new(wxVERTICAL);
	$msizer->AddWindow($txtShow, 0, wxALIGN_LEFT|wxTOP, 3);	# show name									
	$msizer->AddWindow($txtEpisode, 0, wxALIGN_LEFT|wxTOP, 3) if $episode; # Episode text										
	$msizer->AddWindow($c[1], 0, wxALIGN_LEFT|wxTOP, 12); # Gauge										
	
	# File size; current and total
	my $msizer_h = Wx::FlexGridSizer->new(1,2,0,0);
	$msizer_h->AddGrowableRow(0);
	$msizer_h->AddGrowableCol(0);
	$msizer_h->AddWindow($c[0], 0, wxALIGN_LEFT|wxGROW, 0); # Download text
	$txtTotal = Wx::StaticText->new($self, -1, "Estimated Total: 000mb");
	$txtTotal->SetFont($fontsm);										
	$msizer_h->AddWindow($txtTotal, 0, wxALIGN_RIGHT|wxGROW, 0); # total mb										
	$msizer->Add($msizer_h, 0, wxTOP|wxGROW, 6);

	# Time remaining, etc...
	my $fs=Wx::FlexGridSizer->new(2,2,0,0); 
	$fs->AddWindow($c[2]);									
	$fs->AddWindow($c[3]);								
	$fs->AddWindow($c[4], 0, wxTOP, 3); 
	$fs->AddWindow($c[5], 0, wxTOP, 3);
	$msizer->Add($fs, 0, wxTOP, 6);

	# Buttons + queue status
	my $sizer_buttons = Wx::BoxSizer->new(wxHORIZONTAL);
	my $infobut = Wx::Button->new($self, -1, "Info");
	$c[6]->SetLabel("Stop");
	$sizer_buttons->AddWindow($txtQueue, 0, wxALIGN_RIGHT|wxTOP|wxRIGHT, 11); # x of x
	$sizer_buttons->AddSpace(16, 0, 0, wxALIGN_CENTER|wxALL, 5);		
	$sizer_buttons->AddWindow($infobut, 0, wxALIGN_RIGHT|wxTOP|wxRIGHT, 6); # info button
	$sizer_buttons->AddWindow($c[6], 0, wxALIGN_RIGHT|wxLEFT|wxTOP, 6); # Stop button
	$msizer->Add($sizer_buttons, 0, wxALIGN_RIGHT|wxTOP, 6); 
	
	$sizer->Add($msizer);										
	$sizer->AddSpace(14, 20, 0, wxALIGN_CENTER|wxALL, 5);
	$sizer->AddSpace(10,10,0,wxALL,5);	$sizer->AddSpace(10,10,0,wxALL,5);	$sizer->AddSpace(10,10,0,wxALL,5);
	$self->SetAutoLayout(1);
    $self->SetSizer( $sizer );
    $sizer->Fit( $self );
    $sizer->SetSizeHints( $self );
    
    EVT_BUTTON($self, $infobut, \&OnClickInfo);
	EVT_IDLE($self, \&OnIdle);
	
    # Finish up class
   	bless($self, $class);
	return $self;
}

sub OnIdle 
{
	my $self = shift;
	
	# Only do once..
	return unless $startup==1;
	$startup=0;
	
	# Fill values for ffmpeg run
	my $max = $rec->duration();
	my $cmd = $con->build_mp4command($rec);	

	# Open ffmpeg
	my $pid = open (FFMPEG, "$cmd 2>&1 |") or die ("could not start download $!");
	local $/ = "\r";

	while (<FFMPEG>)
	{
		# Grab values from stdout
		/^frame=\s*(\d+) q=\s*(\d+\.\d) size=\s*(\d+)kB time=(\d+\.\d) bitrate=\s*(\d+\.\d)kbits\/s.*/;
		next unless ($3); # this isn't status line
		
		#main::TTDebug("$_");
		
		# Parse values for display
		my $percent = (($max/$4)*$3)/1024 if ($4>0);
		my $o = sprintf("Size: %.1fMB", ($3/1024));
	
		# Display
		$txtTotal->SetLabel("Estimated Total: ".int($percent)."MB");
		my $usercontinue = $self->Update($4,"$o\n");
		
		kill(9, ($pid+2)) if ($usercontinue==0);
	}	

	close FFMPEG or print "Couldn't close ffmpeg $!\n";

	if ($rec->itunes_download() eq "1")
	{
			main::TTDebug("Moving to iTunes");
			$self->MoveToItunes();
	}
	
	# Launch next queue download
	$Frame::cur++; # increment index
	
	# Go to next if it exists
	if ($Frame::cur < @Frame::recs)
	{
		$caller->{dialog} = $class->new($caller, $Frame::recs[$Frame::cur]);
	}

	$self->Destroy();
}

sub MoveToItunes
{
	my $self = shift;
	
	local $/ = "\n";

	my $lib_applescript = qq|
		tell application "iTunes"
		  tell library playlist 1
			tell file track 1
			  location as string
			end tell
		  end tell
		end tell
	|;

	my $itdetect = `/usr/bin/osascript -e \'$lib_applescript\'`;

	$itdetect =~ s/:/\//g;
	$itdetect =~ m/(\/.*iTunes\sMusic)/;
	
	my $it = $1;

	main::TTDebug("Detected library location: ".$it);
	
	###################################
	# VERIFY ITUNES LIBRARY LOCATION
	###################################
	my $itunes_lib = $it."/Unknown\ Artist/Unknown\ Album";
	
	## Create the folder inside the iTunes lib if it doesnt exist.
	unless (-d "$itunes_lib") 
	{ 
		mkdir("$it/Unknown\ Artist", 0755);
		mkdir("$itunes_lib", 0755);
	}
	
	# Move file
	main::TTDebug("Moving file to ".$itunes_lib);
	
	my $mvcmd = $con->build_itunesmove($rec, $itunes_lib);
	main::TTDebug("Using this move command:".$mvcmd);
	`$mvcmd`;
		
	############################
	# META-DATA
	############################
	my $tagcmd = "\'/Library/Application\ Support/TivoTool/AtomicParsley\' \'".
		$itunes_lib."/".$rec->filename().".".$rec->saveformat()."\' ".
		"--genre \"TV Shows\" --stik \"TV Show\" ".
		"--title \"".$rec->episode()."\" --TVEpisode \"".$rec->episode()."\" ".
		"--TVShowName \"".$rec->show()."\" --artist \"".$rec->show()."\" --albumArtist \"".$rec->show()."\" ".
		"--comment \"Recorded: ".$rec->date().". Created with TivoTool. http://www.tivotool.com\" --overWrite";

	#my $tagcmd = "\'/Library/Application\ Support/TivoTool/mp4tags\' -s \"".
	#	$rec->episode()."\" -a \"".
	#	$rec->show()."\" -c \"\" \'".
	#	$itunes_lib."/".$rec->filename().".".$rec->saveformat()."\'";

	main::TTDebug("Tagging with this command:", $tagcmd);

	`$tagcmd`;

	############################
	# APPLESCRIPT
	############################
	my $myfile = "$itunes_lib/".$rec->filename().".".$rec->saveformat();
	my $the_applescript = qq|
		set posixFile to "$myfile"
		set hfsFile to (POSIX file posixFile)
		set tt_playlist to "Tivo Recordings"
		tell application "iTunes"
			launch
			if not (exists playlist tt_playlist) then
				set this_playlist to make new playlist
				set name of this_playlist to tt_playlist
			end if
			add hfsFile to playlist tt_playlist
		end tell				
	|;

	main::TTDebug("Running this applescript:",$the_applescript);
	my $result = `/usr/bin/osascript -e \'$the_applescript\'`;	
	main::TTDebug("Result of applescript run:",$result);
}

# Spawn inspector for more info while downloading
sub OnClickInfo 
{
	my $self = shift;
	my $iframe = Inspector->new($self, $rec);
	$iframe->Show(1);
}


1;