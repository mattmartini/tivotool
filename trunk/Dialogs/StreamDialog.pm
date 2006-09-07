package StreamDialog;
use strict;
use TTConfig;
use Recording;
use Data::Dumper;
use Wx;
use base 'Wx::Frame';
use Wx qw(:everything);
use Wx::Event qw(EVT_BUTTON EVT_IDLE EVT_CLOSE EVT_TIMER EVT_SCROLL_THUMBRELEASE);
use Expect;
$|++;

$Expect::Log_Stdout=0; # On by default.

my $home = $ENV{'HOME'};
my $con = CommandLineController->new();
my $c = $TTConfig::config; 
my $vstream = $c->vstream();
my $mp = $c->mplayer();

my $state = 'stopped'; # stopped, paused, playing

my $pnghandler = Wx::PNGHandler->new();

##################### CONSTRUCTOR ###########################
sub new 
{
	my ($ref, $caller, $rec) = @_;
	
    my $self = $ref->SUPER::new( $caller, -1, $rec->show(), [-1, -1], [-1, -1], wxDEFAULT_FRAME_STYLE);
    
    $self->{recording} = $rec;
	$self->{handle} = undef;
	
	# Draw GUI                                                          
	Draw($self, $rec); 

	bless($self, $ref);	

	# Starting playing
	$state = 'playing';
	my $mp_cmd = $con->build_streamcommand($rec);	
	main::TTDebug($mp_cmd);
	$self->{handle} = Expect->spawn("$mp_cmd 2>&1") or die "Couldn't spawn mplayer, $!";
	
	return $self;
}

##################### IDLE EVENT ###########################
sub OnIdle 
{	
	my $self = shift;
	
	# Update GUI with values
	if ($state ne 'paused' && defined($self->{handle}))
	{
		$self->{handle}->send("get_time_pos\r");

		my ($matched_pattern_position, $error, $successfully_matching_string, $before_match, $after_match)
			= $self->{handle}->expect(2, "ANS_TIME_POSITION=");

		chomp($after_match);
				
		if ($error)
		{
			main::TTDebug("Expect message: $error");
			main::TTDebug(Dumper($matched_pattern_position, $error, $successfully_matching_string, $before_match, $after_match));
		}
		
		if ($error =~ m/^3/)
		{
			$self->Close();
		}
		
		$self->{slider}->SetValue( int($after_match+.5) );
	}
}

##################### BUTTON EVENTS ########################
sub OnClickFullScreen
{
	my $self = shift;
	$self->{handle}->send("vo_fullscreen 1\r");
}

sub OnClickRW
{
	my $self = shift;
	$self->{handle}->send("speed_incr -0.5\r");
}

sub OnClickFF
{
	my $self = shift;
	$self->{handle}->send("speed_incr 0.5\r");
}

sub OnClickSkipBackward
{
	my $self = shift;
	$self->{handle}->send("seek -30\r");
}

sub OnClickSkipForward 
{
	my $self = shift;
	$self->{handle}->send("seek 30\r");
}

sub OnClickPause
{
	my $self = shift;
	if ($self->{handle})
	{
		if ($state eq 'paused')
		{
			$state = 'playing';
			$self->{handle}->send("pause\r");
		}
		elsif ($state eq 'playing')
		{
			$state = 'paused';
			$self->{handle}->send("pause\r");
		}
	}
}

sub OnSlide
{
	my $self = shift;
	if ($self->{handle})
	{
		$self->{handle}->send("seek ".$self->{slider}->GetValue()." 2\r");
	}
}

##################### GUI DRAWING CODE ########################
sub MyBitmapsFunc {
	my $self = shift;

	my $image = Wx::Image->new();
	
    if ($self == 0) {
		my $file = IO::File->new("TivoTool.app/Contents/Resources/Dialogs/MyBitmapsFunc_0.png") or die("need icon!\n$! $?");
		binmode $file;
		$pnghandler->LoadFile($image, $file);
		my $bitmap = Wx::Bitmap->new($image);
        return $bitmap;
    }
    if ($self == 1) {
		my $file = IO::File->new("TivoTool.app/Contents/Resources/Dialogs/MyBitmapsFunc_1.png") or die("need icon!\n$! $?");
		binmode $file;
		$pnghandler->LoadFile($image, $file);
		my $bitmap = Wx::Bitmap->new($image);
        return $bitmap;
    }
    if ($self == 2) {
		my $file = IO::File->new("TivoTool.app/Contents/Resources/Dialogs/MyBitmapsFunc_2.png") or die("need icon!\n$! $?");
		binmode $file;
		$pnghandler->LoadFile($image, $file);
		my $bitmap = Wx::Bitmap->new($image);
        return $bitmap;
    }
    if ($self == 3) {
		my $file = IO::File->new("TivoTool.app/Contents/Resources/Dialogs/MyBitmapsFunc_3.png") or die("need icon!\n$! $?");
		binmode $file;
		$pnghandler->LoadFile($image, $file);
		my $bitmap = Wx::Bitmap->new($image);
        return $bitmap;
    }
    if ($self == 4) {
		my $file = IO::File->new("TivoTool.app/Contents/Resources/Dialogs/MyBitmapsFunc_4.png") or die("need icon!\n$! $?");
		binmode $file;
		$pnghandler->LoadFile($image, $file);
		my $bitmap = Wx::Bitmap->new($image);
        return $bitmap;
    }
    if ($self == 5) {
		my $file = IO::File->new("TivoTool.app/Contents/Resources/Dialogs/MyBitmapsFunc_5.png") or die("need icon!\n$! $?");
		binmode $file;
		$pnghandler->LoadFile($image, $file);
		my $bitmap = Wx::Bitmap->new($image);
        return $bitmap;
    }
	wxNullBitmap;
}

sub Draw 
{
	my ($self, $rec) = @_;

	main::TTDebug(Dumper($rec));

    my( $item0 ) = Wx::FlexGridSizer->new( 0, 1, 0, 0 );
    $item0->AddGrowableCol( 0 );
    $item0->AddGrowableRow( 0 );
    
    my( $item2 ) = Wx::StaticBox->new( $self, -1, "" );
    my( $item1 ) = Wx::StaticBoxSizer->new( $item2, wxVERTICAL );
    
    my( $item3 ) = Wx::BoxSizer->new( wxHORIZONTAL );
    
    my( $item4 ) = Wx::BitmapButton->new( $self, -1, MyBitmapsFunc( 5 ), wxDefaultPosition, wxDefaultSize );
    $item3->AddWindow( $item4, 0, wxALIGN_CENTER|wxALL, 5 );

    my( $item5 ) = Wx::BitmapButton->new( $self, -1, MyBitmapsFunc( 2 ), wxDefaultPosition, wxDefaultSize );
    $item3->AddWindow( $item5, 0, wxALIGN_CENTER|wxALL, 5 );

    my( $item6 ) = Wx::BitmapButton->new( $self, -1, MyBitmapsFunc( 1 ), wxDefaultPosition, wxDefaultSize );
    $item3->AddWindow( $item6, 0, wxALIGN_CENTER|wxALL, 5 );

    my( $item7 ) = Wx::BitmapButton->new( $self, -1, MyBitmapsFunc( 0 ), wxDefaultPosition, wxDefaultSize );
    $item3->AddWindow( $item7, 0, wxALIGN_CENTER|wxALL, 5 );

    my( $item8 ) = Wx::BitmapButton->new( $self, -1, MyBitmapsFunc( 3 ), wxDefaultPosition, wxDefaultSize );
    $item3->AddWindow( $item8, 0, wxALIGN_CENTER|wxALL, 5 );

    $item3->AddSpace( 20, 20, 0, wxALIGN_CENTER|wxALL, 5 );

    my( $item9 ) = Wx::BitmapButton->new( $self, -1, MyBitmapsFunc( 4 ), wxDefaultPosition, wxDefaultSize );
    $item3->AddWindow( $item9, 0, wxALIGN_CENTER|wxALL, 5 );

    $item1->Add( $item3, 0, wxALIGN_CENTER|wxLEFT|wxRIGHT|wxBOTTOM, 5 );

    my( $item10 ) = Wx::BoxSizer->new( wxVERTICAL );
    
	my( $item11 ) = $self->{slider} = Wx::Slider->new($self, -1, 0, 1, $rec->duration(), wxDefaultPosition, wxDefaultSize, wxSL_HORIZONTAL|wxSL_AUTOTICKS );
	#$item11->Enable(0);
    $item10->AddWindow( $item11, 0, wxGROW|wxALIGN_CENTER_VERTICAL|wxALL, 5 );

    $item1->Add( $item10, 0, wxGROW|wxALIGN_CENTER_VERTICAL|wxALL, 5 );

    $item0->Add( $item1, 0, wxALIGN_CENTER|wxALL, 10 );

    $self->SetSizer( $item0 );
         
    $item0->SetSizeHints( $self );
    
    $item0;

	EVT_SCROLL_THUMBRELEASE($self, \&OnSlide);
	EVT_BUTTON($self, $item9, \&OnClickFullScreen);
	EVT_BUTTON($self, $item5, \&OnClickRW);
	EVT_BUTTON($self, $item7, \&OnClickFF);
	EVT_BUTTON($self, $item8, \&OnClickSkipForward);
	EVT_BUTTON($self, $item4, \&OnClickSkipBackward);
	EVT_BUTTON($self, $item6, \&OnClickPause);
	EVT_IDLE($self, \&OnIdle);
}

1;