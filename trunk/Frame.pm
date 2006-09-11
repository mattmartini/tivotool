# The GUI frame - draw and handle events for main GUI window
package Frame;
use Wx;
use base 'Wx::Frame';
use Wx qw(:everything);
use Wx::Event qw(EVT_BUTTON EVT_MENU EVT_COMBOBOX EVT_CLOSE EVT_UPDATE_UI EVT_KEY_DOWN EVT_IDLE EVT_TOOL);
use TTConfig;
use CommandLineController;
use RefreshController;
use TTListCtrl;
use TTPrefs;
use Inspector;
use TivoUnit;
use Dialogs::TivoServerDialog;
use Dialogs::MFSExportDownloadDialog;
use Dialogs::FFDownloadDialog;
use Dialogs::MencoderDownloadDialog;
use Dialogs::HdemuxDownloadDialog;
use Dialogs::StreamDialog;
use Dialogs::vSplitDownloadDialog;
use Dialogs::MplexMuxDialog;
use Data::Dumper;
$|++;

my $c = $TTConfig::config;
my $t = TivoUnit->new();
my $rc = RefreshController->new();
my $con = CommandLineController->new();
my $startup = 1; 
our $cur = 0;
our @recs;

# This is for wxwidgets "special" ID system. 
($ID_VSTART, $ID_VSTOP, $ID_SHOW_TIVOSERVER,$ID_SHOW_LOG,$ID_QUIT,$ID_REFRESH,$ID_LIST,$ID_DOWNLOAD,$ID_FIT,$ID_INFO,$ID_WATCH,$ID_TOOL_TOGGLE,$ID_TOOL_DELETE,$ID_TOOL_REFRESH,$ID_TOOL_WATCH,$ID_TOOL_DOWNLOAD,$ID_TOOL_PREFS) = (1..1000);

sub get_local_ips
{
    my @lines = `ifconfig |grep 'inet ' |grep -v '127.0.0.1'`;
    my @local_ips = ();

    foreach (@lines)
    {
        /^.*inet\s(\d+\.\d+.\d+.\d+).*$/;
        push(@local_ips, $1);
    }

	return @local_ips;
}

############################ IDLE EVENT PROCESSING ################################
sub OnIdle 
{
	my $self = shift;
	
	# STARTUP
	if ($startup==1)  
	{
		$startup=0;
		
		main::TTDebug("Starting up from Frame.pm OnIdle()");
		
		$self->{infotext}->SetLabel((@TTListCtrl::row_objects)." recordings.");
				
		if ($c->tivoip eq '0.0.0.0')
		{
			$self->{vservertext}->SetLabel("Looking on local network...");
			Wx::SafeYield;
			
			my $detected = $t->ScanSubnet(get_local_ips());
			if (defined($detected))
			{
				$c->set(TIVOIP, $detected);
				TTConfig::Write;
				TTConfig::Refresh;
				$startup=1;
			}
			else
			{
				$self->OnPrefFrame();
			}
		}

		my $p = $self->Pulse();
		
		$self->OnClickRefresh() if (($c->REFRESHSTARTUP) && ($p > 0));

	}
	
	# EVERY 120 SECONDS
	if ((time() % 120) == 0) 
	{
		$self->Pulse();
	}
	
	# REFRESHING
	if ($rc->Refreshing()==1) 
	{
		if (-e "$main::home/Library/Caches/listings") 
		{
			$self->{infotext}->SetLabel("Populating listings...");
			$self->{list}->Populate();
			$self->ToggleRefreshButton(1);
			$rc->Refreshing(0);
			$self->{infotext}->SetLabel((@TTListCtrl::row_objects+1)." recordings.");
		}
	}
		
}


############################ START/STOP VSERVER #####################################
sub OnStartVserver 
{
	$self = shift;
	
	my @r = $t->StartVserver();
	
	foreach (@r) 
	{ 
		if (/listen failed/) # already running
		{ 
			$self->{vservertext}->SetLabel("Vserver Started");
		} 
		elsif (/waiting for connections/) # success
		{
			$self->{vservertext}->SetLabel("Vserver Started");
		} 
		elsif (/Could not connect/) 
		{
			$self->{vservertext}->SetLabel("Could Not Connect to ".$c->TIVOIP);
		} 
		elsif (/No such file or directory/) 
		{
			$self->{vservertext}->SetLabel("Could not find vserver at ".$c->VSERVERPATH);
		}
	}
}

sub OnStopVserver 
{
	my $self = shift;
	$self->{vservertext}->SetLabel($t->StopVserver());
}


############################ DELETE EVENT #####################################
sub OnClickDelete
{
	my $self = shift;
	return(0) if ($self->Pulse()==0);

	my @result;
	my $do_refresh = undef;
	
	for ( ;; )
	{
		$selrow = $self->{list}->GetNextItem($selrow, wxLIST_NEXT_ALL, wxLIST_STATE_SELECTED);
		last if ($selrow == -1); # outta rows
		
		my $ddialog = Wx::MessageDialog->new( $self, "Are you sure you want to delete the episode \"".@TTListCtrl::row_objects[$selrow]->episode()."\"?\nYou cannot undo this operation.", "Delete ".@TTListCtrl::row_objects[$selrow]->show(), wxYES_NO|wxICON_QUESTION);
		
		unless ($ddialog->ShowModal() == wxID_NO)
		{
			Wx::SafeYield;
			@result = $t->Delete(@TTListCtrl::row_objects[$selrow]->fsid());
			Wx::SafeYield;
			$do_refresh = 1;
		}
		
		main::TTDebug("Result of delete".@result) if ($main::debug==1);
	}
	
	Wx::SafeYield;
	sleep 1;
	$self->OnClickRefresh() if $do_refresh;
}

############################ ITUNES EVENT #####################################
sub OnClickItunes
{
	my $self = shift;	
	return(0) if ($self->Pulse()==0);
	
	# Reset values
    my $selrow = -1;
	$cur = 0;
	@recs = ();
	
	# Close any stray connections
	$con->CloseTivoConnections();
	
	# Populate @recs with selected recordings. Fill their info as we go along.
	for ( ;; )
	{
		$selrow = $self->{list}->GetNextItem($selrow, wxLIST_NEXT_ALL, wxLIST_STATE_SELECTED);
		last if ($selrow == -1); # outta rows
		
		my $filesize = FillInfo($self, $TTListCtrl::row_objects[$selrow]);
		unless ($filesize > 0) { Wx::LogError(Dumper($TTListCtrl::row_objects[$selrow])); Wx::LogError("Could not retrieve filesize. Recording may have been deleted from your Tivo. Please refresh."); $self->Destroy(); }

		@TTListCtrl::row_objects[$selrow]->saveformat("mp4");
		@TTListCtrl::row_objects[$selrow]->itunes_download("1");

		push(@recs, $TTListCtrl::row_objects[$selrow]); 

		$something_selected = 1;
	}

	$self->{dialog} = FFDownloadDialog->new($self, $recs[0]) if ($something_selected == 1);
	$self->{dialog}->ShowModal();
}


############################ DOWNLOAD EVENT #####################################
sub OnClickDownload 
{
	my $self = shift;	
	return(0) if ($self->Pulse()==0);

	# Reset values
	my $something_selected = 0;
	my $choice = $self->{formatchooser}->GetSelection();
    my $selrow = -1;
	$cur = 0;
	@recs = ();
	
	# Close any stray connections
	$con->CloseTivoConnections();
	
	# Populate @recs with selected recordings. Fill their info as we go along.
	for ( ;; )
	{
		$selrow = $self->{list}->GetNextItem($selrow, wxLIST_NEXT_ALL, wxLIST_STATE_SELECTED);
		last if ($selrow == -1); # outta rows
		
		my $filesize = FillInfo($self, $TTListCtrl::row_objects[$selrow]);
		unless ($filesize > 0) { Wx::LogError(Dumper($TTListCtrl::row_objects[$selrow])); Wx::LogError("Could not retrieve filesize. Recording may have been deleted from your Tivo. Please refresh."); $self->Destroy(); }

		if ($choice==0) {
			@TTListCtrl::row_objects[$selrow]->saveformat("ty");
		}
		elsif ($choice==1) {
			@TTListCtrl::row_objects[$selrow]->saveformat("tmf");
		} 
		elsif ($choice==2) {
			@TTListCtrl::row_objects[$selrow]->mux_after_download(1);
			@TTListCtrl::row_objects[$selrow]->saveformat("mpg");
		} 
		elsif ($choice==3) {
			@TTListCtrl::row_objects[$selrow]->mux_after_download(1);
			@TTListCtrl::row_objects[$selrow]->saveformat("vob");
		} 
		elsif ($choice==4) {
			@TTListCtrl::row_objects[$selrow]->saveformat("mpg");
		} 
		elsif ($choice==5) {
			@TTListCtrl::row_objects[$selrow]->saveformat("vob");
		} 
		elsif ($choice==6) {
			@TTListCtrl::row_objects[$selrow]->saveformat("m2v");
			@TTListCtrl::row_objects[$selrow]->saveformat_audio("m2a");
		}
		elsif ($choice==7) {
			@TTListCtrl::row_objects[$selrow]->saveformat("m2v");
			@TTListCtrl::row_objects[$selrow]->saveformat_audio("wav");
		}
		elsif ($choice==8) {
			@TTListCtrl::row_objects[$selrow]->saveformat("avi");
		} 
		elsif ($choice==9) {
			@TTListCtrl::row_objects[$selrow]->itunes_download("0");
			@TTListCtrl::row_objects[$selrow]->saveformat("mp4");
		}		

		push(@recs, $TTListCtrl::row_objects[$selrow]); 
		$something_selected = 1;
	}

	# Start download using selected format
	if ($something_selected == 1) 
	{
		if ($choice==0) {
			$self->{dialog} = MFSExportDownloadDialog->new($self, $recs[0]);
		}
		elsif ($choice==1) {
			$self->{dialog} = MFSExportDownloadDialog->new($self, $recs[0]);
		} 
		elsif ($choice==2) {
			$self->{dialog} = HdemuxDownloadDialog->new($self, $recs[0]);
		} 
		elsif ($choice==3) {
			$self->{dialog} = HdemuxDownloadDialog->new($self, $recs[0]);
		} 
		elsif ($choice==4) {
			$self->{dialog} = vSplitDownloadDialog->new($self, $recs[0]);
		} 
		elsif ($choice==5) {
			$self->{dialog} = vSplitDownloadDialog->new($self, $recs[0]);
		} 
		elsif ($choice==6) {
			$self->{dialog} = HdemuxDownloadDialog->new($self, $recs[0]);			
		}
		elsif ($choice==7) {
			$self->{dialog} = HdemuxDownloadDialog->new($self, $recs[0]);
		}
		elsif ($choice==8) {
			$self->{dialog} = MencoderDownloadDialog->new($self, $recs[0]);
		} 
		elsif ($choice==9) {
			$self->{dialog} = FFDownloadDialog->new($self, $recs[0]);
		}		
	}
	
	$self->{dialog}->ShowModal();

}

############################ STREAM EVENT #####################################
sub OnClickWatch 
{
	my $self = shift;
	return(0) if ($self->Pulse()==0);

	my $selrow = -1;	
	for ( ;; )
	{
		$selrow = $self->{list}->GetNextItem($selrow, wxLIST_NEXT_ALL, wxLIST_STATE_SELECTED);
		last if ($selrow == -1); # outta rows
		
		main::TTDebug("Starting to fill info...");
		
		@TTListCtrl::row_objects[$selrow]->fill_attributes();	
		
		main::TTDebug("Fillinfo done, opening stream window");
		
		my $streamwindow = StreamDialog->new($self, @TTListCtrl::row_objects[$selrow]);
		$streamwindow->Show(1);
	}
}

############################ PREFERENCES ######################################
sub OnPrefFrame 
{
	my $self = shift;
	my $prefs_frame = TTPrefs->new($self, $c);
	$prefs_frame->Show(1);
}

############################ REFRESH EVENTS ######################################
sub OnClickRefresh 
{
	my $self = shift;
	return(0) if ($self->Pulse()==0);

	$rc->DownloadRecordings();
	$self->{infotext}->SetLabel("Refreshing from ".$c->tivoip()."...");
	$self->ToggleRefreshButton(0);
	# At this point, idle routine will detect DownloadRecordings was called and
	# call Populate() when the listings are done downloading
	# (Without blocking IO, yay!)
}

sub ToggleRefreshButton 
{
	my ($self, $o) = @_;
	$self->{refresh_button}->Enable($o);
	$self->{delete_button}->Enable($o);
	$self->{formatchooser}->Enable($o);
	$self->{save_button}->Enable($o);
	$self->{watch_button}->Enable($o);
	$self->{itunes_button}->Enable($o);
	$self->{toolbar}->Enable($o) if $self->{toolbar};
}


############################ INSPECTOR #####################################
sub OnGetInfo 
{
	my $self = shift;
	return(0) if ($self->Pulse()==0);

	my $selrow = -1;
	for ( ;; )
	{
		$selrow = $self->{list}->GetNextItem($selrow, wxLIST_NEXT_ALL, wxLIST_STATE_SELECTED);
		last if ($selrow == -1); # outta rows

		# Get the information from the tivo..
		my $filesize = FillInfo($self, @TTListCtrl::row_objects[$selrow]);
		
		if ($filesize > 0)
		{
			# then populate an inspector with it.
			my $iframe = Inspector->new($self, @TTListCtrl::row_objects[$selrow]);
			$iframe->Show(1);		
		}
		else
		{
			Wx::LogError("Could not retrieve filesize. Recording may have been deleted from your Tivo. Please refresh.");
		}

	}
}

############################# FILL RECORDING INFO #################################
# Populate extended attributes
sub FillInfo 
{
	my ($self, $r) = @_;
	
	$self->{infotext}->SetLabel("Getting description...");
 	$r->fill_description();
	Wx::SafeYield();		

	$self->{infotext}->SetLabel("Getting info...");
  	$r->fill_attributes();	
	Wx::SafeYield();	

	$self->{infotext}->SetLabel("Getting size...");
	$r->fill_size();					
	Wx::SafeYield();	

	$self->{infotext}->SetLabel((@TTListCtrl::row_objects+1)." recordings.");
	
	main::TTDebug("Done filling info...");
	return $r->size;
}

############################# CHECK VSERVER #################################
sub Pulse 
{
	my $self = shift;
	
	$self->{vservertext}->SetLabel("Checking Tivo...");
	Wx::SafeYield;

	my $check = $t->IsVserverUp();	

	if ($check==1)
	{
		$self->{vservertext}->SetLabel("Vserver Running");
	}
	elsif ($check==0) 
	{
		$self->{vservertext}->SetLabel("Vserver not found at ".$c->tivoip.".");
	}
	
	return $check;

}

############################ STARTUP AND SHUTDOWN ################################
sub OnClose 
{
	my $self = shift;

	# Save GUI state
	
	main::TTDebug("Current config width and height".$c->windoww." ".$c->windowh);
	
	my ($w, $h) = $self->GetSizeWH();
	$c->set(WINDOWW, $w);
	$c->set(WINDOWH, $h);

	main::TTDebug("New config width and height".$c->windoww." ".$c->windowh);
		
	my ($x, $y) = $self->GetPositionXY();
	$c->set(WINDOWX, $x);
	$c->set(WINDOWY, $y);	
	
	$c->set(COL1, $self->{list}->GetColumnWidth(0));
	$c->set(COL2, $self->{list}->GetColumnWidth(1));
	$c->set(COL3, $self->{list}->GetColumnWidth(2));
	$c->set(COL4, $self->{list}->GetColumnWidth(3));
	$c->set(COL5, $self->{list}->GetColumnWidth(4));
	
	$c->set(DLMODE, $self->{formatchooser}->GetSelection());

	main::TTDebug("Writing to config file");
	
	TTConfig::Write();
	
	$self->Destroy();
}

############################### FIT COLUMNS ####################################
sub FitColumns 
{
	my $self = shift;
	my $all_cols_width = 0;
	# Resize columns to fit data
	$self->{list}->SetColumnWidth(0,-1);
	$self->{list}->SetColumnWidth(1,-1);
	$self->{list}->SetColumnWidth(2,-1);
	$self->{list}->SetColumnWidth(3,-1);
	$self->{list}->SetColumnWidth(4,-1);
	# Then resize window to fit columns...
	for (my $i=0; $i<5; $i++) { $all_cols_width += $self->{list}->GetColumnWidth($i); }	
	$self->SetSize($all_cols_width+14, -1); # Resize the window to fit the listings.

}


############################### TOOLBAR ####################################
sub CreateTivoToolbar() 
{
	my $self = shift;
	my $toolbar = $self->{toolbar} = $self->CreateToolBar(); # removes some whitespace even if we dont need a toolbar yet

    # Needed for PNG loading
	Wx::InitAllImageHandlers();
	my @file;
	my @bmp;
	for (my $i=0; $i<6; $i++) 
	{
		$file[$i] = IO::File->new("TivoTool.app/Contents/Resources/ico".$i.".png") or die("need icon!\n$! $?");
		binmode $file[$i];
		my $handler = Wx::PNGHandler->new();
		my $image = Wx::Image->new();
		$handler->LoadFile( $image, $file[$i] );
		$bmp[$i] = Wx::Bitmap->new($image);
		$toolbar->SetToolBitmapSize(wxSIZE(32,32));
	}

	$toolbar->AddTool($ID_TOOL_REFRESH, "Refresh", $bmp[0], "Refresh listings", wxITEM_NORMAL );
	$toolbar->AddTool($ID_TOOL_DOWNLOAD, "Save", $bmp[2], "Save", wxITEM_NORMAL );
	$toolbar->AddTool($ID_TOOL_WATCH, "Watch Now", $bmp[1], "Watch Now", wxITEM_NORMAL );
	$toolbar->AddSeparator();
	$toolbar->AddTool($ID_TOOL_DELETE, "Delete Recording", $bmp[4], "Delete Recording", wxITEM_NORMAL );
	$toolbar->AddTool($ID_TOOL_PREFS, "Preferences", $bmp[5], "Preferences", wxITEM_NORMAL );
	
	$toolbar->SetMargins(6,1);
    my $size = $self->GetSize();
	$self->SetSize($size->x,$size->y+32); #+++
	$toolbar->Realize();
}

# Toggle toolbar on/off
sub OnToggleToolbar 
{
  my($self, $event) = @_;
  my $size = $self->GetSize();

  if ($self->{toolbar}) 
  {
	$self->{toolbar}->Destroy();
	$self->SetSize($size->x,$size->y-32);
	$self->{list}->Move(0,-2);
	$c->set(TOOLBAR, 0);
	$self->{toolbar} = undef;
  } 
  else 
  {
	$self->CreateTivoToolbar();
	$self->{list}->Move(0,-2);    
	$self->{toolbar}->Move(0,-32-11);
	$c->set(TOOLBAR, 1);
	$self->{toolbar}->Realize();
  }

}

############################### MENU ITEMS ####################################
sub OnAbout 
{
	my $self = shift;
	my $aboutdialog = Wx::MessageDialog->new($self, "Version: $main::version\n\nUI/TivoTool - John Susek <tivotool\@johnsolo.net>\nOriginal DVD Burning - Cristin Pescosolido\n\nvserver, et al - Andrew Tridgell <tridge\@samba.org>\n\nSpecial thanks to the MPlayer & dvdauthor teams, Joey Parrish for his vstream patches to mplayer, jdiner for vsplit and bcc for hdemux.\n\nThis program is written in Perl, using the wxWidgets toolkit. It was built in Xcode using Camelbones.\n\n JR \"Bob\" Dobbs head property of the Church of the Subgenius.", "Credits", wxOK|wxICON_EXCLAMATION);
	$aboutdialog->ShowModal();
}

############################### SHOW TIVO SERVER ####################################
sub ShowTivoServer
{
	my $self = shift;
	my $tivoserver_window = TivoServerDialog->new($start);
	$tivoserver_window->Show(1);
}

############################### SHOW LOG ####################################
sub ShowLog
{
	my $self = shift;
	my $home = $ENV{'HOME'};
	`open $home/Library/Logs/tivotool.log`;
}

################################# CONSTRUCTOR ####################################
sub new 
{ 
my $ref = shift;

main::TTDebug("Resizing window width and height: ".$c->windoww()." ".$c->windowh());
main::TTDebug("Placing window x and y: ".$c->windowx()." ".$c->windowy());

my $self = $ref->SUPER::new( undef,         # parent window - none in this case, it is the main frame
							 -1,            # wx ID number
							 "TivoTool - Version $main::version",	# title
							 [$c->windowx(), $c->windowy()],      # default position
							 [$c->windoww(), $c->windowh()],      # default size
							 wxDEFAULT_FRAME_STYLE, # styles
							 );

my $lucida = Wx::Font->new(11,wxDEFAULT,wxBOLD,wxNORMAL,0,'Lucida Grande');

$self->{toolbar} = undef;

# Create panel and sizers
my $panel = Wx::Panel->new($self, -1);
my $panel_sizer = Wx::FlexGridSizer->new(1,1,0,0);
$panel_sizer->AddGrowableCol(0);
$panel_sizer->AddGrowableRow(0);
$panel_sizer->AddWindow($panel, 0, wxGROW, 0);
my $root_sizer = Wx::FlexGridSizer->new(2,1,0,0); # 2 rows 1 column
$root_sizer->AddGrowableCol(0);
$root_sizer->AddGrowableRow(0);

# The listings
$self->{list} = TTListCtrl->new($panel, $ID_LIST, [-1,-1], [-1,-1], wxLC_REPORT);    
$self->{list}->BuildColumns(); # Add show, episode, etc columns
$self->{list}->Populate(); # $rc->PopulateRecordings($self);
$root_sizer->Add($self->{list}, 0, wxGROW, 0);

# The buttons
my $box = Wx::StaticBox->new($panel, -1, "", wxDefaultPosition, [-1,-1]);				
my $staticboxsizer = Wx::StaticBoxSizer->new($box, wxVERTICAL);

# Top row 
my $boxgrid_t = Wx::FlexGridSizer->new(0,8,0,0);
$boxgrid_t->AddGrowableCol(6); 
$boxgrid_t->Add(my $refresh = $self->{refresh_button} = Wx::Button->new($panel, -1, "Refresh"), 0, wxALIGN_LEFT|wxLEFT|wxRIGHT|wxBOTTOM, 6);
$boxgrid_t->AddSpace(10,10,0,wxALL,5);
$boxgrid_t->Add(my $delete = $self->{delete_button} = Wx::Button->new($panel, -1, "Delete"), 0, wxALIGN_LEFT|wxLEFT|wxRIGHT|wxBOTTOM, 6);
$boxgrid_t->Add(my $info = $self->{info_button} = Wx::Button->new($panel, -1, "Info"), 0, wxALIGN_LEFT|wxLEFT|wxRIGHT|wxBOTTOM, 6);
$boxgrid_t->AddSpace(10,10,0,wxALL,5);
$boxgrid_t->Add(my $watch = $self->{watch_button} = Wx::Button->new($panel, -1, "Watch Now"), 0,  wxALIGN_LEFT|wxLEFT|wxRIGHT|wxBOTTOM, 6);
$boxgrid_t->Add(my $additunes = $self->{itunes_button} = Wx::Button->new($panel, -1, "Add to iTunes"), 0, wxALIGN_LEFT|wxLEFT|wxRIGHT|wxBOTTOM, 6);
$boxgrid_t->Add(my $download = $self->{save_button} = Wx::Button->new($panel, -1, "Save"), 0, wxALIGN_RIGHT|wxLEFT|wxRIGHT, 76);
$staticboxsizer->Add($boxgrid_t, 0, wxGROW|wxALIGN_CENTER, 0);

# Bottom row
my $boxgrid_b = Wx::FlexGridSizer->new(0,3,0,0);
$boxgrid_b->AddGrowableCol(0);	
$boxgrid_b->AddGrowableCol(1);	
$boxgrid_b->Add($self->{infotext} = Wx::StaticText->new($panel, -1, ""), 0, wxALIGN_LEFT|wxGROW|wxLEFT|wxRIGHT|wxTOP, 6);
$self->{infotext}->SetFont($lucida);
$boxgrid_b->Add($self->{vservertext} = Wx::StaticText->new($panel, -1, ""), 0, wxALIGN_CENTER|wxGROW|wxLEFT|wxRIGHT|wxTOP, 6);
$self->{vservertext}->SetFont($lucida);	
$boxgrid_b->Add( $self->{formatchooser} = Wx::Choice->new($panel, -1, [-1,-1], [-1,-1], ["Tivo Format (.ty)", "Tivo Media Format (.tmf)", "MPEG2 (.mpg)", "DVD Format (.vob)", "MPEG2 alternate (.mpg)", "DVD Format alternate (.vob)", "Unmuxed (.m2v .m2a)", "Unmuxed (.m2v .wav)", "DivX/MP3 (.avi)","MPEG4/AAC (.mp4)"]), 0, wxALIGN_RIGHT|wxLEFT|wxRIGHT|wxBOTTOM, 6);
$self->{formatchooser}->SetSelection($c->dlmode());
$staticboxsizer->Add($boxgrid_b, 0, wxGROW|wxALIGN_CENTER, 0);	
$root_sizer->Add($staticboxsizer, 0, wxGROW|wxALIGN_CENTER|wxALL, 13);
	
# Final layout settings		
$self->SetAutoLayout(1);
$panel->SetAutoLayout(1);
$self->SetSizer($panel_sizer);
$panel->SetSizer($root_sizer);
$panel_sizer->Fit($panel);
$panel_sizer->SetSizeHints($panel);
#main::TTDebug("Minimum width: ",$root_sizer->GetMinSize()->GetWidth());
	

# Menu Bar
my $file_menu = Wx::Menu->new();
my $view_menu = Wx::Menu->new();
my $remote_menu = Wx::Menu->new();
my $tools_menu = Wx::Menu->new();
my $help_menu = Wx::Menu->new();

$help_menu->Append(wxID_ABOUT, "About", "About");
$file_menu->Append(wxID_PREFERENCES, "Preferences...\tCtrl-,", "Preferences...");
$file_menu->Append(wxID_EXIT, "E&xit\tCtrl-X", "Exit $0");
$file_menu->Append($ID_REFRESH, "&Refresh Listings\tCtrl-R","Refresh Listings from your Tivo");
$file_menu->Append($ID_DOWNLOAD,"&Save Selection(s)\tCtrl-S","Save Selection(s)");
$file_menu->Append($ID_WATCH,"Watch &Now\tCtrl-N","Watch Selection(s)");
$view_menu->Append($ID_FIT,"&Autofit Columns\tCtrl-A","Autofit Columns");
$view_menu->Append($ID_INFO,"&Info\tCtrl-I","Info");
$view_menu->Append($ID_TOOL_TOGGLE,"&Toggle Toolbar\tCtrl-T","Toggle Toolbar");
$remote_menu->Append($ID_VSTART,"Start vserver","Start vserver");
$remote_menu->Append($ID_VSTOP,"Stop vserver","Stop vserver");
$tools_menu->Append($ID_SHOW_TIVOSERVER,"TivoServer\tCtrl-1","TivoServer");
$tools_menu->Append($ID_SHOW_LOG,"Log\tCtrl-2","Log");

my $menubar = Wx::MenuBar->new();
$menubar->Append($file_menu, '&File');
$menubar->Append($view_menu, '&View');
$menubar->Append($remote_menu, '&Remote');
$menubar->Append($tools_menu, '&Tools');
$menubar->Append($help_menu, '&Help');
$self->SetMenuBar($menubar);

# Event table
EVT_BUTTON($self, $refresh, \&OnClickRefresh);
EVT_BUTTON($self, $delete, \&OnClickDelete);
EVT_BUTTON($self, $watch, \&OnClickWatch);
EVT_BUTTON($self, $download, \&OnClickDownload);
EVT_BUTTON($self, $additunes, \&OnClickItunes);
EVT_BUTTON($self, $info, \&OnGetInfo);

EVT_MENU($self, wxID_PREFERENCES, \&OnPrefFrame);
EVT_MENU($self, $ID_REFRESH, \&OnClickRefresh);
EVT_MENU($self, $ID_WATCH, \&OnClickWatch);
EVT_MENU($self, $ID_DOWNLOAD, \&OnClickDownload);

EVT_MENU($self, $ID_SHOW_TIVOSERVER, \&ShowTivoServer);
EVT_MENU($self, $ID_SHOW_LOG, \&ShowLog);

EVT_MENU($self, $ID_INFO, \&OnGetInfo);
EVT_MENU($self, $ID_FIT, \&FitColumns);
EVT_MENU($self, wxID_ABOUT, \&OnAbout);
EVT_MENU($self, wxID_EXIT, \&OnClose );
EVT_MENU($self, $ID_TOOL_TOGGLE, \&OnToggleToolbar);

EVT_MENU($self, $ID_VSTART, \&OnStartVserver);
EVT_MENU($self, $ID_VSTOP, \&OnStopVserver);

EVT_IDLE($self, \&OnIdle);
EVT_CLOSE($self, \&OnClose);

EVT_TOOL($self, $ID_TOOL_REFRESH, \&OnClickRefresh);
EVT_TOOL($self, $ID_TOOL_WATCH, \&OnClickWatch);
EVT_TOOL($self, $ID_TOOL_DOWNLOAD, \&OnClickDownload);
EVT_TOOL($self, $ID_TOOL_PREFS, \&OnPrefFrame);
EVT_TOOL($self, $ID_TOOL_DELETE, \&OnClickDelete);

# Keep toolbar state
$self->OnToggleToolbar() if ($c->toolbar()==1);

# Final list header tweak
$self->{list}->Move(0,-4);    


return $self;
}

1;