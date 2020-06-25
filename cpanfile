requires 'perl', '5.010';
requires 'Mojolicious', '8.03';
requires 'HTTP::Date', '6.02';
requires 'Time::Zone', '2.2';

on 'test' => sub {
    requires 'Test::More', '0.98';
    requires 'Test::Deep', '1.127';
};

on 'develop' => sub {
    # sunshine and rainbows
    requires 'Minilla';
};
