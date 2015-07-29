##
## Just a simple logger
##

package TrackerProtocol::Log;

use 5.008008;
use strict;
use warnings;

require Exporter;

our @ISA = qw(Exporter);

# Items to export into callers namespace by default. Note: do not export
# names by default without a very good reason. Use EXPORT_OK instead.
# Do not simply export all your public functions/methods/constants.

our @EXPORT = qw( LOG WARN ERROR DEBUG LOGLEVEL VERBOSE PRINT );

our $VERSION = '0.02';

our $LEVEL = 0;
our $VERBOSE = 1;

# Preloaded methods go here.

##
## print level 3 messages
##
sub LOG($)  {
	my ($message) = @_;
	&_print("[INFO] " . $message) if ($LEVEL >= 3);
}

##
## print level 2 messages
##
sub WARN($)  {
	my ($message) = @_;
	&_print("[WARN] " . $message) if ($LEVEL >= 2);
}

##
## print level 1 messages
##
sub ERROR($) {
	my ($message) = @_;
	&_print("[ERROR] " . $message) if ($LEVEL >= 1);
}

##
## print level 4 or higher messages
##
sub DEBUG  {
	my ($message, $debuglevel) = @_;
	$debuglevel = 4 if (!defined($debuglevel));
	&_print("[DEBUG] " . $message) if ($LEVEL >= $debuglevel);
}

##
## set the logging level (default = off = 0)
##
sub LOGLEVEL($)  {
	my ($loglevel) = shift;
	$LEVEL = $loglevel if (defined($loglevel) && $loglevel >= 0);
}

##
## enable or disable verbose logging (default = on = 1)
##
sub VERBOSE($)  {
	my ($verbose) = shift;
	$VERBOSE = $verbose if (defined($verbose) && $verbose >= 0);
}

##
## just print a line, no matter what the loglevel is (if verbose is enabled)
##
sub PRINT($)  {
	my ($message) = @_;
	&_print($message);
}

##
## print a message if verbose logging is enabled
##
sub _print()  {
	my ($message) = @_;
	print $message . "\n" if ($VERBOSE);
}

1;
__END__
# Below is stub documentation for your module. You'd better edit it!

=head1 NAME

TrackerProtocol::Log - A simple logger module

=head1 SYNOPSIS

  use TrackerProtocol::Log;
  PRINT("print some normal info");
  LOG("the same but this will add an [INFO] tag");
  DEBUG("exactly the same but with a [DEBUG] tag");
  LOGLEVEL(5);
  VERBOSE(0);

=head1 DESCRIPTION

A very simple logger module used by the TrackerProtocol module.
All functions are exported by default.

=head2 EXPORT

LOG
WARN
ERROR
DEBUG
PRINT
LOGLEVEL
VERBOSE

=head1 AUTHOR

Maarten Wallraf, E<lt>mwallraf@2nms.comE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2008 by Maarten Wallraf

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.8 or,
at your option, any later version of Perl 5 you may have available.


=cut
