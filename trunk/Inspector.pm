# I used wxDesigner for the inspector design,
# hence the odd variable names :-)
package Inspector;
use strict;
use Data::Dumper;
use Wx;
use base 'Wx::Frame';
use Wx qw(:everything);
use Wx::Event qw(EVT_BUTTON);
$|++;

use vars qw($ID_TEXT); $ID_TEXT = 10000;
use vars qw($ID_LINE); $ID_LINE = 10001;
use vars qw($ID_TEXTCTRL); $ID_TEXTCTRL = 10002;

sub new 
{ 
	my ($ref, $caller, $rec) = @_;

	# We are creating a new Wx::Frame here.
    my $self = $ref->SUPER::new( $caller,         # parent
                                 -1,           
                                 'Info',	# title
                                 [-1, -1],      # default position
                                 [-1, -1],      # default size
                                 wxDEFAULT_FRAME_STYLE, # styles
                                 );

    my $fontm = Wx::Font->new(13,wxDEFAULT,wxNORMAL,wxNORMAL,0,'Lucida Grande');
    my $fontmb = Wx::Font->new(13,wxDEFAULT,wxNORMAL,wxBOLD,0,'Lucida Grande');
    my $fontsm = Wx::Font->new(11,wxDEFAULT,wxNORMAL,wxNORMAL,0,'Lucida Grande');
    my $fontsmb = Wx::Font->new(11,wxDEFAULT,wxNORMAL,wxBOLD,0,'Lucida Grande');
    
    my( $item0 ) = Wx::FlexGridSizer->new( 6, 0, 0, 0 );
    $item0->AddGrowableCol( 0 );
    $item0->AddGrowableRow( 4 );
    $self->{topflex} = $item0;
    
    my( $item1 ) = Wx::GridSizer->new( 0, 2, 0, 0 );
    $self->{toprow} = $item1;
    
    my( $item2 ) = Wx::StaticText->new( $self, -1, "The Daily Show", wxDefaultPosition, wxDefaultSize, 0 );
    $item1->AddWindow( $item2, 0, wxALIGN_CENTER_VERTICAL|wxLEFT|wxRIGHT|wxTOP, 5 );

    my( $item3 ) = Wx::StaticText->new( $self, -1, "1240MB", wxDefaultPosition, wxDefaultSize, wxALIGN_RIGHT );
    $item1->AddWindow( $item3, 0, wxALIGN_RIGHT|wxALIGN_CENTER_VERTICAL|wxLEFT|wxRIGHT|wxTOP, 5 );

    $item0->Add( $item1, 0, wxGROW|wxALL, 5 );

    my( $item4 ) = Wx::StaticLine->new( $self, -1, wxDefaultPosition, [255,-1], wxLI_HORIZONTAL );
    $item0->AddWindow( $item4, 0, wxALIGN_CENTER|wxGROW, 10 );

    my( $item5 ) = Wx::FlexGridSizer->new( 0, 2, 0, 0 );
    $item5->AddGrowableCol( 1 );
    $item5->AddGrowableRow( 0 );
    $item5->AddGrowableRow( 1 );
    $self->{middlerow} = $item5;
    
    my( $item6 ) = Wx::StaticText->new( $self, -1, "Episode:", wxDefaultPosition, wxDefaultSize, 0 );
    $item5->AddWindow( $item6, 0, wxALIGN_RIGHT|wxALIGN_CENTER_VERTICAL|wxTOP|wxLEFT|wxRIGHT, 5 );

    my( $item7 ) = Wx::StaticText->new( $self, -1, "text", wxDefaultPosition, wxDefaultSize, 0 );
    $item5->AddWindow( $item7, 0, wxALIGN_CENTER_VERTICAL|wxTOP|wxLEFT|wxRIGHT, 5 );

    my( $item8 ) = Wx::StaticText->new( $self, -1, "Date:", wxDefaultPosition, wxDefaultSize, 0 );
    $item5->AddWindow( $item8, 0, wxALIGN_RIGHT|wxALIGN_CENTER_VERTICAL|wxTOP|wxLEFT|wxRIGHT, 5 );

    my( $item9 ) = Wx::StaticText->new( $self, -1, "text", wxDefaultPosition, wxDefaultSize, 0 );
    $item5->AddWindow( $item9, 0, wxALIGN_CENTER_VERTICAL|wxTOP|wxLEFT|wxRIGHT, 5 );

    my( $item20 ) = Wx::StaticText->new( $self, -1, "Duration:", wxDefaultPosition, wxDefaultSize, 0 );
    $item5->AddWindow( $item20, 0, wxALIGN_RIGHT|wxALIGN_CENTER_VERTICAL|wxTOP|wxLEFT|wxRIGHT, 5 );

    my( $item21 ) = Wx::StaticText->new( $self, -1, "text", wxDefaultPosition, wxDefaultSize, 0 );
    $item5->AddWindow( $item21, 0, wxALIGN_CENTER_VERTICAL|wxTOP|wxLEFT|wxRIGHT, 5 );

    my( $item10 ) = Wx::StaticText->new( $self, -1, "Station:", wxDefaultPosition, wxDefaultSize, 0 );
    $item5->AddWindow( $item10, 0, wxALIGN_RIGHT|wxALIGN_CENTER_VERTICAL|wxTOP|wxLEFT|wxRIGHT, 5 );

    my( $item11 ) = Wx::StaticText->new( $self, -1, "text", wxDefaultPosition, wxDefaultSize, 0 );
    $item5->AddWindow( $item11, 0, wxALIGN_CENTER_VERTICAL|wxTOP|wxLEFT|wxRIGHT, 5 );

    my( $item14 ) = Wx::StaticText->new( $self, -1, "Dimensions:", wxDefaultPosition, wxDefaultSize, 0 );
    $item5->AddWindow( $item14, 0, wxALIGN_RIGHT|wxALIGN_CENTER_VERTICAL|wxTOP|wxLEFT|wxRIGHT, 5 );

    my( $item15 ) = Wx::StaticText->new( $self, -1, "text", wxDefaultPosition, wxDefaultSize, 0 );
    $item5->AddWindow( $item15, 0, wxALIGN_CENTER_VERTICAL|wxTOP|wxLEFT|wxRIGHT, 5 );

    my( $item12 ) = Wx::StaticText->new( $self, -1, "FPS:", wxDefaultPosition, wxDefaultSize, 0 );
    $item5->AddWindow( $item12, 0, wxALIGN_RIGHT|wxALIGN_CENTER_VERTICAL|wxTOP|wxLEFT|wxRIGHT, 5 );

    my( $item13 ) = Wx::StaticText->new( $self, -1, "text", wxDefaultPosition, wxDefaultSize, 0 );
    $item5->AddWindow( $item13, 0, wxALIGN_CENTER_VERTICAL|wxTOP|wxLEFT|wxRIGHT, 5 );

    my( $item16 ) = Wx::StaticText->new( $self, -1, "Aspect Ratio:", wxDefaultPosition, wxDefaultSize, 0 );
    $item5->AddWindow( $item16, 0, wxALIGN_RIGHT|wxALIGN_CENTER_VERTICAL|wxTOP|wxLEFT|wxRIGHT, 5 );

    my( $item17 ) = Wx::StaticText->new( $self, -1, "text", wxDefaultPosition, wxDefaultSize, 0 );
    $item5->AddWindow( $item17, 0, wxALIGN_CENTER_VERTICAL|wxTOP|wxLEFT|wxRIGHT, 5 );

    my( $item18 ) = Wx::StaticText->new( $self, -1, "Bitrate:", wxDefaultPosition, wxDefaultSize, 0 );
    $item5->AddWindow( $item18, 0, wxALIGN_RIGHT|wxALIGN_CENTER_VERTICAL|wxTOP|wxLEFT|wxRIGHT, 5 );

    my( $item19 ) = Wx::StaticText->new( $self, -1, "text", wxDefaultPosition, wxDefaultSize, 0 );
    $item5->AddWindow( $item19, 0, wxALIGN_CENTER_VERTICAL|wxTOP|wxLEFT|wxRIGHT, 5 );

    my( $item30 ) = Wx::StaticText->new( $self, -1, "Audio Format:", wxDefaultPosition, wxDefaultSize, 0 );
    $item5->AddWindow( $item30, 0, wxALIGN_RIGHT|wxALIGN_CENTER_VERTICAL|wxTOP|wxLEFT|wxRIGHT, 5 );

    my( $item31 ) = Wx::StaticText->new( $self, -1, "text", wxDefaultPosition, wxDefaultSize, 0 );
    $item5->AddWindow( $item31, 0, wxALIGN_CENTER_VERTICAL|wxTOP|wxLEFT|wxRIGHT, 5 );

    my( $item26 ) = Wx::StaticText->new( $self, -1, "Audio Channels:", wxDefaultPosition, wxDefaultSize, 0 );
    $item5->AddWindow( $item26, 0, wxALIGN_RIGHT|wxALIGN_CENTER_VERTICAL|wxTOP|wxLEFT|wxRIGHT, 5 );

    my( $item27 ) = Wx::StaticText->new( $self, -1, "text", wxDefaultPosition, wxDefaultSize, 0 );
    $item5->AddWindow( $item27, 0, wxALIGN_CENTER_VERTICAL|wxTOP|wxLEFT|wxRIGHT, 5 );

    my( $item24 ) = Wx::StaticText->new( $self, -1, "Audio Bitrate:", wxDefaultPosition, wxDefaultSize, 0 );
    $item5->AddWindow( $item24, 0, wxALIGN_RIGHT|wxALIGN_CENTER_VERTICAL|wxTOP|wxLEFT|wxRIGHT, 5 );

    my( $item25 ) = Wx::StaticText->new( $self, -1, "text", wxDefaultPosition, wxDefaultSize, 0 );
    $item5->AddWindow( $item25, 0, wxALIGN_CENTER_VERTICAL|wxTOP|wxLEFT|wxRIGHT, 5 );

    my( $item28 ) = Wx::StaticText->new( $self, -1, "Audio Frequency:", wxDefaultPosition, wxDefaultSize, 0 );
    $item5->AddWindow( $item28, 0, wxALIGN_RIGHT|wxALIGN_CENTER_VERTICAL|wxALL, 5 );

    my( $item29 ) = Wx::StaticText->new( $self, -1, "text", wxDefaultPosition, wxDefaultSize, 0 );
    $item5->AddWindow( $item29, 0, wxALIGN_CENTER_VERTICAL|wxALL, 5 );

    $item0->Add( $item5, 0, wxALIGN_CENTER_VERTICAL|wxLEFT|wxRIGHT, 10 );

    my( $item22 ) = Wx::StaticLine->new( $self, -1, wxDefaultPosition, [255,-1], wxLI_HORIZONTAL );
    $item0->AddWindow( $item22, 0, wxALIGN_CENTER|wxGROW, 10 );

    my( $item23 ) = Wx::TextCtrl->new( $self, -1, "", wxDefaultPosition, [80,60], wxTE_MULTILINE|wxTE_READONLY|wxVSCROLL );
    $item0->AddWindow( $item23, 0, wxGROW|wxALL, 17 );

	$item0->Add(my $xmlbtn = $self->{xmlbtn} = Wx::Button->new($self, -1, "View XML"), 0, wxALIGN_RIGHT|wxLEFT|wxRIGHT|wxBOTTOM, 13);
    EVT_BUTTON($self, $xmlbtn, sub { OnClickXML($rec) });

	# Set fonts
	$item2->SetFont($fontmb);
    $item3->SetFont($fontm);
    $item6->SetFont($fontsmb);
    $item7->SetFont($fontsm);
    $item8->SetFont($fontsmb);
    $item9->SetFont($fontsm);
    $item10->SetFont($fontsmb);
    $item11->SetFont($fontsm);
    $item14->SetFont($fontsmb);
    $item15->SetFont($fontsm);
    $item12->SetFont($fontsmb);
    $item13->SetFont($fontsm);
    $item16->SetFont($fontsmb);
    $item17->SetFont($fontsm);
    $item18->SetFont($fontsmb);
    $item19->SetFont($fontsm);
    $item20->SetFont($fontsmb);
    $item21->SetFont($fontsm);
    $item24->SetFont($fontsmb);
    $item25->SetFont($fontsm);
    $item26->SetFont($fontsmb);
    $item27->SetFont($fontsm);
    $item28->SetFont($fontsmb);
    $item29->SetFont($fontsm);
    $item30->SetFont($fontsmb);
    $item31->SetFont($fontsm);
    $item23->SetFont($fontsm);
 
    # Fill all these labels..
 	$item2->SetLabel(substr($rec->show, 0, 20));
	$item3->SetLabel(($rec->size/1024)."MB");
	$item7->SetLabel($rec->episode);
	$item9->SetLabel($rec->date);
	$item11->SetLabel($rec->station);
	$item13->SetLabel($rec->fps);
	$item15->SetLabel($rec->width."x".$rec->height);
	$item17->SetLabel(($rec->aspect eq "1.3333")?"4:3 (1.333)":$rec->aspect);
	$item19->SetLabel($rec->bitrate."kbps (".($rec->bitrate/8)." kbytes/s)");
	
	my $t = int($rec->duration/60)."m".($rec->duration%60)."s";
	$item21->SetLabel($t);
	$item23->SetValue($rec->description);
	$item25->SetLabel($rec->abitrate."kbps");
	$item27->SetLabel($rec->achan);
	$item29->SetLabel($rec->afreq."hz");
	$item31->SetLabel(($rec->aformat eq "80")?"80 (MP2)":$rec->aformat);
   
    $self->SetSizer( $item0 );
    $item0->SetSizeHints( $self );

 	$item2->SetLabel(substr($rec->show, 0, 32));

	return $self;
}

sub OnClickXML 
{
	my $rec = shift;
	open (TMP, "| open -f");	
	print TMP $rec->get_xml();
	close TMP;
}
