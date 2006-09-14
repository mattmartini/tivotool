# All conceivable options
# Data Model of user choices
package TTConfig;
use strict;
use AppConfig;

# class data
my $home = $ENV{'HOME'};
my $file = "$home/Library/Preferences/tivotool.conf";

# create object HERE, so we just have one copy, instead of a bunch of these floating around 
# among different packages
our $config = AppConfig->new({ GLOBAL => { ARGCOUNT => '1' } });

# Define names and defaults		
$config->define(
	'TIVOIP' 	=> { DEFAULT => '0.0.0.0' },
	'OUTPUTDIR' => { DEFAULT => "$home/Desktop" },
	'TIVOSERVER'   => { DEFAULT => '/Library/Application\ Support/TivoTool/tivoserver' },
	'MPLAYER'   => { DEFAULT => '/Library/Application\ Support/TivoTool/ttmplayer' },
	'MENCODER'  => { DEFAULT => '/Library/Application\ Support/TivoTool/ttmencoder' },
	'UBER'		=> { DEFAULT => '/Library/Application\ Support/TivoTool/mfs_uberexport' },
	'VSTREAM'   => { DEFAULT => '/Library/Application\ Support/TivoTool/vstream-client' },
	'VSPLIT'    => { DEFAULT => '/Library/Application\ Support/TivoTool/vsplit' },
	'HDEMUX'    => { DEFAULT => '/Library/Application\ Support/TivoTool/hdemux' },
	'DUMPOBJ'   => { DEFAULT => '/Library/Application\ Support/TivoTool/mfs_dumpobj' },
	'MENCODERS' => { DEFAULT => '/Library/Application\ Support/TivoTool/ttmencoder-stdout' },
	'FFMPEG'    => { DEFAULT => '/Library/Application\ Support/TivoTool/ffmpeg' },
	'MPLEX'     => { DEFAULT => '/Library/Application\ Support/TivoTool/mplex' },
	'DVDAUTHOR' => { DEFAULT => '/Library/Application\ Support/TivoTool/dvdauthor' },
	'MKISOFS'   => { DEFAULT => '/Library/Application\ Support/TivoTool/mkisofs' },
	'DVDAPP'    => { DEFAULT => '/Applications/DVD\ Player.app/' },						    
	'CACHE' 	=> { DEFAULT => '8' },
	'CACHEMIN'  => { DEFAULT => '10' },
	'POST' 		=> { DEFAULT => 'crop=0:0:0:0' },
	'REFRESHSTARTUP' 		=> { DEFAULT => '0' },
	'ELEMENTAL' => { DEFAULT => '0' },
	'TWOPASS'	=> { DEFAULT => '0' },
	'CROP_LEFT' => { DEFAULT => '0' },
	'CROP_RIGHT' => { DEFAULT => '0' },
	'CROP_TOP'  => { DEFAULT => '0' },
	'CROP_BOTTOM' => { DEFAULT => '0' },
	'RESIZE_W'  => { DEFAULT => '0' },
	'RESIZE_H'  => { DEFAULT => '0' },
	'FORCE_ASPECT' => { DEFAULT => '0' },
	'DEINT'		=> { DEFAULT => '0' },
	'WAVOUT'	=> { DEFAULT => '0' },
	'BITRATE'	=> { DEFAULT => '1200' },
	'TC_HZ'		=> { DEFAULT => '0' },
	'TC_BPS'	=> { DEFAULT => '0' },
	'TC_ENABLE'	=> { DEFAULT => '0' },
	'TC_HOLE'	=> { DEFAULT => '0' },
	'FRAMEDROP'	=> { DEFAULT => '0' },
	'STREAM_DEINT'	=> { DEFAULT => '0' },
	'STREAM_DENOISE' => { DEFAULT => '0' },
	'STREAM_CROP'	=> { DEFAULT => '0' },
	'STREAM_TRANSCODE'	=> { DEFAULT => '0' },
	'STREAM_ASPECT'	=> { DEFAULT => '0' }, # 0 auto 1 4:3 2 16:9
	'WINDOWX' => { DEFAULT => '0' },
	'WINDOWY' => { DEFAULT => '22' },
	'WINDOWW' => { DEFAULT => '796' },
	'WINDOWH' => { DEFAULT => '384' },
	'COL1' => { DEFAULT => '120' },
	'COL2' => { DEFAULT => '190' },
	'COL3' => { DEFAULT => '100' },
	'COL4' => { DEFAULT => '60' },
	'COL5' => { DEFAULT => '60' },
	'COL6' => { DEFAULT => '17' },
	'DLMODE' => { DEFAULT => '0' }, # the download format combobox
	'DLMODE_AUTO' => { DEFAULT => '0' }, # the download format for scheduled downloads
	'AUTO_HOUR' => { DEFAULT => '12' }, # the what hour of the day?
	'AUTO_MINUTE' => { DEFAULT => '0' }, # what minute of the hour?
	'AUTO_AMPM' => { DEFAULT => '0' }, # am or pm
	'SCHED_ENABLE' => { DEFAULT => '0' }, # enable the scheduler (cron)
	'SCHED_HOUR' => { DEFAULT => '0' }, # 0-23
	'SCHED_MINUTE' => { DEFAULT => '0' }, # 0-59
	'TOOLBAR' => { DEFAULT => '0' }, # show/hide toolbar
	'BBPATH' => { DEFAULT => '/var/hacks/bin/busybox' }, # location, on the tivo, of busybox
	'VSERVERPATH' => { DEFAULT => '/var/hacks/bin/vserver' }, # ditto vserver
);  

# Do one refresh on startup...
Refresh();

# Subroutines 
sub Refresh 
{
	$config->file($file) if -f $file; # refresh values from a (perhaps recently) saved config file
}
	
sub Write 
{		
	open (CONFIG,"> $file") or die("cant write tivotool config file!! $! \n", 0);
	
	# Dig into config hash to loop through keys, then print values for variable hash to disk.
	# use of data::dumper on $config will give a better idea of the structure here..
	foreach my $q ( sort ( keys %{ $config->{STATE}->{VARIABLE} } ) ) 
	{
		print CONFIG uc("$q")."=$config->{STATE}->{VARIABLE}{$q} \n";
	}
	
	close CONFIG or die("cant close config $!");
}

1;