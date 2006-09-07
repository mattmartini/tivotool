package vSplitDownloadDialog;
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
my $DOWNLOADHANDLE;
my $starttime;
my $pid;
my $after_download = 1;
my $usercontinue = 1;
my ($class, $caller, $rec) = undef;

sub new 
{
	($class, $caller, $rec) = @_;		
		
	$after_download = 1;
	$usercontinue = 1;
		
	my $max = $rec->size(); # size of video in KB
	my $show = $rec->show(); # name of show
	my $episode = $rec->episode(); # episode title
	my $desc = $rec->description(); # episode description

	my $self = $class->SUPER::new('Downloading (vsplit)...', 'Please Wait...                  ', $max, $caller, 
		wxPD_CAN_ABORT|wxPD_ELAPSED_TIME|wxPD_REMAINING_TIME|wxPD_AUTO_HIDE);	

	# GUI Elements
	my @ch = $self->GetChildren();
	my $fontsm = Wx::Font->new(11,wxDEFAULT,wxNORMAL,wxNORMAL,0,'Lucida Grande');
	for (my $i=0; $i<6; $i++) { $ch[$i]->SetFont($fontsm); }

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
	$txtEpisode->SetToolTip($desc);
	$txtShow->SetToolTip($desc);
	my $txtTotal = Wx::StaticText->new($self, -1, "Total : ".($max/1024)."MB");
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
	my $infobut = Wx::Button->new($self, -1, "Info");
	$ch[6]->SetLabel("Stop");
	$sizer_buttons->AddWindow($txtQueue, 0, wxALIGN_RIGHT|wxTOP|wxRIGHT, 11); # x of x
	$sizer_buttons->AddSpace(16, 0, 0, wxALIGN_CENTER|wxALL, 5);	
	$sizer_buttons->AddWindow($infobut, 0, wxALIGN_RIGHT|wxTOP|wxRIGHT, 6); # info button
	$sizer_buttons->AddWindow($ch[6], 0, wxALIGN_RIGHT|wxLEFT|wxTOP, 6); # Stop button
	$msizer->Add($sizer_buttons, 0, wxALIGN_RIGHT|wxTOP, 6); 
	
	$sizer->Add($msizer);										
	$sizer->AddSpace(14, 20, 0, wxALIGN_CENTER|wxALL, 5);
	$sizer->AddSpace(10,10,0,wxALL,5);	$sizer->AddSpace(10,10,0,wxALL,5);	$sizer->AddSpace(10,10,0,wxALL,5);
	$self->SetAutoLayout(1);
    $self->SetSizer( $sizer );
    $sizer->Fit( $self );
    $sizer->SetSizeHints( $self );
    
    # Events
    EVT_BUTTON($self, $infobut, \&OnClickInfo);
	EVT_IDLE($self, \&OnIdle);

	# Begin the main download method
	StartDownload($self);
	
    # Finish up class
   	bless($self, $class);
	return $self;
}

sub StartDownload
{
	my $self = shift;
	my $cmd;
	
	if ($rec->saveformat() eq "mpg") 
	{ 
		$cmd = $con->build_mpg2command_v($rec); 
	}
	else 
	{ 
		$cmd = $con->build_vobcommand_v($rec); 
	}
	
	if (-e $out."/".$rec->filename().".".$rec->saveformat())
	{
		unlink($out."/".$rec->filename().".".$rec->saveformat());
	}
	
	main::TTDebug($cmd) if $main::debug==1;
	
	$pid = open($DOWNLOADHANDLE, "$cmd 2>&1 |") or die ("could not start download $!");
	
	$starttime=time()+2;
}

sub OnIdle 
{
	my $self = shift;

	if (kill(0, ($pid+2)) > 0) # If child process still exists 
  	{			 				
		my $filesize = (-s $out."/".$rec->filename().".".$rec->saveformat())/1024.0;
		$usercontinue = $self->Update($filesize,
										 "Downloaded : ".int($filesize/1024)."MB\n\nAverage rate :     ".
										 int($filesize/((time()-$starttime)==0?1:(time()-$starttime)))."KB/s" );
	}
	else 
	{ 		
		if ($after_download > 0) 
		{	
			# Finish up this download
			$after_download = 0;
			
			# Format specific stuff
			chmod 0664, $out."/".$rec->filename().".".$rec->saveformat();
			unlink($out."/".$rec->filename().".".$rec->saveformat().".chp");
			
			# Prepare next in queue
			$Frame::cur++; # increment index		
			
			# Launch next queue download
			if ($Frame::cur < @Frame::recs)
			{
				$caller->{dialog} = $class->new($caller, $Frame::recs[$Frame::cur]);
			}
			
			$self->Destroy();
		}
	}
	
	if ($usercontinue==0)
	{
		close $DOWNLOADHANDLE or print "Couldn't close. $!\n";
		$con->CloseTivoConnections();
		chmod 0664, $out."/".$rec->filename().".".$rec->saveformat();
		unlink($out."/".$rec->filename().".".$rec->saveformat().".chp");
		$self->Destroy();
	}
	
}

# spawn inspector based on current recording
sub OnClickInfo 
{
	my $self = shift;
	my $iframe = Inspector->new($self, $rec);
	$iframe->Show(1);
}


1;