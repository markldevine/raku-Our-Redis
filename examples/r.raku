#!/usr/bin/env raku

use lib '/home/mdevine/github.com/raku-Our-Redis/lib';

use Our::Redis;

my Our::Redis $redis-cli .= new;
#my Our::Redis $redis-cli .= new: :tunnel;
#my Our::Redis $redis-cli .= new: :remote-server<jgstmgtgate1lpv.wmata.local>, :tunnel;

my $key     = 'String';
my $value   = ('A' .. 'Z').Str;

put '|' ~ $value ~ '|';

$redis-cli.SET(:$key, :$value);
#$redis-cli.EXPIRE(:$key, :seconds(30));
my $text = $redis-cli.GET(:$key);
put '|' ~ $text ~ '|';

=finish

$key        = 'Path';
$redis-cli.SET(:$key, :path('/home/mdevine/github.com/raku-Our-Redis/examples/r.dat'));
#$redis-cli.EXPIRE(:$key, :seconds(30));
$text = $redis-cli.GET(:$key);
put '|' ~ $text ~ '|';

=finish
