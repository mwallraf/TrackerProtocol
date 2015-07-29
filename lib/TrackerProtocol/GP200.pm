##
## Module to decode/encode messages being received from or sent to GP200 GPS tracking device
##

package TrackerProtocol::GP200;

use 5.008008;
use strict;
use warnings;
use TrackerProtocol;
use TrackerProtocol::Log;

our @ISA = qw( TrackerProtocol );

our $VERSION = '0.02';

##
## this is the GP200 protocol description
##
our %PROTOCOL =  (
				'gps_coord_stop'	=>	{	
									'header'	=>	"00",
									'mask'		=>	"FC",
									'descr'		=>	"gps coordinates stop",
									'unit'		=>	"UNKNOWN",
									'length'	=>	7,	# length in bytes, including header
									'dispatch'	=>	\&_decode_gps_coord_stop,
								},
				'gps_coord'	=>	{	
									'header'	=>	"08",
									'mask'		=>	"FC",
									'descr'		=>	"gps coordinates",
									'unit'		=>	"UNKNOWN",
									'length'	=>	7,	# length in bytes, including header
									'dispatch'	=>	\&_decode_gps_coord,
								},
				'datetime_start'	=>	{	
									'header'	=>	"10",
									'mask'		=>	"FC",
									'descr'		=>	"date and time of start",
									'unit'		=>	"UTC",
									'length'	=>	4,	# length in bytes, including header
									'dispatch'	=>	\&_decode_datetime_start,
								},
				'datetime'	=>	{	
									'header'	=>	"18",
									'mask'		=>	"FC",
									'descr'		=>	"date and time",
									'unit'		=>	"UTC",
									'length'	=>	4,	# length in bytes, including header
									'dispatch'	=>	\&_decode_datetime,
								},
				'avg_coord'	=>	{	
									'header'	=>	"38",
									'mask'		=>	"FC",
									'descr'		=>	"average coordinates",
									'unit'		=>	"UNKNOWN",
									'length'	=>	7,	# length in bytes, including header
									'dispatch'	=>	\&_decode_avg_coord,
								},
				'speed'	=>	{	
									'header'	=>	"40",
									'mask'		=>	"FC",
									'descr'		=>	"speed",
									'unit'		=>	"km/u",
									'length'	=>	2,	# length in bytes, including header
									'dispatch'	=>	\&_decode_speed,
								},
				'satellites'	=>	{	
									'header'	=>	"48",
									'mask'		=>	"FF",
									'descr'		=>	"number of satellites",
									'unit'		=>	"number of satellites",
									'length'	=>	2,	# length in bytes, including header
									'dispatch'	=>	\&_decode_number_of_satellites,
								},
				'altitude'	=>	{	
									'header'	=>	"49",
									'mask'		=>	"FF",
									'descr'		=>	"altitude",
									'unit'		=>	"m",
									'length'	=>	3,	# length in bytes, including header
									'dispatch'	=>	\&_decode_altitude,
								},
				'direction'	=>	{	
									'header'	=>	"4A",
									'mask'		=>	"FF",
									'descr'		=>	"direction",
									'unit'		=>	"m",
									'length'	=>	2,	# length in bytes, including header
									'dispatch'	=>	\&_decode_direction,
								},
				'distance'	=>	{	
									'header'	=>	"4C",
									'mask'		=>	"FF",
									'descr'		=>	"distance",
									'unit'		=>	"m",
									'length'	=>	5,	# length in bytes, including header
									'dispatch'	=>	\&_decode_distance,
								},
				'position_error'	=>	{	
									'header'	=>	"4D",
									'mask'		=>	"FF",
									'descr'		=>	"position error",
									'unit'		=>	"m",
									'length'	=>	2,	# length in bytes, including header
									'dispatch'	=>	\&_decode_position_error,
								},
				'quality_gsm_signal'	=>	{	
									'header'	=>	"70",
									'mask'		=>	"FF",
									'descr'		=>	"quality gsm signal",
									'unit'		=>	"NA",
									'length'	=>	2,	# length in bytes, including header
									'dispatch'	=>	\&_decode_quality_gsm_signal,
								},
				'imei'	=>	{	
									'header'	=>	"71",
									'mask'		=>	"FF",
									'descr'		=>	"imei",
									'unit'		=>	"NA",
									'length'	=>	15,	# length in bytes, including header
									'dispatch'	=>	\&_decode_imei,
								},
				'gsm_number_last_rcvd_sms'	=>	{	
									'header'	=>	"72",
									'mask'		=>	"FF",
									'descr'		=>	"gsm number last received sms",
									'unit'		=>	"NA",
									'length'	=>	-1,	# length in bytes, including header
									'length_bits' => [0,8], # these are the bits that contain the packet length
															# 0 = index of data part, 8 is length (number of bits)
									'dispatch'	=>	\&_decode_gsm_number_last_rcvd_sms,
								},
				'call_value'	=>	{	
									'header'	=>	"75",
									'mask'		=>	"FF",
									'descr'		=>	"call value",
									'unit'		=>	"time and date",
									'length'	=>	-1,	# length in bytes, including header
									'length_bits' => [0,8], # these are the bits that contain the packet length
															# 0 = index of data part, 8 is length (number of bits)
									'dispatch'	=>	\&_decode_call_value,
								},
				'datatype'	=>	{	
									'header'	=>	"80",
									'mask'		=>	"FF",
									'descr'		=>	"datatype",
									'unit'		=>	"NA",
									'length'	=>	2,	# length in bytes, including header
									'dispatch'	=>	\&_decode_datatype,
								},
				'powersupply_voltage'	=>	{	
									'header'	=>	"88",
									'mask'		=>	"FF",
									'descr'		=>	"power supply voltage",
									'unit'		=>	"V",
									'length'	=>	3,	# length in bytes, including header
									'dispatch'	=>	\&_decode_powersupply_voltage,
								},
				'battery_voltage'	=>	{	
									'header'	=>	"89",
									'mask'		=>	"FF",
									'descr'		=>	"battery voltage",
									'unit'		=>	"V",
									'length'	=>	3,	# length in bytes, including header
									'dispatch'	=>	\&_decode_battery_voltage,
								},
				'status_inputs_1'	=>	{	
									'header'	=>	"90",
									'mask'		=>	"FF",
									'descr'		=>	"status of inputs-1",
									'unit'		=>	"NA",
									'length'	=>	2,	# length in bytes, including header
									'dispatch'	=>	\&_decode_status_inputs_1,
								},
				'status_inputs_2'	=>	{	
									'header'	=>	"93",
									'mask'		=>	"FF",
									'descr'		=>	"status of inputs-2",
									'unit'		=>	"NA",
									'length'	=>	2,	# length in bytes, including header
									'dispatch'	=>	\&_decode_status_inputs,
								},
				'status_outputs'	=>	{	
									'header'	=>	"98",
									'mask'		=>	"FF",
									'descr'		=>	"status of outputs",
									'unit'		=>	"NA",
									'length'	=>	2,	# length in bytes, including header
									'dispatch'	=>	\&_decode_status_outputs,
								},
				'status_alarms'	=>	{	
									'header'	=>	"A0",
									'mask'		=>	"FF",
									'descr'		=>	"alarm status",
									'unit'		=>	"NA",
									'length'	=>	2,	# length in bytes, including header
									'dispatch'	=>	\&_decode_status_alarms,
								},
				'status_geofence'	=>	{	
									'header'	=>	"AC",
									'mask'		=>	"FF",
									'descr'		=>	"status of geofence",
									'unit'		=>	"off/inside/outside",
									'length'	=>	3,	# length in bytes, including header
									'dispatch'	=>	\&_decode_status_geofence,
								},
	);


# Preloaded methods go here.


sub _init()  {
	my ($self, %args) = @_;
	
	$self->{'protocol'} = \%PROTOCOL;	## store the protocol information in the object
	$self->{'decoded'} = {};					## here we will stored the decoded values
	
	DEBUG("GP200 object created");
}

##
## prepare the data packet so we can start decoding it
##
sub _scrub_packet()  {
	my ($self, $packet) = @_;
	
	$packet =~ s/[\n<>]//g;
	
	LOG("scrubbing data packet, removing unwanted characters");
	DEBUG("scrubbed packet = $packet");
	
	return $packet;
}




##
## calculate the speed :
## Length: 2 bytes
## Structure: 010000AA  AAAAAAAA 
## Header mask: 6 bits
## Header result: 64 (010000XX)
## Speed
## Length: 	10 bits
## Format:	Speed in km/h
##
sub _decode_speed()	{
	my ($self, $measurement, $data) = @_;
	
	my $value = $self->_hex2dec($data);
	
	DEBUG("decoded value $measurement (hex $data) = $value");
	return { 'speed' => $value };
}


##
## calculate the number of received satellites
## Length: 2 bytes
## Structure: 01001000  AAAAAAAA 
## Header mask: 8 bits
## Header result: 72 (01001000)
##	Number of satellites
## Length: 	8 bits
## Format:	Number of satellites
##
sub _decode_number_of_satellites()  {
	my ($self, $measurement, $data) = @_;
	
	my $value = $self->_hex2dec($data);
	
	DEBUG("decoded value $measurement (hex $data) = $value");
	return { 'satellites' => $value };
}


##
## calculate the altitude
## Length: 3 bytes
## Structure: 01001001  AAAAAAAA  AAAAAAAA 
## Header mask: 8 bits
## Header result: 73 (01001001)
## 	Altitude
## Length: 	16 bits
## Format:	Height in m. If this is greater than 32767 then the height is negative. Ex. 65533 is -3m
## 
sub _decode_altitude()  {
	my ($self, $measurement, $data) = @_;
	
	my $value = $self->_hex2dec($data);
	
	if ($value > 32767)  {
		DEBUG("altitude is higher than 32767 => use negative altitude");
		$value = $value - 65535;
	}
	
	DEBUG("decoded value $measurement (hex $data) = $value");
	return { 'height' => $value };
}



##
## calculate gps coordinates of stop packet
## Length: 7 bytes
## Structure: 000000AB BBBBBBBB BBBBBBBB BBBBBBBC CCCCCCCC CCCCCCCC CCCCCCCC
## Header mask: 6 bits
## Header result: 0 (000000XX)
##	GPS reception
## Length: 	1 bit
## Format:	0: No GPS reception
## 		1: GPS reception OK
##	Latitude
## Length: 	24 bits
## Format: 	latitude * 50000 + 4500000
##	Longitude
## Length: 	25 bits
## Format: 	longitude * 50000 + 9000000
##
sub _decode_gps_coord_stop()  {
	my ($self, $measurement, $data) = @_;
	
	my $bits = $self->_hex2bits($data);
	my $gps_reception = $self->_bin2dec(substr($bits, 6, 1));
	my $latitude = ($self->_bin2dec(substr($bits, 7, 24)) - 4500000) / 50000;
	my $longitude = ($self->_bin2dec(substr($bits, 31, 25)) - 9000000) / 50000;
	
	DEBUG("decoded value $measurement (hex $data) : gps = $gps_reception, lat = $latitude, long = $longitude");
	return { 'gps' => $gps_reception, 'latitude' => $latitude, 'longitude' => $longitude };
}

##
## calculate gps coordinates
## Length: 7 bytes
## Structure: 000000AB BBBBBBBB BBBBBBBB BBBBBBBC CCCCCCCC CCCCCCCC CCCCCCCC
## Header mask: 6 bits
## Header result: 0 (000000XX)
##	GPS reception
## Length: 	1 bit
## Format:	0: No GPS reception
## 		1: GPS reception OK
##	Latitude
## Length: 	24 bits
## Format: 	latitude * 50000 + 4500000
##	Longitude
## Length: 	25 bits
## Format: 	longitude * 50000 + 9000000
##
sub _decode_gps_coord()  {
	my ($self, $measurement, $data) = @_;
	
	return &_decode_gps_coord_stop($self, $measurement, $data);
}


##
## calculate average gps coordinates
## Length: 7 bytes
## Structure: 000000AB BBBBBBBB BBBBBBBB BBBBBBBC CCCCCCCC CCCCCCCC CCCCCCCC
## Header mask: 6 bits
## Header result: 0 (000000XX)
##	GPS reception
## Length: 	1 bit
## Format:	0: No GPS reception
## 		1: GPS reception OK
##	Latitude
## Length: 	24 bits
## Format: 	latitude * 50000 + 4500000
##	Longitude
## Length: 	25 bits
## Format: 	longitude * 50000 + 9000000
##
sub _decode_avg_coord()  {
	my ($self, $measurement, $data) = @_;
	
	return &_decode_gps_coord_stop($self, $measurement, $data);
}

##
## calculate datetime
## Length: 4 bytes
## Structure: 000110AA  AAAAAAAA AAAAAAAA AAAAAAAA
## Header mask: 6 bits
## Header result: 24 (000110XX)
##	Time
## Length: 	26 bit
## Format:	(year*35942400 +month*2764800 +day*86400 +hour*3600 +minute*60 +second)/10
##
sub _decode_datetime()  {
	my ($self, $measurement, $data) = @_;
	
	my $value = $self->_hex2dec($data);
	
	## date/time calculation since beginning 2000 (assuming...)
	$value = $value * 10;
	my $year = sprintf("%04s", int($value / 35942400) + 2000);
	$value = $value % 35942400;
	my $month = sprintf("%02s", int($value / 2764800));
	$value = $value % 2764800;
	my $day = sprintf("%02s", int($value / 86400));
	$value = $value % 86400;
	my $hour = sprintf("%02s", int($value / 3600));
	$value = $value % 3600;
	my $minute = sprintf("%02s", int($value / 60));
	my $second = sprintf("%02s", $value % 60);
	
	
	DEBUG("decoded value $measurement (hex $data) = $value");
	return { 'year' => "$year", 'month' => "$month", 'day' => "$day", 'hour' => "$hour", 'minute' => "$minute", 'second' => "$second" };
}

##
## decode the direction parameter
## Length: 2 bytes
## Structure: 01001010  AAAAAAAA
## Header mask: 8 bits
## Header result: 74 (01001010)
##	Direction
## Length: 	8 bits
## Format:	Height Direction / 2 in meter
##
sub _decode_direction()  {
	my ($self, $measurement, $data) = @_;
	
	my $value = $self->_hex2dec($data) * 2;
	
	DEBUG("decoded value $measurement (hex $data) = $value");
	return { 'direction' => $value };
}


##
## calculate datetime of start record
## Length: 4 bytes
## Structure: 000110AA  AAAAAAAA AAAAAAAA AAAAAAAA
## Header mask: 6 bits
## Header result: 24 (000110XX)
##	Time
## Length: 	26 bit
## Format:	(year*35942400 +month*2764800 +day*86400 +hour*3600 +minute*60 +second)/10
##
sub _decode_datetime_start()  {
	my ($self, $measurement, $data) = @_;
	
	return &_decode_datetime(@_);
}


##
## parse the imei number
## Length: 15 bytes
## Structure: 01110001  AAAAAAAA  AAAAAAAA  AAAAAAAA  AAAAAAAA  AAAAAAAA  AAAAAAAA  AAAAAAAA  AAAAAAAA  AAAAAAAA  AAAAAAAA  AAAAAAAA  AAAAAAAA  AAAAAAAA  AAAAAAAA
## Header mask: 8 bits
## Header result: 113 (01110001)
##	IMEI
## Length: 	112 bits
## Format:	Imei in asci
##
sub _decode_imei()  {
	my ($self, $measurement, $data) = @_;
	
	my $value = "";
	
	## convert imei number byte per byte
	my @bytes = split(//, $data);
	shift(@bytes); shift(@bytes); ## skip header byte
	
	while (@bytes)  {
		$value = $value . ($self->_hex2ascii( shift(@bytes) . shift(@bytes) ));
	}
	
	DEBUG("decoded value $measurement (hex $data) = $value");
	return { 'number' => $value };
}


##
## decode battery voltage
## Length: 3 bytes
## Structure: 10001001  AAAAAAAA  AAAAAAAA 
## Header mask: 8 bits
## Header result: 137 (10001001)
## 	Battery voltage
## Length: 	16 bits
## Format:	Voltage * 933 / 4
##
sub _decode_battery_voltage()  {
	my ($self, $measurement, $data) = @_;
	
	my $value = $self->_hex2dec($data);
	$value = sprintf("%.04f", ($value * 4) / 933);
	
	DEBUG("decoded value $measurement (hex $data) = $value");
	return { 'voltage' => $value };
}


##
## decode power supply voltage
## Length: 3 bytes
## Structure: 10001000  AAAAAAAA  AAAAAAAA 
## Header mask: 8 bits
## Header result: 136 (10001000)
##	Pwr supply voltage
## Length: 	16 bits
## Format:	voltage * 345 / 12
##
sub _decode_powersupply_voltage() {
	my ($self, $measurement, $data) = @_;
	
	my $value = $self->_hex2dec($data);
	$value = sprintf("%.04f", ($value * 12) / 345);
	
	DEBUG("decoded value $measurement (hex $data) = $value");
	return { 'voltage' => $value };
}


##
## decode distance parameter
## Length: 5 bytes
## Structure: 01001100  AAAAAAAA  AAAAAAAA  AAAAAAAA  AAAAAAAA
## Header mask: 8 bits
## Header result: 76 (01001100)
##	Distance
## Length: 	32 bits
## Format:	Distance in meter
##
sub _decode_distance()  {
	my ($self, $measurement, $data) = @_;
	
	my $value = $self->_hex2dec($data);
	
	DEBUG("decoded value $measurement (hex $data) = $value");
	return { 'distance' => $value };
}


##
## decode the position error
## Length: 2 bytes
## Structure: 01001101  AAAAAAAA
## Header mask: 8 bits
## Header result: 77 (01001101)
##
sub _decode_position_error()  {
	my ($self, $measurement, $data) = @_;
	
	my $value = $self->_hex2dec($data);
	
	DEBUG("decoded value $measurement (hex $data) = $value");
	return { 'error' => $value };
}


##
## decode the quality of the gsm signal
## Length: 2 bytes
## Structure: 01110000  AAAAAAAA
## Header mask: 8 bits
## Header result: 112 (01110000)
##	Quality GSM signal
## Length: 	8 bits
## Format:	Quality GSM signal
##
sub _decode_quality_gsm_signal()  {
	my ($self, $measurement, $data) = @_;
	
	my $value = $self->_hex2dec($data);
	
	DEBUG("decoded value $measurement (hex $data) = $value");
	return { 'signal' => $value };
}


##
## decode the datatype (=postion, start, stop, address request)
## Length: 2 bytes
## Structure: 10000000  AAAAAAAA
## Header mask: 8 bits
## Header result: 128 (10000000)
##	Datatype
## Length: 	8 bits
## Format:	0: position
##		1: start
##		2:stop
##		3:address request
##
sub _decode_datatype()  {
	my ($self, $measurement, $data) = @_;
	
	my $value = $self->_hex2dec($data);
	
	if    ($value == 0)  { $value = "position";   }
	elsif ($value == 1)  { $value = "start";   }
	elsif ($value == 2)  { $value = "stop";   }
	elsif ($value == 1)  { $value = "address request";   }
	else {
		$value = "UNKNOWN";
		ERROR("datatype has an unknown value : $value");
	}
	
	DEBUG("decoded value $measurement (hex $data) = $value");
	return { 'type' => $value };
}



##
## decode status inputs_1 values
## Length: 2 bytes
## Structure: 10010000 ABCDEEEE
## Header mask: 8 bits
## Header result: 144 (10010000)
## 	Input1
## Length: 	1 bit
## Format:	0: Off
## 		1: On
## 	Input2
## Length: 	1 bit
## Format:	0: Off
## 		1: On
## 	Input3
## Length: 	1 bit
## Format:	0: Off
## 		1: On
## 	Input4
## Length: 	1 bit
## Format:	0: Off
## 		1: On
## 	Reserved
## Length: 	4 bits
## Format:	0000
##
sub _decode_status_inputs_1()  {
	my ($self, $measurement, $data) = @_;
	
	my $bits = $self->_hex2bits($data);
	
	my $input1 = $self->_bin2dec(substr($bits, 0, 1));
	my $input2 = $self->_bin2dec(substr($bits, 1, 1));
	my $input3 = $self->_bin2dec(substr($bits, 2, 1));
	my $input4 = $self->_bin2dec(substr($bits, 3, 1));
	
	DEBUG("decoded value $measurement (hex $data) : input1 = $input1, input2 = $input2, input3 = $input3, input4 = $input4");
	return { 'input1' => $input1, 'input2' => $input2, 'input3' => $input3, 'input4' => $input4 };
}



##
## decode status inputs values
## Length: 2 bytes
## Structure: 10010011 ABBBBBBB
## Header mask: 8 bits
## Header result: 147 (10010011)
##	Vibrations
## Length: 	1 bit
## Format:	0: No vibrations
##		1: Vibrations
##	Reserved
## Length: 	7 bits
## Format:	0000000
##
sub _decode_status_inputs()  {
	my ($self, $measurement, $data) = @_;
	
	my $bits = $self->_hex2bits($data);
	
	my $value = $self->_bin2dec(substr($bits, 0, 1));
	
	DEBUG("decoded value $measurement (hex $data) : vibrations = $value");
	return { 'vibrations' => $value };
}



##
## decode status outputs values
## Length: 2 bytes
## Structure: 11000 ABCCCCCC
## Header mask: 8 bits
## Header result: 152 (10011000)
## 	Output1
## Length: 	1 bit
## Format:	0: Off
## 		1: On
## 	Output2
## Length: 	1 bit
## Format:	0: Off
## 		1: On
## 	Reserved
## Length: 	6 bits
## Format:	000000
##
sub _decode_status_outputs()  {
	my ($self, $measurement, $data) = @_;
	
	my $bits = $self->_hex2bits($data);
	
	my $output1 = $self->_bin2dec(substr($bits, 0, 1));
	my $output2 = $self->_bin2dec(substr($bits, 1, 1));
	
	DEBUG("decoded value $measurement (hex $data) : output1 = $output1, output2 = $output2");
	return { 'output1' => $output1, 'output2' => $output2 };
}


##
## decode status alarms values
## Length: 2 bytes
## Structure: 10100000 ABCDEFGH
## Header mask: 8 bits
## Header result: 160 (10100000)
## 	Trilsensor alarm
## Length: 	1 bit
## Format:	0: No alarm
## 		1: Alarm
## 	Reserved
## Length: 	1 bit
## Format:	0: No alarm
## 		1: Alarm
## 	Reserved
## Length: 	1 bit
## Format:	0: No alarm
## 		1: Alarm
## 	Reserved
## Length: 	1 bit
## Format:	0: No alarm
## 		1: Alarm
## 	Reserved
## Length: 	1 bit
## Format:	0: No alarm
## 		1: Alarm
## 	Reserved
## Length: 	1 bit
## Format:	0: No alarm
## 		1: Alarm
## 	Reserved
## Length: 	1 bit
## Format:	0: No alarm
## 		1: Alarm
## 	Reserved
## Length: 	1 bit
## Format:	0: No alarm
## 		1: Alarm
##
sub _decode_status_alarms()  {
	my ($self, $measurement, $data) = @_;
	
	my $bits = $self->_hex2bits($data);
	
	my $trilsensor = $self->_bin2dec(substr($bits, 0, 1));
	
	DEBUG("decoded value $measurement (hex $data) : trilsensor = $trilsensor");
	return { 'trilsensor' => $trilsensor };
}


##
## decode status alarms values
## Length: 3 bytes
## Structure: 10101100 AABBCCDD EEFFGGHH
## Header mask: 8 bits
## Header result: 172 (10101100)
## 	Geofence1
## Length: 	2 bit
## Format:	00: fence off
## 		01: inside fence
## 		10: outside fence
## 	Geofence2
## Length: 	2 bit
## Format:	00: fence off
## 		01: inside fence
## 		10: outside fence
## 	Geofence3
## Length: 	2 bit
## Format:	00: fence off
## 		01: inside fence
## 		10: outside fence
## 	Geofence4
## Length: 	2 bit
## Format:	00: fence off
## 		01: inside fence
## 		10: outside fence
## 	Geofence5
## Length: 	2 bit
## Format:	00: fence off
## 		01: inside fence
## 		10: outside fence
## 	Geofence6
## Length: 	2 bit
## Format:	00: fence off
## 		01: inside fence
## 		10: outside fence
## 	Geofence7
## Length: 	2 bit
## Format:	00: fence off
## 		01: inside fence
## 		10: outside fence
## 	Geofence8
## Length: 	2 bit
## Format:	00: fence off
## 		01: inside fence
## 		10: outside fence
##
sub _decode_status_geofence()  {
	my ($self, $measurement, $data) = @_;
	
	my $bits = $self->_hex2bits($data);
	
	my $fence1 = $self->_bin2dec(substr($bits, 0, 2));
	my $fence2 = $self->_bin2dec(substr($bits, 2, 2));
	my $fence3 = $self->_bin2dec(substr($bits, 4, 2));
	my $fence4 = $self->_bin2dec(substr($bits, 6, 2));
	my $fence5 = $self->_bin2dec(substr($bits, 8, 2));
	my $fence6 = $self->_bin2dec(substr($bits, 10, 2));
	my $fence7 = $self->_bin2dec(substr($bits, 12, 2));
	my $fence8 = $self->_bin2dec(substr($bits, 14, 2));
	
	foreach ($fence1, $fence2, $fence3, $fence4, $fence5, $fence6, $fence7, $fence8)  {
		if    ($_ == 0)  { $_ = "off";  }
		elsif ($_ == 1)  { $_ = "in"; }
		elsif ($_ == 2)  { $_ = "out"; }
		else {
			$$_ = "UNKNOWN";
			ERROR("datatype has an unknown value : $_");
		}
	}
	
	DEBUG("decoded value $measurement (hex $data) : fence1 = $fence1, fence2 = $fence2, fence3 = $fence3, fence4 = $fence4, fence5 = $fence5, fence6 = $fence6, fence7 = $fence7, fence8 = $fence8");
	return {  'fence1' => $fence1, 'fence2' => $fence2, 'fence3' => $fence3, 'fence4' => $fence4, 'fence5' => $fence5, 'fence6' => $fence6, 'fence7' => $fence7, 'fence8' => $fence8 };
}



## 
## decode the GSM number of the last received SMS
## Length: variable 
## Structure: 01110010  AAAAAAAA BBBBBBBB BBBBBBBB BBBBBBBB É
## Header mask: 8 bits
## Header result: 114 (01110010)
## 	Lenght
## Length: 	8 bits
## Format:	Number of bytes of the following data
## 	GSM number
## Length: 	variable
## Format:	GSM number of the last received SMS
##
sub _decode_gsm_number_last_rcvd_sms()  {
	my ($self, $measurement, $data) = @_;
	
	## shift the first byte, it contains the length of the packet
	my @bytes = split(//, $data);
	shift(@bytes); shift(@bytes);
	$data = join("", @bytes);

## TODO: this may be byte per byte,  need to check when live packets are arriving
	my $value = $self->_hex2dec($data);
	
	DEBUG("decoded value $measurement (hex $data) = $value");
	return { 'number' => $value };
}

##
## decode the call value parameter
## Length: variable 
## Structure: 01110101  AAAAAAAA BBBBBBBB BBBBBBBB BBBBBBBB É
## Header mask: 8 bits
## Header result: 117 (01110101)
## 	Lenght
## Length: 	8 bits
## Format:	Number of bytes of the following data
## 	Call value
## Length: 	variable
## Format:	Call value. Example Ò:18.20:17/06/2008Ó
##
sub _decode_call_value()  {
	my ($self, $measurement, $data) = @_;
	
	## shift the first byte, it contains the length of the packet
	my @bytes = split(//, $data);
	shift(@bytes); shift(@bytes);
	$data = join("", @bytes);

## TODO: this may be byte per byte,  need to check when live packets are arriving
	my $value = $self->_hex2dec($data);
	
	DEBUG("decoded value $measurement (hex $data) = $value");
	return { 'value' => $value };
}

1;

__END__
# Below is stub documentation for your module. You'd better edit it!

=head1 NAME

TrackerProtocol::GP200 - Module to decode/encode messages received from a GP200 GPS tracking device

=head1 SYNOPSIS

  use TrackerProtocol::GP200;
  my $p = new TrackerProtocol::GP200();
  my $packet = '<19CC4ECB08D729088D053F400048034900244A004C000B8D3D700E7130313130313530303031313437358801A689039990009800>';
  my $rc = $p->decode($packet);
  
=head1 DESCRIPTION

This module decodes packets received from a GPS200 Tracking device. Packets are usually sent via GPRS.

=head2 PROCEDURES

=head3 new(debug => 0)

Creates a new TrackerProtocol::GP200 object.

Parameters :

	debug => value

	Where value is a number between 0 and 9.  
	
=head3 decode(packet)

Parameters :

	packet
	
	Where packet is a valid packet received from a GP200 tracker

=head1 SEE ALSO

www.lecatecs.com for information about the GP200 tracker

=head1 AUTHOR

Maarten Wallraf, E<lt>mwallraf@2nms.comE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2008 by Maarten Wallraf

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.8 or,
at your option, any later version of Perl 5 you may have available.


=cut
