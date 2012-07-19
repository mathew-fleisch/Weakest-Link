#!/usr/bin/perl
use LWP::UserAgent;

my $base	= "";
my $output	= "";
my $domain_name	= "";
my $display_ext	= 1;
my $recursive	= 1;
my $arg		= "";
my $val		= "";
my $us		= 0;
my $bad_links	= 0;
my $count_files = 0;
my $total_links = 0;
my $inter_links = 0;
my $exter_links = 0;
my $files_found = 0;
my $files_missd = 0;
my %urls = ();



if($#ARGV >= 0)
{
	for($i = 0; $i <= $#ARGV; $i++)
	{
		if($ARGV[$i] =~ /^-/)
		{
			$arg = $ARGV[$i];
			if($ARGV[$i+1] !~ /^-/) { $val = $ARGV[$i+1]; }
			else { $val = 1; }
			process_arguments($arg, $val);
		}
	}
}
else { error_msg("Must specify a directory to profile."); }

#bare minimum requirements
if(!$base) { error_msg("Must specify a directory to profile"); }
if(!$output) { 
	print "**************WARNING: No output file was specified for the link report... One was created automatically at ~/Desktop/link_report.txt**************\n"; 
	$output = "~/Desktop/link_report.txt"; 
}
#To Do Code: prompt user to specify a domain name
if(!$domain_name) { print "**************WARNING: No target domain name was specified... All internal hard/absolute links will appear as external links**************\n"; }

#End min req


open(OUT, ">$output") or die "Cannot open output file, for writing: $!";

my @directories = check_directory($base);
foreach $dir ( 0..$#directories )
{
	$base_dir = trim($directories[$dir]);
	@files = `ls $base_dir/*.html`;
	foreach $file ( 0..$#files )
	{ 
		my $count = 0;
		$crnt_file = trim($files[$file]);
		print OUT "file: \"$crnt_file\"\n";
		print "Processing file: \"$crnt_file\"";
		open(IN, "<$crnt_file") or die "Cannot open file $crnt_file: $!";
		$count_files++;
		@in = <IN>;
		foreach $i ( 0..$#in ) 
		{
			if($in[$i] =~ /href=/)
			{
				my $temp_line = $in[$i];
				$temp_line =~ s/.*href=\"//;
				$temp_line =~ s/\".*//;
				$temp_line =~ s/\n//;
				if($temp_line !~ /^mailto/ and $temp_line) 
				{
					my $link_result = check_link($temp_line, $base_dir);
					$count++;
					$total_links++;
					print OUT $count . "\tLineNum(" . $i . ")\t" . $link_result . "\t" . $temp_line . "\n";
				}
			}
		}
		print "complete.\n";
		print OUT "\n\n";
	}
}

if($display_ext)
{
	$url_size	= keys %urls;
	$us		= $url_size+1;
	$bad_links	= 0;
	print "\nPreparing to test " . commify($url_size) . " absolute links found...\nPlease be patient, as each link takes a second or two, to get a response.\n";
	print OUT commify($url_size) . " External Link HTTP responses and link counts:\n";
	foreach $key (sort (keys(%urls))) 
	{
		my $ua = LWP::UserAgent->new;
		my $req = HTTP::Request->new(GET => $key);
		my $res = $ua->request($req);
		
		if($res->is_success)
		{
			print "$url_size\t$key\t(link active)\n";
			print OUT ($us-$url_size) . "\tlink active\tLinkCount($urls{$key})\t$key\n";
		}
		else
		{
			print "$url_size\t$key\t" . $res->status_line . "\t\n";
			print OUT ($us-$url_size) . "\t" . $res->status_line . "\tLinkCount($urls{$key})\t$key\n";
			$bad_links++;
		}
		$url_size--;
	}
}


print OUT "\nThere were " . commify($count_files) . " files processed and " . commify($total_links) . " links were found.\n" . commify($exter_links) . " were external links and " . commify($inter_links) . " were internal (any remaining links were top anchor links)... \nof those internal links, " . commify($files_found) . " were matched to files, and " . commify($files_missd) . " had no matching files.";
if($display_ext) { print OUT "\nThere were " . commify($us-1) . " unique external links, and " . commify($bad_links) . " did not load successfully."; }


close OUT;


sub check_directory($)
{
	my @directories;
	my $directory = shift;
	push(@directories, $directory);
	if(!$recursive) { @dirs = `ls -F $directory`; }
	else { @dirs = `ls -R -F $directory`; }
	foreach $dir ( 0..$#dirs )
	{ 
		$crnt_dir = trim($dirs[$dir]);
		if($crnt_dir =~ /:/)
		{
			$crnt_dir =~ s/://g;
			print $crnt_dir . "\n";
			push(@directories, $crnt_dir);
		}
	}
	return @directories;
}


sub check_link($)
{
	my $link = shift;
	my $base_dir = shift;

	if($link =~ /^http/)
	{
		$exter_links++;
		
		if(exists($urls{$link}))
		{
			my $tmp = $urls{$link};
			$urls{$link} = $tmp+1;
		}
		else { $urls{$link} = 1; }

		if($domain_name)
		{
			if($link =~ /$domain_name/) { return "int(absolute)"; }
			else { return "ext(absolute)"; }
		}
		else { return "ext(absolute)"; }
	} 
	else 
	{
		if($link !~ /^\#/)
		{
			$inter_links++;
			$link =~ s/\#.*//g;
			$file_exists = `test -e $base_dir/$link && echo "true"`;
			if($file_exists) { $files_found++; return "int(File fnd)"; }
			else { $files_missd++; return "int(No File!)"; }
		}
		else { return "int( anchor )"; }
	}
}

sub process_arguments($)
{
	my $arg = shift;
	my $val = shift;
	if (!$val) { $val = 1; }

	if($arg =~ /^-d/) #user specified domain for internal/external absolute link distinction
	{
		$domain_name = $val;
		$domain_name =~ s/http(s)*:\/\/(www\.)*//g;
	}
	elsif($arg =~ /^-e/) #user specifies not to check external links
	{
		if(!$val or $val =~ /false/i) { $display_ext = 0; }
		else { $display_ext = 1; }
	}
	elsif($arg =~ /^-m/) #user wants to see man page
	{
		print "
--------------------------------------------------------------------------------------------------------
Project: Weakest Link
Author: Mathew Fleisch (mathew.fleisch\@gmail.com)
Description:
\t\tUse this script to test internal and external links in a directory.
\t\tPass a target directory, and a destination/filename for a report
\t\tand the script identifies every link, in every .html file, found
\t\tin the target directory. After all of the links have been identified
\t\tthe script loops through every link... If the link is an external link
\t\t(starts with \"http\"), the script will run an http request, to test
\t\tif the link is active, and is documented in the generated report. If 
\t\tthe link is internal (does NOT start with \"http\"), the script will
\t\tattempt to locate the file, and document in the report if it was found,
\t\tor not.

Required Arguments:
\t-target or –t:
\t\tDescription: Specifies the target directory where the script 
\t\t\tis to run from.
\t\tExample: -t /path/to/target/directory

Optional Arguments:
\t-domain_name or –d:
\t\tDescription: Specifies the domain name of the target website.
\t\tExample: -d my-domain.com
\t\tNote: \"http://www.\" Automatically removed. If omitted, all 
\t\t\tinternal absolute/hard links will appear as external links.

\t-external or –e:
\t\tDescription: Specifies whether to display link counts and http error 
\t\t\tcodes in the report.
\t\tExample: -e false
\t\tNote: Default has this flag set to true (-e true is the same as -e)

\t-manual or -m:
\t\tDescription: Displays this dialog.
\t\tExample: -m

\t-output or -o:
\t\tDescription: Specifies the location and filename of the generated report.
\t\tExample: -o /path/to/my_link_report.xls
\t\tNote: Default is ~/Desktop/link_report.txt

\t-recursive or –r:
\t\tDescription: Toggles a recursive search of all .html files under the 
\t\t\ttarget directory.
\t\tExample: -r false
\t\tNote: Default has this flag set to true (-r true is the same as -r)

Thank you,
\t~Mathew
--------------------------------------------------------------------------------------------------------\n\n";
		exit;
	}
	elsif($arg =~ /^-o/) #user specified output directory
	{
		#to do code: if file already exists, ask user if they want to overwrite, if not, error out
		
		@output_dirs = split(/\//, $val);
		@output_dRev = reverse @output_dirs;

		my $filename = $output_dRev[0];
		if($filename)
		{
			if($filename =~ /\./) {
				@split_file = split(/\./, $filename);
				@split_fRev = reverse @split_file;
				$file_title = $split_file[0];
				$file_type = $split_fRev[0];
			}
			else { error_msg("No filetype found"); }
		}
		else { error_msg("Must specify a filename"); }

		$output_path = $val;
		$output_path =~ s/\/$filename//g;
		
		if(-d $output_path) { $output = $val; }
		else { error_msg("The output directory specified was not found..."); }
	}
	elsif($arg =~ /^-r/)
	{
		if(!$val or $val =~ /false/i) { $recursive = 0; }
		else { $recursive = 1; }
	}
	elsif($arg =~ /^-t/) #user specified target directory
	{
		#Remove any trailing periods and slashes
		$val =~ s/\.$//g;
		$val =~ s/\/$//g;
		
		#Check to see if the directory exists, and error out, if it doesn't
		if(-d $val) { $base = $val; }
		else { error_msg("No Directory Found"); }
	}
	else { error_msg("Argument not recognized... use -m to view the possible arguments"); }
}

sub error_msg($)
{
	my $msg = shift;
	print "\nERROR: $msg\n";
	exit;
}

sub commify {
	# commify a number. Perl Cookbook, 2.17, p. 64
	my $text = reverse $_[0];
	$text =~ s/(\d\d\d)(?=\d)(?!\d*\.)/$1,/g;
	return scalar reverse $text;
}


sub trim($)
{
	my $string = shift;
	$string =~ s/^\s+//;
	$string =~ s/\s+$//;
	return $string;
}
