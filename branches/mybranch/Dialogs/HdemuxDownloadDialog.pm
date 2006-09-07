package HdemuxDownloadDialog;
use strict;
use warnings;
use Wx;
use base 'Wx::ProgressDialog';
use Wx qw(:everything);
use Wx::Event qw(EVT_BUTTON EVT_IDLE);
use Dialogs::FFAudioConvertDialog;
use Dialogs::MplexMuxDialog;
use Data::Dumper;

my $con = CommandLineController->new();
my $out = $TTConfig::config->outputdir();
my $DOWNLOADHANDLE; # the hdemux stdout
my $starttime;
my $pid;
my $after_download = 1;
my $usercontinue = 1;
my ($class, $caller, $rec) = undef;

sub OnIdle {
	my $self = shift;

  	if (kill(0, ($pid+2)) > 0) # If child process still exists 
  	{			 							    
		# Check file progress
		my $filesize = (-s $out."/".$rec->filename().".m2v");
		$filesize += (-s $out."/".$rec->filename().".m2a");
	  	$usercontinue = $self->Update($filesize/1024, 
									  "Downloaded : ".int($filesize/1048576)."MB\n\nAverage rate :     ".
									  int($filesize/1024/((time()-$starttime)==0?1:(time()-$starttime)))."KB/s");
	} 
	else 
	{ 
		if ($after_download > 0) 
		{	
			# Finish up this download
			$after_download = 0;

			# Format specific stuff
			FFAudioConvertDialog->new($caller, $rec) if ($rec->saveformat_audio() eq "wav");
			MplexMuxDialog->new($caller, $rec) if ($rec->mux_after_download() == 1);
			
			# Prepare next in queue
			$Frame::cur++; # increment index
			
			# Launch next queue download
			if ($Frame::cur < @Frame::recs)
			{
				$caller->{dialog} = $class->new($caller, $Frame::recs[$Frame::cur]);
			}
			
			$self->Destroy(); # we are done with this recording & dialog
		} 
	}

	if ($usercontinue==0) 
	{ 
		kill(9, ($pid+2));
		close $DOWNLOADHANDLE;
		$con->CloseTivoConnections();
	}
}

# Spawn inspector for more info while downloading
sub OnClickInfo 
{
	my $self = shift;
	my $iframe = Inspector->new($self, $rec);
	$iframe->Show(1);
}

# CONSTRUCTOR
sub new 
{
	($class, $caller, $rec) = @_;

	# Reset variables
	$after_download = 1;
	$usercontinue = 1;

	# Info about this recording..
	my $max = $rec->size(); # size of video in KB
	my $show = $rec->show(); # name of show
	my $episode = $rec->episode(); # episode title
	my $desc = $rec->description(); # episode description

	my $self = $class->SUPER::new('Downloading (hdemux)... ', 'Please Wait...                  ', $max, $caller, 
		wxPD_CAN_ABORT|wxPD_ELAPSED_TIME|wxPD_REMAINING_TIME|wxPD_AUTO_HIDE);	

	# GUI Elements
	my $fontsm = Wx::Font->new(11,wxDEFAULT,wxNORMAL,wxNORMAL,0,'Lucida Grande');
	my @c = $self->GetChildren();
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
	my $txtQueue = Wx::StaticText->new($self, -1, "Downloading ".($Frame::cur+1)." of ".@Frame::recs);	
	my $txtShow = Wx::StaticText->new($self, -1, "$show");	
	my $txtEpisode = Wx::StaticText->new($self, -1, "$episode");	
	my $txtTotal = Wx::StaticText->new($self, -1, "Total : ".($max/1024)."MB");
	$txtEpisode->SetToolTip($desc);
	$txtShow->SetToolTip($desc);
	$txtTotal->SetFont($fontsm);
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
	my $msizer_h = Wx::BoxSizer->new(wxHORIZONTAL);
	$msizer_h->AddWindow($c[0], 0, wxALIGN_LEFT, 0); # Download text										
	$msizer_h->AddWindow($txtTotal, 0, wxALIGN_RIGHT|wxLEFT, 81); # total.										
	$msizer->Add($msizer_h, 0, wxTOP, 6);

	# Time remaining, etc...
	my $fs=Wx::FlexGridSizer->new(2,2,0,0); 
	$fs->AddWindow($c[2]);									
	$fs->AddWindow($c[3]);								
	$fs->AddWindow($c[4], 0, wxTOP, 3); 
	$fs->AddWindow($c[5], 0, wxTOP, 3);
	$msizer->Add($fs, 0, wxTOP, 29);

	# Stop button
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
	EVT_IDLE($self, \&OnIdle);	# Start download process..

	# Remove files if they already exist
	unlink($out."/".$rec->filename().".m2v");
	unlink($out."/".$rec->filename().".m2a");
	
	# Open hdemux
	my $cmd = $con->build_m2vcommand_h($rec);	

	main::TTDebug($cmd);
	
	$pid = open ($DOWNLOADHANDLE, "$cmd 2>&1 |") or die ("could not start download $!");
	$starttime=time();

    # Finish up class
   	bless($self, $class);
	return $self;
}


1;