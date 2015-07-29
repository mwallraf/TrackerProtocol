##
## General module to decode/encode messages being received from or sent to GPS tracking devices
##

package TrackerProtocol;

use 5.008008;
use strict;
use warnings;
use TrackerProtocol::Log;

our $DEBUG = 0;

our $VERSION = '0.02';


# Preloaded methods go here.

##
## create a new object (TrackerProtocol class itself should never be used)
##
sub new()  {
	my ($class, %args) = @_;
	my $self = bless {}, ref ($class) || $class;

	$DEBUG = $args{'debug'} if (defined($args{'debug'}));
	$self->debug($DEBUG);

	## init should be loaded in the subclass (ex. GP200)
	$self->_init(%args);
	return $self;
}


sub _init()  {
	## dummy procedure in case the subclass hasn't defined it
}

sub _scrub_packet()  {
	## dummy procedure in case the subclass hasn't defined it
}


##
## decode a single packet received via GPRS from a tracking device
## (ex. packet = <19CAE24E0AD71BB08CBDE9400B48064900084AA44C0002A033701871333539353231303030303038393588019E8903C390019800>)
## Protocol specific information is stored in each separate class
## this assumes that each packet is in HEX format !!
##
sub decode()  {
	my ($self, $packet) = @_;
	
	## initialize decoded values
	$self->{'decoded'} = {};
	
	## check if we have any data
	if (!$packet)  {
		ERROR("no packet given as parameter or packet is empty, nothing to decode");
		return -1;
	}
	
	LOG("packet to decode = $packet");
	
	## scrub the packet, preparing it for decoding
	$packet = $self->_scrub_packet($packet);
	
	## now let's start decoding
	$self->_start_decode($packet);
	
	return $self->{'decoded'};
}


##
## this procedure does the actual work to decode
## this assumes that the packet is in HEX format !!
##
sub _start_decode()  {
	my ($self, $packet) = @_;
	
	## we'll have to parse the packet byte by byte
	my @bytestream = split(//, $packet);
	DEBUG("length of packet = " . (scalar @bytestream)/2 . " bytes");
	
	my @match_history = ();	## keep track of all the protocol measurements we've found so far
							## to make sure that there's only 1 match
	my $trusted = 1;	## this is an attempt to ensure that the parsed information can be trusted
	
	while (@bytestream)  {
		## get the next byte
		my $byte = shift(@bytestream) . shift(@bytestream);
		DEBUG("parsing next byte : $byte", 5);
		
		my $count_matched_headers = 0;	## keep track on number of matched headers with this byte
		my @matching_headers = ();		## store the matched measurements in a temp array
		my @unmatched_bytes = ();		## these bytes could not be mapped to the protocol
		
		## loop through each parameter in the protocol and see if the header matches the byte
		foreach my $msr (keys %{$self->{'protocol'}})  {
			## convert the byte to a valid header by applying the header mask of each measure
			## we have to do this for each measurement because the mask is not always the same
			my $header = $self->_apply_bit_mask($byte, $self->{'protocol'}->{$msr}->{'mask'});
						
			## now check if the protocol measurement header matches
			## if it matches, save the measure in a temp arry so that we can verify if we had exactly 1 match or not
			if ($header eq $self->{'protocol'}->{$msr}->{'header'})  {
				DEBUG("matching header found : $byte matches measurement $msr (exp. byte length = " . $self->{'protocol'}->{$msr}->{'length'} . ")");
				if (grep { /^msr$/ } @match_history)  {
					WARN("protocol measurement $msr occurs more than once, the decoded information could be faulty");
					$trusted = 0;
				}
				$count_matched_headers ++;
				push(@matching_headers, $msr);
				push(@match_history, $msr);
			}
		}
		
		## now we've matched the byte against all known protocol measurements
		## let's analyze the results, if it's a known measurement then get the next required bytes
		## perfect : exact 1 matching header found
		if ($count_matched_headers == 1)  {
			my $data = $byte;
			my $length = 0;
			
			## fixed length measurement
			if ($self->{'protocol'}->{$matching_headers[0]}->{'length'} >= 0)  {
				$length = $self->{'protocol'}->{$matching_headers[0]}->{'length'};
				DEBUG("fixed length measurement : $length bytes");
			}
			## variable length measurement
			else {
				## get the data part of the packet without headder
				my $data_part = $self->_apply_inverted_bit_mask($data, $self->{'protocol'}->{$matching_headers[0]}->{'mask'});
				DEBUG("variable length measurement : $length bytes");
			}

			## get the next bytes belonging to this measurement			
			for (my $i = 1; $i < $length; $i++)  {
				$data .= shift(@bytestream);
				$data .= shift(@bytestream);
			}
			DEBUG("complete data packet found for $matching_headers[0] = $data");
			
			## parse the value if a dispatcher function exists
			if (defined($self->{'protocol'}->{$matching_headers[0]}->{'dispatch'}))  {
				my $result = {};
				eval {
					## execute the dispatcher procedure to calculate the actual values of the measurement
					## parameters = the measurement + the actual data part in HEX
					## we expect an hash result
					$result->{$matching_headers[0]} = $self->{'protocol'}->{$matching_headers[0]}->{'dispatch'}($self, $matching_headers[0], $self->_apply_inverted_bit_mask($data, $self->{'protocol'}->{$matching_headers[0]}->{'mask'}));
					if (defined($self->{'protocol'}->{$matching_headers[0]}->{'unit'}))  {
						DEBUG("unit of " . $matching_headers[0] . " = " . $self->{'protocol'}->{$matching_headers[0]}->{'unit'});
						$result->{$matching_headers[0]}->{'unit'} = $self->{'protocol'}->{$matching_headers[0]}->{'unit'};
					}
					else {
						WARN("unit of " . $matching_headers[0] . " is not defined");
						$result->{$matching_headers[0]}->{'unit'} = "UNKNOWN";
					}

					## save the result on the hash array
					%{$self->{'decoded'}} = (%{$self->{'decoded'}}, %{$result});
				};
				if ($@) {
					ERROR("error executing dispatcher function for " . $matching_headers[0] . " : $@");
				}
			}
			else {
					ERROR("there is no dispatcher function defined for " . $matching_headers[0]);
			}
		}
		## problem : we found duplicate matches
		elsif ($count_matched_headers > 1)  {
			ERROR("byte $byte matches $count_matched_headers measurements, decoded packet could be false : " . join(" ", @matching_headers) );
			$trusted = 0;
		}
		## no matches were found
		else  {
			ERROR("byte $byte could not be matched agains any measurement, decoded packet could be false");
			$trusted = 0;
			push(@unmatched_bytes, $byte);
		}
	}
	
	## additional checks to see if decoding can be trusted : 
	##  - assuming we require at least a datetime
	##  - assuming that there has to be at least 1 satellite
	##  - assuming that we need at least a GPS signal
	my $trusted_temp = 1;
	## check the datetime
	$trusted_temp = 0 unless (defined($self->{'decoded'}->{'datetime'}) || defined($self->{'decoded'}->{'datetime_start'}) );
	## check the satellites
	$trusted_temp = 0 unless (defined($self->{'decoded'}->{'satellites'}) && ($self->{'decoded'}->{'satellites'}->{'satellites'} > 0) );
	## check GPS signal
	$trusted_temp = 0 unless ( 	(defined($self->{'decoded'}->{'gps_coord_stop'}) && ($self->{'decoded'}->{'gps_coord_stop'}->{'gps'} > 0) ) || 
								(defined($self->{'decoded'}->{'gps_coord'}) && ($self->{'decoded'}->{'gps_coord'}->{'gps'} > 0) ) || 
								(defined($self->{'decoded'}->{'avg_coord'}) && ($self->{'decoded'}->{'avg_coord'}->{'gps'} > 0) ) );
	
	$trusted = $trusted && $trusted_temp;
	
	## save some general info for each packet
	$self->{'decoded'}->{'_info'}->{'packet'} = $packet;	## store the original packet
	$self->{'decoded'}->{'_info'}->{'trusted'} = $trusted;	## try to indicate if parsing the packet was successfull
}


##
## find out the length of the packet in case the packet length is variable
## Input = name of measurement, data = databytes without header
##
sub _find_variable_packet_length()  {
	my ($self, $measurement, $data) = @_;
	
	DEBUG("variable length measurement, parse the packet to know the length");

	## convert data to bits
	my $data_part = $self->_hex2bits($data);
	DEBUG("data in bits : $data = $data_part", 5);
	
	## find out which bits describe the length of the packet
	my @offset = @{$self->{'protocol'}->{$measurement}->{'length_bits'}};
	$data_part = substr($data_part, $offset[0], $offset[1]);
	DEBUG("byte which describes length : data_part", 5);

	## length = decode part of the length byte + 1 byte
	my $length = $self->_bits2dec($data_part) + 1;

	return $length;
}

##
## input = HEX byte + HEX mask
## output => result after bitwise ANDing byte + mask (in HEX)
##
sub _apply_bit_mask()  {
	my ($self, $byte, $mask) = @_;

	## TODO: is this the easiest way to do this ?? -- need to check
	## make sure we're dealing with BITS, apply AND operator and convert back to HEX
	my $result = uc(unpack("H2", pack("B8", unpack("B8", pack("H2", $byte)) & unpack("B8", pack("H2", $mask)) )));
	DEBUG("applying mask : $mask AND $byte = $result", 5);
	return $result;
}

##
## input = HEX data + HEX mask
## output => result after bitwise ANDing data + INVERTED mask (in HEX)
## purpose is to remove the header from the data part
## needed like this because headers are not always exactly 1 byte
##
sub _apply_inverted_bit_mask()  {
	my ($self, $data, $mask) = @_;

	my $l = length($data);	## length of the data part (including header)

	## find number of 1 bits of the header
	## assuming that header masks are exactly 1 byte
	my $inverted_mask = unpack("B8", pack("H2", $mask));
	my @bits = split(//, $inverted_mask);
	map {  $_ = !$_; } @bits;
	$inverted_mask = join("", @bits);
	$inverted_mask = sprintf("%08s", $inverted_mask);
	$inverted_mask = uc(unpack("H2", pack("B8", $inverted_mask)));
	DEBUG("inverted mask of $mask is $inverted_mask", 5);
	$inverted_mask = $inverted_mask . "F" x ($l - 2);

	## apply inverse header mask to get data bits
	## TODO: check if this is the best way
	my $result = uc(unpack("H".$l, pack("B".($l*4), unpack("B".($l*4), pack("H".$l, $data)) & unpack("B".($l*4), pack("H".$l, $inverted_mask)) )));
	DEBUG("applying inverted mask : $inverted_mask AND $data = $result", 5);
	
	return $result;
}


##
## Convert hexadecimal to decimal
##
sub _hex2dec()  {
	my ($self, $hex) = @_;
	my $dec = hex($hex);
	DEBUG("convert hex to decimal : $hex = $dec", 5);
	return $dec;
}


##
## convert hexadecimal stream to bits
##
sub _hex2bits()  {
	my ($self, $hex) = @_;
	my $l = length($hex);
	my $bin = unpack("B".($l*4), pack("H".$l, $hex));
	DEBUG("convert hex to binary : $hex = $bin", 5);
	return $bin;
}


##
## convert hexadecimal stream to ascii
##
sub _hex2ascii()  {
	my ($self, $hex) = @_;
	my $l = length($hex);
	my $ascii = unpack("A*", pack("H".$l, $hex));
	DEBUG("convert hex to ascii : $hex = $ascii", 5);
	return $ascii;
}


##
## convert binary to decimal
## pad with 0 if needed
##
sub _bin2dec()  {
	my ($self, $bin) = @_;
	my $l = length($bin);
	$l = $l + (8 - ($l % 8)) unless ($l % 8 == 0);
	$bin = sprintf("%0".$l."s", $bin);
	$l = length($bin);
	my $dec = uc(unpack("H*", pack("B".$l, $bin)));
	$dec = hex($dec);
	DEBUG("convert bin to decimal : $bin = $dec", 5);
	return $dec;
}

##
## set the debug level
##
sub debug()  {
	my ($self, $level) = @_;

	return $DEBUG if (!defined($level) || $level !~ /^[0-9]$/);

	$DEBUG = $level;
	
	LOGLEVEL($DEBUG);
	DEBUG("DEBUG level set to $DEBUG");
}


1;
__END__
# Below is stub documentation for your module. You'd better edit it!

=head1 NAME

TrackerProtocol - Module to decode/encode tcp messages received from or sent to GPS tracking devices

=head1 SYNOPSIS

  DO NOT USE THE THIS MODULE DIRECTLY
  USE ONE OF THE SUBCLASSES INSTEAD
  
  use TrackerProtocol::GP200;
  my $p = new TrackerProtocol::GP200();
  my $rc = $p->decode($packet);

=head1 DESCRIPTION

This is the base module for decoding/encoding packets received from GPS Tracker devices.
Currently only the GP200 protocol is supported.
Do no use this module directly, use one of the subclasses instead.


=head1 SEE ALSO

More information can be found in the perldoc of one of the subclasses.

=head1 AUTHOR

Maarten Wallraf, E<lt>mwallraf@2nms.comE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2008 by Maarten Wallraf

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.8 or,
at your option, any later version of Perl 5 you may have available.


=cut
