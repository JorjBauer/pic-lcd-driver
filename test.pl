#!/usr/bin/perl

use strict;
use warnings;
use Device::SerialPort;
use Fcntl;
use Carp;

$|=1;

my $dev = "/dev/tty.usbserial";
#my $dev = "/dev/tty.KeySerial1";

# Set up the serial port
my $quiet = 1;
my $port = Device::SerialPort->new($dev, $quiet, undef)
    || die "Unable to open serial port";
$port->user_msg(1);
$port->error_msg(1);
$port->databits(8);
$port->baudrate(9600);
$port->parity("none");
$port->stopbits(1);
$port->handshake("none");
$port->reset_error();

my $baud = $port->baudrate;
my $parity = $port->parity;
my $data = $port->databits;
my $stop = $port->stopbits;
my $hshake = $port->handshake;
print "$baud ${data}/${parity}/${stop} handshake: $hshake\n";

$port->purge_all();

# Command reference:
#   0x01: clear display, return to home
#   0x02: return to home, unshift display
#   0x04: set cursor move direction decrement, no shift
#   0x05: set cursor move direction decrement, with shift
#   0x06: set cursor move direction increment, no shift
#   0x07: set cursor move direction increment, with shift
#   0x08: display off
#   0x0C: display on, cursor off, blink off
#   0x0D: display on, cursor off, blink on
#   0x0E: display on, cursor on, blink off
#   0x0F: display on, cursor on, blink on
#   0x4x: set CG ram address
#   0x8x: set DD ram address

init_custom_chars($port);

do_sendmeta($port, 0x00); # move to first display
do_sendcommand($port, 0x01); # clear
do_sendcommand($port, 0x0C); # disable cursor
do_sendmeta($port, 0x01); # move to second display
do_sendcommand($port, 0x01); # clear
do_sendcommand($port, 0x0C); # disable cursor

my $line0 = ' / /*+ /*+  /* *** /*+ **+ /*+ /*+ /*+  ';
my $line1 = '/* % *. _% / * *+  *    /% $_% $+* * *  ';
my $line2 = ' *  /%. =+ ***  $+ *$+ =*= /=+   * * *  ';
my $line3 = ' * *** $*%   * $*% $*%  *  $*% $*% $*%  ';

my %map = ( ' ' => ' ',
            '/' => chr(0),
            '+' => chr(1),
	    '$' => chr(2),
	    '%' => chr(3),
	    '_' => chr(4),
	    '=' => chr(5),
	    '.' => chr(6),
	    '*' => chr(255) 
    );

# First display
# line 1
print "sending $line0\n";
do_sendmeta($port, 0x00);
do_sendcommand($port, 0x80 + 0);
foreach my $i (split(//, $line0)) {
    print "sending $i\n";
    do_sendtext($port, $map{$i} || $i);
}
# line 2
do_sendcommand($port, 0x80 + 40);
foreach my $i (split(//, $line1)) {
    do_sendtext($port, $map{$i} || $i);
}

# Second display
# line 3
do_sendmeta($port, 0x01);
do_sendcommand($port, 0x80 + 0);
foreach my $i (split(//, $line2)) {
    do_sendtext($port, $map{$i} || $i);
}
do_sendcommand($port, 0x80 + 40);
foreach my $i (split(//, $line3)) {
    do_sendtext($port, $map{$i} || $i);
}


sleep(1);
$port->close();
undef $port;

exit 0;

sub init_custom_chars {
    my ($port) = @_;

    my %chars = ( 0 => [ 0x01, 0x03, 0x03, 0x07, 0x07, 0x0F, 0x0F, 0x1F ],
		  1 => [ 0x10, 0x10, 0x18, 0x1C, 0x1C, 0x1E, 0x1E, 0x1F ],
		  2 => [ 0x1F, 0x0F, 0x0F, 0x07, 0x07, 0x03, 0x03, 0x01 ],
		  3 => [ 0x1F, 0x1E, 0x1E, 0x1C, 0x1C, 0x18, 0x18, 0x10 ],
		  4 => [ 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x1F, 0x1F ],
		  5 => [ 0x1F, 0x1F, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00 ],
		  6 => [ 0x00, 0x00, 0x0E, 0x0E, 0x0E, 0x00, 0x00, 0x00 ],
	);

    # Send custom characters to both display chips.

    foreach my $charnum (keys %chars) {
	my $counter = 0;
	print "programming character $charnum\n";
	my @data = @{$chars{$charnum}};
	foreach my $i (@data) {
	    do_sendmeta($port, 0x00); # move to first display
	    # Select the DDram address to write to
	    do_sendcommand($port, 0x40 + ($charnum << 3) + $counter);
	    do_sendtext($port, chr($i));

	    do_sendmeta($port, 0x01); # move to second display
	    do_sendcommand($port, 0x40 + ($charnum << 3) + $counter);
	    do_sendtext($port, chr($i));

	    $counter++;
	}
    }
    print "done programming chars\n";
    # Move back to DD ram, pos 0...
    do_sendmeta($port, 0x00);
    do_sendcommand($port, 0x80);
    do_sendmeta($port, 0x01);
    do_sendcommand($port, 0x80);
}


sub do_sendmeta {
    my ($p, $metacmd) = @_;

    printf("sending meta-command 0x%X\n", $metacmd);
    die "Failed to send meta-command"
	unless ($p->write(chr(0x7C) . chr($metacmd)) == 2);
    die
	unless (read_byte($p) eq chr(0x7C) && read_byte($p) eq chr($metacmd));
}

sub do_sendcommand {
    my ($p, $command) = @_;

    printf("sending command 0x%X\n", $command);

    die "Failed to send command"
	unless ($p->write(chr(254) . chr($command)) == 2);
    die
	unless (read_byte($p) eq chr(254) && read_byte($p) eq chr($command));
}

sub do_sendtext {
    my ($p, $text) = @_;

    printf("sending text '$text'\n");
    foreach my $i (1..length($text)) {
	die "failed to send"
	    unless ($p->write(substr($text, $i-1, 1)) == 1);
	die "failed to read"
	    unless (read_byte($p) eq substr($text, $i-1, 1));
    }
}

sub read_byte {
    my ($p) = @_;

    my $counter = 500000;
   
    my ($count, $data);
    do { 
	croak "Failed to read"
	    if ($counter == 0);
	$counter--;
	($count, $data) = $p->read(1);
    } while ($count == 0);

    return $data;
}


