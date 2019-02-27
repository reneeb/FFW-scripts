#!/usr/bin/perl

use strict;
use warnings;

use utf8;

use Email::Sender::Transport::SMTP;
use Email::Stuffer;
use File::Spec;
use File::Basename;
use Mojo::Template;
use Net::Netrc;
use Text::CSV_XS;
use Time::Piece;

use constant LEVEL_1      => 5;
use constant INPUT_FILE   => File::Spec->catfile( dirname(__FILE__), 'Dienstplan.csv');
use constant ADDRESS_FILE => File::Spec->catfile( dirname(__FILE__), 'addresses.txt');
use constant TEMPLATE     => File::Spec->catfile( dirname(__FILE__), 'drill_mail.ep' );

my %groups         = _get_groups();
my ($group, $text) = _get_group_and_mail_text();

exit if !$text;

my $to = join ', ', @{ $groups{$group} || [] };
exit if !$to;

_send_mail( $to, $text );

exit;

# -----



sub _send_mail {
    my ($to, $text) = @_;

    my ($subject, $mailtext) = split /\n\n/, $text, 2;

    my $machine = Net::Netrc->lookup( 'ffw.mail' );
    my $login   = $machine->login;
    my $passwd  = $machine->password;
    my $host    = $machine->account;

    Email::Stuffer->from     ( $login )
                  ->to       ( $to )
                  ->subject  ( $subject )
                  ->text_body( $mailtext )
                  ->transport( Email::Sender::Transport::SMTP->new( {
                      host          => $host,
                      sasl_username => $login,
                      sasl_password => $passwd,
                  }) )
                  ->send;
}


sub _get_drill {
    open my $fh, '<:encoding(utf-8)', INPUT_FILE;
    return if !$fh;

    my $csv = Text::CSV_XS->new ({ binary => 1, auto_diag => 1 });

    my $is_list;
    my $drill;
    my $today = int( time / 86_400 );

    while ( my $row = $csv->getline( $fh ) ) {
        $is_list++   if $row->[1] eq 'Datum';
        $is_list = 0 if !$row->[1];

        next if !$is_list;
        next if $row->[1] eq 'Datum';

        my $date   = Time::Piece->strptime( $row->[1], '%d.%m.%y' );
        my $epoche = int ( $date->epoch / 86_400 );

        if ( $epoche - $today == 5 ) {
            $drill = {
                group       => $row->[4],
                type        => $row->[5],
                time        => $row->[2],
                date        => $row->[1],
                responsible => $row->[6],
                topic       => $row->[3],
            };

            last;
        }
    }
    
    return $drill;
}

sub _get_group_and_mail_text {
    my $drill = _get_drill();

    return if !$drill;

    my %vars = (
        type  => 'die nächste Übung',
        date  => $drill->{date},
        resp  => $drill->{responsible},
        topic => $drill->{topic},
        time  => $drill->{time},
        group => 'die Einsatzabteilung',
    );

    if ( $drill->{type} eq 'Theorie' ) {
        $vars{type} = 'der nächste Schulungsabend';
    }

    if ( $drill->{group} ne 'EA' ) {
        $vars{group} = $drill->{group};
    }

    my $text = Mojo::Template->new( vars => 1 )->render_file( TEMPLATE, \%vars );

    return $drill->{group}, $text;
}

sub _get_groups {
    open my $fh, '<', ADDRESS_FILE;
    return if !$fh;

    my %groups;
    while ( my $line = <$fh> ) {
        chomp $line;
        next if !$line;

        my ($mail, $membership) = split /\s/, $line, 2;

        $membership //= 'EA';

        push @{ $groups{$_} }, $mail for split /\s*,\s*/, $membership;
    }

    return %groups;
}

