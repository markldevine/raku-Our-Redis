#!/usr/bin/env raku

#use lib '/home/mdevine/github.com/raku-Our-Redis/lib';

use Our::Redis;

my Our::Redis $redis-cli;

sub MAIN (Str :$redis-server!) {
    $redis-cli .= new: :$redis-server, :tunnel;
    my $key     = 'Test_String';
    my $value   = ('A' .. 'Z').Str;                                                     put '|' ~ $value ~ '|';
    $redis-cli.SET(:$key, :$value);
    $redis-cli.EXPIRE(:$key, :seconds(30));                                             put '|' ~ $redis-cli.GET(:$key).chomp ~ '|';
}

=finish

$key        = 'Path';
$redis-cli.SET(:$key, :path('/home/mdevine/github.com/raku-Our-Redis/examples/r.dat'));
#$redis-cli.EXPIRE(:$key, :seconds(30));
$text = $redis-cli.GET(:$key);
put '|' ~ $text ~ '|';

=finish
