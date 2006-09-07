package FFAudioConvertDialog;
use strict;
use base 'Wx::ProgressDialog';
use Wx;
use Wx qw(:everything);
use Wx::Event qw(EVT_BUTTON EVT_IDLE);
use Data::Dumper;

# Class data
my $con = CommandLineController->new();
our $DOWNLOADHANDLE; # the ffmpeg stdout
our $rec; # recording object
our $startup=1; # are we starting up?
our $totalsize; # estimated total size

# Constructor
sub new {
	our ($class, $caller, $rec) = @_;
	our $startup=1;		
	my $max = $rec->duration(); # duration in seconds
	my $show = $rec->show(); # name of show
	my $episode = $rec->episode(); # episode title
	my $desc = $rec->description(); # episode description

	my $self = $class->SUPER::new('Converting Audio to .WAV...', 'Please Wait...                  ', $max, $caller, 
		wxPD_CAN_ABORT|wxPD_ELAPSED_TIME|wxPD_REMAINING_TIME|wxPD_AUTO_HIDE);	
	
	my @c = $self->GetChildren();
	my $fontsm = Wx::Font->new(11,wxDEFAULT,wxNORMAL,wxNORMAL,0,'Lucida Grande');
	for (my $i=0; $i<6; $i++) { $c[$i]->SetFont($fontsm); }

	# My labels
	my $txtShow = Wx::StaticText->new($self, -1, "$show");	
	my $txtEpisode = Wx::StaticText->new($self, -1, "$episode");	
	$txtEpisode->SetToolTip($desc);
	$txtShow->SetToolTip($desc);
	
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
	
	# File size
	$msizer->Add($c[0], 0, wxTOP|wxGROW, 8);

	# Time remaining, etc...
	my $fs=Wx::FlexGridSizer->new(2,2,0,0); 
	$fs->AddWindow($c[2]);									
	$fs->AddWindow($c[3]);								
	$fs->AddWindow($c[4], 0, wxTOP, 3); 
	$fs->AddWindow($c[5], 0, wxTOP, 3);
	$msizer->Add($fs, 0, wxTOP, 6);

	# Stop button
	my $sizer_buttons = Wx::BoxSizer->new(wxHORIZONTAL);
	my $infobut = Wx::Button->new($self, -1, "Info");
	$c[6]->SetLabel("Stop");
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

sub OnIdle {
	my $self = shift;
	# Only do once..
	return unless $startup==1;
	$startup=0;
	
	# Fill values for ffmpeg run
	my $max = $rec->duration();
	my $cmd = $con->build_wavcommand($rec);	

	# Open ffmpeg
	my $pid = open ($DOWNLOADHANDLE, "$cmd 2>&1 |") or die ("could not start download $!");
	local $/ = "\r";
	while (<$DOWNLOADHANDLE>)
	{
		# Grab values from stdout
		/^size=\s*(\d+)kB time=(\d+\.\d) bitrate=\s*(\d+\.\d)kbits\/s.*/;
		# Display
		my $usercontinue = $self->Update($2,"Audio Filesize: ".int($1/1024)."MB");
		# Did user click stop?
		last if ($usercontinue==0);
	}	
	close $DOWNLOADHANDLE;

	$self->Destroy();
}

# Spawn inspector for more info while downloading
sub OnClickInfo {
	my $self = shift;
	my $iframe = Inspector->new($self, $rec);
	$iframe->Show(1);
}


1;