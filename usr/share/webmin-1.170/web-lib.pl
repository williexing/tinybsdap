# web-lib.pl
# Common functions and definitions for web admin programs

# Vital libraries
use Socket;
use SelfLoader;

# Configuration and spool directories
if (!defined($ENV{'WEBMIN_CONFIG'})) {
	die "WEBMIN_CONFIG not set";
	}
$config_directory = $ENV{'WEBMIN_CONFIG'};
if (!defined($ENV{'WEBMIN_VAR'})) {
	open(VARPATH, "$config_directory/var-path");
	chop($var_directory = <VARPATH>);
	close(VARPATH);
	}
else {
	$var_directory = $ENV{'WEBMIN_VAR'};
	}

if ($ENV{'SESSION_ID'}) {
	# Hide this variable from called programs, but keep it for internal use
	$main::session_id = $ENV{'SESSION_ID'};
	delete($ENV{'SESSION_ID'});
	}
if ($ENV{'REMOTE_PASS'}) {
	# Hide the password too
	$main::remote_pass = $ENV{'REMOTE_PASS'};
	delete($ENV{'REMOTE_PASS'});
	}

if ($> == 0 && $< != 0 && !$ENV{'FOREIGN_MODULE_NAME'}) {
	# Looks like we are running setuid, but the real UID hasn't been set.
	# Do so now, so that executed programs don't get confused
	$( = $);
	$< = $>;
	}

$remote_error_handler = "error";
@INC = &unique(@INC, ".");

use vars qw($user_risk_level $loaded_theme_library $wait_for_input
	    $done_webmin_header $trust_unknown_referers
	    %done_foreign_require $webmin_feedback_address
	    $user_skill_level $pragma_no_cache $foreign_args);

__DATA__

# read_file(file, &assoc, [&order], [lowercase], [split-char])
# Fill an associative array with name=value pairs from a file
sub read_file
{
local $_;
local $split = defined($_[4]) ? $_[4] : "=";
open(ARFILE, $_[0]) || return 0;
while(<ARFILE>) {
	chomp;
	local $hash = index($_, "#");
	local $eq = index($_, $split);
	if ($hash != 0 && $eq >= 0) {
		local $n = substr($_, 0, $eq);
		local $v = substr($_, $eq+1);
		$_[1]->{$_[3] ? lc($n) : $n} = $v;
		push(@{$_[2]}, $n) if ($_[2]);
        	}
        }
close(ARFILE);
if (defined($main::read_file_cache{$_[0]})) {
	%{$main::read_file_cache{$_[0]}} = %{$_[1]};
	}
return 1;
}

# read_file_cached(file, &assoc)
# Like read_file, but reads from a cache if the file has already been read
sub read_file_cached
{
if (defined($main::read_file_cache{$_[0]})) {
	%{$_[1]} = ( %{$_[1]}, %{$main::read_file_cache{$_[0]}} );
	}
else {
	local %d;
	&read_file($_[0], \%d, $_[2], $_[3], $_[4]);
	%{$main::read_file_cache{$_[0]}} = %d;
	%{$_[1]} = ( %{$_[1]}, %d );
	}
}
 
# write_file(file, array, [join-char])
# Write out the contents of an associative array as name=value lines
sub write_file
{
local(%old, @order);
local $join = defined($_[2]) ? $_[2] : "=";
&read_file($_[0], \%old, \@order);
open(ARFILE, ">$_[0]") || &error(&text("efilewrite", $_[0], $!));
foreach $k (@order) {
	if (exists($_[1]->{$k})) {
		(print ARFILE $k,$join,$_[1]->{$k},"\n") ||
			&error(&text("efilewrite", $_[0], $!));
		}
	}
foreach $k (keys %{$_[1]}) {
	if (!exists($old{$k})) {
		(print ARFILE $k,$join,$_[1]->{$k},"\n") ||
			&error(&text("efilewrite", $_[0], $!));
		}
        }
close(ARFILE);
if (defined($main::read_file_cache{$_[0]})) {
	%{$main::read_file_cache{$_[0]}} = %{$_[1]};
	}
}

# html_escape(string)
# Convert &, < and > codes in text to HTML entities
sub html_escape
{
local $tmp = $_[0];
$tmp =~ s/&/&amp;/g;
$tmp =~ s/</&lt;/g;
$tmp =~ s/>/&gt;/g;
$tmp =~ s/\"/&quot;/g;
$tmp =~ s/\'/&#39;/g;
$tmp =~ s/=/&#61;/g;
return $tmp;
}

# quote_escape(string)
# Converts ' and " characters in a string into HTML entities
sub quote_escape
{
local $tmp = $_[0];
$tmp =~ s/\"/&quot;/g;
$tmp =~ s/\'/&#39;/g;
return $tmp;
}

# tempname([filename])
# Returns a mostly random temporary file name
sub tempname
{
local $tmp_base = $gconfig{'tempdir'} || "/tmp/.webmin";
local $tmp_dir = -d $remote_user_info[7] && !$gconfig{'nohometemp'} ?
			"$remote_user_info[7]/.tmp" :
		 @remote_user_info ? $tmp_base."-".$remote_user :
		 $< != 0 ? $tmp_base."-".getpwuid($<) :
				     $tmp_base;
local $tries = 0;
while($tries++ < 10) {
	local @st = lstat($tmp_dir);
	last if ($st[4] == $< && (-d _) && ($st[2] & 0777) == 0755);
	if (@st) {
		unlink($tmp_dir) || rmdir($tmp_dir) ||
			system("/bin/rm -rf ".quotemeta($tmp_dir));
		}
	mkdir($tmp_dir, 0755) || next;
	chown($<, $(, $tmp_dir);
	chmod(0755, $tmp_dir);
	}
&error("Failed to create temp directory $tmp_dir") if ($tries >= 10);
if (defined($_[0]) && $_[0] !~ /\.\./) {
	return "$tmp_dir/$_[0]";
	}
else {
	$main::tempfilecount++;
	&seed_random();
	return $tmp_dir."/".int(rand(1000000))."_".
	       $main::tempfilecount."_".$scriptname;
	}
}

# trunc
# Truncation a string to the shortest whole word less than or equal to
# the given width
sub trunc {
  local($str,$c);
  if (length($_[0]) <= $_[1])
    { return $_[0]; }
  $str = substr($_[0],0,$_[1]);
  do {
    $c = chop($str);
    } while($c !~ /\S/);
  $str =~ s/\s+$//;
  return $str;
}

# indexof(string, array)
# Returns the index of some value in an array, or -1
sub indexof {
  local($i);
  for($i=1; $i <= $#_; $i++) {
    if ($_[$i] eq $_[0]) { return $i - 1; }
  }
  return -1;
}

# unique
# Returns the unique elements of some array
sub unique
{
local(%found, @rv, $e);
foreach $e (@_) {
	if (!$found{$e}++) { push(@rv, $e); }
	}
return @rv;
}

# sysprint(handle, [string]+)
sub sysprint
{
local($str, $fh);
$str = join('', @_[1..$#_]);
$fh = $_[0];
syswrite $fh, $str, length($str);
}

# check_ipaddress(ip)
# Check if some IP address is properly formatted
sub check_ipaddress
{
return $_[0] =~ /^(\d+)\.(\d+)\.(\d+)\.(\d+)$/ &&
	$1 >= 0 && $1 <= 255 &&
	$2 >= 0 && $2 <= 255 &&
	$3 >= 0 && $3 <= 255 &&
	$4 >= 0 && $4 <= 255;
}

# generate_icon(image, title, link, [href], [width], [height])
sub generate_icon
{
&load_theme_library();
if (defined(&theme_generate_icon)) {
	&theme_generate_icon(@_);
	return;
	}
local $w = !defined($_[4]) ? "width=48" : $_[4] ? "width=$_[4]" : "";
local $h = !defined($_[5]) ? "height=48" : $_[5] ? "height=$_[5]" : "";
if ($tconfig{'noicons'}) {
	if ($_[2]) {
		print "<a href=\"$_[2]\" $_[3]>$_[1]</a>\n";
		}
	else {
		print "$_[1]\n";
		}
	}
elsif ($_[2]) {
	print "<table border><tr><td width=48 height=48>\n",
	      "<a href=\"$_[2]\" $_[3]><img src=\"$_[0]\" alt=\"\" border=0 ",
	      "$w $h></a></td></tr></table>\n";
	print "<a href=\"$_[2]\" $_[3]>$_[1]</a>\n";
	}
else {
	print "<table border><tr><td width=48 height=48>\n",
	      "<img src=\"$_[0]\" alt=\"\" border=0 $w $h>",
	      "</td></tr></table>\n$_[1]\n";
	}
}

# urlize
# Convert a string to a form ok for putting in a URL
sub urlize {
  local $rv = $_[0];
  $rv =~ s/([^A-Za-z0-9])/sprintf("%%%2.2X", ord($1))/ge;
  return $rv;

#  local($tmp, $tmp2, $c);
#  $tmp = $_[0];
#  $tmp2 = "";
#  while(($c = chop($tmp)) ne "") {
#	if ($c !~ /[A-z0-9]/) {
#		$c = sprintf("%%%2.2X", ord($c));
#		}
#	$tmp2 = $c . $tmp2;
#	}
#  return $tmp2;
}

# un_urlize(string)
# Converts a URL-encoded string to the original
sub un_urlize
{
local $rv = $_[0];
$rv =~ s/\+/ /g;
$rv =~ s/%(..)/pack("c",hex($1))/ge;
return $rv;
}

# include
# Read and output the named file
sub include
{
local $_;
open(INCLUDE, $_[0]) || return 0;
while(<INCLUDE>) {
	print;
	}
close(INCLUDE);
return 1;
}

# copydata
# Read from one file handle and write to another
sub copydata
{
local ($buf, $out, $in);
$out = $_[1];
$in = $_[0];
while(read($in, $buf, 1024) > 0) {
	print $out $buf;
	}
}

# ReadParseMime([maximum])
# Read data submitted via a POST request using the multipart/form-data coding.
sub ReadParseMime
{
local ($boundary, $line, $foo, $name, $got);
local $err = &text('readparse_max', $_[0]);
$ENV{'CONTENT_TYPE'} =~ /boundary=(.*)$/ || &error($text{'readparse_enc'});
$boundary = $1;
<STDIN>;	# skip first boundary
while(1) {
	$name = "";
	# Read section headers
	local $lastheader;
	while(1) {
		$line = <STDIN>;
		$got += length($line);
		&error($err) if ($_[0] && $got > $_[0]);
		$line =~ tr/\r\n//d;
		last if (!$line);
		if ($line =~ /^(\S+):\s*(.*)$/) {
			$header{$lastheader = lc($1)} = $2;
			}
		elsif ($line =~ /^\s+(.*)$/) {
			$header{$lastheader} .= $line;
			}
		}

	# Parse out filename and type
	if ($header{'content-disposition'} =~ /^form-data(.*)/) {
		$rest = $1;
		while ($rest =~ /([a-zA-Z]*)=\"([^\"]*)\"(.*)/) {
			if ($1 eq 'name') {
				$name = $2;
				}
			else {
				$foo = $name . "_$1";
				$in{$foo} = $2;
				}
			$rest = $3;
			}
		}
	else {
		&error($text{'readparse_cdheader'});
		}
	if ($header{'content-type'} =~ /^([^\s;]+)/) {
		$foo = $name . "_content_type";
		$in{$foo} = $1;
		}

	# Read data
	$in{$name} .= "\0" if (defined($in{$name}));
	while(1) {
		$line = <STDIN>;
		$got += length($line);
		&error($err) if ($_[0] && $got > $_[0]);
		if (!$line) { return; }
		if (index($line, $boundary) != -1) { last; }
		$in{$name} .= $line;
		}
	chop($in{$name}); chop($in{$name});
	if (index($line,"$boundary--") != -1) { last; }
	}
}

# ReadParse([&assoc], [method], [noplus])
# Fills the given associative array with CGI parameters, or uses the global
# %in if none is given. Also sets the global variables $in and @in
sub ReadParse
{
local $a = $_[0] ? $_[0] : \%in;
%$a = ( );
local $i;
local $meth = $_[1] ? $_[1] : $ENV{'REQUEST_METHOD'};
undef($in);
if ($meth eq 'POST') {
	read(STDIN, $in, $ENV{'CONTENT_LENGTH'});
	}
if ($ENV{'QUERY_STRING'}) {
	if ($in) { $in .= "&".$ENV{'QUERY_STRING'}; }
	else { $in = $ENV{'QUERY_STRING'}; }
	}
@in = split(/\&/, $in);
foreach $i (@in) {
	local ($k, $v) = split(/=/, $i, 2);
	if (!$_[2]) {
		$k =~ tr/\+/ /;
		$v =~ tr/\+/ /;
		}
	$k =~ s/%(..)/pack("c",hex($1))/ge;
	$v =~ s/%(..)/pack("c",hex($1))/ge;
	$a->{$k} = defined($a->{$k}) ? $a->{$k}."\0".$v : $v;
	}
}

# PrintHeader(charset)
# Outputs the HTTP header for HTML
sub PrintHeader
{
if ($pragma_no_cache || $gconfig{'pragma_no_cache'}) 
{
	print "pragma: no-cache\n";
	print "Expires: Thu, 1 Jan 1970 00:00:00 GMT\n";
	print "Cache-Control: no-store, no-cache, must-revalidate\n";
	print "Cache-Control: post-check=0, pre-check=0\n";
	}
if (defined($_[0])) {
	print "Content-type: text/html; Charset=$_[0]\n\n";
	}
else {
	print "Content-type: text/html\n\n";
	}
	print "<link href=/style.css rel=stylesheet type=text/css>";
}

# header(title, image, [help], [config], [nomodule], [nowebmin], [rightside],
#	 [header], [body], [below])
# Output a page header with some title and image. The header may also
# include a link to help, and a link to the config page.
# The header will also have a link to to webmin index, and a link to the
# module menu if there is no config link
sub header
{
return if ($main::done_webmin_header++);
local $ll;
local $charset = defined($force_charset) ? $force_charset : &get_charset();
&PrintHeader($charset);
&load_theme_library();
if (defined(&theme_header)) {
	&theme_header(@_);
	return;
	}
print "<!doctype html public \"-//W3C//DTD HTML 3.2 Final//EN\">\n";
print "<html>\n";
local $os_type = $gconfig{'real_os_type'} ? $gconfig{'real_os_type'}
					  : $gconfig{'os_type'};
local $os_version = $gconfig{'real_os_version'} ? $gconfig{'real_os_version'}
					        : $gconfig{'os_version'};
print "<head>\n";
if ($charset) {
	print "<meta http-equiv=\"Content-Type\" ",
	      "content=\"text/html; Charset=$charset\">\n";
	}
if (@_ > 0) {
	if ($gconfig{'sysinfo'} == 1) {
		printf "<title>%s : %s on %s (%s %s)</title>\n",
			$_[0], $remote_user, &get_display_hostname(),
			$os_type, $os_version;
		}
	elsif ($gconfig{'sysinfo'} == 4) {
		printf "<title>%s on %s (%s %s)</title>\n",
			$remote_user, &get_display_hostname(),
			$os_type, $os_version;
		}
	else {
		print "<title>$_[0]</title>\n";
		}
	print $_[7] if ($_[7]);
	print "<LINK href=/style.css rel=stylesheet type=text/css>";

	if ($gconfig{'sysinfo'} == 0 && $remote_user) {
		print "<script language=JavaScript type=text/javascript>\n";
		printf
		"defaultStatus=\"%s%s logged into %s %s on %s (%s%s)\";\n",
			$ENV{'ANONYMOUS_USER'} ? "Anonymous user" :$remote_user,
			$ENV{'SSL_USER'} ? " (SSL certified)" :
			$ENV{'LOCAL_USER'} ? " (Local user)" : "",
			$text{'programname'},
			&get_webmin_version(), &get_display_hostname(),
			$os_type, $os_version eq "*" ? "" : " $os_version";
		print "</SCRIPT>\n";
		}
	}
print "$tconfig{'headhtml'}\n" if ($tconfig{'headhtml'});
if ($tconfig{'headinclude'}) {
	local $_;
	open(INC, "$root_directory/$current_theme/$tconfig{'headinclude'}");
	while(<INC>) {
		print;
		}
	close(INC);
	}
print "</head>\n";
local $bgcolor = defined($tconfig{'cs_page'}) ? $tconfig{'cs_page'} :
		 defined($gconfig{'cs_page'}) ? $gconfig{'cs_page'} : "ffffff";
local $link = defined($tconfig{'cs_link'}) ? $tconfig{'cs_link'} :
	      defined($gconfig{'cs_link'}) ? $gconfig{'cs_link'} : "0000ee";
local $text = defined($tconfig{'cs_text'}) ? $tconfig{'cs_text'} : 
	      defined($gconfig{'cs_text'}) ? $gconfig{'cs_text'} : "000000";
local $bgimage = defined($tconfig{'bgimage'}) ? "background=$tconfig{'bgimage'}"
					      : "";

$bgcolor = "27455B";

print "<body bgcolor=#$bgcolor link=#$link vlink=#$link text=#$text ",
      "$bgimage $tconfig{'inbody'} $_[8]>\n";

#       -- Makeup background / Wapsol
print "<table bgcolor=white align=center class=main><tr><td class=capsule>";

local $hostname = &get_display_hostname();
local $version = &get_webmin_version();
local $prebody = $tconfig{'prebody'};
if ($prebody) {
	$prebody =~ s/%HOSTNAME%/$hostname/g;
	$prebody =~ s/%VERSION%/$version/g;
	$prebody =~ s/%USER%/$remote_user/g;
	$prebody =~ s/%OS%/$os_type $os_version/g;
	print "$prebody\n";
	}
if ($tconfig{'prebodyinclude'}) {
	local $_;
	open(INC, "$root_directory/$current_theme/$tconfig{'prebodyinclude'}");
	while(<INC>) {
		print;
		}
	close(INC);
	}
if (defined(&theme_prebody)) {
	&theme_prebody(@_);
	}
if (@_ > 1) {
	print "<table class=header border=0 width=100%><tr>\n";
	if ($gconfig{'sysinfo'} == 2 && $remote_user) {
		print "<td colspan=3 align=center>\n";
		printf "%s%s logged into %s (%s%s)</td>\n",
			$ENV{'ANONYMOUS_USER'} ? "Anonymous user" : "<tt>$remote_user</tt>",
			$ENV{'SSL_USER'} ? " (SSL certified)" :
			$ENV{'LOCAL_USER'} ? " (Local user)" : "",
			$text{'programname'},
			$version, "<tt>$hostname</tt>",
			$os_type, $os_version eq "*" ? "" : " $os_version";
		print "</tr> <tr>\n";
		}
	print "<td width=15% valign=top align=left>";
	if ($ENV{'HTTP_WEBMIN_SERVERS'}) {
		print "<a href='$ENV{'HTTP_WEBMIN_SERVERS'}'>",
		      "$text{'header_servers'}</a><br>\n";
		}
	if (!$_[5] && !$tconfig{'noindex'}) {
		local %acl;
		&read_acl(undef, \%acl);
		#local $mc = @{$acl{$base_remote_user}};
		local @avail = &get_available_module_infos(1);
		local $nolo = $ENV{'ANONYMOUS_USER'} ||
			      $ENV{'SSL_USER'} || $ENV{'LOCAL_USER'} ||
			      $ENV{'HTTP_USER_AGENT'} =~ /webmin/i;
		if ($gconfig{'gotoone'} && $main::session_id && @avail == 1 &&
		    !$nolo) {
			print "<a href='$gconfig{'webprefix'}/session_login.cgi?logout=1'>",
			      "$text{'main_logout'}</a><br>";
			}
		elsif ($gconfig{'gotoone'} && @avail == 1 && !$nolo) {
			print "<a href=$gconfig{'webprefix'}/switch_user.cgi>",
			      "$text{'main_switch'}</a><br>";
			}
		elsif (!$gconfig{'gotoone'} || @avail > 1) {
			print "<a href='$gconfig{'webprefix'}/?cat=$module_info{'category'}'>",
			      "$text{'header_webmin'}</a><br>\n";
			}
		}
	if (!$_[4] && !$tconfig{'nomoduleindex'}) {
		local $idx = $module_info{'index_link'};
		local $mi = $module_index_link || "/$module_name/$idx";
		local $mt = $module_index_name || $text{'header_module'};
		print "<a href=\"$gconfig{'webprefix'}$mi\">$mt</a><br>\n";
		}
	if (ref($_[2]) eq "ARRAY" && !$ENV{'ANONYMOUS_USER'}) {
		print &hlink($text{'header_help'}, $_[2]->[0], $_[2]->[1]),
		      "<br>\n";
		}
	elsif (defined($_[2]) && !$ENV{'ANONYMOUS_USER'}) {
		print &hlink($text{'header_help'}, $_[2]),"<br>\n";
		}
	if ($_[3]) {
		local %access = &get_module_acl();
		if (!$access{'noconfig'} && !$config{'noprefs'}) {
			local $cprog = $user_module_config_directory ?
					"uconfig.cgi" : "config.cgi";
			print "<a href=\"$gconfig{'webprefix'}/$cprog?$module_name\">",
			      $text{'header_config'},"</a><br>\n";
			}
		}
	print "</td>\n";

	#	-- Title gifs
	if ($_[1]) {
		# Title is a single image
		print "<td align=center width=70%>",
		      "<img alt=\"$_[0]\" src=\"$_[1]\"></td>\n";
		}
	elsif ($current_lang_info->{'titles'} && !$gconfig{'texttitles'} &&
	       !$tconfig{'texttitles'}) {
		# Title is made out of letter images
		local $title = &entities_to_ascii($_[0]);
		print "<td align=center width=70%>";
		foreach $l (split(//, $title)) {
			$ll = ord($l);
			if ($ll > 127 && $current_lang_info->{'charset'}) {
				print "<img src=$gconfig{'webprefix'}/images/letters/$ll.$current_lang_info->{'charset'}.gif alt=\"$l\" align=bottom>";
				}
			elsif ($l eq " ") {
				print "<img src=$gconfig{'webprefix'}/images/letters/$ll.gif alt=\"\&nbsp;\" align=bottom>";
				}
			else {
				print "<img src=$gconfig{'webprefix'}/images/letters/$ll.gif alt=\"$l\" align=bottom>";
				}
			}
		print "<br>$_[9]\n" if ($_[9]);
		print "</td>\n";
		}
	else {
		# Title is just text
		print "<td align=center width=70%><h1>$_[0]</h1>\n";
		print "$_[9]\n" if ($_[9]);
		print "</td>\n";
		}
	print "<td width=15% valign=top align=right>";
	print $_[6];
	print "</td></tr></table>\n";
	}
}

# footer([page, name]+, [noendbody])
# Output a footer for returning to some page
sub footer
{
&load_theme_library();
if (defined(&theme_footer)) {
	&theme_footer(@_);
	return;
	}
local $i;
for($i=0; $i+1<@_; $i+=2) {
	local $url = $_[$i];
	if ($url ne '/' || !$tconfig{'noindex'}) {
		if ($url eq '/') {
			$url = "/?cat=$module_info{'category'}";
			}
		elsif ($url eq '' && $module_name) {
			$url = "/$module_name/$module_info{'index_link'}";
			}
		elsif ($url =~ /^\?/ && $module_name) {
			$url = "/$module_name/$url";
			}
		$url = "$gconfig{'webprefix'}$url" if ($url =~ /^\//);
		if ($i == 0) {
			print "<a href=\"$url\"><img alt=\"<-\" align=middle border=0 src=$gconfig{'webprefix'}/images/left.gif></a>\n";
			}
		else {
			print "&nbsp;|\n";
			}
		print "&nbsp;<a href=\"$url\">",&text('main_return', $_[$i+1]),"</a>\n";
		}
	}
print "<br>\n";
if (!$_[$i]) {
	local $postbody = $tconfig{'postbody'};
	if ($postbody) {
		local $hostname = &get_display_hostname();
		local $version = &get_webmin_version();
		local $os_type = $gconfig{'real_os_type'} ?
				$gconfig{'real_os_type'} : $gconfig{'os_type'};
		local $os_version = $gconfig{'real_os_version'} ?
				$gconfig{'real_os_version'} : $gconfig{'os_version'};
		$postbody =~ s/%HOSTNAME%/$hostname/g;
		$postbody =~ s/%VERSION%/$version/g;
		$postbody =~ s/%USER%/$remote_user/g;
		$postbody =~ s/%OS%/$os_type $os_version/g;
		print "$postbody\n";
		}
	if ($tconfig{'postbodyinclude'}) {
		local $_;
		open(INC,
		 "$root_directory/$current_theme/$tconfig{'postbodyinclude'}");
		while(<INC>) {
			print;
			}
		close(INC);
		}
	if (defined(&theme_postbody)) {
		&theme_postbody(@_);
		}

	#       -- Makeup background / Wapsol
	print "</td></tr>
		<tr><td style='font-size: 7pt; align=center; font-family: verdana; border-style=solid; border-width: 1 0 0 0;' class=copyright>
			&copy; 2006 Wapsol GmbH | Best viewed with Firefox 1.5+</td></tr>
		</table>";

	print "</body></html>\n";
	}
}

# load_theme_library()
# For internal use only
sub load_theme_library
{
return if (!$current_theme || !$tconfig{'functions'} ||
	   $loaded_theme_library++);
do "$root_directory/$current_theme/$tconfig{'functions'}";
}

# redirect
# Output headers to redirect the browser to some page
sub redirect
{
local($port, $prot, $url);
$port = $ENV{'SERVER_PORT'} == 443 && uc($ENV{'HTTPS'}) eq "ON" ? "" :
	$ENV{'SERVER_PORT'} == 80 && uc($ENV{'HTTPS'}) ne "ON" ? "" :
		":$ENV{'SERVER_PORT'}";
$prot = uc($ENV{'HTTPS'}) eq "ON" ? "https" : "http";
local $wp = $gconfig{'webprefixnoredir'} ? undef : $gconfig{'webprefix'};
if ($_[0] =~ /^(http|https|ftp|gopher):/) {
	# Absolute URL (like http://...)
	$url = $_[0];
	}
elsif ($_[0] =~ /^\//) {
	# Absolute path (like /foo/bar.cgi)
	$url = "$prot://$ENV{'SERVER_NAME'}$port$wp$_[0]";
	}
elsif ($ENV{'SCRIPT_NAME'} =~ /^(.*)\/[^\/]*$/) {
	# Relative URL (like foo.cgi)
	$url = "$prot://$ENV{'SERVER_NAME'}$port$wp$1/$_[0]";
	}
else {
	$url = "$prot://$ENV{'SERVER_NAME'}$port/$wp$_[0]";
	}
print "Location: $url\n\n";
}

# kill_byname(name, signal)
# Use the command defined in the global config to find and send a signal
# to a process matching some name
sub kill_byname
{
local(@pids);
@pids = &find_byname($_[0]);
if (@pids) { kill($_[1], @pids); return scalar(@pids); }
else { return 0; }
}

# kill_byname_logged(name, signal)
# Like kill_byname, but also logs the killing
sub kill_byname_logged
{
local(@pids);
@pids = &find_byname($_[0]);
if (@pids) { &kill_logged($_[1], @pids); return scalar(@pids); }
else { return 0; }
}

# find_byname(name)
# Finds a process by name, and returns a list of matching PIDs
sub find_byname
{
local($cmd, @pids);
$cmd = $gconfig{'find_pid_command'};
$cmd =~ s/NAME/"$_[0]"/g;
@pids = split(/\n/, `($cmd) </dev/null 2>/dev/null`);
@pids = grep { $_ != $$ } @pids;
return @pids;
}

# error([message]+)
# Display an error message and exit. The variable $whatfailed must be set
# to the name of the operation that failed.
sub error
{
&load_theme_library();
if ($main::error_must_die) {
	die @_;
	}
elsif (!$ENV{'REQUEST_METHOD'}) {
	# Show text-only error
	print STDERR "$text{'error'}\n";
	print STDERR "-----\n";
	print STDERR ($main::whatfailed ? "$main::whatfailed : " : ""),@_,"\n";
	print STDERR "-----\n";
	}
elsif (defined(&theme_error)) {
	&theme_error(@_);
	}
else {
	&header($text{'error'}, "");
	print "<hr>\n";
	print "<h3>",($main::whatfailed ? "$main::whatfailed : " : ""),@_,"</h3>\n";
	print "<hr>\n";
	&footer();
	}
&unlock_all_files();
exit;
}

# error_setup(message)
# Register a message to be prepended to all error strings
sub error_setup
{
$main::whatfailed = $_[0];
}

# wait_for(handle, regexp, regexp, ...)
# Read from the input stream until one of the regexps matches..
sub wait_for
{
local ($c, $i, $sw, $rv, $ha); undef($wait_for_input);
if ($wait_for_debug) {
	print STDERR "wait_for(",join(",", @_),")\n";
	}
$ha = $_[0];
$codes =
"local \$hit;\n".
"while(1) {\n".
" if ((\$c = getc($ha)) eq \"\") { return -1; }\n".
" \$wait_for_input .= \$c;\n";
if ($wait_for_debug) {
	$codes .= "print STDERR \$wait_for_input,\"\\n\";";
	}
for($i=1; $i<@_; $i++) {
        $sw = $i>1 ? "elsif" : "if";
        $codes .= " $sw (\$wait_for_input =~ /$_[$i]/i) { \$hit = $i-1; }\n";
        }
$codes .=
" if (defined(\$hit)) {\n".
"  \@matches = (-1, \$1, \$2, \$3, \$4, \$5, \$6, \$7, \$8, \$9);\n".
"  return \$hit;\n".
"  }\n".
" }\n";
$rv = eval $codes;
if ($@) { &error("wait_for error : $@\n"); }
return $rv;
}

# fast_wait_for(handle, string, string, ...)
sub fast_wait_for
{
local($inp, $maxlen, $ha, $i, $c, $inpl);
for($i=1; $i<@_; $i++) {
	$maxlen = length($_[$i]) > $maxlen ? length($_[$i]) : $maxlen;
	}
$ha = $_[0];
while(1) {
	if (($c = getc($ha)) eq "") {
		&error("fast_wait_for read error : $!");
		}
	$inp .= $c;
	if (length($inp) > $maxlen) {
		$inp = substr($inp, length($inp)-$maxlen);
		}
	$inpl = length($inp);
	for($i=1; $i<@_; $i++) {
		if ($_[$i] eq substr($inp, $inpl-length($_[$i]))) {
			return $i-1;
			}
		}
	}
}

# has_command(command)
# Returns the full path if some command is in the path, undef if not
sub has_command
{
local($d);
if (!$_[0]) { return undef; }
if (exists($main::has_command_cache{$_[0]})) {
	return $main::has_command_cache{$_[0]};
	}
local $rv = undef;
if ($_[0] =~ /^\//) {
	$rv = (-x $_[0]) ? $_[0] : undef;
	}
else {
	foreach $d (split(/:/ , $ENV{PATH})) {
		if (-x "$d/$_[0]") { $rv = "$d/$_[0]"; last; }
		}
	}
$main::has_command_cache{$_[0]} = $rv;
return $rv;
}

# make_date(seconds)
# Converts a Unix date/time in seconds to a human-readable form
sub make_date
{
local(@tm);
@tm = localtime($_[0]);
return sprintf "%d/%s/%d %2.2d:%2.2d",
		$tm[3], $text{"smonth_".($tm[4]+1)},
		$tm[5]+1900, $tm[2], $tm[1];
}

# file_chooser_button(input, type, [form], [chroot], [addmode])
# Return HTML for a file chooser button, if the browser supports Javascript.
# Type values are 0 for file or directory, or 1 for directory only
sub file_chooser_button
{
local $form = defined($_[2]) ? $_[2] : 0;
local $chroot = defined($_[3]) ? $_[3] : "/";
local $add = int($_[4]);
return "<input type=button onClick='ifield = document.forms[$form].$_[0]; chooser = window.open(\"$gconfig{'webprefix'}/chooser.cgi?add=$add&type=$_[1]&chroot=$chroot&file=\"+escape(ifield.value), \"chooser\", \"toolbar=no,menubar=no,scrollbar=no,width=400,height=300\"); chooser.ifield = ifield; window.ifield = ifield' value=\"...\">\n";
}

# read_acl(&array, &array)
# Reads the acl file into the given associative arrays
sub read_acl
{
local($user, $_, @mods);
if (!defined(%main::acl_hash_cache)) {
	local $_;
	open(ACL, &acl_filename());
	while(<ACL>) {
		if (/^([^:]+):\s*(.*)/) {
			local(@mods);
			$user = $1;
			@mods = split(/\s+/, $2);
			foreach $m (@mods) {
				$main::acl_hash_cache{$user,$m}++;
				}
			$main::acl_array_cache{$user} = \@mods;
			}
		}
	close(ACL);
	}
if ($_[0]) { %{$_[0]} = %main::acl_hash_cache; }
if ($_[1]) { %{$_[1]} = %main::acl_array_cache; }
}

# acl_filename()
# Returns the file containing the webmin ACL
sub acl_filename
{
return "$config_directory/webmin.acl";
}

# acl_check()
# Does nothing, but kept around for compatability
sub acl_check
{
}

# get_miniserv_config(&array)
# Store miniserv configuration into the given array
sub get_miniserv_config
{
return &read_file($ENV{'MINISERV_CONFIG'} ? $ENV{'MINISERV_CONFIG'} :
		  "$config_directory/miniserv.conf", $_[0]);
}

# put_miniserv_config(&array)
# Store miniserv configuration from the given array
sub put_miniserv_config
{
&write_file($ENV{'MINISERV_CONFIG'} ? $ENV{'MINISERV_CONFIG'} :
	    "$config_directory/miniserv.conf", $_[0]);
}

# restart_miniserv()
# Kill the old miniserv process and re-start it
sub restart_miniserv
{
local($pid, %miniserv, $addr, $i);
&get_miniserv_config(\%miniserv) || return;
$miniserv{'inetd'} && return;
open(PID, $miniserv{'pidfile'}) || &error("Failed to open pid file");
chop($pid = <PID>);
close(PID);
if (!$pid) { &error("Invalid pid file"); }

# Just signal miniserv to restart
&kill_logged('HUP', $pid);

## Totally kill the process and re-run it
#$SIG{'TERM'} = 'IGNORE';
#&kill_logged('TERM', $pid);
#&system_logged("$config_directory/start >/dev/null 2>&1 </dev/null");

# wait for miniserv to come back up
$addr = inet_aton($miniserv{'bind'} ? $miniserv{'bind'} : "127.0.0.1");
local $ok = 0;
for($i=0; $i<20; $i++) {
#	sleep(1);
	socket(STEST, PF_INET, SOCK_STREAM, getprotobyname("tcp"));
	local $rv = connect(STEST, pack_sockaddr_in($miniserv{'port'}, $addr));
	close(STEST);
	last if ($rv && ++$ok >= 2);
	}
if ($i == 20) { &error("Failed to restart Webmin server!"); }
}

# check_os_support(&minfo)
sub check_os_support
{
local $oss = $_[0]->{'os_support'};
return 1 if (!$oss || $oss eq '*');
local $osver = $gconfig{'os_version'};
local $ostype = $gconfig{'os_type'};
while(1) {
	local ($os, $ver, $codes);
	if ($oss =~ /^([^\/\s]+)\/([^\{\s]+)\{([^\}]*)\}\s*(.*)$/) {
		# OS/version{code}
		$os = $1; $ver = $2; $codes = $3; $oss = $4;
		}
	elsif ($oss =~ /^([^\/\s]+)\/([^\/\s]+)\s*(.*)$/) {
		# OS/version
		$os = $1; $ver = $2; $oss = $3;
		}
	elsif ($oss =~ /^([^\{\s]+)\{([^\}]*)\}\s*(.*)$/) {
		# OS/{code}
		$os = $1; $codes = $2; $oss = $3;
		}
	elsif ($oss =~ /^\{([^\}]*)\}\s*(.*)$/) {
		# {code}
		$codes = $1; $oss = $2;
		}
	elsif ($oss =~ /^(\S+)\s*(.*)$/) {
		# OS
		$os = $1; $oss = $2;
		}
	else { last; }
	next if ($os && !($os eq $ostype ||
			  $ostype =~ /^(\S+)-(\S+)$/ && $os eq "*-$2"));
	if ($ver =~ /^([0-9\.]+)\-([0-9\.]+)$/) {
		next if ($osver < $1 || $osver > $2);
		}
	elsif ($ver =~ /^([0-9\.]+)\-\*$/) {
		next if ($osver < $1);
		}
	elsif ($ver =~ /^\*\-([0-9\.]+)$/) {
		next if ($osver > $1);
		}
	elsif ($ver) {
		next if ($ver ne $osver);
		}
	next if ($codes && !eval $codes);
	return 1;
	}
return 0;
}

# http_download(host, port, page, destfile, [&error], [&callback], [sslmode],
#		[user, pass])
# Download data from a HTTP url to a local file
sub http_download
{
$download_timed_out = undef;
local $SIG{ALRM} = "download_timeout";
alarm(60);
local $h = &make_http_connection($_[0], $_[1], $_[6], "GET", $_[2]);
alarm(0);
$h = $download_timed_out if ($download_timed_out);
if (!ref($h)) {
	if ($_[4]) { ${$_[4]} = $h; return; }
	else { &error($h); }
	}
&write_http_connection($h, "Host: $_[0]\r\n");
&write_http_connection($h, "User-agent: Webmin\r\n");
if ($_[7]) {
	local $auth = &encode_base64("$_[7]:$_[8]");
	$auth =~ tr/\r\n//d;
	&write_http_connection($h, "Authorization: Basic $auth\r\n");
	}
&write_http_connection($h, "\r\n");
&complete_http_download($h, $_[3], $_[4], $_[5]);
}

# complete_http_download(handle, destfile, [&error], [&callback])
# Do a HTTP download, after the headers have been sent
sub complete_http_download
{
local($line, %header, $s);
local $cbfunc = $_[3];

# read headers
alarm(60);
($line = &read_http_connection($_[0])) =~ tr/\r\n//d;
if ($line !~ /^HTTP\/1\..\s+(200|302|301)\s+/) {
	if ($_[2]) { ${$_[2]} = $line; return; }
	else { &error("Download failed : $line"); }
	}
local $rcode = $1;
&$cbfunc(1, $rcode == 302 || $rcode == 301 ? 1 : 0) if ($cbfunc);
while(1) {
	$line = &read_http_connection($_[0]);
	$line =~ tr/\r\n//d;
	$line =~ /^(\S+):\s+(.*)$/ || last;
	$header{lc($1)} = $2;
	}
alarm(0);
if ($download_timed_out) {
	if ($_[3]) { ${$_[3]} = $download_timed_out; return 0; }
	else { &error($download_timed_out); }
	}
&$cbfunc(2, $header{'content-length'}) if ($cbfunc);
if ($rcode == 302 || $rcode == 301) {
	# follow the redirect
	&$cbfunc(5, $header{'location'}) if ($cbfunc);
	local ($host, $port, $page);
	if ($header{'location'} =~ /^http:\/\/([^:]+):(\d+)(\/.*)?$/) {
		$host = $1; $port = $2; $page = $3 || "/";
		}
	elsif ($header{'location'} =~ /^http:\/\/([^:\/]+)(\/.*)?$/) {
		$host = $1; $port = 80; $page = $2 || "/";
		}
	else {
		if ($_[2]) { ${$_[2]} = "Missing Location header"; return; }
		else { &error("Missing Location header"); }
		}
	&http_download($host, $port, $page, $_[1], $_[2], $cbfunc);
	}
else {
	# read data
	if (ref($_[1])) {
		# Append to a variable
		while(defined($buf = &read_http_connection($_[0], 1024))) {
			${$_[1]} .= $buf;
			&$cbfunc(3, length(${$_[1]})) if ($cbfunc);
			}
		}
	else {
		# Write to a file
		local $got = 0;
		if (!open(PFILE, ">$_[1]")) {
			if ($_[2]) { ${$_[2]} = "Failed to write to $_[1] : $!"; return; }
			else { &error("Failed to write to $_[1] : $!"); }
			}
		while(defined($buf = &read_http_connection($_[0], 1024))) {
			print PFILE $buf;
			$got += length($buf);
			&$cbfunc(3, $got) if ($cbfunc);
			}
		close(PFILE);
		if ($header{'content-length'} &&
		    $got != $header{'content-length'}) {
			if ($_[2]) { ${$_[2]} = "Download incomplete"; return; }
			else { &error("Download incomplete"); }
			}
		}
	&$cbfunc(4) if ($cbfunc);
	}
&close_http_connection($_[0]);
}


# ftp_download(host, file, destfile, [&error], [&callback], [user, pass])
# Download data from an FTP site to a local file
sub ftp_download
{
local($buf, @n);
local $cbfunc = $_[4];

$download_timed_out = undef;
local $SIG{ALRM} = "download_timeout";
alarm(60);
if ($gconfig{'ftp_proxy'} =~ /^http:\/\/(\S+):(\d+)/ && !&no_proxy($_[0])) {
	# download through http-style proxy
	&open_socket($1, $2, "SOCK", $_[3]) || return 0;
	if ($download_timed_out) {
		if ($_[3]) { ${$_[3]} = $download_timed_out; return 0; }
		else { &error($download_timed_out); }
		}
	local $esc = $_[1]; $esc =~ s/ /%20/g;
	local $up = "$_[5]:$_[6]\@" if ($_[5]);
	print SOCK "GET ftp://$up$_[0]$esc HTTP/1.0\r\n";
	print SOCK "User-agent: Webmin\r\n";
	if ($gconfig{'proxy_user'}) {
		local $auth = &encode_base64(
		   "$gconfig{'proxy_user'}:$gconfig{'proxy_pass'}");
		$auth =~ tr/\r\n//d;
		print SOCK "Proxy-Authorization: Basic $auth\r\n";
		}
	print SOCK "\r\n";
	&complete_http_download({ 'fh' => "SOCK" }, $_[2], $_[3], $_[4]);
	}
else {
	# connect to host and login
	&open_socket($_[0], 21, "SOCK", $_[3]) || return 0;
	alarm(0);
	if ($download_timed_out) {
		if ($_[3]) { ${$_[3]} = $download_timed_out; return 0; }
		else { &error($download_timed_out); }
		}
	&ftp_command("", 2, $_[3]) || return 0;
	if ($_[5]) {
		# Login as supplied user
		local @urv = &ftp_command("USER $_[5]", [ 2, 3 ], $_[3]);
		@urv || return 0;
		if (int($urv[1]/100) == 3) {
			&ftp_command("PASS $_[6]", 2, $_[3]) || return 0;
			}
		}
	else {
		# Login as anonymous
		local @urv = &ftp_command("USER anonymous", [ 2, 3 ], $_[3]);
		@urv || return 0;
		if (int($urv[1]/100) == 3) {
			&ftp_command("PASS root\@".&get_system_hostname(), 2,
				     $_[3]) || return 0;
			}
		}
	&$cbfunc(1, 0) if ($cbfunc);

	# get the file size and tell the callback
	&ftp_command("TYPE I", 2, $_[3]) || return 0;
	local $size = &ftp_command("SIZE $_[1]", 2, $_[3]);
	defined($size) || return 0;
	if ($cbfunc) {
		&$cbfunc(2, int($size));
		}

	# request the file
	local $pasv = &ftp_command("PASV", 2, $_[3]);
	defined($pasv) || return 0;
	$pasv =~ /\(([0-9,]+)\)/;
	@n = split(/,/ , $1);
	&open_socket("$n[0].$n[1].$n[2].$n[3]", $n[4]*256 + $n[5], "CON", $_[3]) || return 0;
	&ftp_command("RETR $_[1]", 1, $_[3]) || return 0;

	# transfer data
	local $got = 0;
	open(PFILE, "> $_[2]");
	while(read(CON, $buf, 1024) > 0) {
		print PFILE $buf;
		$got += length($buf);
		&$cbfunc(3, $got) if ($cbfunc);
		}
	close(PFILE);
	close(CON);
	if ($got != $size) {
		if ($_[3]) { ${$_[3]} = "Download incomplete"; return 0; }
		else { &error("Download incomplete"); }
		}
	&$cbfunc(4) if ($cbfunc);

	# finish off..
	&ftp_command("", 2, $_[3]) || return 0;
	&ftp_command("QUIT", 2, $_[3]) || return 0;
	close(SOCK);
	}
return 1;
}

# ftp_upload(host, file, srcfile, [&error], [&callback], [user, pass])
# Download data from a local file to an FTP site
sub ftp_upload
{
local($buf, @n);
local $cbfunc = $_[4];

$download_timed_out = undef;
local $SIG{ALRM} = "download_timeout";
alarm(60);

# connect to host and login
&open_socket($_[0], 21, "SOCK", $_[3]) || return 0;
alarm(0);
if ($download_timed_out) {
	if ($_[3]) { ${$_[3]} = $download_timed_out; return 0; }
	else { &error($download_timed_out); }
	}
&ftp_command("", 2, $_[3]) || return 0;
if ($_[5]) {
	# Login as supplied user
	local @urv = &ftp_command("USER $_[5]", [ 2, 3 ], $_[3]);
	@urv || return 0;
	if (int($urv[1]/100) == 3) {
		&ftp_command("PASS $_[6]", 2, $_[3]) || return 0;
		}
	}
else {
	# Login as anonymous
	local @urv = &ftp_command("USER anonymous", [ 2, 3 ], $_[3]);
	@urv || return 0;
	if (int($urv[1]/100) == 3) {
		&ftp_command("PASS root\@".&get_system_hostname(), 2,
			     $_[3]) || return 0;
		}
	}
&$cbfunc(1, 0) if ($cbfunc);

&ftp_command("TYPE I", 2, $_[3]) || return 0;

# get the file size and tell the callback
local @st = stat($_[2]);
if ($cbfunc) {
	&$cbfunc(2, $st[7]);
	}

# send the file
local $pasv = &ftp_command("PASV", 2, $_[3]);
defined($pasv) || return 0;
$pasv =~ /\(([0-9,]+)\)/;
@n = split(/,/ , $1);
&open_socket("$n[0].$n[1].$n[2].$n[3]", $n[4]*256 + $n[5], "CON", $_[3]) || return 0;
&ftp_command("STOR $_[1]", 1, $_[3]) || return 0;

# transfer data
local $got;
open(PFILE, $_[2]);
while(read(PFILE, $buf, 1024) > 0) {
	print CON $buf;
	$got += length($buf);
	&$cbfunc(3, $got) if ($cbfunc);
	}
close(PFILE);
close(CON);
if ($got != $st[7]) {
	if ($_[3]) { ${$_[3]} = "Upload incomplete"; return 0; }
	else { &error("Upload incomplete"); }
	}
&$cbfunc(4) if ($cbfunc);

# finish off..
&ftp_command("", 2, $_[3]) || return 0;
&ftp_command("QUIT", 2, $_[3]) || return 0;
close(SOCK);

return 1;
}

# no_proxy(host)
# Checks if some host is on the no proxy list
sub no_proxy
{
local $ip = &to_ipaddress($_[0]);
foreach $n (split(/\s+/, $gconfig{'noproxy'})) {
	return 1 if ($_[0] =~ /\Q$n\E/ ||
		     $ip =~ /\Q$n\E/);
	}
return 0;
}

# open_socket(host, port, handle, [&error])
sub open_socket
{
local($addr, $h); $h = $_[2];
if (!socket($h, PF_INET, SOCK_STREAM, getprotobyname("tcp"))) {
	if ($_[3]) { ${$_[3]} = "Failed to create socket : $!"; return 0; }
	else { &error("Failed to create socket : $!"); }
	}
if (!($addr = inet_aton($_[0]))) {
	if ($_[3]) { ${$_[3]} = "Failed to lookup IP address for $_[0]"; return 0; }
	else { &error("Failed to lookup IP address for $_[0]"); }
	}
if ($gconfig{'bind_proxy'}) {
	if (!bind($h, pack_sockaddr_in(0, inet_aton($gconfig{'bind_proxy'})))) {
		if ($_[3]) { ${$_[3]} = "Failed to bind to source address : $!"; return 0; }
		else { &error("Failed to bind to source address : $!"); }
		}
	}
if (!connect($h, pack_sockaddr_in($_[1], $addr))) {
	if ($_[3]) { ${$_[3]} = "Failed to connect to $_[0]:$_[1] : $!"; return 0; }
	else { &error("Failed to connect to $_[0]:$_[1] : $!"); }
	}
select($h); $| =1; select(STDOUT);
return 1;
}


# download_timeout()
# Called when a download times out
sub download_timeout
{
$download_timed_out = "Download timed out";
}


# ftp_command(command, expected, [&error])
# Send an FTP command, and die if the reply is not what was expected
sub ftp_command
{
local($line, $rcode, $reply, $c);
$what = $_[0] ne "" ? "<i>$_[0]</i>" : "initial connection";
if ($_[0] ne "") {
        print SOCK "$_[0]\r\n";
        }
alarm(60);
if (!($line = <SOCK>)) {
	if ($_[2]) { ${$_[2]} = "Failed to read reply to $what"; return undef; }
	else { &error("Failed to read reply to $what"); }
        }
$line =~ /^(...)(.)(.*)$/;
local $found = 0;
if (ref($_[1])) {
	foreach $c (@{$_[1]}) {
		$found++ if (int($1/100) == $c);
		}
	}
else {
	$found++ if (int($1/100) == $_[1]);
	}
if (!$found) {
	if ($_[2]) { ${$_[2]} = "$what failed : $3"; return undef; }
	else { &error("$what failed : $3"); }
	}
$rcode = $1; $reply = $3;
if ($2 eq "-") {
        # Need to skip extra stuff..
        while(1) {
                if (!($line = <SOCK>)) {
			if ($_[2]) { ${$_[2]} = "Failed to read reply to $what";
				     return undef; }
			else { &error("Failed to read reply to $what"); }
                        }
                $line =~ /^(....)(.*)$/; $reply .= $2;
		if ($1 eq "$rcode ") { last; }
                }
        }
alarm(0);
return wantarray ? ($reply, $rcode) : $reply;
}

# to_ipaddress(hostname)
# Converts a hostname to an a.b.c.d format IP address
sub to_ipaddress
{
if (&check_ipaddress($_[0])) {
	return $_[0];
	}
else {
	local $hn = gethostbyname($_[0]);
	return undef if (!$hn);
	local @ip = unpack("CCCC", $hn);
	return join("." , @ip);
	}
}

# icons_table(&links, &titles, &icons, [columns], [href], [width], [height])
# Renders a 4-column table of icons
sub icons_table
{
&load_theme_library();
if (defined(&theme_icons_table)) {
	&theme_icons_table(@_);
	return;
	}
local ($i, $need_tr);
local $cols = $_[3] ? $_[3] : 4;
local $per = int(100.0 / $cols);
print "<table width=100% cellpadding=5>\n";
for($i=0; $i<@{$_[0]}; $i++) {
	if ($i%$cols == 0) { print "<tr>\n"; }
	print "<td width=$per% align=center valign=top>\n";
	&generate_icon($_[2]->[$i], $_[1]->[$i], $_[0]->[$i],
		       ref($_[4]) ? $_[4]->[$i] : $_[4], $_[5], $_[6]);
	print "</td>\n";
        if ($i%$cols == $cols-1) { print "</tr>\n"; }
        }
while($i++%$cols) { print "<td width=$per%></td>\n"; $need_tr++; }
print "</tr>\n" if ($need_tr);
print "</table>\n";
}

# replace_file_line(file, line, [newline]*)
# Replaces one line in some file with 0 or more new lines
sub replace_file_line
{
local(@lines);
open(FILE, $_[0]);
@lines = <FILE>;
close(FILE);
if (@_ > 2) { splice(@lines, $_[1], 1, @_[2..$#_]); }
else { splice(@lines, $_[1], 1); }
open(FILE, "> $_[0]");
print FILE @lines;
close(FILE);
}

# read_file_lines(file)
# Returns a reference to an array containing the lines from some file. This
# array can be modified, and will be written out when flush_file_lines()
# is called.
sub read_file_lines
{
if (!$main::file_cache{$_[0]}) {
        local(@lines, $_);
        open(READFILE, $_[0]);
        while(<READFILE>) {
                tr/\r\n//d;
                push(@lines, $_);
                }
        close(READFILE);
        $main::file_cache{$_[0]} = \@lines;
        }
return $main::file_cache{$_[0]};
}

# flush_file_lines([file], [eol])
sub flush_file_lines
{
local $f;
local @files = $_[0] ? ( $_[0] ) : ( keys %main::file_cache );
local $eol = $_[1] || "\n";
foreach $f (@files) {
        open(FLUSHFILE, ">$f");
	local $line;
        foreach $line (@{$main::file_cache{$f}}) {
                print FLUSHFILE $line,$eol;
                }
        close(FLUSHFILE);               
	delete($main::file_cache{$f});
        }
}                                       

# unix_user_input(fieldname, user, [form])
# Returns HTML for an input to select a Unix user
sub unix_user_input
{
return "<input name=$_[0] size=13 value=\"$_[1]\"> ".
       &user_chooser_button($_[0], 0, $_[2] || 0)."\n";
}

# unix_group_input(fieldname, user, [form])
# Returns HTML for an input to select a Unix group
sub unix_group_input
{
return "<input name=$_[0] size=13 value=\"$_[1]\"> ".
       &group_chooser_button($_[0], 0, $_[2] || 0)."\n";
}

# hlink(text, page, [module])
sub hlink
{
local $mod = $_[2] ? $_[2] : $module_name;
return "<a onClick='window.open(\"$gconfig{'webprefix'}/help.cgi/$mod/$_[1]\", \"help\", \"toolbar=no,menubar=no,scrollbars=yes,width=400,height=300,resizable=yes\"); return false' href=\"$gconfig{'webprefix'}/help.cgi/$mod/$_[1]\">$_[0]</a>";
}

# user_chooser_button(field, multiple, [form])
# Returns HTML for a javascript button for choosing a Unix user or users
sub user_chooser_button
{
local $form = defined($_[2]) ? $_[2] : 0;
local $w = $_[1] ? 500 : 300;
return "<input type=button onClick='ifield = document.forms[$form].$_[0]; chooser = window.open(\"$gconfig{'webprefix'}/user_chooser.cgi?multi=$_[1]&user=\"+escape(ifield.value), \"chooser\", \"toolbar=no,menubar=no,scrollbars=yes,width=$w,height=200\"); chooser.ifield = ifield; window.ifield = ifield' value=\"...\">\n";
}

# group_chooser_button(field, multiple, [form])
# Returns HTML for a javascript button for choosing a Unix group or groups
sub group_chooser_button
{
local $form = defined($_[2]) ? $_[2] : 0;
local $w = $_[1] ? 500 : 300;
return "<input type=button onClick='ifield = document.forms[$form].$_[0]; chooser = window.open(\"$gconfig{'webprefix'}/group_chooser.cgi?multi=$_[1]&group=\"+escape(ifield.value), \"chooser\", \"toolbar=no,menubar=no,scrollbars=yes,width=$w,height=200\"); chooser.ifield = ifield; window.ifield = ifield' value=\"...\">\n";
}

# foreign_check(module)
# Checks if some other module exists and is supported on this OS
sub foreign_check
{
local %minfo;
&read_file_cached("$root_directory/$_[0]/module.info", \%minfo) || return 0;
return &check_os_support(\%minfo);
}

# foreign_require(module, file)
# Brings in functions from another module
sub foreign_require
{
return 1 if ($main::done_foreign_require{$_[0],$_[1]}++);
local $pkg = $_[0] ? $_[0] : "global";
$pkg =~ s/[^A-Za-z0-9]/_/g;
local @OLDINC = @INC;
@INC = &unique("$root_directory/$_[0]", @INC);
-d "$root_directory/$_[0]" || &error("module $_[0] does not exist");
if (!$module_name && $_[0]) {
	chdir("$root_directory/$_[0]");
	}
eval <<EOF;
package $pkg;
\$ENV{'FOREIGN_MODULE_NAME'} = '$_[0]';
\$ENV{'FOREIGN_ROOT_DIRECTORY'} = '$root_directory';
do "$root_directory/$_[0]/$_[1]" || die \$@;
EOF
@OLDINC = @INC;
if ($@) { &error("require $_[0]/$_[1] failed : <pre>$@</pre>"); }
return 1;
}

# foreign_call(module, function, [arg]*)
# Call a function in another module
sub foreign_call
{
local $pkg = $_[0] ? $_[0] : "global";
$pkg =~ s/[^A-Za-z0-9]/_/g;
local @args = @_[2 .. @_-1];
$main::foreign_args = \@args;
local @rv = eval <<EOF;
package $pkg;
&$_[1](\@{\$main::foreign_args});
EOF
if ($@) { &error("$_[0]::$_[1] failed : $@"); }
return wantarray ? @rv : $rv[0];
}

# foreign_config(module)
# Get the configuration from another module
sub foreign_config
{
local %fconfig;
&read_file_cached("$config_directory/$_[0]/config", \%fconfig);
return %fconfig;
}

# foreign_installed(module, mode)
# Checks if the server for some module is installed, and possibly also checks
# if the module has been configured by Webmin.
# For mode 1, returns 2 if the server is installed and configured for use by
# Webmin, 1 if installed but not configured, or 0 otherwise.
# For mode 0, returns 1 if installed, 0 if not.
# If the module does not provide an install_check.pl script, assumes that
# the server is installed.
sub foreign_installed
{
return 0 if (!&foreign_check($_[0]));
if (!-r "$root_directory/$_[0]/install_check.pl") {
	return $_[1] ? 2 : 1;
	}
&foreign_require($_[0], "install_check.pl");
return &foreign_call($_[0], "is_installed", $_[1]);
}

# foreign_defined(module, function)
# Returns 1 if some function is defined in another module
sub foreign_defined
{
local $pkg = $_[0];
$pkg =~ s/[^A-Za-z0-9]/_/g;
local $func = "${pkg}::$_[1]";
return defined(&$func);
}

# get_system_hostname([short])
# Returns the hostname of this system
sub get_system_hostname
{
local $m = int($_[0]);
if (!$get_system_hostname[$m]) {
	chop($get_system_hostname[$m] = `hostname 2>/dev/null`);
	if ($?) {
		use Sys::Hostname;
		$get_system_hostname[$m] = eval "hostname()";
		if ($@ || !$get_system_hostname[$m]) {
			$get_system_hostname[$m] = "UNKNOWN";
			}
		}
	elsif ($get_system_hostname[$m] !~ /\./ &&
	       $gconfig{'os_type'} =~ /linux$/ &&
	       !$gconfig{'no_hostname_f'} && !$_[0]) {
		# Try with -f flag to get fully qualified name
		local $flag = `hostname -f 2>/dev/null`;
		chop($flag);
		if ($? || $flag eq "") {
			# -f not supported! We have probably set the hostname
			# to just '-f'. Fix the problem (if we are root)
			if ($< == 0) {
				system("hostname '$get_system_hostname[$m]' >/dev/null 2>&1");
				}
			}
		else {
			$get_system_hostname[$m] = $flag;
			}
		}
	}
return $get_system_hostname[$m];
}

# get_webmin_version()
# Returns the version of Webmin currently being run
sub get_webmin_version
{
if (!$get_webmin_version) {
	open(VERSION, "$root_directory/version") || return 0;
	($get_webmin_version = <VERSION>) =~ tr/\r|\n//d;
	close(VERSION);
	}
return $get_webmin_version;
}

# get_module_acl([user], [module])
# Returns an array containing access control options for the given user
sub get_module_acl
{
local %rv;
local $u = defined($_[0]) ? $_[0] : $base_remote_user;
local $m = defined($_[1]) ? $_[1] : $module_name;
&read_file_cached("$root_directory/$m/defaultacl", \%rv);
if ($gconfig{"risk_$u"} && $m) {
	local $rf = $gconfig{"risk_$u"}.'.risk';
	&read_file_cached("$root_directory/$m/$rf", \%rv);

	local $sf = $gconfig{"skill_$u"}.'.skill';
	&read_file_cached("$root_directory/$m/$sf", \%rv);
	}
else {
	&read_file_cached("$config_directory/$m/$u.acl", \%rv);
	if ($remote_user ne $base_remote_user && !defined($_[0])) {
		&read_file_cached("$config_directory/$m/$remote_user.acl",\%rv);
		}
	}
if (defined(&theme_get_module_acl)) {
	%rv = &theme_get_module_acl($_[0], $_[1], \%rv);
	}
return %rv;
}

# save_module_acl(&acl, [user], [module])
# Updates the acl hash for some user and module (or the current one)
sub save_module_acl
{
local $u = defined($_[1]) ? $_[1] : $base_remote_user;
local $m = defined($_[2]) ? $_[2] : $module_name;
if (&foreign_check("acl")) {
	# Check if this user is a member of a group, and if he gets the
	# module from a group. If so, update its ACL as well
	&foreign_require("acl", "acl-lib.pl");
	local ($g, $group);
	foreach $g (&acl::list_groups()) {
		if (&indexof($u, @{$g->{'members'}}) >= 0 &&
		    &indexof($m, @{$g->{'modules'}}) >= 0) {
			$group = $g;
			last;
			}
		}
	if ($group) {
		&save_module_acl($_[0], $group->{'name'}, $m);
		}
	}
if (!-d "$config_directory/$m") {
	mkdir("$config_directory/$m", 0755);
	}
&write_file("$config_directory/$m/$u.acl", $_[0]);
}

# init_config()
# Sets the following variables
#  %config - Per-module configuration
#  %gconfig - Global configuration
#  $tb - Background for table headers
#  $cb - Background for table bodies
#  $scriptname - Base name of the current perl script
#  $module_name - The name of the current module
#  $module_config_directory - The config directory for this module
#  $module_config_file - The config file for this module
#  $webmin_logfile - The detailed logfile for webmin
#  $remote_user - The actual username used to login to webmin
#  $base_remote_user - The username whose permissions are in effect
#  $current_theme - The theme currently in use
#  $root_directory - The root directory of this webmin install
sub init_config
{
# Read the webmin global config file. This contains the OS type and version,
# OS specific configuration and global options such as proxy servers
$config_file = "$config_directory/config";
&read_file_cached($config_file, \%gconfig);

# Set PATH and LD_LIBRARY_PATH
$ENV{'PATH'} = $gconfig{'path'} if ($gconfig{'path'});
$ENV{$gconfig{'ld_env'}} = $gconfig{'ld_path'} if ($gconfig{'ld_env'});

# Work out which module we are in, and read the per-module config file
if (defined($ENV{'FOREIGN_MODULE_NAME'})) {
	# In a foreign call - use the module name given
	$root_directory = $ENV{'FOREIGN_ROOT_DIRECTORY'};
	$module_name = $ENV{'FOREIGN_MODULE_NAME'};
	}
elsif ($ENV{'SCRIPT_NAME'}) {
	local $sn = $ENV{'SCRIPT_NAME'};
	$sn =~ s/^$gconfig{'webprefix'}//
		if (!$gconfig{'webprefixnoredir'});
	if ($sn =~ /^\/([^\/]+)\//) {
		# Get module name from CGI path
		$module_name = $1;
		}
	if ($ENV{'SERVER_ROOT'}) {
		$root_directory = $ENV{'SERVER_ROOT'};
		}
	elsif ($ENV{'SCRIPT_FILENAME'}) {
		$root_directory = $ENV{'SCRIPT_FILENAME'};
		$root_directory =~ s/$sn$//;
		}
	}
else {
	# Get root directory from miniserv.conf, and deduce module name from $0
	local %miniserv;
	&get_miniserv_config(\%miniserv);
	$root_directory = $miniserv{'root'};
	if ($0 =~ /^$root_directory\/([^\/]+)\/[^\/]+$/) {
		$module_name = $1;
		}
	elsif ($0 !~ /^$root_directory\/[^\/]+$/) {
		&error("Script was not run with full path");
		}
	}
if ($module_name) {
	$module_config_directory = "$config_directory/$module_name";
	$module_config_file = "$module_config_directory/config";
	&read_file_cached($module_config_file, \%config);
	}

# Get the username
local $u = $ENV{'BASE_REMOTE_USER'} ? $ENV{'BASE_REMOTE_USER'}
				    : $ENV{'REMOTE_USER'};
$base_remote_user = $u;
$remote_user = $ENV{'REMOTE_USER'};

# Set some useful variables
$current_theme = defined($gconfig{'theme_'.$remote_user}) ?
		    $gconfig{'theme_'.$remote_user} :
		 defined($gconfig{'theme_'.$base_remote_user}) ?
		    $gconfig{'theme_'.$base_remote_user} :
		    $gconfig{'theme'};
if ($current_theme) {
	&read_file_cached("$root_directory/$current_theme/config", \%tconfig);
	}
$tb = defined($tconfig{'cs_header'}) ? "bgcolor=#$tconfig{'cs_header'}" :
      defined($gconfig{'cs_header'}) ? "bgcolor=#$gconfig{'cs_header'}" :
				       "bgcolor=#9999ff";
$cb = defined($tconfig{'cs_table'}) ? "bgcolor=#$tconfig{'cs_table'}" :
      defined($gconfig{'cs_table'}) ? "bgcolor=#$gconfig{'cs_table'}" :
				      "bgcolor=#ffffcc";
$tb .= ' '.$tconfig{'tb'} if ($tconfig{'tb'});
$cb .= ' '.$tconfig{'cb'} if ($tconfig{'cb'});
if ($tconfig{'preload_functions'}) {
	# Force load of theme functions right now, if requested
	&load_theme_library();
	}

$0 =~ /([^\/]+)$/;
$scriptname = $1;
$webmin_logfile = $gconfig{'webmin_log'} ? $gconfig{'webmin_log'}
					 : "$var_directory/webmin.log";

# Load language strings into %text
local @langs = &list_languages();
local ($l, $a, $accepted_lang);
if ($gconfig{'acceptlang'}) {
	foreach $a (split(/,/, $ENV{'HTTP_ACCEPT_LANGUAGE'})) {
		local ($al) = grep { $_->{'lang'} eq $a } @langs;
		if ($al) {
			$accepted_lang = $al->{'lang'};
			last;
			}
		}
	}
$current_lang = $force_lang ? $force_lang :
    $accepted_lang ? $accepted_lang :
    $gconfig{"lang_$remote_user"} ? $gconfig{"lang_$remote_user"} :
    $gconfig{"lang_$base_remote_user"} ? $gconfig{"lang_$base_remote_user"} :
    $gconfig{"lang"} ? $gconfig{"lang"} : $default_lang;
foreach $l (@langs) {
	$current_lang_info = $l if ($l->{'lang'} eq $current_lang);
	}
@lang_order_list = &unique($default_lang,
		     	   split(/:/, $current_lang_info->{'fallback'}),
			   $current_lang);
%text = &load_language($module_name);
%text || &error("Failed to determine Webmin root from SERVER_ROOT or SCRIPT_FILENAME");

# Get the %module_info for this module
if ($module_name) {
	local ($mi) = grep { $_->{'dir'} eq $module_name }
			 &get_all_module_infos(2);
	%module_info = %$mi;
	$module_root_directory = "$root_directory/$module_name";
	}

if ($module_name && !$main::no_acl_check &&
    !defined($ENV{'FOREIGN_MODULE_NAME'})) {
	# Check if the HTTP user can access this module
	local(%acl, %minfo);
	&read_acl(\%acl, undef);
	local $risk = $gconfig{'risk_'.$u};
	if ($risk) {
		$risk eq 'high' || !$module_info{'risk'} ||
		    $module_info{'risk'} =~ /$risk/ ||
			&error(&text('emodule', "<i>$u</i>",
				     "<i>$module_info{'desc'}</i>"));
		$user_risk_level = $risk;
		$user_skill_level = $gconfig{'skill_'.$u};
		}
	else {
		$acl{$u,$module_name} || $acl{$u,'*'} ||
			&error(&text('emodule', "<i>$u</i>",
				     "<i>$module_info{'desc'}</i>"));
		}

	# Check for usermod restrictions
	local @usermods = &list_usermods();
	if (!&available_usermods( [ \%module_info ], \@usermods)) {
		&error(&text('emodule', "<i>$u</i>",
			     "<i>$module_info{'desc'}</i>"));
		}

	$main::no_acl_check++;
	}

# Check the Referer: header for nasty redirects
local @referers = split(/\s+/, $gconfig{'referers'});
local $referer_site;
if ($ENV{'HTTP_REFERER'} =~/^(http|https|ftp):\/\/([^:\/]+:[^@\/]+@)?([^\/:@]+)/) {
	$referer_site = $3;
	}
local $http_host = $ENV{'HTTP_HOST'};
$http_host =~ s/:\d+$//;
if ($0 && $ENV{'SCRIPT_NAME'} !~ /^\/(index.cgi)?$/ && $0 !~ /referer_save\.cgi$/ &&
    $0 !~ /session_login\.cgi$/ && !$gconfig{'referer'} &&
    $ENV{'MINISERV_CONFIG'} && !$main::no_referers_check &&
    $ENV{'HTTP_USER_AGENT'} !~ /^Webmin/i &&
    ($referer_site && $referer_site ne $http_host &&
     &indexof($referer_site, @referers) < 0 ||
    !$referer_site && $gconfig{'referers_none'} && !$trust_unknown_referers)) {
	# Looks like a link from elsewhere ..
	&header($text{'referer_title'}, "", undef, 0, 1, 1);
	print "<hr><center>\n";
	print "<form action=$gconfig{'webprefix'}/referer_save.cgi>\n";
	&ReadParse();
	foreach $k (keys %in) {
		foreach $kk (split(/\0/, $in{$k})) {
			print "<input type=hidden name=$k value='$kk'>\n";
			}
		}
	print "<input type=hidden name=referer_original ",
	      "value='$ENV{'REQUEST_URI'}'>\n";

	$prot = lc($ENV{'HTTPS'}) eq 'on' ? "https" : "http";
	local $url = "<tt>$prot://$ENV{'HTTP_HOST'}$ENV{'REQUEST_URI'}</tt>";
	if ($referer_site) {
		print "<p>",&text('referer_warn',
		      "<tt>$ENV{'HTTP_REFERER'}</tt>", $url),"<p>\n";
		}
	else {
		print "<p>",&text('referer_warn_unknown', $url),"<p>\n";
		}
	print "<input type=submit value='$text{'referer_ok'}'><br>\n";
	print "<input type=checkbox name=referer_again value=1> ",
	      "$text{'referer_again'}<p>\n";
	print "</form></center><hr>\n";
	&footer("/", $text{'index'});
	exit;
	}
$main::no_referers_check++;

return 1;
}

$default_lang = "en";

# load_language(module, [directory])
# Returns a hashtable mapping text codes to strings in the appropriate language
sub load_language
{
local %text;
local $root = $root_directory;
local $ol = $gconfig{'overlang'};
local $o;
local ($dir) = ($_[1] || "lang");

# Read global lang files
foreach $o (@lang_order_list) {
	local $ok = &read_file_cached("$root/$dir/$o", \%text);
	return () if (!$ok && $o eq $default_lang);
	}
if ($ol) {
	foreach $o (@lang_order_list) {
		&read_file_cached("$root/$ol/$o", \%text);
		}
	}
&read_file_cached("$config_directory/custom-lang", \%text);

if ($_[0]) {
	# Read module's lang files
	foreach $o (@lang_order_list) {
		&read_file_cached("$root/$_[0]/$dir/$o", \%text);
		}
	if ($ol) {
		foreach $o (@lang_order_list) {
			&read_file_cached("$root/$_[0]/$ol/$o", \%text);
			}
		}
	&read_file_cached("$config_directory/$_[0]/custom-lang", \%text);
	}
foreach $k (keys %text) {
	$text{$k} =~ s/\$(\{([^\}]+)\}|([A-Za-z0-9\.\-\_]+))/text_subs($2 || $3,\%text)/ge;
	}
return %text;
}

sub text_subs
{
if (substr($_[0], 0, 8) eq "include:") {
	local $_;
	local $rv;
	open(INCLUDE, substr($_[0], 8));
	while(<INCLUDE>) {
		$rv .= $_;
		}
	close(INCLUDE);
	return $rv;
	}
else {
	local $t = $_[1]->{$_[0]};
	return defined($t) ? $t : '$'.$_[0];
	}
}

# text(message, [substitute]+)
sub text
{
local $rv = $text{$_[0]};
local $i;
for($i=1; $i<@_; $i++) {
	$rv =~ s/\$$i/$_[$i]/g;
	}
return $rv;
}

# terror(text params)
sub terror
{
&error(&text(@_));
}

# encode_base64(string)
# Encodes a string into base64 format
sub encode_base64
{
    local $res;
    pos($_[0]) = 0;                          # ensure start at the beginning
    while ($_[0] =~ /(.{1,57})/gs) {
        $res .= substr(pack('u57', $1), 1)."\n";
        chop($res);
    }
    $res =~ tr|\` -_|AA-Za-z0-9+/|;
    local $padding = (3 - length($_[0]) % 3) % 3;
    $res =~ s/.{$padding}$/'=' x $padding/e if ($padding);
    return $res;
}

# decode_base64(string)
# Converts a base64 string into plain text
sub decode_base64
{
    local $str = $_[0];
    local $res;
 
    $str =~ tr|A-Za-z0-9+=/||cd;            # remove non-base64 chars
    if (length($str) % 4) {
	return undef;
    }
    $str =~ s/=+$//;                        # remove padding
    $str =~ tr|A-Za-z0-9+/| -_|;            # convert to uuencoded format
    while ($str =~ /(.{1,60})/gs) {
        my $len = chr(32 + length($1)*3/4); # compute length byte
        $res .= unpack("u", $len . $1 );    # uudecode
    }
    return $res;
}

# get_module_info(module, [noclone], [forcache])
# Returns a hash containg a module name, desc and os_support
sub get_module_info
{
return () if ($_[0] =~ /^\./);
local (%rv, $clone, $o);
&read_file_cached("$root_directory/$_[0]/module.info", \%rv) || return ();
$clone = -l "$root_directory/$_[0]";
foreach $o (@lang_order_list) {
	$rv{"desc"} = $rv{"desc_$o"} if ($rv{"desc_$o"});
	}
if ($clone && !$_[1] && $config_directory) {
	$rv{'clone'} = $rv{'desc'};
	&read_file("$config_directory/$_[0]/clone", \%rv);
	}
$rv{'dir'} = $_[0];
local %module_categories;
&read_file_cached("$config_directory/webmin.cats", \%module_categories);
local $pn = &get_product_name();
if (defined($rv{'category_'.$pn})) {
	# Can override category for webmin/usermin
	$rv{'category'} = $rv{'category_'.$pn};
	}
$rv{'realcategory'} = $rv{'category'};
$rv{'category'} = $module_categories{$_[0]}
	if (defined($module_categories{$_[0]}));

if (!$_[2]) {
	# Apply per-user description overridde
	local %gaccess = &get_module_acl(undef, "");
	if ($gaccess{'desc_'.$_[0]}) {
		$rv{'desc'} = $gaccess{'desc_'.$_[0]};
		}
	}

if ($rv{'longdesc'}) {
	# All standard modules have an index.cgi
	$rv{'index_link'} = 'index.cgi';
	}
return %rv;
}

# get_all_module_infos(cachemode)
# Returns a vector contains the information on all modules in this webmin
# install, including clones.
# Cache mode 0 = read and write, 1 = don't read or write, 2 = read only
sub get_all_module_infos
{
local (%cache, $k, $m, @rv);
local $cache_file = "$config_directory/module.infos.cache";
local @st = stat($root_directory);
if ($_[0] != 1 && &read_file_cached($cache_file, \%cache) &&
    $cache{'lang'} eq $current_lang &&
    $cache{'mtime'} == $st[9]) {
	# Can use existing module.info cache
	local %mods;
	foreach $k (keys %cache) {
		if ($k =~ /^(\S+) (\S+)$/) {
			$mods{$1}->{$2} = $cache{$k};
			}
		}
	@rv = map { $mods{$_} } (keys %mods) if (%mods);
	}
else {
	# Need to rebuild cache
	%cache = ( );
	opendir(DIR, $root_directory);
	foreach $m (readdir(DIR)) {
		next if ($m =~ /^(config-|\.)/ || $m =~ /\.(cgi|pl)$/);
		local %minfo = &get_module_info($m, 0, 1);
		next if (!%minfo);
		push(@rv, \%minfo);
		foreach $k (keys %minfo) {
			$cache{"${m} ${k}"} = $minfo{$k};
			}
		}
	closedir(DIR);
	$cache{'lang'} = $current_lang;
	$cache{'mtime'} = $st[9];
	&write_file($cache_file, \%cache) if (!$_[0]);
	}

# Override descriptions for modules for current user
local %gaccess = &get_module_acl(undef, "");
foreach $m (@rv) {
	if ($gaccess{"desc_".$m->{'dir'}}) {
		$m->{'desc'} = $gaccess{"desc_".$m->{'dir'}};
		}
	}
return @rv;
}

# get_theme_info(theme)
# Returns a hash containing a theme's details
sub get_theme_info
{
return () if ($_[0] =~ /^\./);
local (%rv, $o);
&read_file("$root_directory/$_[0]/theme.info", \%rv) || return ();
foreach $o (@lang_order_list) {
	$rv{"desc"} = $rv{"desc_$o"} if ($rv{"desc_$o"});
	}
$rv{"dir"} = $_[0];
return %rv;
}

# list_languages()
# Returns an array of supported languages
sub list_languages
{
if (!@main::list_languages_cache) {
	local ($o, $_);
	open(LANG, "$root_directory/lang_list.txt");
	while(<LANG>) {
		if (/^(\S+)\s+(.*)/) {
			local $l = { 'desc' => $2 };
			foreach $o (split(/,/, $1)) {
				if ($o =~ /^([^=]+)=(.*)$/) {
					$l->{$1} = $2;
					}
				}
			$l->{'index'} = scalar(@rv);
			push(@list_languages_cache, $l);
			}
		}
	close(LANG);
	@main::list_languages_cache = sort { $a->{'desc'} cmp $b->{'desc'} }
				     @main::list_languages_cache;
	}
return @main::list_languages_cache;
}

# read_env_file(file, &array)
sub read_env_file
{
local $_;
open(FILE, $_[0]) || return 0;
while(<FILE>) {
	s/#.*$//g;
	if (/([A-Za-z0-9_\.]+)\s*=\s*"(.*)"/ ||
	    /([A-Za-z0-9_\.]+)\s*=\s*'(.*)'/ ||
	    /([A-Za-z0-9_\.]+)\s*=\s*(.*)/) {
		$_[1]->{$1} = $2;
		}
	}
close(FILE);
return 1;
}

# write_env_file(file, &array, export)
sub write_env_file
{
local $k;
local $exp = $_[2] ? "export " : "";
open(FILE, ">$_[0]");
foreach $k (keys %{$_[1]}) {
	local $v = $_[1]->{$k};
	if ($v =~ /^\S+$/) {
		print FILE "$exp$k=$v\n";
		}
	else {
		print FILE "$exp$k=\"$v\"\n";
		}
	}
close(FILE);
}

# lock_file(filename, [readonly], [forcefile])
# Lock a file for exclusive access. If the file is already locked, spin
# until it is freed. This version uses a .lock file, which is not very reliable.
sub lock_file
{
return 0 if (!$_[0] || defined($main::locked_file_list{$_[0]}));
local $lock_tries_count = 0;
while(1) {
	local $pid;
	if (open(LOCKING, "$_[0].lock")) {
		$pid = <LOCKING>;
		$pid = int($pid);
		close(LOCKING);
		}
	if (!$pid || !kill(0, $pid) || $pid == $$) {
		# got the lock!
		open(LOCKING, ">$_[0].lock") || return 0;
		local $lck = eval "flock(LOCKING, 2+4)";
		if (!$lck && !$@) {
			# Lock of lock file failed! Wait till later
			goto tryagain;
			}
		print LOCKING $$,"\n";
		eval "flock(LOCKING, 8)";
		close(LOCKING);
		$main::locked_file_list{$_[0]} = int($_[1]);
		if ($gconfig{'logfiles'} && !$_[1]) {
			# Grab a copy of this file for later diffing
			local $lnk;
			$main::locked_file_data{$_[0]} = undef;
			if (-d $_[0]) {
				$main::locked_file_type{$_[0]} = 1;
				$main::locked_file_data{$_[0]} = '';
				}
			elsif (!$_[2] && ($lnk = readlink($_[0]))) {
				$main::locked_file_type{$_[0]} = 2;
				$main::locked_file_data{$_[0]} = $lnk;
				}
			elsif (open(ORIGFILE, $_[0])) {
				$main::locked_file_type{$_[0]} = 0;
				$main::locked_file_data{$_[0]} = '';
				local $_;
				while(<ORIGFILE>) {
					$main::locked_file_data{$_[0]} .= $_;
					}
				close(ORIGFILE);
				}
			}
		last;
		}
tryagain:
	sleep(1);
	if ($lock_tries_count++ > 5*60) {
		# Give up after 5 minutes
		&error(&text('elock_tries', "<tt>$_[0]</tt>", 5));
		}
	}
return 1;
}

# unlock_file(filename)
# Release a lock on a file. When unlocking a file that was locked in
# read mode, optionally save the update in RCS
sub unlock_file
{
return if (!$_[0] || !defined($main::locked_file_list{$_[0]}));
unlink("$_[0].lock");
delete($main::locked_file_list{$_[0]});
if (exists($main::locked_file_data{$_[0]})) {
	# Diff the new file with the old
	stat($_[0]);
	local $lnk = readlink($_[0]);
	local $type = -d _ ? 1 : $lnk ? 2 : 0;
	local $oldtype = $main::locked_file_type{$_[0]};
	local $new = !defined($main::locked_file_data{$_[0]});
	if ($new && !-e _) {
		# file doesn't exist, and never did! do nothing ..
		}
	elsif ($new && $type == 1 || !$new && $oldtype == 1) {
		# is (or was) a directory ..
		if (-d _ && !defined($main::locked_file_data{$_[0]})) {
			push(@main::locked_file_diff,
			     { 'type' => 'mkdir', 'object' => $_[0] });
			}
		elsif (!-d _ && defined($main::locked_file_data{$_[0]})) {
			push(@main::locked_file_diff,
			     { 'type' => 'rmdir', 'object' => $_[0] });
			}
		}
	elsif ($new && $type == 2 || !$new && $oldtype == 2) {
		# is (or was) a symlink ..
		if ($lnk && !defined($main::locked_file_data{$_[0]})) {
			push(@main::locked_file_diff,
			     { 'type' => 'symlink', 'object' => $_[0],
			       'data' => $lnk });
			}
		elsif (!$lnk && defined($main::locked_file_data{$_[0]})) {
			push(@main::locked_file_diff,
			     { 'type' => 'unsymlink', 'object' => $_[0],
			       'data' => $main::locked_file_data{$_[0]} });
			}
		elsif ($lnk ne $main::locked_file_data{$_[0]}) {
			push(@main::locked_file_diff,
			     { 'type' => 'resymlink', 'object' => $_[0],
			       'data' => $lnk });
			}
		}
	else {
		# is a file, or has changed type?!
		local ($diff, $delete_file);
		local $type = "modify";
		if (!-r _) {
			open(NEWFILE, ">$_[0]");
			close(NEWFILE);
			$delete_file++;
			$type = "delete";
			}
		if (!defined($main::locked_file_data{$_[0]})) {
			$type = "create";
			}
		open(ORIGFILE, ">$_[0].webminorig");
		print ORIGFILE $main::locked_file_data{$_[0]};
		close(ORIGFILE);
		$diff = `diff "$_[0].webminorig" "$_[0]"`;
		push(@main::locked_file_diff,
		     { 'type' => $type, 'object' => $_[0],
		       'data' => $diff } ) if ($diff);
		unlink("$_[0].webminorig");
		unlink($_[0]) if ($delete_file);
		}
	delete($main::locked_file_data{$_[0]});
	delete($main::locked_file_type{$_[0]});
	}
}

# unlock_all_files()
# Unlocks all files locked by this program
sub unlock_all_files
{
foreach $f (keys %main::locked_file_list) {
	&unlock_file($f);
	}
}

# webmin_log(action, type, object, &params, [module], [host, script-on-host, client-ip])
# Log some action taken by a user
sub webmin_log
{
return if (!$gconfig{'log'});
local $m = $_[4] ? $_[4] : $module_name;

if ($gconfig{'logclear'}) {
	# check if it is time to clear the log
	local @st = stat("$webmin_logfile.time");
	local $write_logtime = 0;
	if (@st) {
		if ($st[9]+$gconfig{'logtime'}*60*60 < time()) {
			# clear logfile and all diff files
			system("rm -f $ENV{'WEBMIN_VAR'}/diffs/* 2>/dev/null");
			unlink($webmin_logfile);
			$write_logtime = 1;
			}
		}
	else { $write_logtime = 1; }
	if ($write_logtime) {
		open(LOGTIME, ">$webmin_logfile.time");
		print LOGTIME time(),"\n";
		close(LOGTIME);
		}
	}

# If an action script directory is defined, call the appropriate scripts
if ($gconfig{'action_script_dir'}) {
    my ($action, $type, $object) = ($_[0], $_[1], $_[2]);
    my ($basedir) = $gconfig{'action_script_dir'};

    for my $dir ($basedir/$type/$action, $basedir/$type, $basedir) {
	if (-d $dir) {
	    my ($file);
	    opendir(DIR, $dir) or die "Can't open $dir: $!";
	    while (defined($file = readdir(DIR))) {
		next if ($file =~ /^\.\.?$/); # skip '.' and '..'
		if (-x "$dir/$file") {
		    # Call a script notifying it of the action
		    local %OLDENV = %ENV;
		    $ENV{'ACTION_MODULE'} = $module_name;
		    $ENV{'ACTION_ACTION'} = $_[0];
		    $ENV{'ACTION_TYPE'} = $_[1];
		    $ENV{'ACTION_OBJECT'} = $_[2];
		    $ENV{'ACTION_SCRIPT'} = $script_name;
		    local $p;
		    foreach $p (keys %param) {
			    $ENV{'ACTION_PARAM_'.uc($p)} = $param{$p};
			    }
		    system("$dir/$file", @_, '</dev/null', '>/dev/null', '2>&/dev/null');
		    %ENV = %OLDENV;
		    }
		}
	    }
	}
    }

# should logging be done at all?
return if ($gconfig{'logusers'} && &indexof($base_remote_user,
	   split(/\s+/, $gconfig{'logusers'})) < 0);
return if ($gconfig{'logmodules'} && &indexof($m,
	   split(/\s+/, $gconfig{'logmodules'})) < 0);

# log the action
local $now = time();
local @tm = localtime($now);
local $script_name = $0 =~ /([^\/]+)$/ ? $1 : '-';
local $id = sprintf "%d.%d.%d",
		$now, $$, $main::action_id_count;
$main::action_id_count++;
local $line = sprintf "%s [%2.2d/%s/%4.4d %2.2d:%2.2d:%2.2d] %s %s %s %s %s \"%s\" \"%s\" \"%s\"",
	$id, $tm[3], $text{"smonth_".($tm[4]+1)}, $tm[5]+1900,
	$tm[2], $tm[1], $tm[0],
	$remote_user, $main::session_id ? $main::session_id : '-',
	$_[7] || $ENV{'REMOTE_HOST'},
	$m, $_[5] ? "$_[5]:$_[6]" : $script_name,
	$_[0], $_[1] ne '' ? $_[1] : '-', $_[2] ne '' ? $_[2] : '-';
local %param;
foreach $k (sort { $a cmp $b } keys %{$_[3]}) {
	local $v = $_[3]->{$k};
	local @pv;
	if ($v eq '') {
		$line .= " $k=''";
		@rv = ( "" );
		}
	elsif (ref($v) eq 'ARRAY') {
		foreach $vv (@$v) {
			next if (ref($vv));
			push(@pv, $vv);
			$vv =~ s/(['"\\\r\n\t\%])/sprintf("%%%2.2X",ord($1))/ge;
			$line .= " $k='$vv'";
			}
		}
	elsif (!ref($v)) {
		foreach $vv (split(/\0/, $v)) {
			push(@pv, $vv);
			$vv =~ s/(['"\\\r\n\t\%])/sprintf("%%%2.2X",ord($1))/ge;
			$line .= " $k='$vv'";
			}
		}
	$param{$k} = join(" ", @pv);
	}
open(WEBMINLOG, ">>$webmin_logfile");
print WEBMINLOG $line,"\n";
close(WEBMINLOG);
if ($gconfig{'logperms'}) {
	chmod(oct($gconfig{'logperms'}), $webmin_logfile);
	}

if ($gconfig{'logfiles'}) {
	# Find and record the changes made to any locked files
	local $i = 0;
	mkdir("$ENV{'WEBMIN_VAR'}/diffs", 0700);
	foreach $d (@main::locked_file_diff) {
		open(DIFFLOG, ">$ENV{'WEBMIN_VAR'}/diffs/$id.$i");
		print DIFFLOG "$d->{'type'} $d->{'object'}\n";
		print DIFFLOG $d->{'data'};
		close(DIFFLOG);
		if ($gconfig{'logperms'}) {
			chmod(oct($gconfig{'logperms'}),
			      "$ENV{'WEBMIN_VAR'}/diffs/$id.$i");
			}
		$i++;
		}
	@main::locked_file_diff = undef;
	}
}

# additional_log(type, object, data)
# Records additional log data for an upcoming call to webmin_log, such
# as command that was run or SQL that was executed.
sub additional_log
{
if ($gconfig{'logfiles'}) {
	push(@main::locked_file_diff,
	     { 'type' => $_[0], 'object' => $_[1], 'data' => $_[2] } );
	}
}

# system_logged(command)
# Just calls the system() function, but also logs the command
sub system_logged
{
local $cmd = join(" ", @_);
local $and;
if ($cmd =~ s/(\s*&\s*)$//) {
	$and = $1;
	}
while($cmd =~ s/(\d*)(<|>)((\/(tmp|dev)\S+)|&\d+)\s*$//) { }
$cmd =~ s/^\((.*)\)\s*$/$1/;
$cmd .= $and;
&additional_log('exec', undef, $cmd);
return system(@_);
}

# backquote_logged(command)
# Executes a command and returns the output (like `cmd`), but also logs it
sub backquote_logged
{
local $cmd = $_[0];
local $and;
if ($cmd =~ s/(\s*&\s*)$//) {
	$and = $1;
	}
while($cmd =~ s/(\d*)(<|>)((\/(tmp|dev)\S+)|&\d+)\s*$//) { }
$cmd =~ s/^\((.*)\)\s*$/$1/;
$cmd .= $and;
&additional_log('exec', undef, $cmd);
return `$_[0]`;
}

# kill_logged(signal, pid, ...)
sub kill_logged
{
&additional_log('kill', $_[0], join(" ", @_[1..@_-1])) if (@_ > 1);
return kill(@_);
}

# rename_logged(old, new)
sub rename_logged
{
&additional_log('rename', $_[0], $_[1]) if ($_[0] ne $_[1]);
return rename($_[0], $_[1]);
}

# remote_foreign_require(server, module, file)
# Connect to rpc.cgi on a remote webmin server and have it open a session
# to a process that will actually do the require and run functions.
sub remote_foreign_require
{
local $call = { 'action' => 'require',
		'module' => $_[1],
		'file' => $_[2] };
if ($remote_session{$_[0]}) {
	$call->{'session'} = $remote_session{$_[0]};
	}
else {
	$call->{'newsession'} = 1;
	}
local $rv = &remote_rpc_call($_[0], $call);
$remote_session{$_[0]} = $rv->{'session'} if ($rv->{'session'});
}

# remote_foreign_call(server, module, function, [arg]*)
# Call a function on a remote server. Must have been setup first with
# remote_foreign_require for the same server and module
sub remote_foreign_call
{
return &remote_rpc_call($_[0], { 'action' => 'call',
				 'module' => $_[1],
				 'func' => $_[2],
				 'session' => $remote_session{$_[0]},
				 'args' => [ @_[3 .. $#_] ] } );
}

# remote_foreign_check(server, module)
# Checks if some module is installed and supported on a remote server
sub remote_foreign_check
{
return &remote_rpc_call($_[0], { 'action' => 'check',
				 'module' => $_[1] });
}

# remote_foreign_config(server, module)
# Gets the configuration for some module from a remote server
sub remote_foreign_config
{
return &remote_rpc_call($_[0], { 'action' => 'config',
				 'module' => $_[1] });
}

# remote_eval(server, module, code)
# Eval some perl code in the context of a module on a remote webmin server
sub remote_eval
{
return &remote_rpc_call($_[0], { 'action' => 'eval',
				 'module' => $_[1],
				 'code' => $_[2],
				 'session' => $remote_session{$_[0]} });
}

# remote_write(server, localfile, [remotefile])
sub remote_write
{
local ($data, $got);
if ($remote_server_version{$_[0]} >= 0.966) {
	# Copy data over TCP connection
	local $rv = &remote_rpc_call($_[0],
			{ 'action' => 'tcpwrite', 'file' => $_[2] } );
	local $error;
	&open_socket($_[0], $rv->[1], TWRITE, \$error);
	return &$remote_error_handler("Failed to transfer file : $error")
		if ($error);
	open(FILE, $_[1]);
	while(read(FILE, $got, 1024) > 0) {
		print TWRITE $got;
		}
	close(FILE);
	close(TWRITE);
	return $rv->[0];
	}
else {
	# Just pass file contents as parameters
	open(FILE, $_[1]);
	while(read(FILE, $got, 1024) > 0) {
		$data .= $got;
		}
	close(FILE);
	return &remote_rpc_call($_[0], { 'action' => 'write',
					 'data' => $data,
					 'file' => $_[2],
					 'session' => $remote_session{$_[0]} });
	}
}

# remote_read(server, localfile, remotefile)
sub remote_read
{
if ($remote_server_version{$_[0]} >= 0.966) {
	# Copy data over TCP connection
	local $rv = &remote_rpc_call($_[0],
			{ 'action' => 'tcpread', 'file' => $_[2] } );
	local $error;
	&open_socket($_[0], $rv->[1], TREAD, \$error);
	return &$remote_error_handler("Failed to transfer file : $error")
		if ($error);
	local $got;
	open(FILE, ">$_[1]");
	while(read(TREAD, $got, 1024) > 0) {
		print FILE $got;
		}
	close(FILE);
	close(TREAD);
	}
else {
	# Just get data as return value
	local $d = &remote_rpc_call($_[0], { 'action' => 'read',
				     'file' => $_[2],
				     'session' => $remote_session{$_[0]} });
	open(FILE, ">$_[1]");
	print FILE $d;
	close(FILE);
	}
}

# remote_finished()
# Close all remote sessions. This happens automatically after a while
# anyway, but this function should be called to clean things up faster.
sub remote_finished
{
foreach $h (keys %remote_session) {
	&remote_rpc_call($h, { 'action' => 'quit',
			       'session' => $remote_session{$h} } );
	delete($remote_session{$h});
	}
foreach $fh (keys %fast_fh_cache) {
	close($fh);
	delete($fast_fh_cache{$fh});
	}
}

# remote_error_setup(&function)
# Sets a function to be called instead of &error when a remote RPC fails
sub remote_error_setup
{
$remote_error_handler = $_[0];
}

# remote_rpc_call(server, structure)
# Calls rpc.cgi on some server and passes it a perl structure (hash,array,etc)
# and then reads back a reply structure
sub remote_rpc_call
{
local $serv;
if ($_[0]) {
	# lookup the server in the webmin servers module if needed
	if (!defined(%remote_servers_cache)) {
		&foreign_require("servers", "servers-lib.pl");
		foreach $s (&foreign_call("servers", "list_servers")) {
			$remote_servers_cache{$s->{'host'}} = $s;
			}
		}
	$serv = $remote_servers_cache{$_[0]};
	$serv || return &$remote_error_handler(
				"No Webmin Servers entry for $_[0]");
	$serv->{'user'} || return &$remote_error_handler(
				"No login set for server $_[0]");
	}
if ($serv->{'fast'} || !$_[0]) {
	# Make TCP connection call to fastrpc.cgi
	if (!$fast_fh_cache{$_[0]} && $_[0]) {
		# Need to open the connection
		local $con = &make_http_connection(
			$serv->{'host'}, $serv->{'port'}, $serv->{'ssl'},
			"POST", "/fastrpc.cgi");
		return &$remote_error_handler(
		    "Failed to connect to $serv->{'host'} : $con")
			if (!ref($con));
		&write_http_connection($con, "Host: $serv->{'host'}\r\n");
		&write_http_connection($con, "User-agent: Webmin\r\n");
		local $auth = &encode_base64("$serv->{'user'}:$serv->{'pass'}");
		$auth =~ tr/\n//d;
		&write_http_connection($con, "Authorization: basic $auth\r\n");
		&write_http_connection($con, "Content-length: ",
					     length($tostr),"\r\n");
		&write_http_connection($con, "\r\n");
		&write_http_connection($con, $tostr);

		# read back the response
		local $line = &read_http_connection($con);
		$line =~ tr/\r\n//d;
		if ($line =~ /^HTTP\/1\..\s+401\s+/) {
			return &$remote_error_handler("Login to RPC server as $serv->{'user'} rejected");
			}
		$line =~ /^HTTP\/1\..\s+200\s+/ || return &$remote_error_handler("HTTP error : $line");
		do {
			$line = &read_http_connection($con);
			$line =~ tr/\r\n//d;
			} while($line);
		$line = &read_http_connection($con);
		if ($line =~ /^0\s+(.*)/) {
			return &$remote_error_handler("RPC error : $1");
			}
		elsif ($line =~ /^1\s+(\S+)\s+(\S+)\s+(\S+)/ ||
		       $line =~ /^1\s+(\S+)\s+(\S+)/) {
			# Started ok .. connect and save SID
			&close_http_connection($con);
			local ($port, $sid, $version, $error) = ($1, $2, $3);
			&open_socket($serv->{'host'}, $port, $sid, \$error);
			return &$remote_error_handler("Failed to connect to fastrpc.cgi : $error")
				if ($error);
			$fast_fh_cache{$_[0]} = $sid;
			$remote_server_version{$_[0]} = $version;
			}
		else {
			while($stuff = &read_http_connection($con)) {
				$line .= $stuff;
				}
			return &$remote_error_handler("Bad response from fastrpc.cgi : $line");
			}
		}
	elsif (!$fast_fh_cache{$_[0]}) {
		# Open the connection by running fastrpc.cgi locally
		pipe(RPCOUTr, RPCOUTw);
		if (!fork()) {
			untie(*STDIN);
			untie(*STDOUT);
			open(STDOUT, ">&RPCOUTw");
			close(STDIN);
			close(RPCOUTr);
			$| = 1;
			$ENV{'REQUEST_METHOD'} = 'GET';
			$ENV{'SCRIPT_NAME'} = '/fastrpc.cgi';
			$ENV{'SERVER_ROOT'} ||= $root_directory;
			local %acl;
			if ($base_remote_user ne 'root' &&
			    $base_remote_user ne 'admin') {
				# Need to fake up a login for the CGI!
				&read_acl(undef, \%acl);
				$ENV{'BASE_REMOTE_USER'} =
					$ENV{'REMOTE_USER'} =
						$acl{'root'} ? 'root' : 'admin';
				}
			delete($ENV{'FOREIGN_MODULE_NAME'});
			delete($ENV{'FOREIGN_ROOT_DIRECTORY'});
			chdir($root_directory);
			if (!exec("$root_directory/fastrpc.cgi")) {
				print "exec failed : $!\n";
				exit 1;
				}
			}
		close(RPCOUTw);
		local $line;
		do {
			($line = <RPCOUTr>) =~ tr/\r\n//d;
			} while($line);
		$line = <RPCOUTr>;
		#close(RPCOUTr);
		if ($line =~ /^0\s+(.*)/) {
			return &$remote_error_handler("RPC error : $2");
			}
		elsif ($line =~ /^1\s+(\S+)\s+(\S+)/) {
			# Started ok .. connect and save SID
			close(SOCK);
			local ($port = $1, $sid = $2, $error);
			&open_socket("localhost", $port, $sid, \$error);
			return &$remote_error_handler("Failed to connect to fastrpc.cgi : $error") if ($error);
			$fast_fh_cache{$_[0]} = $sid;
			}
		else {
			local $_;
			while(<RPCOUTr>) {
				$line .= $_;
				}
			&error("Bad response from fastrpc.cgi : $line");
			}
		}
	# Got a connection .. send off the request
	local $fh = $fast_fh_cache{$_[0]};
	local $tostr = &serialise_variable($_[1]);
	print $fh length($tostr)," $fh\n";
	print $fh $tostr;
	local $rlen = int(<$fh>);
	local ($fromstr, $got);
	while(length($fromstr) < $rlen) {
		return &$remote_error_handler("Failed to read from fastrpc.cgi")
			if (read($fh, $got, $rlen - length($fromstr)) <= 0);
		$fromstr .= $got;
		}
	local $from = &unserialise_variable($fromstr);
	if (!$from) {
		return &$remote_error_handler("Remote Webmin error");
		}
	if (defined($from->{'arv'})) {
		return @{$from->{'arv'}};
		}
	else {
		return $from->{'rv'};
		}
	}
else {
	# Call rpc.cgi on remote server
	local $tostr = &serialise_variable($_[1]);
	local $error = 0;
	local $con = &make_http_connection($serv->{'host'}, $serv->{'port'},
					   $serv->{'ssl'}, "POST", "/rpc.cgi");
	return &$remote_error_handler("Failed to connect to $serv->{'host'} : $con") if (!ref($con));

	&write_http_connection($con, "Host: $serv->{'host'}\r\n");
	&write_http_connection($con, "User-agent: Webmin\r\n");
	local $auth = &encode_base64("$serv->{'user'}:$serv->{'pass'}");
	$auth =~ tr/\n//d;
	&write_http_connection($con, "Authorization: basic $auth\r\n");
	&write_http_connection($con, "Content-length: ",length($tostr),"\r\n");
	&write_http_connection($con, "\r\n");
	&write_http_connection($con, $tostr);

	# read back the response
	local $line = &read_http_connection($con);
	$line =~ tr/\r\n//d;
	if ($line =~ /^HTTP\/1\..\s+401\s+/) {
		return &$remote_error_handler("Login to RPC server as $serv->{'user'} rejected");
		}
	$line =~ /^HTTP\/1\..\s+200\s+/ || return &$remote_error_handler("RPC HTTP error : $line");
	do {
		$line = &read_http_connection($con);
		$line =~ tr/\r\n//d;
		} while($line);
	local $fromstr;
	while($line = &read_http_connection($con)) {
		$fromstr .= $line;
		}
	close(SOCK);
	local $from = &unserialise_variable($fromstr);
	return &$remote_error_handler("Invalid RPC login to $_[0]") if (!$from->{'status'});
	if (defined($from->{'arv'})) {
		return @{$from->{'arv'}};
		}
	else {
		return $from->{'rv'};
		}
	}
}

# serialise_variable(variable)
# Converts some variable (maybe a scalar, hash ref, array ref or scalar ref)
# into a url-encoded string
sub serialise_variable
{
if (!defined($_[0])) {
	return 'UNDEF';
	}
local $r = ref($_[0]);
local $rv;
if (!$r) {
	$rv = &urlize($_[0]);
	}
elsif ($r eq 'SCALAR') {
	$rv = &urlize(${$_[0]});
	}
elsif ($r eq 'ARRAY') {
	$rv = join(",", map { &urlize(&serialise_variable($_)) } @{$_[0]});
	}
elsif ($r eq 'HASH') {
	$rv = join(",", map { &urlize(&serialise_variable($_)).",".
			      &urlize(&serialise_variable($_[0]->{$_})) }
		            keys %{$_[0]});
	}
elsif ($r eq 'REF') {
	$rv = &serialise_variable(${$_[0]});
	}
return ($r ? $r : 'VAL').",".$rv;
}

# unserialise_variable(string)
# Converts a string created by serialise_variable() back into the original
# scalar, hash ref, array ref or scalar ref.
sub unserialise_variable
{
local @v = split(/,/, $_[0]);
local ($rv, $i);
if ($v[0] eq 'VAL') {
	@v = split(/,/, $_[0], -1);
	$rv = &un_urlize($v[1]);
	}
elsif ($v[0] eq 'SCALAR') {
	local $r = &un_urlize($v[1]);
	$rv = \$r;
	}
elsif ($v[0] eq 'ARRAY') {
	$rv = [ ];
	for($i=1; $i<@v; $i++) {
		push(@$rv, &unserialise_variable(&un_urlize($v[$i])));
		}
	}
elsif ($v[0] eq 'HASH') {
	$rv = { };
	for($i=1; $i<@v; $i+=2) {
		$rv->{&unserialise_variable(&un_urlize($v[$i]))} =
			&unserialise_variable(&un_urlize($v[$i+1]));
		}
	}
elsif ($v[0] eq 'REF') {
	local $r = &unserialise_variable($v[1]);
	$rv = \$r;
	}
elsif ($v[0] eq 'UNDEF') {
	$rv = undef;
	}
return $rv;
}

# other_groups(user)
# Returns a list of secondary groups a user is a member of
sub other_groups
{
local (@rv, @g);
setgrent();
while(@g = getgrent()) {
	local @m = split(/\s+/, $g[3]);
	push(@rv, $g[2]) if (&indexof($_[0], @m) >= 0);
	}
endgrent() if ($gconfig{'os_type'} ne 'hpux');
return @rv;
}

# date_chooser_button(dayfield, monthfield, yearfield, [form])
# Returns HTML for a date-chooser button
sub date_chooser_button
{
local $form = @_ > 3 ? $_[3] : 0;
return "<input type=button onClick='window.dfield = document.forms[$form].$_[0]; window.mfield = document.forms[$form].$_[1]; window.yfield = document.forms[$form].$_[2]; window.open(\"$gconfig{'webprefix'}/date_chooser.cgi?day=\"+escape(dfield.value)+\"&month=\"+escape(mfield.selectedIndex)+\"&year=\"+yfield.value, \"chooser\", \"toolbar=no,menubar=no,scrollbars=yes,width=250,height=225\")' value=\"...\">\n";
}

# help_file(module, file)
# Returns the path to a module's help file
sub help_file
{
local $dir = "$root_directory/$_[0]/help";
foreach $o (@lang_order_list) {
	local $lang = "$dir/$_[1].$current_lang.html";
	return $lang if (-r $lang);
	}
return "$dir/$_[1].html";
}

# seed_random()
# Seeds the random number generator, if needed
sub seed_random
{
if (!$main::done_seed_random) {
	if (open(RANDOM, "/dev/urandom")) {
		local $buf;
		read(RANDOM, $buf, 4);
		close(RANDOM);
		srand(time() ^ $$ ^ $buf);
		}
	else {
		srand(time() ^ $$);
		}
	$main::done_seed_random = 1;
	}
}

# disk_usage_kb(directory)
# Returns the number of kb used by some directory and all subdirs
sub disk_usage_kb
{
local $out = `du -sk \"$_[0]\"`;
if ($?) {
	$out = `du -s \"$_[0]\"`;
	}
return $out =~ /^([0-9]+)/ ? $1 : "???";
}

# help_search_link(term, [ section, ... ] )
# Returns HTML for a link to the man module for searching local and online
# docs for various search terms
sub help_search_link
{
local %acl;
&read_acl(\%acl, undef);
if ($acl{$base_remote_user,'man'} || $acl{$base_remote_user,'*'}) {
	local $for = &urlize(shift(@_));
	return "<!--a href='$gconfig{'webprefix'}/man/search.cgi?".
	       join("&", map { "section=$_" } @_)."&".
	       "for=$for&exact=1&check=$module_name'>".
	       $text{'helpsearch'}."</a-->\n";
	}
else {
	return "";
	}
}

# make_http_connection(host, port, ssl, method, page)
# Opens a connection to some HTTP server, maybe through a proxy, and returns
# a handle object. The handle can then be used to send additional headers
# and read back a response. If anything goes wrong, returns an error string.
sub make_http_connection
{
local $rv = { 'fh' => time().$$ };
local $error;
if ($_[2]) {
	# Connect using SSL
	eval "use Net::SSLeay";
	$@ && &error($text{'link_essl'});
	eval "Net::SSLeay::SSLeay_add_ssl_algorithms()";
	eval "Net::SSLeay::load_error_strings()";
	$rv->{'ssl_ctx'} = Net::SSLeay::CTX_new() ||
		return "Failed to create SSL context";
	$rv->{'ssl_con'} = Net::SSLeay::new($rv->{'ssl_ctx'}) ||
		return "Failed to create SSL connection";
	if ($gconfig{'http_proxy'} =~ /^http:\/\/(\S+):(\d+)/ &&
	    !&no_proxy($_[0])) {
		&open_socket($1, $2, $rv->{'fh'}, \$error);
		return $error if ($error);
		local $fh = $rv->{'fh'};
		print $fh "CONNECT $_[0]:$_[1] HTTP/1.0\r\n";
		if ($gconfig{'proxy_user'}) {
			local $auth = &encode_base64(
			   "$gconfig{'proxy_user'}:$gconfig{'proxy_pass'}");
			$auth =~ tr/\r\n//d;
			print $fh "Proxy-Authorization: Basic $auth\r\n";
			}
		print $fh "\r\n";
		local $line = <$fh>;
		if ($line =~ /^HTTP(\S+)\s+(\d+)\s+(.*)/) {
			return "Proxy error : $3" if ($2 != 200);
			}
		else {
			return "Proxy error : $line";
			}
		$line = <$fh>;
		}
	else {
		&open_socket($_[0], $_[1], $rv->{'fh'}, \$error);
		return $error if ($error);
		}
	Net::SSLeay::set_fd($rv->{'ssl_con'}, fileno($rv->{'fh'}));
	Net::SSLeay::connect($rv->{'ssl_con'}) ||
		return "SSL connect() failed";
	Net::SSLeay::write($rv->{'ssl_con'}, "$_[3] $_[4] HTTP/1.0\r\n");
	}
else {
	# Plain HTTP request
	local $error;
	if ($gconfig{'http_proxy'} =~ /^http:\/\/(\S+):(\d+)/ &&
	    !&no_proxy($_[0])) {
		# Via a proxy
		&open_socket($1, $2, $rv->{'fh'}, \$error);
		return $error if ($error);
		local $fh = $rv->{'fh'};
		print $fh "$_[3] http://$_[0]:$_[1]$_[4] HTTP/1.0\r\n";
		if ($gconfig{'proxy_user'}) {
			local $auth = &encode_base64(
			   "$gconfig{'proxy_user'}:$gconfig{'proxy_pass'}");
			$auth =~ tr/\r\n//d;
			print $fh "Proxy-Authorization: Basic $auth\r\n";
			}
		}
	else {
		# Connecting directly
		&open_socket($_[0], $_[1], $rv->{'fh'}, \$error);
		return $error if ($error);
		local $fh = $rv->{'fh'};
		print $fh "$_[3] $_[4] HTTP/1.0\r\n";
		}
	}
return $rv;
}

# read_http_connection(handle, [amount])
# Reads either one line or up to the specified amount of data from the handle
sub read_http_connection
{
local $h = $_[0];
local $rv;
if ($h->{'ssl_con'}) {
	if (!$_[1]) {
		local ($idx, $more);
		while(($idx = index($h->{'buffer'}, "\n")) < 0) {
			# need to read more..
			if (!($more = Net::SSLeay::read($h->{'ssl_con'}))) {
				# end of the data
				$rv = $h->{'buffer'};
				delete($h->{'buffer'});
				return $rv;
				}
			$h->{'buffer'} .= $more;
			}
		$rv = substr($h->{'buffer'}, 0, $idx+1);
		$h->{'buffer'} = substr($h->{'buffer'}, $idx+1);
		}
	else {
		if (length($h->{'buffer'})) {
			$rv = $h->{'buffer'};
			delete($h->{'buffer'});
			}
		else {
			$rv = Net::SSLeay::read($h->{'ssl_con'}, $_[1]);
			}
		}
	}
else {
	if ($_[1]) {
		read($h->{'fh'}, $rv, $_[1]) > 0 || return undef;
		}
	else {
		local $fh = $h->{'fh'};
		$rv = <$fh>;
		}
	}
$rv = undef if ($rv eq "");
return $rv;
}

# write_http_connection(handle, [data+])
# Writes the given data to the handle
sub write_http_connection
{
local $h = shift(@_);
local $fh = $h->{'fh'};
if ($h->{'ssl_ctx'}) {
	foreach (@_) {
		Net::SSLeay::write($h->{'ssl_con'}, $_);
		}
	}
else {
	print $fh @_;
	}
}

# close_http_connection(handle)
sub close_http_connection
{
close($h->{'fh'});
}

# clean_environment()
# Deletes any environment variables inherited from miniserv so that they
# won't be passed to programs started by webmin.
sub clean_environment
{
local ($k, $e);
%UNCLEAN_ENV = %ENV;
foreach $k (keys %ENV) {
	if ($k =~ /^HTTP_/) {
		delete($ENV{$k});
		}
	}
foreach $e ('WEBMIN_CONFIG', 'SERVER_NAME', 'CONTENT_TYPE', 'REQUEST_URI',
	    'PATH_INFO', 'WEBMIN_VAR', 'REQUEST_METHOD', 'GATEWAY_INTERFACE',
	    'QUERY_STRING', 'REMOTE_USER', 'SERVER_SOFTWARE', 'SERVER_PROTOCOL',
	    'REMOTE_HOST', 'SERVER_PORT', 'DOCUMENT_ROOT', 'SERVER_ROOT',
	    'MINISERV_CONFIG', 'SCRIPT_NAME', 'SERVER_ADMIN', 'CONTENT_LENGTH',
	    'HTTPS', 'FOREIGN_MODULE_NAME', 'FOREIGN_ROOT_DIRECTORY',
	    'SCRIPT_FILENAME', 'PATH_TRANSLATED', 'BASE_REMOTE_USER') {
	delete($ENV{$e});
	}
}

# reset_environment()
# Puts the environment back how it was before &clean_environment
sub reset_environment
{
%ENV = %UNCLEAN_ENV;
}

$webmin_feedback_address = "feedback\@webmin.com";

# progress_callback()
# Never called directly, but useful for passing to &http_download
sub progress_callback
{
if (defined(&theme_progress_callback)) {
	# Call the theme override
	return &theme_progress_callback(@_);
	}
if ($_[0] == 2) {
	# Got size
	print $progress_callback_prefix;
	if ($_[1]) {
		$progress_size = $_[1];
		$progress_step = int($_[1] / 10);
		print &text('progress_size', $progress_callback_url,
			    $progress_size),"<br>\n";
		}
	else {
		print &text('progress_nosize', $progress_callback_url),"<br>\n";
		}
	}
elsif ($_[0] == 3) {
	# Got data update
	local $sp = $progress_callback_prefix.("&nbsp;" x 5);
	if ($progress_size) {
		local $st = int(($_[1] * 10) / $progress_size);
		local $time_now = time();
		if ($st != $progress_step ||
		    $time_now - $last_progress_time > 60) {
			# Show progress every 10% or 60 seconds
			print $sp,&text('progress_data', $_[1], int($_[1]*100/$progress_size)),"<br>\n";
			$last_progress_time = $time_now;
			}
		$progress_step = $st;
		}
	else {
		print $sp,&text('progress_data2', $_[1]),"<br>\n";
		}
	}
elsif ($_[0] == 4) {
	# All done downloading
	print $progress_callback_prefix,&text('progress_done'),"<br>\n";
	}
elsif ($_[0] == 5) {
	# Got new location after redirect
	$progress_callback_url = $_[1];
	}
}

# switch_to_remote_user()
# Changes the user and group of the current process to that of the unix user
# with the same name as the current webmin login, or fails if there is none.
sub switch_to_remote_user
{
@remote_user_info = getpwnam($remote_user);
@remote_user_info || &error(&text('switch_remote_euser', $remote_user));
if ($< == 0) {
	($(, $)) = ( $remote_user_info[3],
		     "$remote_user_info[3] ".join(" ", $remote_user_info[3],
				       &other_groups($remote_user_info[0])) );
	($>, $<) = ( $remote_user_info[2], $remote_user_info[2] );
	$ENV{'USER'} = $ENV{'LOGNAME'} = $remote_user;
	$ENV{'HOME'} = $remote_user_info[7];
	}
}

# create_user_config_dirs()
# Creates per-user config directories and sets $user_config_directory and
# $user_module_config_directory to them. Also reads per-user module configs
# into %userconfig
sub create_user_config_dirs
{
return if (!$gconfig{'userconfig'});
local @uinfo = @remote_user_info ? @remote_user_info : getpwnam($remote_user);
return if (!@uinfo || !$uinfo[7]);
$user_config_directory = "$uinfo[7]/$gconfig{'userconfig'}";
if (!-d $user_config_directory) {
	mkdir($user_config_directory, 0755) ||
		&error("Failed to create $user_config_directory : $!");
	if ($< == 0 && $uinfo[2]) {
		chown($uinfo[2], $uinfo[3], $user_config_directory);
		}
	}
if ($module_name) {
	$user_module_config_directory = "$user_config_directory/$module_name";
	if (!-d $user_module_config_directory) {
		mkdir($user_module_config_directory, 0755) ||
			&error("Failed to create $user_module_config_directory : $!");
		if ($< == 0 && $uinfo[2]) {
			chown($uinfo[2], $uinfo[3], $user_config_directory);
			}
		}
	undef(%userconfig);
	&read_file_cached("$module_root_directory/defaultuconfig",
			  \%userconfig);
	&read_file_cached("$module_config_directory/uconfig", \%userconfig);
	&read_file_cached("$user_module_config_directory/config",
			  \%userconfig);
	}
}

# filter_javascript(text)
# Disables all javascript <script>, onClick= and so on tags in the given HTML
sub filter_javascript
{
local $rv = $_[0];
$rv =~ s/<\s*script[^>]*>([\000-\377]*?)<\s*\/script\s*>//gi;
$rv =~ s/(on(Abort|Blur|Change|Click|DblClick|DragDrop|Error|Focus|KeyDown|KeyPress|KeyUp|Load|MouseDown|MouseMove|MouseOut|MouseOver|MouseUp|Move|Reset|Resize|Select|Submit|Unload)=)/x$1/gi;
$rv =~ s/(javascript:)/x$1/gi;
$rv =~ s/(vbscript:)/x$1/gi;
return $rv;
}

# resolve_links(path)
# Given a path that may contain symbolic links, returns the real path
sub resolve_links
{
local $path = $_[0];
$path =~ s/\/+/\//g;
$path =~ s/\/$// if ($path ne "/");
local @p = split(/\/+/, $path);
shift(@p);
for($i=0; $i<@p; $i++) {
	local $sofar = "/".join("/", @p[0..$i]);
	local $lnk = readlink($sofar);
	if ($lnk =~ /^\//) {
		# Link is absolute..
		return &resolve_links($lnk."/".join("/", @p[$i+1 .. $#p]));
		}
	elsif ($lnk) {
		# Link is relative
		return &resolve_links("/".join("/", @p[0..$i-1])."/".$lnk."/".join("/", @p[$i+1 .. $#p]));
		}
	}
return $path;
}

# same_file(file1, file2)
# Returns 1 if two files are actually the same
sub same_file
{
return 1 if ($_[0] eq $_[1]);
return 0 if ($_[0] !~ /^\// || $_[1] !~ /^\//);
local @stat1 = $stat_cache{$_[0]} ? @{$stat_cache{$_[0]}}
			          : (@{$stat_cache{$_[0]}} = stat($_[0]));
local @stat2 = $stat_cache{$_[1]} ? @{$stat_cache{$_[1]}}
			          : (@{$stat_cache{$_[1]}} = stat($_[1]));
return 0 if (!@stat1 || !@stat2);
return $stat1[0] == $stat2[0] && $stat1[1] == $stat2[1];
}

# flush_webmin_caches()
# Clears all in-memory and on-disk caches used by webmin
sub flush_webmin_caches
{
undef(%main::read_file_cache);
undef(%main::acl_hash_cache);
undef(%main::acl_array_cache);
undef(%main::has_command_cache);
undef(@main::list_languages_cache);
unlink("$config_directory/module.infos.cache");
&get_all_module_infos();
}

# list_usermods()
# Returns a list of additional module restrictions. For internal use in
# usermin only.
sub list_usermods
{
local @rv;
local $_;
open(USERMODS, "$config_directory/usermin.mods");
while(<USERMODS>) {
	if (/^([^:]+):(\+|-|):(.*)/) {
		push(@rv, [ $1, $2, [ split(/\s+/, $3) ] ]);
		}
	}
close(USERMODS);
return @rv;
}

# available_usermods(&allmods, &usermods)
# Returns a list of modules that are available to the given user, based
# on usermod additional/subtractions
sub available_usermods
{
return @{$_[0]} if (!@{$_[1]});

local %mods;
map { $mods{$_->{'dir'}}++ } @{$_[0]};
local @uinfo = @remote_user_info;
@uinfo = getpwnam($remote_user) if (!@uinfo);
foreach $u (@{$_[1]}) {
	local $applies;
	if ($u->[0] eq "*" || $u->[0] eq $remote_user) {
		$applies++;
		}
	elsif ($u->[0] =~ /^\@(.*)$/) {
		# Check for group membership
		local @ginfo = getgrnam($1);
		$applies++ if (@ginfo && ($ginfo[2] == $uinfo[3] ||
			&indexof($remote_user, split(/\s+/, $ginfo[3])) >= 0));
		}
	elsif ($u->[0] =~ /^\//) {
		# Check users and groups in file
		local $_;
		open(USERFILE, $u->[0]);
		while(<USERFILE>) {
			tr/\r\n//d;
			if ($_ eq $remote_user) {
				$applies++;
				}
			elsif (/^\@(.*)$/) {
				local @ginfo = getgrnam($1);
				$applies++
				  if (@ginfo && ($ginfo[2] == $uinfo[3] ||
				      &indexof($remote_user,
					       split(/\s+/, $ginfo[3])) >= 0));
				}
			last if ($applies);
			}
		close(USERFILE);
		}
	if ($applies) {
		if ($u->[1] eq "+") {
			map { $mods{$_}++ } @{$u->[2]};
			}
		elsif ($u->[1] eq "-") {
			map { delete($mods{$_}) } @{$u->[2]};
			}
		else {
			undef(%mods);
			map { $mods{$_}++ } @{$u->[2]};
			}
		}
	}
return grep { $mods{$_->{'dir'}} } @{$_[0]};
}

# get_available_module_infos(nocache)
# Returns a list of modules available to the current user, based on
# operating system support, access control and usermod restrictions.
sub get_available_module_infos
{
local (%acl, %uacl);
&read_acl(\%acl, \%uacl);
local $risk = $gconfig{'risk_'.$base_remote_user};
local ($minfo, @rv);
foreach $minfo (&get_all_module_infos($_[0])) {
	next if (!&check_os_support($minfo));
	if ($risk) {
		# Check module risk level
		next if ($risk ne 'high' && $minfo->{'risk'} &&
			 $minfo->{'risk'} !~ /$risk/);
		}
	else {
		# Check user's ACL
		next if (!$acl{$base_remote_user,$minfo->{'dir'}} &&
			 !$acl{$base_remote_user,"*"});
		}
	push(@rv, $minfo);
	}
local @usermods = &list_usermods();
return sort { $a->{'desc'} cmp $b->{'desc'} }
	    &available_usermods(\@rv, \@usermods);
}

# get_visible_module_infos(nocache)
# Like get_available_module_infos, but excludes hidden modules from the list
sub get_visible_module_infos
{
return grep { !$_->{'hidden'} } &get_available_module_infos($_[0]);
}

# is_under_directory(directory, file)
# Returns 1 if the given file is under the specified directory, 0 if not.
# Symlinks are taken into account in the file to find it's 'real' location
sub is_under_directory
{
local ($dir, $file) = @_;
return 1 if ($dir eq "/");
return 0 if ($file =~ /\.\./);
local $lp = &resolve_links($file);
if ($lp ne $file) {
	return &is_under_directory($dir, $lp);
	}
return 0 if (length($file) < length($dir));
return 1 if ($dir eq $file);
$dir =~ s/\/*$/\//;
return substr($file, 0, length($dir)) eq $dir;
}

# parse_http_url(url, [basehost, baseport, basepage, basessl])
# Given an absolute URL, returns the host, port, page and ssl components.
# Relative URLs can also be parsed, if the base information is provided
sub parse_http_url
{
if ($_[0] =~ /^(http|https):\/\/([^:\/]+)(:(\d+))?(\/\S*)?$/) {
	# An absolute URL
	local $ssl = $1 eq 'https';
	return ($2, $3 ? $4 : $ssl ? 443 : 80, $5 || "/", $ssl);
	}
elsif (!$_[1]) {
	# Could not parse
	return undef;
	}
elsif ($_[0] =~ /^\/\S*$/) {
	# A relative to the server URL
	return ($_[1], $_[2], $_[0], $_[4]);
	}
else {
	# A relative to the directory URL
	local $page = $_[3];
	$page =~ s/[^\/]+$//;
	return ($_[1], $_[2], $page.$_[0], $_[4]);
	}
}

# check_clicks_function()
# Returns HTML for a JavaScript function called check_clicks that returns
# true when first called, but false subsequently. Useful on onClick for
# critical buttons.
sub check_clicks_function
{
return <<EOF;
<script>
clicks = 0;
function check_clicks(form)
{
clicks++;
if (clicks == 1)
	return true;
else {
	if (form != null) {
		for(i=0; i<form.length; i++)
			form.elements[i].disabled = true;
		}
	return false;
	}
}
</script>
EOF
}

# load_entities_map()
# Returns a hash ref containing mappings between HTML entities (like ouml) and
# ascii values (like 246)
sub load_entities_map
{
if (!defined(%entities_map_cache)) {
	local $_;
	open(EMAP, "$root_directory/entities_map.txt");
	while(<EMAP>) {
		if (/^(\d+)\s+(\S+)/) {
			$entities_map_cache{$2} = $1;
			}
		}
	close(EMAP);
	}
return \%entities_map_cache;
}

# entities_to_ascii(string)
# Given a string containing HTML entities like &ouml; and &#55;, replace them
# with their ASCII equivalents
sub entities_to_ascii
{
local $str = $_[0];
local $emap = &load_entities_map();
$str =~ s/&([a-z]+);/chr($emap->{$1})/ge;
$str =~ s/&#(\d+);/chr($1)/ge;
# print "str = $str"; exit;
return $str;
}

# get_product_name()
# Returns either 'webmin' or 'usermin'
sub get_product_name
{
return $gconfig{'product'} if (defined($gconfig{'product'}));
return defined($gconfig{'userconfig'}) ? 'usermin' : 'webmin';
}

$default_charset = "iso-8859-1";

# get_charset()
# Returns the character set for the current language
sub get_charset
{
local $charset = defined($gconfig{'charset'}) ? $gconfig{'charset'} :
		 $current_lang_info->{'charset'} ?
		 $current_lang_info->{'charset'} : $default_charset;
return $charset;
}

# get_display_hostname()
# Returns the system's hostname for UI display purposes
sub get_display_hostname
{
if ($gconfig{'hostnamemode'} == 0) {
	return &get_system_hostname();
	}
elsif ($gconfig{'hostnamemode'} == 3) {
	return $gconfig{'hostnamedisplay'};
	}
else {
	local $h = $ENV{'HTTP_HOST'};
	$h =~ s/:\d+//g;
	if ($gconfig{'hostnamemode'} == 2) {
		$h =~ s/^(www|ftp|mail)\.//i;
		}
	return $h;
	}
}

# save_module_config([&config], [modulename])
# Saves the configuration for some module
sub save_module_config
{
local $c = $_[0] || \%config;
local $m = $_[1] || $module_name;
&write_file("$config_directory/$m/config", $c);
}

# save_user_module_config([&config], [modulename])
# Saves the user's Usermin configuration for some module
sub save_user_module_config
{
local $c = $_[0] || \%userconfig;
local $m = $_[1] || $module_name;
local $ucd = $user_config_directory;
if (!$ucd) {
	local @uinfo = @remote_user_info ? @remote_user_info
					 : getpwnam($remote_user);
	return if (!@uinfo || !$uinfo[7]);
	$ucd = "$uinfo[7]/$gconfig{'userconfig'}";
	}
&write_file("$ucd/$m/config", $c);
}

# nice_size(bytes, [min])
# Converts a number of bytes into a number of bytes, kb, mb or gb
sub nice_size
{
if ($_[0] > 10*1024*1024*1024 || $_[1] >= 1024*1024*1024) {
	return int(($_[0]+1024*1024*1024-1)/1024/1024/1024)." GB";
	}
elsif ($_[0] > 10*1024*1024 || $_[1] >= 1024*1024) {
	return int(($_[0]+1024*1024-1)/1024/1024)." MB";
	}
elsif ($_[0] > 10*1024 || $_[1] >= 1024) {
	return int(($_[0]+1024-1)/1024)." kB";
	}
else {
	return int($_[0])." bytes";
	}
}

# get_perl_path()
# Returns the path to Perl currently in use
sub get_perl_path
{
local $rv;
if (open(PERL, "$config_directory/perl-path")) {
	chop($rv = <PERL>);
	close(PERL);
	return $rv;
	}
return $^X if (-x $^X);
return &has_command("perl");
}

# get_goto_module([&mods])
# Returns the details of a module that the current user should be re-directed
# to after logging in, or undef if none
sub get_goto_module
{
local @mods = $_[0] ? @{$_[0]} : &get_visible_module_infos();
if ($gconfig{'gotomodule'}) {
	local ($goto) = grep { $_->{'dir'} eq $gconfig{'gotomodule'} } @mods;
	return $goto if ($goto);
	}
if (@mods == 1 && $gconfig{'gotoone'}) {
	return $mods[0];
	}
return undef;
}

# select_all_link(field, form, text)
# Returns HTML for a 'Select all' link that uses Javascript to select
# multiple checkboxes with the same name
sub select_all_link
{
local ($field, $form, $text) = @_;
$form = int($form);
$text ||= "Select all";
return "<a href='' onClick='document.forms[$form].$field.checked = true; for(i=0; i<document.forms[$form].$field.length; i++) { document.forms[$form].${field}[i].checked = true; } return false'>$text</a>";
}

# select_all_link(field, form, text)
# Returns HTML for a 'Select all' link that uses Javascript to invert the
# selection on multiple checkboxes with the same name
sub select_invert_link
{
local ($field, $form, $text) = @_;
$form = int($form);
$text ||= "Invert selection";
return "<a href='' onClick='document.forms[$form].$field.checked = !document.forms[$form].$field.checked; for(i=0; i<document.forms[$form].$field.length; i++) { document.forms[$form].${field}[i].checked = !document.forms[$form].${field}[i].checked; } return false'>$text</a>";
}

# check_pid_file(file)
# Given a pid file, returns the PID it contains if the process is running
sub check_pid_file
{
open(PIDFILE, $_[0]) || return undef;
local $pid = <PIDFILE>;
close(PIDFILE);
$pid =~ /^\s*(\d+)/ || return undef;
kill(0, $1) || return undef;
return $1;
}

#
# Return the local os-specific library name to this module
#
sub get_mod_lib
{
local $lib;
if (-r "$module_root_directory/$module_name-$gconfig{'os_type'}-$gconfig{'os_version'}-lib.pl") {
        return "$module_name-$gconfig{'os_type'}-$gconfig{'os_version'}-lib.pl";
        }
elsif (-r "$module_root_directory/$module_name-$gconfig{'os_type'}-lib.pl") {
        return "$module_name-$gconfig{'os_type'}-lib.pl";
        }
elsif (-r "$module_root_directory/$module_name-generic-lib.pl") {
        return "$module_name-generic-lib.pl";
        }
else {
	return "";
	}
}

# 	-- Mount the file-system read-write
sub mountrw
{
	# system('/usr/local/sbin/remountrw');
	system("/sbin/mount -u -o rw /");
}

1;  # return true?

