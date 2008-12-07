#!/usr/bin/perl
package AjaxConnector;
use Utils;

#	-- This just prints contents of the ajaxConnector.js with folln variables et
#	 - handler_function:  	Which function should be called on onReadyStateChange
#	 - div_element: 	which DOM element should be repopulated with output returned by AJAX call

sub printAjaxConnector
{
	my ($self, $handler_func, $div_element)	=	@_;

	my $utils		= 	new Utils();
	my $ajaxConnFile	=	$utils->getProperty('AppPath') . "/ajaxConnector.js";

	open (JS, $ajaxConnFile) or die ("File I/O error: $ajaxConnFile $!");
	while (<JS>) 	 
	{ 
		s/handler_func/$handler_func/g;
		s/modified_div/$div_element/g;
		print; 
	} 
	close JS;	
}

#	-- similar to printAjaxConnector, but this func returns
#	   the JS, instead of printing to stdout
sub getAjaxConnector
{
	my ($self, $handler_func, $div_element)	=	@_;

	my $utils		= 	new Utils();
	my $app_path		=	$utils->getProperty('AppPath');
	my $ajaxConnFile	=	$app_path . "/ajaxConnector.js";

	my $js_return_code	=	"";

	open (JS, $ajaxConnFile) or die ("File I/O error: $ajaxConnFile $!");
	while (<JS>) 	 
	{ 
		s/handler_func/$handler_func/g;
		s/modified_div/$div_element/g;
		$js_return_code	.= $_;
#		print; 
	} 
	close JS;
	return $js_return_code;
}


sub new 
{
	my $self	=	{};
	my $class 	= 	shift;
	bless $self, 'AjaxConnector';
	return $self;
}


1;
