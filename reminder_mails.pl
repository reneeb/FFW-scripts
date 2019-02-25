#!/usr/bin/perl

use strict;
use warnings;

use Email::Sender::Transport::SMTP;
use Email::Stuffer;
use File::Spec;
use File::Basename;
use Mojo::Template;
use Net::Netrc;

use feature 'say';

my $machine = Net::Netrc->lookup( 'ffw.mail' );
my $login   = $machine->login;
my $passwd  = $machine->password;

my %vars;
my $template = File::Spec->catfile( dirname(__FILE__), 'mongers.ep' );
my $text     = Mojo::Template->new( vars => 1 )->render_file( $template, \%vars );

my $file = '.txt';
if ( open my $fh, '<', $file ) {
    while ( my $line = <$fh> ) {
        chomp $line;
        next if !$line;
        next if grep{ $line eq $_ }@not;
        next if @only and !grep{ $line eq $_ }@only;

        say "Send mail to $line...";
        Email::Stuffer->from     ( 'pm.list@perl-services.de' )
                      ->to       ( $line )
                      ->subject  ( $subject . "" )
                      ->text_body( $text )
                      ->transport( Email::Sender::Transport::SMTP->new( {
                          host          => 'mail.perl-services.de',
                          sasl_username => 'reb@perl-services.de',
                          sasl_password => $password . '',
                      }) )
                      ->send;

        sleep 2;
    }
}

