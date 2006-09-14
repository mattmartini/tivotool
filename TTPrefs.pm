package TTPrefs;
use AppConfig;
use Tie::File;
use Data::Dumper;
use base 'Wx::Frame';
use Wx qw(:everything);
use Wx::Event qw(EVT_BUTTON EVT_MENU EVT_COMBOBOX EVT_UPDATE_UI EVT_TOOL_ENTER EVT_LIST_COL_CLICK EVT_CHECKBOX EVT_CHOICE);
my ($ID_ADD_FAV, $ID_REMOVE_FAV, $ID_EDIT_FAV, $ID_ENABLE_SCHED, $ID_RADIOBOX, $ID_NOTEBOOK, $ID_BUTTON, $ID_SLIDER, $ID_CLSPRF, $ID_BON, $PB1ID, $ID_BITSLIDER, $ID_BTC, $ID_HOUR, $ID_MINUTE, $ID_AMPM, $SCBTNID, $RSBTNID ) = (1001..2000);
$|++;

my $home = $ENV{'HOME'};
my @fav_file = (); # the user's favorites on disk
my @ips = (); # ip addr's of tivos found with bonjour
my ($ref, $caller, $c);

my $smallfont = Wx::Font->new(10, wxSWISS, wxNORMAL, wxNORMAL, 0, 'Lucida Grande');
my $boldfont = Wx::Font->new(11, wxSWISS, wxBOLD, wxBOLD, 0, 'Lucida Grande');
my $mediumfont = Wx::Font->new(11, wxSWISS, wxNORMAL, wxNORMAL, 0, 'Lucida Grande');


#################### ADD A FAVORITE #######################
sub OnAddFav 
{ 	
	my ($self, $event) = @_;
	my $dialog = Wx::TextEntryDialog->new($self, "Please enter the exact name of the show to add as a favorite.", "Add Favorite", "", wxOK|wxCANCEL, [-1,-1]);
	
	if ($dialog->ShowModal() == wxID_OK)
	{
		push(@fav_file, $dialog->GetValue());
		$self->{favlist}->Set(\@fav_file);
	}
	
}

#################### EDIT SELECTED FAVORITE #######################
sub OnEditFav 
{ 
	my $self = shift;
	if ($self->{favlist}->GetSelection() >= 0)
	{
		my $dialog = Wx::TextEntryDialog->new($self, "Enter new name for show.", "Edit Favorite", 
			@fav_file[$self->{favlist}->GetSelection], 
			wxOK|wxCANCEL, [-1,-1]);
			
		if ($dialog->ShowModal() == wxID_OK)
		{
			@fav_file[$self->{favlist}->GetSelection] = $dialog->GetValue(); 
			$self->{favlist}->Set(\@fav_file);
		}
	}
}

#################### REMOVE SELECTED FAVORITE #######################
sub OnRemoveFav 
{ 
	my $self = shift;
	if ($self->{favlist}->GetSelection() >= 0)
	{
		splice(@fav_file, $self->{favlist}->GetSelection, 1);
		$self->{favlist}->Set(\@fav_file);
	}
}

#################### RESET SEEN RECS #######################
sub OnResetSeen { unlink("$home/Library/Preferences/tivotool.seen"); }

#################### ADD OR REMOVE OUR CRON ENTRY #######################
sub OnToggleCron
{
	my ($self, $event) = @_;
	
	main::TTDebug("Toggling scheduler status...");
	
	my $hour = $self->{chooser_hour}->GetSelection + (12*($self->{chooser_ampm}->GetSelection));
	my $cronline = $self->{chooser_minute}->GetSelection." ".$hour." * * * \"/Library/Application\ Support/TivoTool/start-scheduler\"";
	
	if ($self->{schedcheck}->IsChecked())
	{
		main::TTDebug("Starting scheduler...");

		$self->{cronstatus}->SetLabel("Starting...");

		main::TTDebug("Getting old cron...");
		
		my @oldcron = `crontab -l`;

		open (CRON, "| crontab") or die($!);
		foreach (@oldcron) { print CRON unless (/.*TivoTool.*/); } # skip previous value
		print CRON "$cronline\n";
		close CRON or die($!);

		main::TTDebug("Finished adding our entry...");
		
		#$self->{light}->SetBitmap($bmp_off);
		$self->{cronstatus}->SetLabel("Started");
		
		main::TTDebug("Done setting bitmap and label.");
	}
	else
	{
		main::TTDebug("Removing our cron entry.");
		$self->{cronstatus}->SetLabel("Stopping...");
		my @oldcron = `crontab -l`;

		open (CRON, "| crontab") or die($!);
		foreach (@oldcron) { print CRON unless (/.*TivoTool.*/); } # skip previous value
		close CRON or die($!);
		
		main::TTDebug("Turning off status light...");

		#$self->{light}->SetBitmap($bmp_off);
		$self->{cronstatus}->SetLabel("Stopped");		 	
	}
}

#################### DISCOVER SERIES 2 TIVOS #######################
sub OnFindTivo 
{
	my $self = shift;
	my $res = Net::Rendezvous->new('tivo_videos');
	$res->discover;
	foreach my $entry ($res->entries) 
	{
		my $i = $entry->address;
		push (@ips, $i);
	}
	$self->{addressbox2}->Clear();
	foreach (@ips) 
	{
		$self->{addressbox2}->Append($_);
	}
	$self->{addressbox2}->SetValue($ips[0]);
}

#################### BROWSE FOR SAVE LOCATION #######################
sub BrowseForOut 
{
	my $self = shift;
	my $ddialog = Wx::DirDialog->new( $self, "Save Location", $home);
	unless ($ddialog->ShowModal() == wxID_CANCEL) 
	{
		my $result = $ddialog->GetPath();
		$self->{outtext}->SetLabel($result); 
	}
}

#################### RESET PREFS #######################
sub ResetPrefs 
{
	my $self = shift;
	my $ddialog = Wx::MessageDialog->new( $self, "Are you sure you want to reset your settings?\n(TivoTool must be restarted after reset.)", "Reset", wxYES_NO|wxICON_INFORMATION|wxNO_DEFAULT);
	unless ($ddialog->ShowModal() == wxID_NO)
	{
		unlink("$home/Library/Preferences/tivotool.conf");
		$caller->Destroy();
	}

}

#################### CLOSE WINDOW #######################
sub ClosePrefs 
{
	my $self = shift;

	# Update config hash from the controls
	$c->set(TIVOIP, $self->{addressbox2}->GetValue());
	$c->set(OUTPUTDIR, $self->{outtext}->GetLabel());
	$c->set(DLMODE_AUTO, $self->{autoformatchooser}->GetSelection());
	$c->set(AUTO_HOUR, $self->{chooser_hour}->GetSelection());
	$c->set(AUTO_MINUTE, $self->{chooser_minute}->GetSelection());
	$c->set(AUTO_AMPM, $self->{chooser_ampm}->GetSelection());
	$c->set(CACHE, $self->{cslider}->GetValue());
	$c->set(CACHEMIN, $self->{cmslider}->GetValue());
	$c->set(BITRATE, $self->{bitslider}->GetValue());
#	$c->set(TWOPASS, $self->{radiobox3}->GetSelection());
	$c->set(DEINT, $self->{radiobox4}->GetSelection());
	$c->set(CROP_LEFT, $self->{lcrop}->GetValue());
	$c->set(CROP_RIGHT, $self->{rcrop}->GetValue());
	$c->set(CROP_TOP, $self->{tcrop}->GetValue());
	$c->set(CROP_BOTTOM, $self->{bcrop}->GetValue());
	$c->set(RESIZE_W, $self->{wresize}->GetValue());
	$c->set(RESIZE_H, $self->{hresize}->GetValue());
	$c->set(STREAM_ASPECT, $self->{stream_aspect}->GetSelection());
	$c->set(BBPATH, $self->{bbpath}->GetValue());
	$c->set(VSERVERPATH, $self->{vserverpath}->GetValue());

	# these won't return 0, so can't set right from control like above..
	if ($self->{stream_deint}->GetValue() == 1)       {	$c->set(STREAM_DEINT, 1);		} else {	$c->set(STREAM_DEINT, 0); }	
	if ($self->{stream_denoise}->GetValue() == 1)     {	$c->set(STREAM_DENOISE, 1);		} else {	$c->set(STREAM_DENOISE, 0); }
	if ($self->{stream_crop}->GetValue() == 1)        {	$c->set(STREAM_CROP, 1);		} else {	$c->set(STREAM_CROP, 0); }
	if ($self->{framedrop}->GetValue() == 1)          {	$c->set(FRAMEDROP, 1);			} else {	$c->set(FRAMEDROP, 0); }
	if ($self->{schedcheck}->GetValue() == 1)         {	$c->set(SCHED_ENABLE, 1);		} else {	$c->set(SCHED_ENABLE, 0); }	
	if ($self->{refresh_on_startup}->GetValue() == 1) { $c->set(REFRESHSTARTUP, 1);		} else {	$c->set(REFRESHSTARTUP, 0); }
		
	# Save them to the file..
	TTConfig::Write();

	untie @fav_file;
	$self->Close();
}

my $file, $file2;
my $handler, $image, $image2;
my $bmp_on;
my $bmp_off;

########################### PREF FRAME CONSTRUCTOR ############################
sub new 
{
    ($ref, $caller, $c) = @_;

    my $self = $ref->SUPER::new( $caller, 410, 'TivoTool Preferences',	[-1, -1], [334, 580],
								 wxMINIMIZE_BOX | wxSYSTEM_MENU | wxCAPTION | wxCLOSE_BOX);


	
	# Load status icons

	main::TTDebug("Loading icon files...");
	$file = IO::File->new("TivoTool.app/Contents/Resources/light-on.png") or die("need icon!\n$! $?");
	$file2 = IO::File->new("TivoTool.app/Contents/Resources/light-off.png") or die("need icon!\n$! $?");
	binmode $file;
	binmode $file2;

	main::TTDebug("Binmode done. Creating handler...");
	$handler = Wx::PNGHandler->new();

	main::TTDebug("Creating WxImages");
	$image = Wx::Image->new();
	$image2 = Wx::Image->new();

	main::TTDebug("Loading files into images...");
	$handler->LoadFile( $image, $file );
	$handler->LoadFile( $image2, $file2 );

	main::TTDebug("Creating WxBitmaps from wxImages");
	$bmp_on = Wx::Bitmap->new($image);
	$bmp_off = Wx::Bitmap->new($image2);


	# PREFS FILE MENU
	my $prefs_file_menu = Wx::Menu->new();
	my $prefs_menubar = Wx::MenuBar->new();
	$prefs_file_menu->Append ($ID_CLSPRF,"Close &Window\tCtrl-W","Save and Close Preferences");
	$prefs_menubar->Append($prefs_file_menu, '&File');
	$self->SetMenuBar($prefs_menubar);	
	EVT_MENU($self, $ID_CLSPRF, \&ClosePrefs);
	
	# Sizers
    my( $flexsizer) = Wx::FlexGridSizer->new( 0, 1, 0, 0 );
    $flexsizer->AddGrowableCol( 0 );
    $flexsizer->AddGrowableRow( 0 );
	
	# Create notebook
	my( $notebook ) = Wx::Notebook->new( $self, -1, wxDefaultPosition, wxDefaultSize, 0 );
	my( $nnotebook ) = $notebook;
	if( Wx->VERSION < 0.21 ) { $nnotebook = Wx::NotebookSizer->new( $notebook ); }


	#####################################################################################
	#   General Dialog
	#####################################################################################
	my( $pageGeneral ) = Wx::Panel->new( $notebook, -1 );

	my( $remote_sizer ) = Wx::FlexGridSizer->new( 3, 1, 0, 0 );

	$remote_sizer->AddGrowableCol( 0 );
			
	# ADDRESS
	my( $sboxg ) = Wx::StaticBox->new( $pageGeneral, -1, "Tivo Address", wxDefaultPosition, [-1,-1] );				
	my( $boxsizer_address ) = Wx::StaticBoxSizer->new( $sboxg, wxVERTICAL );

	my $textintro = Wx::StaticText->new( $pageGeneral, -1, "", wxDefaultPosition, [-1,-1], 0 );
	$self->{textintro} = $textintro;
	$self->{textintro}->SetFont($boldfont);

	$boxsizer_address->AddWindow( $textintro, 0, wxALIGN_CENTER_VERTICAL|wxALL, 5 );

	my( $boxsizer_address2 ) = Wx::BoxSizer->new( wxHORIZONTAL );

		my $address2 = Wx::ComboBox->new( $pageGeneral, -1, "",  wxDefaultPosition, [162, -1], \@ips);
		$self->{addressbox2} = $address2;
		$boxsizer_address2->AddWindow( $address2, 0, wxALIGN_CENTER|wxALL, 5 );

		my( $bon_but ) = Wx::Button->new( $pageGeneral, $ID_BON, "Bonjour", wxDefaultPosition, wxDefaultSize, 0 );
		$bon_but->SetToolTip("Detect Tivo Address (Series 2 Only)");
		$boxsizer_address2->AddWindow( $bon_but, 0, wxALIGN_CENTER|wxLEFT, 26 );

	$boxsizer_address->Add( $boxsizer_address2, 0, wxALIGN_CENTER_VERTICAL|wxALL, 5 );

	$remote_sizer->Add( $boxsizer_address, 0, wxALIGN_CENTER_HORIZONTAL|wxBOTTOM|wxLEFT|wxRIGHT|wxGROW, 5 );

	# SAVE 
	my( $sbox ) = Wx::StaticBox->new( $pageGeneral, -1, "Save Location", wxDefaultPosition, [-1,-1] );	
	$self->{sbox} = $sbox;			
	my $locsizer = Wx::StaticBoxSizer->new( $sbox, wxHORIZONTAL );
	$self->{locsizer} = $locsizer;
	
	my $stext = Wx::StaticText->new( $pageGeneral, -1, "", wxDefaultPosition, [-1,-1], 0 );
	$self->{outtext} = $stext;
	$self->{outtext}->SetFont($smallfont);
	$locsizer->AddWindow( $stext, 0, wxALIGN_CENTER_VERTICAL|wxTOP|wxLEFT|wxRIGHT, 2 );

	my $br_but = Wx::Button->new( $pageGeneral, $PB1ID, "Browse", wxDefaultPosition, wxDefaultSize, 0 );
	$self->{br_but} = $br_but;
	$locsizer->AddWindow( $br_but, 0, wxALIGN_CENTER|wxALL, 5 );

	$remote_sizer->Add( $locsizer, 0, wxALIGN_CENTER_HORIZONTAL|wxALL|wxGROW, 5 );


	# BUSYBOX
	my $macrobox3 = Wx::StaticBox->new( $pageGeneral, -1, "Tivo Paths (for remote vserver start/stop)", wxDefaultPosition, [-1,-1] );				
	my $boxsizer_path_2  = Wx::StaticBoxSizer->new( $macrobox3, wxVERTICAL );

	my $bbtext = Wx::StaticText->new( $pageGeneral, -1, "Location of Busybox", wxDefaultPosition, wxDefaultSize, 0 );
	$boxsizer_path_2->AddWindow( $bbtext, 0, wxALIGN_CENTER|wxALL|wxGROW, 5 );
	$bbtext->SetFont($mediumfont);

	$self->{bbpath} = Wx::TextCtrl->new( $pageGeneral, -1, "", wxDefaultPosition, [-1, -1]);
	$boxsizer_path_2->AddWindow( $self->{bbpath}, 0, wxALIGN_CENTER|wxALL|wxGROW, 5 );

	my $vstext = Wx::StaticText->new( $pageGeneral, -1, "Location of vserver", wxDefaultPosition, wxDefaultSize, 0 );
	$boxsizer_path_2->AddWindow( $vstext, 0, wxALIGN_CENTER|wxALL|wxGROW, 5 );
	$vstext->SetFont($mediumfont);

	$self->{vserverpath} = Wx::TextCtrl->new( $pageGeneral, -1, "", wxDefaultPosition, [-1, -1]);
	$boxsizer_path_2->AddWindow( $self->{vserverpath}, 0, wxALIGN_CENTER|wxALL|wxGROW, 5 );

	$remote_sizer->Add( $boxsizer_path_2, 0, wxALIGN_CENTER_HORIZONTAL|wxALL|wxGROW, 5 );
	
	
	# OTHER
	my $sbox2 = Wx::StaticBox->new( $pageGeneral, -1, "Other", wxDefaultPosition, [-1,-1] );	
	my $locsizer2 = Wx::StaticBoxSizer->new( $sbox2, wxVERTICAL );

	$self->{refresh_on_startup} = my $refresh_on_startup = Wx::CheckBox->new( $pageGeneral, -1, "Refresh Listings on Launch");					
	$locsizer2->AddWindow( $refresh_on_startup, 0, wxALIGN_CENTER_VERTICAL|wxTOP|wxLEFT|wxRIGHT, 2 );

	$remote_sizer->Add( $locsizer2, 0, wxALIGN_CENTER_HORIZONTAL|wxALL|wxGROW, 5 );

	$pageGeneral->SetSizer( $remote_sizer );
	$remote_sizer->SetSizeHints( $pageGeneral );

	$notebook->AddPage( $pageGeneral, "General" );
	#####################################################################################

	#####################################################################################
	#    Streaming Dialog
	#####################################################################################
	my( $pageStream ) = Wx::Panel->new( $notebook, -1 );

	my( $strflexsizer ) = Wx::FlexGridSizer->new( 4, 1, 0, 0 );
	$strflexsizer->AddGrowableCol( 0 );

	my $sbox3a = Wx::StaticBox->new( $pageStream, -1, "Video Quality" );
	my $qualitysizer = Wx::StaticBoxSizer->new( $sbox3a, wxVERTICAL);

	$self->{stream_deint} = Wx::CheckBox->new( $pageStream, 432, "Deinterlace Video" );
	$self->{stream_deint}->SetToolTip("Remove \"Combing\" Artifacts");
	$qualitysizer->AddWindow( $self->{stream_deint}, 0, wxALIGN_LEFT|wxTOP|wxBOTTOM, 5 );

	$self->{stream_denoise} = Wx::CheckBox->new( $pageStream, 437, "Denoise Image" );
	$self->{stream_denoise}->Show(0);
#	$self->{stream_denoise}->SetToolTip("Apply Light Denoiser to Remove Static from Video (Can only be used on deinterlaced video)");
#	$qualitysizer->AddWindow( $self->{stream_denoise}, 0, wxALIGN_LEFT|wxTOP|wxBOTTOM, 5 );

	$self->{stream_crop} = Wx::CheckBox->new( $pageStream, 433, "Crop Video" );
	$self->{stream_crop}->SetToolTip("Use MPEG4 Crop Settings on Video Stream");
	$qualitysizer->AddWindow( $self->{stream_crop}, 0, wxALIGN_LEFT|wxTOP|wxBOTTOM, 5 );

	$self->{framedrop} = Wx::CheckBox->new( $pageStream, 435, "Drop Frames If Needed" );
	$self->{framedrop}->SetToolTip("Skip Some Frames to Maintain A/V Sync on Slow Systems.");
	$qualitysizer->AddWindow( $self->{framedrop}, 0, wxALIGN_LEFT|wxTOP|wxBOTTOM, 5 );

	$self->{stream_aspect} = Wx::RadioBox->new( $pageStream, 438, "Aspect Ratio", wxDefaultPosition, [-1,-1], ["Automatic","4:3","16:9 (Widescreen)"] , 1, wxRA_SPECIFY_COLS );
	$qualitysizer->AddWindow( $self->{stream_aspect}, 0, wxALIGN_LEFT|wxTOP|wxBOTTOM, 5 );

	$strflexsizer->Add($qualitysizer, 0, wxALIGN_CENTER|wxRIGHT|wxLEFT|wxBOTTOM|wxGROW, 5);

#	my $sbox3d = Wx::StaticBox->new( $pageStream, -1, "Video Quality" );
#	my $schedsizer = Wx::StaticBoxSizer->new( $sbox3d, wxVERTICAL);
#	$self->{stream_transcode} = Wx::CheckBox->new( $pageStream, 434, "Transcode Audio to 48kHz" );
#	$self->{stream_transcode}->SetToolTip("Only Required for Broken Audio");				
#	$schedsizer->AddWindow( $self->{stream_transcode}, 0, wxALIGN_LEFT|wxTOP|wxBOTTOM, 5 );

#	$strflexsizer->Add($schedsizer, 0, wxALIGN_CENTER|wxRIGHT|wxLEFT|wxBOTTOM|wxGROW, 5);

	# H3 - post options
	my( $sbox3 ) = Wx::StaticBox->new( $pageStream, -1, "Streaming Cache" );				
	my( $soboxsizer ) = Wx::StaticBoxSizer->new( $sbox3, wxVERTICAL );

	my( $cachetext ) = Wx::StaticText->new( $pageStream, -1, "Cache (MB)", wxDefaultPosition, wxDefaultSize, 0 );
	$soboxsizer->Add( $cachetext, 0, wxALIGN_CENTER|wxTOP, 5 );

	# H5 - the slider
	my $cslider = Wx::Slider->new( $pageStream, -1, 0, 4, 32, wxDefaultPosition, [-1,-1], wxSL_AUTOTICKS|wxSL_LABELS|wxGROW);
	$self->{cslider} = $cslider;
	$cachetext->SetToolTip("Use smaller cache for quicker skipping.");				

	$soboxsizer->Add( $cslider, 0, wxALIGN_CENTER|wxLEFT|wxBOTTOM|wxGROW, 5 );

	my $cachetext2 = Wx::StaticText->new( $pageStream, -1, "Start Playing When (%) Cache Full", wxDefaultPosition, wxDefaultSize, 0 );
	$soboxsizer->Add( $cachetext2, 0, wxALIGN_CENTER|wxTOP, 5 );

	#  the cache-min slider
	my $cmslider = Wx::Slider->new( $pageStream, -1, 0, 0, 99, wxDefaultPosition, [-1,-1], wxSL_AUTOTICKS|wxSL_LABELS|wxGROW);
	$self->{cmslider} = $cmslider;		
	$soboxsizer->Add( $cmslider, 0, wxALIGN_CENTER|wxLEFT|wxBOTTOM|wxGROW, 5 );

	$strflexsizer->Add( $soboxsizer, 0, wxALIGN_CENTER|wxLEFT|wxRIGHT|wxBOTTOM|wxGROW, 5 );

	$pageStream->SetSizer( $strflexsizer );
	$strflexsizer->SetSizeHints( $pageStream );

	$notebook->AddPage( $pageStream, "Stream" );
	#####################################################################################

	#####################################################################################
	#   VIDEO Dialog
	#####################################################################################
	my( $pageVideo ) = Wx::Panel->new( $notebook, -1 );

	my( $flex ) = Wx::FlexGridSizer->new( 4, 1, 0, 0 );
	$flex->AddGrowableCol( 0 );

#	my( $radiobox3 ) = Wx::RadioBox->new( $pageVideo, -1, "Encoding Passes (DivX .avi only)", wxDefaultPosition, [267,-1], ["One Pass (Quicker)","Two Pass (Better Quality)"] , 1, wxRA_SPECIFY_COLS );
#	$self->{radiobox3} = $radiobox3;
#	$flex->AddWindow( $radiobox3, 0, wxALIGN_CENTER_HORIZONTAL|wxLEFT|wxRIGHT, 14 );
	my( $radiobox4 ) = Wx::RadioBox->new( $pageVideo, -1, "Deinterlacing Mode (DivX .avi only)", wxDefaultPosition, [267,-1], ["Linear Blend","Cubic Interpolate","None"] , 1, wxRA_SPECIFY_COLS );
	$self->{radiobox4} = $radiobox4;
	$flex->AddWindow( $radiobox4, 0, wxALIGN_CENTER_HORIZONTAL|wxALL, 10 );

	my( $lowercropsizer ) = Wx::BoxSizer->new( wxHORIZONTAL );
	my( $sboxCropEdges ) = Wx::StaticBox->new( $pageVideo, -1, "Crop Edges (DivX .avi only)", wxDefaultPosition, [144,-1] );
	my( $boxsizercrop ) = Wx::StaticBoxSizer->new( $sboxCropEdges, wxVERTICAL );
	my( $cropboxsizer1 ) = Wx::BoxSizer->new( wxHORIZONTAL );
	my( $tcrop ) = Wx::TextCtrl->new( $pageVideo, -1, "0", wxDefaultPosition, [30,-1], 0 );	$cropboxsizer1->AddWindow( $tcrop, 0, wxALIGN_CENTER|wxALL, 5 );	$self->{tcrop} = $tcrop;
	$boxsizercrop->Add( $cropboxsizer1, 0, wxALIGN_CENTER|wxLEFT|wxRIGHT|wxBOTTOM, 5 );
	my( $cropboxsizer2 ) = Wx::BoxSizer->new( wxHORIZONTAL );
	my( $lcrop ) = Wx::TextCtrl->new( $pageVideo, -1, "0", wxDefaultPosition, [30,-1], 0 );	$cropboxsizer2->AddWindow( $lcrop, 0, wxALIGN_CENTER|wxRIGHT, 5 );	$self->{lcrop} = $lcrop;
	my( $lcrtext ) = Wx::StaticText->new( $pageVideo, -1, "", wxDefaultPosition, [64,-1], 0 );	$cropboxsizer2->AddWindow( $lcrtext, 0, wxALIGN_CENTER|wxTOP, 7 );	$self->{lcrtext} = $lcrtext;
	my( $rcrop ) = Wx::TextCtrl->new( $pageVideo, -1, "0", wxDefaultPosition, [30,-1], 0 );	$cropboxsizer2->AddWindow( $rcrop, 0, wxALIGN_CENTER|wxLEFT, 5 );	$self->{rcrop} = $rcrop;
	$boxsizercrop->Add( $cropboxsizer2, 0, wxALIGN_CENTER|wxALL, 5 );
	my( $cropboxsizer3 ) = Wx::BoxSizer->new( wxHORIZONTAL );
	my( $bcrop ) = Wx::TextCtrl->new( $pageVideo, -1, "0", wxDefaultPosition, [30,-1], 0 );	$cropboxsizer3->AddWindow( $bcrop, 0, wxALIGN_CENTER|wxALL, 5 );	$self->{bcrop} = $bcrop;			
	$boxsizercrop->Add( $cropboxsizer3, 0, wxALIGN_CENTER|wxLEFT|wxRIGHT|wxTOP, 5 );							
	$lowercropsizer->Add( $boxsizercrop, 0, wxALIGN_LEFT|wxBOTTOM|wxGROW, 0 );
	my( $sboxm4 ) = Wx::StaticBox->new( $pageVideo, -1, "Resize Video (avi/itunes only)", wxDefaultPosition, [-1,-1] );
	$sboxm4->SetToolTip("(DivX .avi and iTunes mode)");
	my( $boxsizerm4 ) = Wx::StaticBoxSizer->new( $sboxm4, wxVERTICAL );
	my( $wrztext ) = Wx::StaticText->new( $pageVideo, -1, " Width", wxDefaultPosition, [-1,-1], 0 );
	$boxsizerm4->AddWindow( $wrztext, 0, wxALIGN_CENTER, 7 );
	$self->{wrztext} = $wrztext;
	my( $wresize ) = Wx::TextCtrl->new( $pageVideo, -1, "0", wxDefaultPosition, [35,-1], 0 );
	$boxsizerm4->AddWindow( $wresize, 0, wxALIGN_CENTER|wxALL, 5 );
	$self->{wresize} = $wresize;
	my( $hrztext ) = Wx::StaticText->new( $pageVideo, -1, "Height", wxDefaultPosition, [-1,-1], 0 );
	$boxsizerm4->AddWindow( $hrztext, 0, wxALIGN_CENTER|wxTOP, 7 );
	$self->{hrztext} = $hrztext;
	my( $hresize ) = Wx::TextCtrl->new( $pageVideo, -1, "0", wxDefaultPosition, [35,-1], 0 );
	$boxsizerm4->AddWindow( $hresize, 0, wxALIGN_CENTER|wxTOP, 5 );
	$self->{hresize} = $hresize;
	$lowercropsizer->Add( $boxsizerm4, 0, wxALIGN_RIGHT|wxLEFT|wxGROW, 34 );
	$flex->Add( $lowercropsizer, 0, wxALIGN_CENTER_HORIZONTAL|wxLEFT|wxRIGHT, 16 );

	my( $sboxbitrate ) = Wx::StaticBox->new( $pageVideo, -1, "Bitrate (kbits/sec) (.avi and iTunes mode)", wxDefaultPosition, [269,-1], wxALIGN_LEFT|wxGROW );				
	my( $bitrate_sizer ) = Wx::StaticBoxSizer->new( $sboxbitrate, wxVERTICAL );

	my( $bslider ) = Wx::Slider->new( $pageVideo, $ID_BITSLIDER, 0, 128, 2500, wxDefaultPosition, [-1,-1], wxSL_AUTOTICKS|wxSL_LABELS|wxGROW);
	$self->{bitslider} = $bslider;
	$bitrate_sizer->AddWindow( $bslider, 0, wxGROW|wxALIGN_RIGHT|wxLEFT|wxTOP|wxBOTTOM, 5 );
	$flex->Add( $bitrate_sizer, 0, wxGROW|wxALIGN_CENTER_VERTICAL|wxLEFT|wxRIGHT|wxTOP, 12 );

	$pageVideo->SetSizer( $flex );
	$flex->SetSizeHints( $pageVideo );
	$notebook->AddPage( $pageVideo, "Video" );
	#####################################################################################

	#####################################################################################
	#   Scheduler Dialog
	#####################################################################################
	my $pageFavorites = Wx::Panel->new($notebook, -1 );
	my $favsizer = Wx::FlexGridSizer->new(2, 1, 0, 0);
	$favsizer->AddGrowableCol(0);
		
	my $sboxsched = Wx::StaticBox->new($pageFavorites, -1, "Scheduler");
	my $schedsizer = Wx::StaticBoxSizer->new($sboxsched, wxVERTICAL);

	$self->{schedcheck} = Wx::CheckBox->new( $pageFavorites, $ID_ENABLE_SCHED, "Automatically Download New Favorites");	
	$self->{schedcheck}->SetToolTip("TivoTool can be closed without affecting the scheduler");
	
	# Video format
	my $txtformat = Wx::StaticText->new($pageFavorites, -1, "In This Video Format:");		
	$txtformat->SetFont($smallfont);
	$self->{autoformatchooser} = Wx::Choice->new($pageFavorites, -1, [-1,-1], [-1,-1], ["Tivo Format (.ty)", "Tivo Media Format (.tmf)", "MPEG2 alternate (.mpg)", "DVD Format alternate (.vob)", "Unmuxed (.m2v .m2a)", "DivX/MP3 (.avi)","MPEG4/AAC (.mp4)"]);
	
	# Time
	my $txttime = Wx::StaticText->new($pageFavorites, -1, "At This Time:");		
	$txttime->SetFont($smallfont);
	my $schedsizer_time = Wx::BoxSizer->new(wxHORIZONTAL);
	$self->{chooser_hour} = Wx::Choice->new($pageFavorites, $ID_HOUR, [-1,-1], [-1,-1], ["12", "01", "02", "03", "04", "05", "06", "07", "08", "09", "10", "11"]);
	$self->{chooser_minute} = Wx::Choice->new($pageFavorites, $ID_MINUTE, [-1,-1], [-1,-1], ["00", "01", "02", "03", "04", "05", "06", "07", "08", "09", "10", "11", "12", "13", "14", "15", "16", "17", "18", "19", "20", "21", "22", "23", "24", "25", "26", "27", "28", "29", "30", "31", "32", "33", "34", "35", "36", "37", "38", "39", "40", "41", "42", "43", "44", "45", "46", "47", "48", "49", "50", "51", "52", "53", "54", "55", "56", "57", "58", "59"]);
	$self->{chooser_ampm} = Wx::Choice->new($pageFavorites, $ID_AMPM, [-1,-1], [-1,-1], ["AM","PM"]);
	$schedsizer_time->AddWindow($self->{chooser_hour}, 0, wxALIGN_LEFT, 5 );
	$schedsizer_time->AddWindow($self->{chooser_minute}, 0, wxALIGN_LEFT, 5 );
	$schedsizer_time->AddWindow($self->{chooser_ampm}, 0, wxALIGN_LEFT, 5 );

	$schedsizer->AddWindow($self->{schedcheck}, 0, wxALIGN_LEFT|wxALL, 2 );	
	$schedsizer->AddWindow($txttime, 0, wxALIGN_LEFT|wxALL, 5 );
	$schedsizer->Add($schedsizer_time, 0, wxALIGN_LEFT|wxALL, 5 );
	$schedsizer->AddWindow($txtformat, 0, wxALIGN_LEFT|wxALL, 5 );
	$schedsizer->AddWindow($self->{autoformatchooser}, 0, wxALIGN_LEFT|wxALL, 5 );


	my $schedsizer_status_top = Wx::GridSizer->new(1,2,5,5);
	
		my $schedsizer_status = Wx::BoxSizer->new(wxHORIZONTAL);

		# Status light		
		#$self->{light} = my $light = Wx::StaticBitmap->new($pageFavorites, -1, $bmp_on);
		#$light->SetToolTip("TivoTool can be closed without affecting the scheduler");
		#$schedsizer_status->AddWindow($light, 0, wxALIGN_CENTER_VERTICAL|wxALL, 0 );

		# Check if light should be on or off
		my $f = 0;
		foreach (`crontab -l`) { next unless (/.*TivoTool.*/); $f++; } # skip previous value
		#$self->{light}->SetBitmap($bmp_off) if $f==0;
		$self->{schedcheck}->SetValue(1) if ($f>0);
		
		# Status text
		$self->{cronstatus} = Wx::StaticText->new($pageFavorites, -1, $f==0?"Stopped":"Started");
		$self->{cronstatus}->SetToolTip("TivoTool can be closed without affecting the scheduler"); 
		$schedsizer_status->AddWindow($self->{cronstatus}, 0, wxALIGN_CENTER_VERTICAL|wxALL, 5 );

	$schedsizer_status_top->Add($schedsizer_status, 0, wxALIGN_LEFT|wxALL, 5 );
	
		# Reset history
		$self->{reset_seen} = Wx::Button->new( $pageFavorites, -1, "Reset History", wxDefaultPosition, [-1,-1], 0 );
		$self->{reset_seen}->SetToolTip("Clears the database of previously checked recordings. (All recordings will show up as 'new' next scheduled run.)");
	
	$schedsizer_status_top->AddWindow($self->{reset_seen}, 0, wxALIGN_RIGHT|wxALIGN_CENTER_VERTICAL|wxALL, 5 );

	$schedsizer->Add($schedsizer_status_top, 0, wxALIGN_CENTER|wxTOP|wxLEFT|wxRIGHT|wxGROW, 5 );
	
	$favsizer->Add( $schedsizer, 0, wxALIGN_CENTER_HORIZONTAL|wxALL|wxGROW, 5 );
	
	# Favorites list
	my $sboxfavs = Wx::StaticBox->new($pageFavorites, -1, "Favorites List", [-1,-1], [-1,225]);
	my $favsizer_favs = Wx::StaticBoxSizer->new($sboxfavs, wxHORIZONTAL);

	# Tie the file and then create listbox to display it..
	tie @fav_file, 'Tie::File', "$home/Library/Preferences/tivotool.favs" or die($!);
	$self->{favlist} = my $favlist = Wx::ListBox->new($pageFavorites, -1, [-1,-1], [185,185], \@fav_file);
	$favlist->SetFont($mediumfont);
	$favsizer_favs->AddWindow($favlist, 0, wxALIGN_LEFT|wxALL|wxGROW, 5 );	
	
	# ADD/REMOVE buttons
	my $fav_button_sizer = Wx::BoxSizer->new(wxVERTICAL);
 	my $add_button = Wx::Button->new( $pageFavorites, $ID_ADD_FAV, "Add", wxDefaultPosition, [75,-1], 0 );
	my $edit_button = Wx::Button->new( $pageFavorites, $ID_EDIT_FAV, "Edit", wxDefaultPosition, [75,-1], 0 );
	my $remove_button = Wx::Button->new( $pageFavorites, $ID_REMOVE_FAV, "Remove", wxDefaultPosition, wxDefaultSize, 0 );
	$fav_button_sizer->AddWindow($add_button, 0, wxALIGN_LEFT|wxLEFT|wxBOTTOM|wxTOP, 5 );
	$fav_button_sizer->AddWindow($edit_button, 0, wxALIGN_LEFT|wxLEFT|wxBOTTOM|wxTOP, 5 );
	$fav_button_sizer->AddWindow($remove_button, 0, wxALIGN_LEFT|wxLEFT|wxBOTTOM|wxTOP, 5 );
	$favsizer_favs->Add($fav_button_sizer, 0, wxALIGN_CENTER_HORIZONTAL|wxALL|wxGROW, 0 );

	$favsizer->Add( $favsizer_favs, 0, wxALIGN_CENTER_HORIZONTAL|wxALL|wxGROW, 5 );
	
	$pageFavorites->SetSizer( $favsizer );
	$favsizer->SetSizeHints( $pageFavorites );		
	$notebook->AddPage( $pageFavorites, "Favorites" );
	#####################################################################################

    $flexsizer->Add( $nnotebook, 0, wxALIGN_CENTER|wxGROW|wxALL, 10 );

	# Bottom Buttons...
	my( $bottomsizer ) = Wx::BoxSizer->new( wxHORIZONTAL );

	my( $prefclose ) = Wx::Button->new( $self, $SCBTNID, "Close", wxDefaultPosition, wxDefaultSize, 0 );
	my( $prefreset ) = Wx::Button->new( $self, $RSBTNID, "Reset", wxDefaultPosition, wxDefaultSize, 0 );

	$bottomsizer->AddWindow( $prefreset, 0, wxALIGN_CENTER|wxLEFT|wxBOTTOM|wxRIGHT, 5 );
	$bottomsizer->AddWindow( $prefclose, 0, wxALIGN_CENTER|wxLEFT|wxBOTTOM, 5 );

    $flexsizer->Add( $bottomsizer, 0, wxALIGN_RIGHT|wxALIGN_BOTTOM|wxLEFT|wxRIGHT|wxBOTTOM, 10 );

	################################## END NOTEBOOK #####################################
	
	$self->SetSizer( $flexsizer );

	#  Populate all the controls from the .conf file
	$self->{addressbox2}->Append($c->TIVOIP);
	$self->{addressbox2}->SetValue($c->TIVOIP);
	$self->{tcrop}->SetValue($c->CROP_TOP);
	$self->{bcrop}->SetValue($c->CROP_BOTTOM);
	$self->{lcrop}->SetValue($c->CROP_LEFT);
	$self->{rcrop}->SetValue($c->CROP_RIGHT);
	$self->{wresize}->SetValue($c->RESIZE_W); 
	$self->{hresize}->SetValue($c->RESIZE_H); 
	$self->{bitslider}->SetValue($c->BITRATE); 
#	$self->{radiobox3}->SetSelection($c->TWOPASS);
	$self->{radiobox4}->SetSelection($c->DEINT);
	$self->{framedrop}->SetValue($c->FRAMEDROP);
	$self->{stream_aspect}->SetSelection($c->STREAM_ASPECT);
	$self->{stream_deint}->SetValue($c->STREAM_DEINT);
	$self->{stream_denoise}->SetValue($c->STREAM_DENOISE);
	$self->{stream_crop}->SetValue($c->STREAM_CROP);
	$self->{cslider}->SetValue($c->CACHE); 
	$self->{cmslider}->SetValue($c->CACHEMIN); 
	$self->{schedcheck}->SetValue($c->SCHED_ENABLE);
	$self->{autoformatchooser}->SetSelection($c->DLMODE_AUTO);
	$self->{chooser_hour}->SetSelection($c->AUTO_HOUR);
	$self->{chooser_minute}->SetSelection($c->AUTO_MINUTE);
	$self->{chooser_ampm}->SetSelection($c->AUTO_AMPM);
	$self->{outtext}->SetLabel($c->OUTPUTDIR);
	$self->{refresh_on_startup}->SetValue($c->REFRESHSTARTUP);	
	$self->{bbpath}->SetValue($c->BBPATH);
	$self->{vserverpath}->SetValue($c->VSERVERPATH);
	
	#  EVENTS
    EVT_BUTTON( $self, $self->{reset_seen}, \&OnResetSeen );
    EVT_BUTTON( $self, $ID_ADD_FAV, \&OnAddFav );
    EVT_BUTTON( $self, $ID_EDIT_FAV, \&OnEditFav );
    EVT_BUTTON( $self, $ID_REMOVE_FAV, \&OnRemoveFav );
    EVT_BUTTON( $self, $SCBTNID, \&ClosePrefs );
    EVT_BUTTON( $self, $RSBTNID, \&ResetPrefs );
    EVT_BUTTON( $self, $PB1ID, \&BrowseForOut );
    EVT_BUTTON( $self, $ID_BON, \&OnFindTivo );
    EVT_CHECKBOX( $self, $ID_ENABLE_SCHED, \&OnToggleCron );
	EVT_CHOICE( $self, $ID_HOUR, \&OnToggleCron );
	EVT_CHOICE( $self, $ID_MINUTE, \&OnToggleCron );
	EVT_CHOICE( $self, $ID_AMPM, \&OnToggleCron );	
		
	return $self;   
}


1;