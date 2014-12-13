# Rex [![Build Status](https://travis-ci.org/RexOps/Rex.svg?branch=development)](https://travis-ci.org/RexOps/Rex)

With (R)?ex you can manage all your boxes from a central point through the complete process of configuration management and software deployment.

## Getting started

We have a [Getting started guide](http://www.rexify.org/docs/guides/start_using__r__ex.html) on the website that should help you with the first steps.

## Installation

There are several methods to install (R)?ex: use your distro's package manager, download it from CPAN or build it from source. Check out the [Get Rex](http://www.rexify.org/get.html) page on the website for the different options, and choose the one that fits you best.

### Build from source

To build (R)?ex from source, you need to install [Dist::Zilla](https://metacpan.org/pod/Dist::Zilla):
```
cpanm Dist::Zilla
```

Dist::Zilla provides the *dzil* command, which you can use to install (R)?ex dependencies:
```
dzil authordeps --missing | cpanm
dzil listdeps --missing | cpanm
```

Then to install (R)?ex:
```
dzil install
```

Or to build a .tar.gz release file:
```
dzil build
```

## Need help?

If a new user has difficulties to get on board, then it's a bug. Let us know!

Feel free to join us on irc.freenode.net in the #rex channel, ask us on the [Rex Users](https://groups.google.com/group/rex-users/) on Google Groups, or browse and open [issues on GitHub](https://github.com/RexOps/Rex/issues).

If you need commercial support for (R)?ex, check out the [Support](http://www.rexify.org/support.html) page on the website.

## Contributing

All contributions are welcome: documentation, patches, bug reports, ideas, promoting (R)?ex at conferences and meetups, or anything else you can think of.

For more details, see the [Help (R)?ex](http://www.rexify.org/care/help__r__ex.html) page on the website.

If you want to contribute new functionality or fix things, you can just clone the repository on GitHub and send pull requests against the *development* branch. We encourage you to logically group your commits together in topic/feature branches and send a pull request for each of your topic branches.

We use perltidy to help us to maintain a consequent code style throughout the project (check out our .perltidyrc for more details). We recommend setting it up with your favorite IDE or text editor, so you can apply formatting easily or even automatically to your changes before committing them.

If you have any questions about how to implement something, join us on irc.freenode.net / #rex.
