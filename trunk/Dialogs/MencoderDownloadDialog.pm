package MencoderDownloadDialog;
use strict;
use base 'Wx::ProgressDialog';
use Wx;
use Wx qw(:everything);
use Wx::Event qw(EVT_BUTTON EVT_IDLE);
use Data::Dumper;

my $con = CommandLineController->new();
my $conf = $TTConfig::config;
my $out = $conf->outputdir();
my $startup = 1;
our ($class, $caller, $rec);

sub new 
{
	($class, $caller, $rec) = @_;
	
	$startup = 1;		
	
	my $show = $rec->show(); # name of show
	my $episode = $rec->episode(); # episode title
	my $desc = $rec->description(); # episode description

	my $self = $class->SUPER::new('Downloading (mencoder)...', 'Please Wait...                  ', 100, $caller, 
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
	$sizer->AddGrowableRow(0);
	$sizer->AddGrowableCol(0);
	$msizer_h->AddWindow($c[0], 0, wxALIGN_CENTER|wxGROW, 0); # Download text
	$msizer->Add($msizer_h, 0, wxTOP|wxGROW, 6);

	# Time remaining, etc...
	my $fs=Wx::FlexGridSizer->new(2,2,0,0); 
	$fs->AddWindow($c[2]);									
	$fs->AddWindow($c[3]);								
	$fs->AddWindow($c[4], 0, wxTOP, 3); 
	$fs->AddWindow($c[5], 0, wxTOP, 3);
	$msizer->Add($fs, 0, wxTOP, 29);

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
	$startup = 0;
	
	# Fill values for mencoder run
	my $filesize = 0;
	my $last_filesize_update = time(); # the last time filesize was checked on disc
									   # we don't want to do this too often so use this to do only 1/s
	
	my $cmd = $con->build_avicommand($rec);	

	main::TTDebug("Sending this command for mencoder:\n $cmd") if $main::debug = 1;
	
	# Open mencoder
	my $pid = open (MENCODER, "$cmd 2>&1 |") or die ("could not start download $!");
	local $/ = "\r";

	while (<MENCODER>)
	{
		# Grab values from stdout
		/^Pos:\s*(\d+\.\d)s\s+(\d*)f\s+\(\s*(\d+)%\)\s+(\d+)fps\sTrem:\s+(\d+)min\s+(\d+)mb/;
		
		next unless ($2); # this isn't the status line.. move on
		next unless (($3<=100) && ($3>=0)); # ditto
				
		if ((time - $last_filesize_update) > 0) # time since last check on disc
		{
			$filesize = (-s $out."/".$rec->filename().".avi");
			$last_filesize_update = time;
		}
		
		# Update dialog
		my $usercontinue = $self->Update($3, "Complete: $3"."%"."                                          ".int($filesize/1048576).
			" of "."$6"."MB\n\nCompressing :    $4 frames/sec");

		last if ($usercontinue==0);
	}	

	close MENCODER or print("Mencoder was not properly closed $!\n");

	# Launch next queue download
	$Frame::cur++; # increment index
	
	# Go to next if it exists
	if ($Frame::cur < @Frame::recs)
	{
		$caller->{dialog} = $class->new($caller, $Frame::recs[$Frame::cur]);
	}

	$self->Destroy();
}

# Spawn inspector for more info while downloading
sub OnClickInfo 
{
	my $self = shift;
	my $iframe = Inspector->new($self, $rec);
	$iframe->Show(1);
}

1;