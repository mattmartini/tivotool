package MplexMuxDialog;
use warnings;
use strict;
use Data::Dumper;

use base 'Wx::ProgressDialog';
use Wx;
use Wx qw(:everything);
use Wx::Event qw(EVT_BUTTON EVT_IDLE);

my $con = CommandLineController->new();
my $c = $TTConfig::config;
my $out = $c->outputdir();
my $MUXHANDLE;
my $starttime;
my $pid;
my $usercontinue = 1;
my ($class, $caller, $rec) = undef;

sub new 
{
	($class, $caller, $rec) = @_;		
		
	$usercontinue = 1;
		
	my $max = $rec->size(); # size of video in KB
	my $show = $rec->show(); # name of show
	my $episode = $rec->episode(); # episode title
	my $desc = $rec->description(); # episode description

	my $self = $class->SUPER::new('Muxing (mplex)...', 'Please Wait...                  ', $max, $caller, 
		wxPD_CAN_ABORT|wxPD_ELAPSED_TIME|wxPD_REMAINING_TIME|wxPD_AUTO_HIDE);	

	# GUI Elements
	my @ch = $self->GetChildren();
	my $fontsm = Wx::Font->new(11,wxDEFAULT,wxNORMAL,wxNORMAL,0,'Lucida Grande');
	for (my $i=0; $i<6; $i++) { $ch[$i]->SetFont($fontsm); }

	# My labels
	my $txtShow = Wx::StaticText->new($self, -1, "$show");	
	my $txtEpisode = Wx::StaticText->new($self, -1, "$episode");	
	$txtEpisode->SetToolTip($desc);
	$txtShow->SetToolTip($desc);
	my $txtTotal = Wx::StaticText->new($self, -1, "Total : ".($max/1024)."MB");
	$txtTotal->SetFont($fontsm);
	
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
	$msizer->AddWindow($ch[1], 0, wxALIGN_LEFT|wxTOP, 12); # Gauge										
	
	# File size; current and total
	my $msizer_h = Wx::BoxSizer->new(wxHORIZONTAL);
	$msizer_h->AddWindow($ch[0], 0, wxALIGN_LEFT, 0); # Download text										
	$msizer_h->AddWindow($txtTotal, 0, wxALIGN_RIGHT|wxLEFT, 81); # total.										
	$msizer->Add($msizer_h, 0, wxTOP, 6);

	# Time remaining, etc...
	my $fs=Wx::FlexGridSizer->new(2,2,0,0); 
	$fs->AddWindow($ch[2]);									
	$fs->AddWindow($ch[3]);								
	$fs->AddWindow($ch[4], 0, wxTOP, 3); 
	$fs->AddWindow($ch[5], 0, wxTOP, 3);
	$msizer->Add($fs, 0, wxTOP, 29);

	# Stop button
	my $sizer_buttons = Wx::BoxSizer->new(wxHORIZONTAL);
	$ch[6]->SetLabel("Stop");
	$sizer_buttons->AddWindow($ch[6], 0, wxALIGN_RIGHT|wxLEFT|wxTOP, 6); # Stop button
	$msizer->Add($sizer_buttons, 0, wxALIGN_RIGHT|wxTOP, 6); 
	
	$sizer->Add($msizer);										
	$sizer->AddSpace(14, 20, 0, wxALIGN_CENTER|wxALL, 5);
	$sizer->AddSpace(10,10,0,wxALL,5);	$sizer->AddSpace(10,10,0,wxALL,5);	$sizer->AddSpace(10,10,0,wxALL,5);
	$self->SetAutoLayout(1);
    $self->SetSizer( $sizer );
    $sizer->Fit( $self );
    $sizer->SetSizeHints( $self );
	
	my @position = $self->GetPositionXY();
    $self->SetSize(-1,($position[0]+220),-1,-1);
	
    # Events
	EVT_IDLE($self, \&OnIdle);

	# Begin the main download method
	StartMux($self);
	
    # Finish up class
   	bless($self, $class);
	return $self;
}

sub StartMux
{
	my $self = shift;
	my $cmd;
	
	if ($rec->saveformat() eq "mpg") 
	{ 
		$cmd = $con->build_muxcommand_mpg($rec); 
	}
	else 
	{ 
		$cmd = $con->build_muxcommand_vob($rec); 
	}
	
	if (-e $out."/".$rec->filename().".".$rec->saveformat())
	{
		unlink($out."/".$rec->filename().".".$rec->saveformat());
	}
	
	main::TTDebug($cmd) if $main::debug==1;
	
	$pid = open($MUXHANDLE, "$cmd 2>&1 |") or die ("could not start download $!");
	
	$starttime=time()+2;
}

sub OnIdle 
{
	my $self = shift;

	if (kill(0, ($pid+1)) > 0) # If child process still exists 
  	{			 				
		my $filesize = (-s $out."/".$rec->filename().".".$rec->saveformat())/1024.0;
		$usercontinue = $self->Update($filesize,
										 "Muxed : ".int($filesize/1024)."MB\n\nAverage rate :      ".
										 int($filesize/((time()-$starttime)==0?1:(time()-$starttime))/1024)."MB/s" );
	}
	else 
	{ 		
		unlink($out."/".$rec->filename().".m2v");
		unlink($out."/".$rec->filename().".m2a");
		$self->Destroy();
	}
	
	if ($usercontinue==0)
	{
		close $MUXHANDLE or print "Couldn't close. $!\n";
		$self->Destroy();
	}
	
}


#########################################################################
#	MUX FILES
#########################################################################
#sub Mux {
#	my ($self, $m2v, $m2a, $outpath, $format, $buf, $avoffset, $rate) = @_;
#	my $name = $outpath;
#	$name =~ s!.*/!!;	
#	my $lastframe = my $totalsize = my $filesize = ();
#	$totalsize = -s "$m2v";
#	$totalsize = $totalsize+(-s "$m2a"); 
#	
#	my $f = "-f $format ";
#	if ($cp->PROFILE_CHOOSE eq "1") { $f = "-f ".$cp->PROFILE." "; }
#	
#	my $opts = "-b $buf ";
#	if ($cp->BUFSIZE_CHOOSE eq "1") {  $opts = "-b ".$cp->BUFSIZE." "; }
#
#	if ($cp->MUXRATE_CHOOSE eq "1") {
#		$opts = $opts." -r ".$cp->MRATE." ";
#	} else {
#		$opts = $opts." -r $rate ";
#	}
#
#	if ($cp->VBR eq "1") { 
#		$opts = $opts." -V "; 
#	}
#	
#	if ($cp->MSEG eq "1") { 
#		$opts = $opts." -M "; 
#	}
#	
#	if ($cp->SECSIZE_CHOOSE eq "1") { $opts = $opts." -s ".$cp->SECSIZE." "; }
#
#	if ($cp->PACKP_CHOOSE eq "1") { $opts = $opts." -p ".$cp->PACKP." "; }
#
#	open (DEBUG,">> $home/Library/Logs/tivotool.log");
#	print DEBUG "\n".localtime(time)." ************************************************** \n";
#	print DEBUG localtime(time)." * Starting mplex (format $format) (offset $avoffset) \n * (opts $opts) \n";
#	print DEBUG localtime(time)." * Output file: '$outpath' \n";
#	print DEBUG localtime(time)." * Video: '$m2v' \n";
#	print DEBUG localtime(time)." * Audio: '$m2a' \n";
#	print DEBUG localtime(time)." * Size of a/v streams: $totalsize"."k\n";
#   print DEBUG localtime(time)." ************************************************** \n";
#	print DEBUG localtime(time)." Mplex command line: \n".$cp->MPLEX." $f -O $avoffset"."ms $opts -o \'$outpath\' \'$m2v\' \'$m2a\' 2>&1 | \n";
#
#	`rm /tmp/mplex.done`;
#
#	my $mplex_dialog = Wx::ProgressDialog->new(
#		"Muxing MPEG2",		# Window Title
#		"Please Wait...                                                          ",	# Text above progress bar
#		 $totalsize,										# The max value
#		 $self,
#		 wxPD_ELAPSED_TIME| wxPD_REMAINING_TIME| wxPD_AUTO_HIDE,
#	 );
#
#	open(MPLEX, $cp->MPLEX." $f -O $avoffset"."ms $opts -o \'$outpath\' \'$m2v\' \'$m2a\' 2>>$home/Library/Logs/tivotool.log && touch /tmp/mplex.done |");
#	
#	while (!-e "/tmp/mplex.done") {
#		
#		$filesize = (-s "$outpath");
#			
#		if ($filesize < $totalsize) { 
#			$mplex_dialog->Update($filesize,"$name");
#		}
#	}
#	
#	print DEBUG localtime(time)." Mplex done.\n";
#	last;
#
#	close MPLEX;
#	$mplex_dialog->Destroy();
#
#
#}



1; 