#!/usr/bin/wxPerl
use strict;
use warnings;
use AppConfig;
use Wx;
use Frame;

#
# Main
#
package main;

# Startup functions - things related to environment 
our $version = "0.6.0";
our $home = $ENV{'HOME'};
our $logfile = $home."/Library/Logs/tivotool.log";
our $debug = 1;

my $logsize = -s $logfile;
`rm $home/Library/Logs/tivotool.log` if ($logsize > 30000);

open(STDOUT, ">> $logfile") or die "Can't redirect stdout: $!";
open(STDERR, ">&STDOUT") or die "Can't dup stdout: $!";

`killall -9 vstream-client &>/dev/null`;

# Check for and create pipes if necessary 
mkdir("$home/.tivotool", 0755) unless (-d "$home/.tivotool");
system('mkfifo', "$home/.tivotool/tydemux") unless (-e "$home/.tivotool/tydemux");
system('mkfifo', "$home/.tivotool/streamty") unless (-e "$home/.tivotool/streamty");

# Start TivoTool
my $app = TTApp->new();
$app->MainLoop;
sub GetApp { return $app; }
sub TTDebug 
{ 
	foreach (@_) 
	{ 
		print localtime(time)." ".$_."\n"; 
	}
}

#
# wxApp override
#
package TTApp;
use base 'Wx::App';
sub OnInit 
{
	my $self = shift;
	$self->SetAppName('TivoTool');
	my $frame = Frame->new;	# The main window gets created here
	$self->SetTopWindow($frame);
	$frame->Show(1);			# and drawn here
}

