#!/usr/bin/perl

use strict;
use warnings;
use Device::SerialPort;
use Fcntl;
use Carp;
use POSIX;
use Data::Dumper;
use Time::Local;

$|=1;

#my $dev = "/dev/tty.usbserial";
#my $dev = "/dev/tty.KeySerial1";
my $dev = "/dev/tty.SocketCSA4156F7-SocketS";

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

select_e1_and_e2($port);
init_custom_chars($port);
enable_backlight($port);

do_sendcommand($port, 0x01); # clear
do_sendcommand($port, 0x0C); # disable cursor

my %numbers = ( 1 => ['  /',
		      ' /*', 
		      '  *',
		      '  *'],
		2 => ['/*+',
		      '% *',
		      ' /%',
		      '/**'],
		3 => ['/*+',
		      ' _%',
		      ' =+',
		      '$*%'],
		4 => [' /*',
		      '/%*',
		      '***',
		      '  *'],
		5 => ['***',
		      '*+ ',
		      ' $+',
		      '$*%'],
		6 => ['/*+',
		      '*  ',
		      '*$+',
		      '$*%'],
		7 => ['**+',
		      ' /%',
		      '=*=',
		      ' * '],
		8 => ['/*+',
		      '$_%',
		      '/=+',
		      '$*%'],
		9 => ['/*+',
		      '$+*',
		      '  *',
		      '$*%'],
		0 => ['/*+',
		      '* *',
		      '* *',
		      '$*%'],
		':' => [' ',
			'.',
			'.',
			' '],
		' ' => [' ',
			' ',
			' ',
			' '],
    );

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

print_time($port, "1234");

while (1) {
    my $now = POSIX::strftime("%H%M", localtime);
    print_time($port, $now);
    print_days_till_xmas($port);
    print_blip($port);
    sleep(1);
}

sleep(1);
$port->close();
undef $port;

exit 0;

my $blip = 0;
sub print_blip {
    my ($port) = @_;

    do_goto($port, 39, 0);
    $blip = $blip ^ 0x01;
    if ($blip) {
	do_sendtext($port, "+");
    } else {
	do_sendtext($port, " ");
    }
    
}

sub print_days_till_xmas {
    my ($port) = @_;
    my @time = localtime;
    $time[4]++;
    my $christmas = timelocal(0,0,0,25,11,$time[5]);
    $time[5]+=1900;
    my $timeleft = $christmas - time();
    my $minsleft = int($timeleft / 60);
    my $hoursleft = int($minsleft / 60);
    my $daysleft = int($hoursleft / 24) + 1;

    do_goto($port, 24, 2);
    do_sendtext($port, "$daysleft day");
    do_sendtext($port, "s") if ($daysleft != 0);
    do_sendtext($port, " until");
    do_goto($port, 26, 3);
    do_sendtext($port, "Christmas ".$time[5]);
}

sub print_time {
    my ($port, $time) = @_;

    my $pos = 0;
    foreach my $digit(split(//, $time)) {
	foreach my $i (0..3) {
	    print_line($port, $pos * 4, $i, $numbers{$digit}->[$i]);
	}
	$pos++;
    }
    # Print the colon...
    foreach my $i (0..3) {
	print_line($port, 7, $i, $numbers{':'}->[$i]);
    }
}

sub do_goto {
    my ($port, $x, $y) = @_;

#    print "do_goto $x, $y\n";
    if ($y >= 2) {
#	print " selecting e2\n";
	select_e2($port);
    } else {
#	print " selecting e1\n";
	select_e1($port);
    }

#    print "Repositioning at ", $x + ($y%2)*0x40, "\n";
    do_sendcommand($port, 0x80 + $x + ($y%2)*0x40);
}

sub print_line {
    my ($port, $xpos, $linenum, $chars) = @_;

#    print "print_line $xpos, $linenum, $chars\n";
    do_goto($port, $xpos, $linenum);

    do_sendtext($port, join('', map { $map{$_} } split(//, $chars)));
#    foreach my $i (split(//, $chars)) {
#	do_sendtext($port, $map{$i} || $i);
#    }
}

sub select_e1 {
    my ($port) = @_;
    do_sendmeta($port, 0x05); # binary 00000101
}

sub select_e2 {
    my ($port) = @_;
    do_sendmeta($port, 0x06); # binary 00000110
}

sub select_e1_and_e2 {
    my ($port) = @_;
    do_sendmeta($port, 0x07); # binary 00000111
}

sub enable_backlight {
    my ($port) = @_;
    do_sendmeta($port, 0x18); # enable backlight
}

sub disable_backlight {
    my ($port) = @_;
    do_sendmeta($port, 0x10); # disable backlight
}

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

    # Send custom characters to whatever display is currently selected.

    foreach my $charnum (keys %chars) {
	my $counter = 0;
#	print "programming character $charnum\n";
	my @data = @{$chars{$charnum}};
	foreach my $i (@data) {
	    # Select the DDram address to write to
	    do_sendcommand($port, 0x40 + ($charnum << 3) + $counter);
	    do_sendtext($port, chr($i));

	    $counter++;
	}
    }
#    print "done programming chars\n";
    # Move back to DD ram, pos 0...
    do_sendcommand($port, 0x80);
    do_sendcommand($port, 0x80);
}


sub do_sendmeta {
    my ($p, $metacmd) = @_;

#    printf("sending meta-command 0x%X\n", $metacmd);
    die "Failed to send meta-command"
	unless ($p->write(chr(0x7C) . chr($metacmd)) == 2);
    die
	unless (read_byte($p) eq chr(0x7C) && read_byte($p) eq chr($metacmd));
}

sub do_sendcommand {
    my ($p, $command) = @_;

#    printf("sending command 0x%X\n", $command);

    die "Failed to send command"
	unless ($p->write(chr(254) . chr($command)) == 2);
    die
	unless (read_byte($p) eq chr(254) && read_byte($p) eq chr($command));
}

sub do_sendtext {
    my ($p, $text) = @_;

#    printf("sending text '%s'\n", $text);
    $p->write($text);
    foreach my $i (1..length($text)) {
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


