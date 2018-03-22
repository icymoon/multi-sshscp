#!/usr/bin/perl
#ID:icymoon
#Date:2011-10-28
use strict;
use warnings;
use Getopt::Std;

###############
# Const Values
###############
## true and false, success and fail
use constant true => 1;
use constant TRUE => 1;
use constant false => 0;
use constant FALSE =>0;

my $uls = "\e[4m";
my $ule = "\e[0m";
my $reds = "\e[31;1m";
my $greens = "\e[32;1m";
my $colore = "\e[0m";

####################
# System Commands
####################
my $SSH_CMD="/usr/bin/ssh -o ConnectTimeout=3 ";
my $SCP_CMD="/usr/bin/scp -o ConnectTimeout=3 -r";
my $CD_CMD="cd ";

####################
# Global Vars
####################
my %options;
my @hosts;
my $script;
my $command;
my $remote_dir;
my $user;
my $sshcmdhead;
my $sshcmdtail;
my $scpcmdhead;
my $scpcmdtail;
my $sshcmdgen=false;
my $scpcmdgen=false;

my %opt_err_num_msg =
(
    '99'=>"Machine list file needed",
    '98'=>"Invalied format of Machine list file",
    '97'=>"Can't open machine list file",
    '96'=>"No valid host to run command or script",
    '95'=>"Invalid host",
    '89'=>"Command or Script needed",
    '88'=>"Invalied Script"
);

##################
# Basic functions
##################
# print usage info and quit
# $_[0] program name
sub usage($)
{
    print("Usage: $0 [-m ${uls}machine list file$ule]\n");
    print("        [-c ${uls}\"command\"$ule]\n");
    print("        [-s ${uls}script$ule]\n");
    print("        [-r ${uls}remote directory$ule]\n");
    print("        [-u ${uls}\"user\"$ule]\n");
    print("        [-h]\n");
    print("        If command is set, script option will be ignored.\n");
    exit(0);
}

# print error message and exit with exit code
# $_[0] error message
# $_[1] exit code
sub err_exit($$)
{
    print "$_[0]\n";
    exit $_[1];
}

sub init_hosts($) {
    my $hosts_file = $_[0];
    my @tmp;
    if(-f $hosts_file) {
        if(open(FD,"<$hosts_file")) {
            my $line;
            while($line=<FD>) {
                chomp($line);
                if($line =~ /^\s*#/) {
                    next;
                }
                @tmp = split("#", $line);
                if($#tmp >= 0 ) {
                    if($tmp[0] =~ /[\.a-z0-9A-Z\_\-]+/) {
                        push(@hosts, $tmp[0]);
                    } else {
                        err_exit("$opt_err_num_msg{'95'}: @tmp" , 95);
                    }
                }
                @tmp = ();
            }
        } else {
            err_exit("$opt_err_num_msg{'97'}" , 97);
        }
    } else {
        err_exit("$opt_err_num_msg{'98'}" , 98);
    }
    if($#hosts < 0) {
        err_exit("$opt_err_num_msg{'96'}" , 96);
    }
}

sub check_opts() {
    my $run = false;
    if($#ARGV < 0 or $ARGV[0] !~ /^\-/ or $ARGV[0] =~ /^\-\-/) {
        usage($0);
    }
    getopts("m:c:s:r:u:h",\%options);
    if(defined($options{h})) {
        usage($0);
    }
    if(defined($options{m}) and -f $options{m}) {
        init_hosts($options{m});
    } else {
        err_exit("$opt_err_num_msg{'99'}" , 99);
    }
    if(defined($options{c})) {
        $command = $options{c};
        $run = true;
    }
    if(defined($options{s})) {
        $script=$options{s};
        if(! -f $script) {
            err_exit("$opt_err_num_msg{'88'}" , 88);
        }
        $run = true;
    }
    if(defined($options{r})) {
        $remote_dir=$options{r};
    }

    if(defined($options{u})) {
        $user=$options{u};
    }
    if(!$run) {
        err_exit("$opt_err_num_msg{'89'}" , 89);
    }
}

sub gen_sshcommand() {
    if($sshcmdgen) {
        return;
    }
    if(defined($user)) {
	    $sshcmdhead="$SSH_CMD -l $user ";
    } else {
	    $sshcmdhead="$SSH_CMD ";
    }
    if(defined($remote_dir)) {
        if(defined($script) and !defined($command)) {
            $sshcmdtail=" \"$CD_CMD $remote_dir; chmod +x ./$command; $command\"";
        } else {
            $sshcmdtail=" \"$CD_CMD $remote_dir; $command\"";
        }
    } else {
        if(defined($script) and !defined($command)) {
            $sshcmdtail=" \"chmod +x ./$command; $command\"";
        } else {
            $sshcmdtail=" \"$command\"";
        }
    }
    $sshcmdgen = true;
}

sub gen_scpcommand() {
    if($scpcmdgen) {
        return;
    }
    if(defined($user)) {
	    $scpcmdhead="$SCP_CMD $script $user@";
    } else {
	    $scpcmdhead="$SCP_CMD $script ";
    }
    if(defined($remote_dir)) {
	    $scpcmdtail=":\"$remote_dir\"";
    } else {
	    $scpcmdtail=":\"~\/\"";
    }
    $scpcmdgen = true;
}

sub run_command($) {
        gen_sshcommand();
	my $h = $_[0];
	my $runcmd = "$sshcmdhead $h $sshcmdtail";
	my $ret;
        print("$runcmd\n");
	$ret = `$runcmd`;
        my $rv = $?>>8;
        if($rv ne 0) {
            print("${reds}$h:Fail[ret=$rv]$colore\n");
        } else {
            print("${greens}$h:Success$colore\n");
        }
        print $ret;
}

sub run_script($) {
	my $ret;
        my @tmp = split("/", $script);
        if($#tmp >= 0) {
            $command="./$tmp[$#tmp]";
        } else {
            $command="./$script";
        }
        gen_scpcommand();
	my $h = $_[0];
	my $scpcmd = "${scpcmdhead}${h}$scpcmdtail";
        print("$scpcmd\n");
        $ret = `$scpcmd`;
        my $rv = $?>>8;
        if($rv ne 0) {
            print("${reds}$h:Distribute script fail[ret=$rv]$colore\n");
            return;
        }

        gen_sshcommand();
	my $runcmd = "$sshcmdhead $h $sshcmdtail";
        print("$runcmd\n");
	$ret = `$runcmd`;
        $rv = $?>>8;
        if($rv ne 0) {
            print("${reds}$h:Fail[ret=$rv]$colore\n");
        } else {
            print("${greens}$h:Success$colore\n");
        }
        print $ret;
}

check_opts();
if(defined($command)) {
    foreach my $h (@hosts) {
        run_command($h);
    }
} elsif(defined($script)) {
    foreach my $h (@hosts) {
        run_script($h);
    }
    $command="rm $command";
    $sshcmdgen = false;
    foreach my $h (@hosts) {
        run_command($h);
    }
}
