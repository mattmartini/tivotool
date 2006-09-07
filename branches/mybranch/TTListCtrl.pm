package TTListCtrl;
use strict;
use Wx;
use Wx qw(:everything);
use Wx::Event qw(EVT_LIST_KEY_DOWN EVT_KEY_DOWN EVT_LIST_COL_CLICK EVT_LIST_ITEM_DESELECTED EVT_LIST_ITEM_ACTIVATED EVT_IDLE);
$|++;
use base 'Wx::ListCtrl';

my $c = $TTConfig::config; 
my $rc = RefreshController->new(); # handles external command lines
my @flip = undef; # stores ascending/descending state for columns
our @row_objects = undef; # an array of hashes, recording data stored here

############################## BUILD COLUMNS #########################################
sub BuildColumns 
{
    my ($self, $event) = @_;
	$self->SetFont(Wx::Font->new(11,wxDEFAULT,wxNORMAL,wxNORMAL,0,'Lucida Grande'));
	$self->InsertColumn( 0, "Show",		wxLIST_FORMAT_LEFT,);
	$self->InsertColumn( 1, "Episode",	wxLIST_FORMAT_LEFT,);
	$self->InsertColumn( 2, "Date",		wxLIST_FORMAT_LEFT,);
	$self->InsertColumn( 3, "Station",	wxLIST_FORMAT_LEFT,);
	$self->InsertColumn( 4, "FSID",		wxLIST_FORMAT_LEFT,);
	$self->SetColumnWidth(0, $c->col1());
	$self->SetColumnWidth(1, $c->col2());
	$self->SetColumnWidth(2, $c->col3());
	$self->SetColumnWidth(3, $c->col4());
	$self->SetColumnWidth(4, $c->col5());
}

############################ COLUMN SORTING #########################################
sub OnColClick 
{
    my ($self, $event) = @_;
	my $selcol = $event->GetColumn;
    my @sorted = ();
    
	# Sort data,
	if 	  ($selcol==0) { @sorted = sort { $a->show cmp $b->show } 		@row_objects; }
	elsif ($selcol==1) { @sorted = sort { $a->episode cmp $b->episode } @row_objects; }
	elsif ($selcol==2) { @sorted = sort { $a->comparable_date <=> $b->comparable_date } @row_objects; }
	elsif ($selcol==3) { @sorted = sort { $a->station cmp $b->station } @row_objects; }
	elsif ($selcol==4) { @sorted = sort { $a->fsid <=> $b->fsid } 		@row_objects; }
	else { return; }
	
	# reverse if necessary,
	@row_objects = (++$flip[$selcol]%2 == 0 ? reverse @sorted : @sorted); # increment flip for next time
	
	# then sync data.
	$self->SyncRecs();
}

############################ REFRESH EVENTS #########################################
# Downloads records from Tivo unit and saves to @row_objects
sub Populate 
{
    my ($self, $event) = @_;
	@row_objects = $rc->PopulateRecordings($self);
	$self->SyncRecs();
}

# Used by Populate() to display objects in listctrl  
sub SyncRecs 
{
    my ($self, $event) = @_;
	my $row_counter = 0;
	my $altcolor = Wx::Colour->new(237,243,254);

	$self->DeleteAllItems();
	$self->Show(0);
	
	foreach (@row_objects) 
	{ 
		my $row = $self->InsertStringItem($row_counter, $_->show());
		$self->SetItem($row_counter, 1, $_->episode());
		$self->SetItem($row_counter, 2, $_->date());
		$self->SetItem($row_counter, 3, $_->station());
		$self->SetItem($row_counter, 4, $_->fsid());
		$self->SetItemData($row, $row_counter);	
		$self->SetItemBackgroundColour($row_counter, $altcolor) if ($row_counter % 2) != 0;
		$row_counter++;
	}

	$self->Show(1);

	EVT_LIST_COL_CLICK($self, $self, \&OnColClick);
}

1;