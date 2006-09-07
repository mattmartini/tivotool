package TivoServerDialog;
use strict;
use TTConfig;
use Data::Dumper;
use Wx;
use base 'Wx::Frame';
use Wx qw(:everything);
use Wx::Event qw(EVT_BUTTON EVT_IDLE EVT_CLOSE EVT_CHECKBOX EVT_MENU);
my ($ID_NOTEBOOK, $ID_TEXT, $ID_CHECKBOX_TIVOSERVER, $ID_BUTTON, $ID_STATICBITMAP, $ID_TEXTCTRL, $ID_RADIOBOX, $ID_SLIDER, $ID_CLOSE, $ID_BROWSE) = (2001..3000);
$|++;

my $home = $ENV{'HOME'};
my $status_file = "$home/Library/Logs/tivoserver.log";
my $c = $TTConfig::config; 
my $con = CommandLineController->new();
my $cmd = $con->build_tivoservercommand();

my $mediumfont = Wx::Font->new(11, wxDEFAULT, wxNORMAL, wxNORMAL, 0, 'Lucida Grande');
my $fixedfont = Wx::Font->new(11, wxDEFAULT, wxNORMAL, wxNORMAL, 0, 'Monaco');

my $last_update = time();
my $last_modified = "";

my $grouping_type = "GroupByDirectory";
my $fake_tivo_name = "TivoServer";
my $log_level = "3";
my $video_dir = "$home/Movies";
my $interface_addr = "0.0.0.0";

# Load status icons
my $file = IO::File->new("TivoTool.app/Contents/Resources/light-on.png") or die("need icon!\n$! $?");
my $file2 = IO::File->new("TivoTool.app/Contents/Resources/light-off.png") or die("need icon!\n$! $?");
binmode $file;
binmode $file2;
my $handler = Wx::PNGHandler->new();
my $image = Wx::Image->new();
my $image2 = Wx::Image->new();
$handler->LoadFile( $image, $file );
$handler->LoadFile( $image2, $file2 );
my $bmp_on = Wx::Bitmap->new($image);
my $bmp_off = Wx::Bitmap->new($image2);

##################### CONSTRUCTOR ###########################
sub new 
{
	my ($ref, $caller) = @_;
	
    my $self = $ref->SUPER::new($caller, -1, "TivoServer", [-1,-1], [-1,-1], wxDEFAULT_FRAME_STYLE);
	
	# Create menubar 
	my $tivoserver_file_menu = Wx::Menu->new();
	my $tivoserver_menubar = Wx::MenuBar->new();
	$tivoserver_file_menu->Append ($ID_CLOSE,"Close\tCtrl-W","Save and Close TivoServer Preferences");
	$tivoserver_menubar->Append($tivoserver_file_menu, '&File');
	$self->SetMenuBar($tivoserver_menubar);	
	EVT_MENU($self, $ID_CLOSE, \&OnClose);

	# load values from file...
	load_config($self);
	
	# Draw GUI with the values.                                            
	Draw($self); 

	my @page1children = $self->GetChildren->GetPage(0)->GetChildren();
	my @page2children = $self->GetChildren->GetPage(1)->GetChildren();
	$self->{video_dir} = $page1children[4];
	$self->{textctrl} = $page2children[0];
		
	if (IsRunning() == 1)
	{
		#$page1children[16]->SetBitmap($bmp_on);
		$page1children[17]->SetLabel("Started");
		$page1children[2]->SetValue(1);
		$self->{textctrl}->SetValue(join('',`cat $status_file`));
	}
	else
	{
		# not running, clear the old log
		unlink($status_file);
	}
	
	bless($self, $ref);	
	return $self;
}


#################### LOAD TIVOSERVER CONFIG #######################
sub load_config
{
	my $self = shift;
	
	open(CFG, "< $home/.tivoserver/settings.cfg") or print($!);
	while (<CFG>)
	{
		if (/^(\w+)=(.+)$/)
		{
			$video_dir = $2 if ($1 eq "VIDEO_DIR"); 
			$interface_addr = $2 if ($1 eq "INTERFACE_ADDR"); 
			$log_level = $2 if ($1 eq "LOG_LEVEL"); 
			$fake_tivo_name = $2 if ($1 eq "FAKE_TIVO_NAME"); 
			$grouping_type = $2 if ($1 eq "GROUPING_TYPE"); 
		}
	}
	close CFG or print($!);
}


#################### SAVE TIVOSERVER CONFIG #######################
sub save_config
{
	my $self = shift;
	
	my @children = $self->GetChildren->GetPage(0)->GetChildren();
			
	open(CFG, "> $home/.tivoserver/settings.cfg") or die($!);
	
	print CFG "FAKE_TIVO_ID=0\n";
	print CFG "INTERFACE_ADDR=".$children[9]->GetValue()."\n";
	print CFG "FAKE_TIVO_NAME=".$children[7]->GetValue()."\n";
	print CFG "VIDEO_DIR=".$children[4]->GetLabel()."\n";
	print CFG "LOG_LEVEL=".$children[14]->GetValue()."\n";

	if ($children[11]->GetSelection() == 0)	{ print CFG "GROUPING_TYPE=GroupBySeries\n"; }
		else { print CFG "GROUPING_TYPE=GroupByDirectory\n"; }	

	close CFG or print($!);	
}


##################### IDLE EVENT ###########################
sub OnIdle 
{	
	my $self = shift;
	
	my $diff = (time() - $last_update);
	
	if ($diff > 2)
	{
		my @result = `/usr/bin/stat -n -f \%m $status_file` if (-e "$status_file");
		
		if (($result[0] - $last_modified) > 0) # file mtime changed.
		{
			$last_modified = $result[0];
			
			$self->{textctrl}->SetValue( join(' ',`tail -n 8000 $status_file`) );
		}
		
		$last_update = time();
	}

}

##################### CLICK START ###########################
sub OnClickStart 
{	
	my $self = shift;

	my @child = $self->GetChildren->GetPage(0)->GetChildren();
	my @child2 = $self->GetChildren->GetPage(1)->GetChildren();
	
	if ($child[2]->IsChecked())
	{
		# User is starting Tivoserver
		save_config($self);
		system("$cmd &> $status_file &");
		#$child[16]->SetBitmap($bmp_on);
		$child[17]->SetLabel("Started");
	}
	else
	{
		# User want's to stop Tivoserver
		`killall tivoserver &>/dev/null; killall -9 tivoserver &>/dev/null`;
		unlink($status_file);
		save_config($self);
		#$child[16]->SetBitmap($bmp_off);
		$child[17]->SetLabel("Stopped");
		$child2[0]->Clear();
	}
}

############### CHECK IF TIVOSERVER IS RUNNING ##################
sub IsRunning
{
	my @result = `\ps ax | grep [t]ivoserver`;
	if ($result[0] =~ /.*\d+.*/) { return 1; } else { return 0; }
}


#################### BROWSE FOR SHARE FOLDER #######################
sub BrowseForShare 
{
	my $self = shift;
	my $ddialog = Wx::DirDialog->new($self, "Choose Location", $home);
	unless ($ddialog->ShowModal() == wxID_CANCEL) 
	{
		my $result = $ddialog->GetPath();
		$self->{video_dir}->SetLabel($result); # 	$children[4]
	}
}


#################### CLOSE #######################
sub OnClose
{
	save_config($_[0]);
	$_[0]->Destroy();
}


##################### GUI DRAWING CODE BELOW HERE ########################
sub Draw 
{	
    my( $item0 ) = Wx::FlexGridSizer->new( 0, 1, 0, 0 );
    $item0->AddGrowableCol( 0 );
    $item0->AddGrowableRow( 0 );
    
    my( $item2 ) = Wx::Notebook->new( $_[0], $ID_NOTEBOOK, wxDefaultPosition, [320,240], 0 );
    my( $item1 ) = $item2;
    if( Wx->VERSION < 0.21 ) {
        $item1 = Wx::NotebookSizer->new( $item2 );
    }
    
    my( $item3 ) = Wx::Panel->new( $item2, -1 );
    &StartStopPage( $item3, 0 );
    $item2->AddPage( $item3, "Manage Server" );

    my( $item4 ) = Wx::Panel->new( $item2, -1 );
    &StatusPage( $item4, 0 );
    $item2->AddPage( $item4, "Console" );

    $item0->Add( $item1, 0, wxGROW|wxALIGN_CENTER_HORIZONTAL|wxLEFT|wxRIGHT|wxBOTTOM, 20 );

    my( $set_size ) = @_ >= 3 ? $_[2] : 1;
    my( $call_fit ) = @_ >= 2 ? $_[1] : 1;
    if( $set_size == 1 ) {
         $_[0]->SetSizer( $item0 );
         
         if( $call_fit == 1 ) {
             $item0->SetSizeHints( $_[0] );
         }
    }
	
    $item0;

	EVT_CHECKBOX($_[0], $ID_CHECKBOX_TIVOSERVER, \&OnClickStart);
	EVT_IDLE($_[0], \&OnIdle);
	EVT_CLOSE($_[0], \&OnClose);
	EVT_BUTTON($_[0], $ID_BROWSE, \&BrowseForShare);
}


### START/STOP Page ###
sub StartStopPage {
    my( $item0 ) = Wx::FlexGridSizer->new( 0, 1, 0, 0 );
    $item0->AddGrowableCol( 0 );
    $item0->AddGrowableRow( 5 );
    $item0->AddGrowableRow( 4 );

    my( $item1 ) = Wx::StaticText->new( $_[0], $ID_TEXT, "TivoServer puts video files back where they belong - on your Tivo! Using the multi-room viewing (MRV) framework normally", wxDefaultPosition, wxDefaultSize, 0 );
    $item1->SetFont($mediumfont);
    $item0->AddWindow( $item1, 0, wxALIGN_TOP|wxLEFT|wxRIGHT|wxTOP, 10 );

    my( $item2 ) = Wx::StaticText->new( $_[0], $ID_TEXT, "meant for Tivo-to-Tivo transfers, you can now watch AVI, MOV and other video files on your TV easily. A Tivo with MRV\nsupport that has been \"Superpatched\" is required. This software is beta and will not work on all videos.", wxDefaultPosition, wxDefaultSize, 0 );
    $item2->SetFont($mediumfont);
    $item0->AddWindow( $item2, 0, wxALIGN_TOP|wxLEFT|wxRIGHT|wxBOTTOM, 10 );

    my( $item3 ) = Wx::CheckBox->new( $_[0], $ID_CHECKBOX_TIVOSERVER, "Enable TivoServer", wxDefaultPosition, wxDefaultSize, 0 );
    $item0->AddWindow( $item3, 0, wxALIGN_TOP|wxALL, 5 );

    my( $item4 ) = Wx::FlexGridSizer->new( 0, 2, 0, 0 );
    
    my( $item5 ) = Wx::BoxSizer->new( wxVERTICAL );
    
    my( $item6 ) = Wx::BoxSizer->new( wxHORIZONTAL );
    
    $item6->AddSpace( 20, 0, 0, wxALIGN_CENTER|wxALL, 5 );

    my( $item7 ) = Wx::StaticText->new( $_[0], $ID_TEXT, "Share this folder:", wxDefaultPosition, wxDefaultSize, 0 );
    $item6->AddWindow( $item7, 0, wxALIGN_CENTER_VERTICAL|wxLEFT|wxRIGHT|wxTOP, 5 );

    $item5->Add( $item6, 0, wxALIGN_CENTER_VERTICAL|wxLEFT|wxRIGHT|wxTOP, 5 );

    my( $item8 ) = Wx::FlexGridSizer->new( 0, 4, 0, 0 );
    $item8->AddGrowableCol( 1 );
    
    $item8->AddSpace( 20, 1, 0, wxALIGN_CENTER|wxALL, 5 );

    my( $item9 ) = Wx::StaticText->new( $_[0], $ID_TEXT, "$video_dir", wxDefaultPosition, wxDefaultSize, 0 );
    $item9->SetFont($mediumfont);
	$item8->AddWindow( $item9, 0, wxALIGN_CENTER_VERTICAL|wxALL, 10 );

    $item8->AddSpace( 1, 1, 0, wxALIGN_CENTER|wxALL, 5 );

    my( $item10 ) = Wx::Button->new( $_[0], $ID_BROWSE, "Browse", wxDefaultPosition, wxDefaultSize, 0 );
    $item8->AddWindow( $item10, 0, wxALIGN_RIGHT|wxALIGN_CENTER_VERTICAL|wxALL, 5 );

    $item5->Add( $item8, 0, wxALIGN_CENTER_VERTICAL|wxLEFT|wxRIGHT, 5 );

    my( $item11 ) = Wx::BoxSizer->new( wxHORIZONTAL );
    
    $item11->AddSpace( 20, 1, 0, wxALIGN_CENTER|wxALL, 5 );

    my( $item12 ) = Wx::StaticText->new( $_[0], $ID_TEXT, "Display Name:", wxDefaultPosition, wxDefaultSize, wxALIGN_RIGHT );
    $item11->AddWindow( $item12, 0, wxALIGN_CENTER|wxALL, 5 );

    my( $item13 ) = Wx::TextCtrl->new( $_[0], $ID_TEXTCTRL, "$fake_tivo_name", wxDefaultPosition, [120,-1], 0 );
    $item11->AddWindow( $item13, 0, wxALIGN_CENTER|wxALL, 5 );

    $item5->Add( $item11, 0, wxALIGN_CENTER_VERTICAL|wxLEFT|wxRIGHT|wxTOP, 5 );

    my( $item14 ) = Wx::BoxSizer->new( wxHORIZONTAL );
    
    $item14->AddSpace( 20, 20, 0, wxALIGN_CENTER|wxALL, 5 );

    my( $item15 ) = Wx::StaticText->new( $_[0], $ID_TEXT, "Interface Address:", wxDefaultPosition, wxDefaultSize, wxALIGN_RIGHT );
    $item14->AddWindow( $item15, 0, wxALIGN_CENTER|wxALL, 5 );

    my( $item16 ) = Wx::TextCtrl->new( $_[0], $ID_TEXTCTRL, "$interface_addr", wxDefaultPosition, [96,-1], 0 );
    $item14->AddWindow( $item16, 0, wxALIGN_CENTER|wxALL, 5 );

    my( $item17 ) = Wx::StaticText->new( $_[0], $ID_TEXT, "(Optional)", wxDefaultPosition, wxDefaultSize, 0 );
    $item17->SetFont($mediumfont);
    $item14->AddWindow( $item17, 0, wxALIGN_CENTER|wxALL, 5 );

    $item5->Add( $item14, 0, wxALIGN_CENTER_VERTICAL|wxALL, 5 );

    $item4->Add( $item5, 0, wxALIGN_CENTER_HORIZONTAL, 5 );

    my( $item18 ) = Wx::BoxSizer->new( wxVERTICAL );
    
    my( $item19 ) = Wx::BoxSizer->new( wxHORIZONTAL );
    
    $item19->AddSpace( 1, 1, 0, wxALIGN_CENTER|wxALL, 5 );
	
    my( $item20 ) = Wx::RadioBox->new( $_[0], $ID_RADIOBOX, "Grouping Type", wxDefaultPosition, wxDefaultSize, 
        ["Group By Series","Group By Directory"] , 1, wxRA_SPECIFY_COLS );
    $item19->AddWindow( $item20, 0, wxALIGN_CENTER_VERTICAL|wxALL, 5 );

	my $i = 1;
	if ($grouping_type eq "GroupBySeries") { $i = 0; }
	$item20->SetSelection($i);
	
    $item18->Add( $item19, 0, wxALIGN_CENTER_VERTICAL|wxLEFT|wxRIGHT, 5 );

    my( $item21 ) = Wx::FlexGridSizer->new( 0, 2, 0, 0 );
    
    $item21->AddSpace( 1, 1, 0, wxALIGN_CENTER|wxALL, 5 );

    my( $item22 ) = Wx::StaticText->new( $_[0], $ID_TEXT, "Log Level:", wxDefaultPosition, wxDefaultSize, wxALIGN_RIGHT );
    $item21->AddWindow( $item22, 0, wxALIGN_CENTER_VERTICAL|wxALL, 5 );

    $item21->AddSpace( 1, 1, 0, wxALIGN_CENTER|wxALL, 5 );

    my( $item23 ) = Wx::BoxSizer->new( wxHORIZONTAL );
    
    $item23->AddSpace( 2, 2, 0, wxALIGN_CENTER|wxALL, 5 );

    my( $item24 ) = Wx::StaticText->new( $_[0], $ID_TEXT, "Least Detail", wxDefaultPosition, wxDefaultSize, wxALIGN_RIGHT );
    $item24->SetFont($mediumfont);
	$item23->AddWindow( $item24, 0, wxALIGN_CENTER|wxALL, 5 );

    my( $item25 ) = Wx::Slider->new( $_[0], $ID_SLIDER, $log_level, 0, 5, wxDefaultPosition, [100,-1], wxSL_AUTOTICKS );
    $item23->AddWindow( $item25, 0, wxALIGN_CENTER|wxALL, 5 );

    my( $item26 ) = Wx::StaticText->new( $_[0], $ID_TEXT, "Most Detail", wxDefaultPosition, wxDefaultSize, 0 );
    $item26->SetFont($mediumfont);
    $item23->AddWindow( $item26, 0, wxALIGN_CENTER|wxALL, 5 );

    $item21->Add( $item23, 0, wxALIGN_CENTER, 5 );

    $item18->Add( $item21, 0, wxALIGN_CENTER_VERTICAL|wxALL, 5 );

    $item4->Add( $item18, 0, wxALIGN_CENTER, 5 );

    $item0->Add( $item4, 0, wxALIGN_CENTER, 5 );

    my( $item27 ) = Wx::BoxSizer->new( wxHORIZONTAL );
    
	my( $item26a ) = Wx::StaticText->new( $_[0], $ID_TEXT, "", wxDefaultPosition, wxDefaultSize, 0 );
    $item27->AddWindow( $item26a, 0, wxALIGN_CENTER|wxALL, 5 );
	
    #my( $item28 ) = Wx::StaticBitmap->new( $_[0], $ID_STATICBITMAP, $bmp_off, wxDefaultPosition, wxDefaultSize );
    #$item27->AddWindow( $item28, 0, wxALIGN_CENTER|wxALL, 5 );

    my( $item29 ) = Wx::StaticText->new( $_[0], $ID_TEXT, "Stopped", wxDefaultPosition, wxDefaultSize, 0 );
    $item27->AddWindow( $item29, 0, wxALIGN_CENTER|wxALL, 5 );

    $item0->Add( $item27, 0, wxALIGN_BOTTOM|wxALL, 5 );

    my( $set_size ) = @_ >= 3 ? $_[2] : 1;
    my( $call_fit ) = @_ >= 2 ? $_[1] : 1;
    if( $set_size == 1 ) {
         $_[0]->SetSizer( $item0 );
         
         if( $call_fit == 1 ) {
             $item0->SetSizeHints( $_[0] );
         }
    }
    
    $item0;
}


### Status Page ###
sub StatusPage 
{
    my( $item0 ) = Wx::FlexGridSizer->new( 0, 1, 0, 0 );
    $item0->AddGrowableCol( 0 );
    $item0->AddGrowableRow( 0 );
    
    my( $item1 ) = Wx::TextCtrl->new( $_[0], $ID_TEXTCTRL, "", wxDefaultPosition, wxDefaultSize, wxTE_MULTILINE|wxTE_READONLY );
    $item1->SetFont($fixedfont);
	$item0->AddWindow( $item1, 0, wxGROW|wxALL, 16 );

    my( $set_size ) = @_ >= 3 ? $_[2] : 1;
    my( $call_fit ) = @_ >= 2 ? $_[1] : 1;
    if( $set_size == 1 ) {
         $_[0]->SetSizer( $item0 );
         
         if( $call_fit == 1 ) {
             $item0->SetSizeHints( $_[0] );
         }
    }
    
    $item0;
}

1;