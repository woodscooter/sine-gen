#!/usr/bin/perl -w
use strict;
use Curses;
use threads;
use threads::shared;

## Sine wave generator

my $ch;
my $EXIT = 'E';
my $freq:shared = 2.6;		## basic frequency
my $freq2:shared = 2.85;	## shifted frequency
my $shadow = 1.0594;	## twelfth root of 2
my $duration:shared = 0.5;	## tone duration
my $guard:shared = 0.5;	## gap between tones
my $genstate:shared = "OFF";
my $pumpstate:shared = "OFF";
my $runstate:shared = 1;
my $audio;

sub printscreen() 
{
	move(1,26);
	printw("Sine Generator Control Screen");
	move(2,26);
	printw("-----------------------------");
	move(12,0);
	printw("KEYBOARD CONTROL");
	move(13,4);
	printw("P/L - inc/dec frequency");
	move(14,4);
	printw("O/K - inc/dec duration");
	move(15,4);
	printw("I/J - inc/dec guard time");
	move(16,4);
	printw("U/H - inc/dec ratio");
	move(17,4);
	printw(" R  - Reset ratio");
	move(20,4);
	printw(" 1  - START GENERATOR       2  - STOP GENERATOR");
	move(21,4);
	printw(" T  - PUMP ON               F  - PUMP OFF");
	move(22,4);
	printw(" E  - EXIT (UPPER-CASE E)");
}

sub printvalues()
{
	move(4,10);
	printw("Frequency       %f Hertz", $freq);
	move(5,10);
	printw("Second freq     %f Hertz", $freq2);
	move(6,10);
	printw("Duration        %f seconds", $duration);
	move(7,10);
	printw("Guard time      %f seconds", $guard);
	move(5,50);
	printw("Frequency ratio %f", $shadow);
	move(6,50);
	printw("   Generator is   %s", $genstate);
	move(7,50);
	printw("        Pump is   %s", $pumpstate);

}

sub generator()
{
    while ($runstate)
    {
	if ($genstate eq "ON ") 
	{
	    my $command = "play -n synth $duration sin ${freq}k sin ${freq2}k trim 0 $guard";
	    system $command;
	}
    }

}

sub done { $runstate = 0; endwin(); print "@_\n"; $audio->detach(); exit; }

$SIG{INT} = sub { done("Ouch") };

$audio = threads->new('generator');

initscr;
noecho();
cbreak();
nodelay(1);
curs_set(0);

while (1)
{

	printscreen();
	printvalues();

	standout();
	addstr($LINES-1, $COLS - 24, scalar localtime);
	standend();

	move(0,0);
	refresh();

	$ch = getch();

	SWITCH:
	{
	if ($ch eq 'E') { done ("Bye"); last SWITCH; }
	if ($ch eq 'e') { done ("Bye"); last SWITCH; }
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
	if ($ch eq 'r') { $shadow = 1.0594; last SWITCH; }
	if ($ch eq '1') { $genstate = "ON "; last SWITCH; }
	if ($ch eq '2') { $genstate = "OFF"; last SWITCH; }
	if ($ch eq 't') { $pumpstate = "ON "; last SWITCH; }
	if ($ch eq 'f') { $pumpstate = "OFF"; last SWITCH; }
	}

	$freq2 = $freq * $shadow;

	my ($in, $out) = ('','');
	vec($in,fileno(STDIN),1) = 1;
	select ($out= $in,undef,undef,1);

}


