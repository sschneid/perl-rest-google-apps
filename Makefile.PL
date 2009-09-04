use strict;
use warnings;
use ExtUtils::MakeMaker;

WriteMakefile(
    NAME                => 'REST::Google::Apps::Provisioning',
    ABSTRACT            => 'A Perl library to Google\'s RESTful Apps API',
    AUTHOR              => 'Scott Schneider <sschneid@gmail.com>',
    VERSION_FROM        => 'lib/REST/Google/Apps/Provisioning.pm',
    PL_FILES            => {},
    PREREQ_PM => {
        'Test::More' => 0,
    },
    dist                => { COMPRESS => 'gzip -9f', SUFFIX => 'gz', },
    clean               => { FILES => 'REST-Google-Apps-Provisioning-*' },
);

