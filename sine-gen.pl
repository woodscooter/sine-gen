#!/usr/bin/perl -w 
use strict;
use Curses;
use threads;
use threads::shared;

## Sine wave generator
## with continuous tone option
## sox_kill.sh must be in same directory as this
## Now with pump control
## requires pigpio daemon running

my $ch;
my $freq:shared = 2.6;		## basic frequency
my $freq2:shared = 2.85;	## shifted frequency
my $shadow = 1.0594;		## twelfth root of 2
my $duration:shared = 0.5;	## tone duration
my $guard = 0.5;		## required gap between tones
my $gtime:shared = 0.5;		## calculated gap time
my $pumprun:shared = 3;		## pump run time, when on
my $pumpstop :shared= 10;	## pump pause time, when on
my $genstate:shared = "OFF";
my $pumpstate:shared = "OFF";
my $noguard:shared = 0;		## set to 1 for continuous run
my $runstate:shared = 1;
my $audio;
my $gpio;
my $PUMP = 15;	## GPIO15, pin 10.

sub printscreen() 
{
	move(1,26);
	printw("Sine Generator Control Screen");
	move(2,26);
	printw("-----------------------------");
	move(12,4);
	printw("KEYBOARD CONTROL");
	move(13,4);
	printw("P/L - inc/dec frequency");
	move(14,4);
	printw("O/K - inc/dec duration");
	move(15,4);
	printw("I/J - inc/dec guard time");
	move(16,4);
	printw("Y/G - pulsed/continuous");

	move(13,35);
	printw("U/H - inc/dec ratio");
	move(14,35);
	printw(" A  - Reset ratio");
	move(15,35);
	printw("R/D - inc/dec pump run time");
	move(16,35);
	printw("E/S - inc/dec pump pause time");

	move(20,4);
	printw(" 1  - START GENERATOR           2  - STOP GENERATOR");
	move(21,4);
	printw(" T  - PUMP ON                   F  - PUMP OFF");
	move(22,4);
	printw(" Q  - QUIT (UPPER-CASE Q)");
}

sub printvalues()
{
	move(4,10);
	printw("Frequency       %f Hertz", $freq);
	move(5,10);
	printw("Second freq     %f Hertz", $freq2);
	move(7,10);
	if ($noguard)
	{
	    printw("Duration        continuous        ");
	} else {
	    printw("Duration        %f seconds", $duration);
	}
	move(8,10);
	if ($noguard)
	{
	    printw("Guard time                        ");
	} else {
	    printw("Guard time      %f seconds", $guard);
	}
	move(4,50);
	printw("Frequency ratio %f", $shadow);
	move(6,50);
	printw("   Generator is   %s", $genstate);
	move(7,50);
	printw("        Pump is   %s", $pumpstate);
	move(8,50);
	printw("Pump run %d s   pause %d s  ",$pumprun,$pumpstop);
}

sub generator()
{
    while ($runstate)
    {
	if ($genstate eq "ON ") 
	{
	    my $command = "play -n -c1 synth $duration sin ${freq}k sin ${freq2}k lowpass 9k : trim 0 $gtime lowpass 1k 2>/dev/null";
	    if ($noguard)
	    {
		$command = "play -n -c1 synth 0 sin ${freq}k sin ${freq2}k lowpass 9k 2>/dev/null";
	    }
	    system $command;
	}
    }
}

sub done 
{ 
    $runstate = 0; 
    sox_end();
    endwin(); 
    print "@_\n"; 
    $audio->detach(); 
    $gpio->detach();
    exit; }

sub sox_end() 
{
	my $cmd = "./sox_kill.sh";
	system $cmd;
}


sub setpump()
{
my $pumpcmd;
my $pumpcount;
my $sleepcmd = "pigs mils 333";

    $pumpcmd = "pigs modes $PUMP W";	## Set output mode
    system $pumpcmd;

    while ($runstate)
    {
	if ($pumpstate eq 'OFF')
	{
	    $pumpcmd = "pigs w $PUMP 0";
	    system $pumpcmd;
	    system $sleepcmd;
	}
	else 
	{
	    $pumpcmd = "pigs w $PUMP 1";
	    system $pumpcmd;
	    $pumpcount = int ($pumprun *1000/333);
	    while  ($pumpcount)
	    {
		last if (!$runstate) ;
		last if ($pumpstate eq 'OFF') ;
		system $sleepcmd;
		--$pumpcount;
	    }
	    $pumpcmd = "pigs w $PUMP 0";
	    system $pumpcmd;
	    $pumpcount = int ($pumpstop *1000/333);
	    while  ($pumpcount)
	    {
		last if (!$runstate) ;
		last if ($pumpstate eq 'OFF') ;
		system $sleepcmd;
		--$pumpcount;
	    }
	}
	system $sleepcmd;
    }
}


$SIG{INT} = sub { done("Ouch") };

$audio = threads->new('generator');
$gpio = threads->new('setpump');

initscr;
noecho();	# characters not echoed by getch
cbreak();	# characters available when typed (no wait for newline)
nodelay(1);	# getch() is non-blocking
curs_set(0);	# non-visible cursor

while (1)
{

	printscreen();
	printvalues();

	standout();
	addstr($LINES-1, $COLS - 24, scalar localtime);
	standend();

	move(22,0);
	refresh();

	$ch = getch();

	SWITCH:
	{
	if ($ch eq 'Q') { done ("Bye"); last SWITCH; }
#	if ($ch eq 'e') { done ("Bye"); last SWITCH; }
	if ($ch eq 'p') { $freq += 0.001; last SWITCH; }
	if ($ch eq 'P') { $freq += 0.1; last SWITCH; }
	if ($ch eq 'l') { $freq -= 0.001; last SWITCH; }
	if ($ch eq 'L') { $freq -= 0.1; last SWITCH; }
	if ($ch eq 'o') { $duration += 0.001; last SWITCH; }
	if ($ch eq 'O') { $duration += 0.1; last SWITCH; }
	if ($ch eq 'k') { $duration -= 0.001; last SWITCH; }
	if ($ch eq 'K') { $duration -= 0.1; last SWITCH; }
	if ($ch eq 'i') { $guard += 0.001; last SWITCH; }
	if ($ch eq 'I') { $guard += 0.1; last SWITCH; }
	if ($ch eq 'j') { $guard -= 0.001; last SWITCH; }
	if ($ch eq 'J') { $guard -= 0.1; last SWITCH; }
	if ($ch eq 'u') { $shadow += 0.001; last SWITCH; }
	if ($ch eq 'U') { $shadow += 0.1; last SWITCH; }
	if ($ch eq 'h') { $shadow -= 0.001; last SWITCH; }
	if ($ch eq 'H') { $shadow -= 0.1; last SWITCH; }
	if ($ch eq 'a') { $shadow = 1.0594; last SWITCH; }
	if ($ch eq 'A') { $shadow = 1.0594; last SWITCH; }
	if ($ch eq 'R') { ++$pumprun; last SWITCH; }
	if ($ch eq 'r') { ++$pumprun; last SWITCH; }
	if ($ch eq 'D') { --$pumprun; last SWITCH; }
	if ($ch eq 'd') { --$pumprun; last SWITCH; }
	if ($ch eq 'E') { ++$pumpstop; last SWITCH; }
	if ($ch eq 'e') { ++$pumpstop; last SWITCH; }
	if ($ch eq 'S') { --$pumpstop; last SWITCH; }
	if ($ch eq 's') { --$pumpstop; last SWITCH; }
	if ($ch eq 'y') { $noguard = 0; sox_end(); last SWITCH; }
	if ($ch eq 'Y') { $noguard = 0; sox_end(); last SWITCH; }
	if ($ch eq 'g') { $noguard = 1; last SWITCH; }
	if ($ch eq 'G') { $noguard = 1; last SWITCH; }
	if ($ch eq '1') { $genstate = "ON "; last SWITCH; }
	if ($ch eq '2') { $genstate = "OFF"; if ($noguard) { sox_end(); } last SWITCH; }
	if ($ch eq 't') { $pumpstate = "ON "; last SWITCH; }
	if ($ch eq 'T') { $pumpstate = "ON "; last SWITCH; }
	if ($ch eq 'f') { $pumpstate = "OFF"; last SWITCH; }
	if ($ch eq 'F') { $pumpstate = "OFF"; last SWITCH; }
	}

	if ($freq > 10) { $freq = 10; }
	if ($freq < 0.2) { $freq = 0.2; }
	if ($duration > 1.5) { $duration = 1.5; }
	if ($duration < 0.2) { $duration = 0.2; }
	if ($guard > 1.5) { $guard = 1.5; }
	if ($guard < 0.2) { $guard = 0.2; }
	if ($shadow > 2.5) { $shadow = 2.5; }
	if ($shadow < 0.001) { $shadow = 0.001; }
	if ($pumprun > 20) { $pumprun = 20; }
	if ($pumprun < 1) { $pumprun = 1; }
	if ($pumpstop > 20) { $pumpstop = 20; }
	if ($pumpstop < 1) { $pumpstop = 1; }

	$freq2 = $freq * $shadow;
	$gtime = $guard - 0.18;

	my ($in, $out) = ('','');
	vec($in,fileno(STDIN),1) = 1;
	select ($out= $in,undef,undef,1);

}


