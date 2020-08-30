# Rex, the friendly automation framework [![Build Status](https://travis-ci.com/RexOps/Rex.svg?branch=master)](https://travis-ci.com/RexOps/Rex)

The main ideas behind Rex are:

1. Puts _you_ in charge

    Rex acknowledges that instead of silver bullets, there is more than one way to manage it.

    It's friendly to any combinations of local and remote execution, push and pull style of management, or imperative and declarative approach.
    Instead of forcing any specific model on you, it trusts you to be in the best position to decide what to automate and how, allowing you to build the automation tool _your_ situation requires.

1. Easy to get on board

    Automate what you are doing today, and add more tomorrow.

    Rex runs locally, even if managing remotes via SSH. This means it's instantly usable, without big rollout processes or anyone else to convince, making it ideal and friendly for incremental automation.

1. It's just Perl

    Perl is a battle-tested, mature language, and Rex code is just Perl code.

    This means whenever you reach the limitations of the built-in Rex features, a powerful programming language and module ecosystem is always at your fingertips to seamlessly extend it with modules from [CPAN](https://metacpan.org) or with your own code.
    As a bonus, you can also use the usual well-established tools and workflows, like IDE integration for syntax highlighting, linting and formatting, or authoring and publishing [Rex modules on CPAN](https://metacpan.org/search?q=rex).
    With the use of [Inline](https://metacpan.org/pod/Inline) and [FFI::Platypus](https://metacpan.org/pod/FFI::Platypus) modules, it's friendly to code written in other languages too. So after all, it's not just Perl.

## Getting started

We have a [Getting started guide](https://www.rexify.org/docs/guides/start_using__r__ex.html) on the website that should help you with the first steps.

## Installation

There are several methods to install (R)?ex: use your distro's package manager, download it from CPAN or build it from source. Check out the [Get Rex](https://www.rexify.org/get/index.html) page on the website for the different options, and choose the one that fits you best.

### Build from source

To build (R)?ex from source, you need to install [Dist::Zilla](https://metacpan.org/pod/Dist::Zilla):

    cpanm Dist::Zilla

Dist::Zilla provides the *dzil* command, which you can use to install (R)?ex dependencies:

    dzil authordeps | cpanm
    dzil listdeps | cpanm

Some of the optional dependencies might not be available on all platforms, but to install them as well, use this command:

    dzil listdeps --suggests | cpanm

Then to install the OS-specific dependencies and (R)?ex itself:

    dzil install

If you'd like to build a .tar.gz release file:

    dzil build

## Need help?

If a new user has difficulties to get on board, then it's a bug. Let us know!

Feel free to join us on irc.freenode.net in the #rex channel, ask us on the [Rex Users](https://groups.google.com/group/rex-users/) on Google Groups, or browse and open [issues on GitHub](https://github.com/RexOps/Rex/issues).

If you need commercial support for (R)?ex, check out the [Support](https://www.rexify.org/support/index.html) page on the website.

## Contributing

All contributions are welcome: documentation, patches, bug reports, ideas, promoting (R)?ex at conferences and meetups, or anything else you can think of.

For more details, see the [Contributing guide](https://github.com/RexOps/Rex/blob/master/CONTRIBUTING.md) in the repo and the [Help (R)?ex](https://www.rexify.org/care/help__r__ex.html) page on the website.
