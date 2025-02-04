# Contributing guide

Thank you for considering to contribute to Rex! Volunteers like you make this
free and open source project possible.

We consider it important to ensure everyone involved can make an efficient use
of the time and effort they choose to invest. This guide aims to streamline
communication around contributions by documenting the most frequently discussed
aspects.

While most sections focus on the code contributions we typically receive, we
encourage and welcome other types of contributions too. For example:

- improving documentation
- testing with different setups
- donating (access to) hardware
- submitting and triaging bug reports
- sharing your use cases and experience with Rex
- spreading the word via blogs, talks, and social media
- starring the project on [GitHub](https://github.com/RexOps/Rex)
- adding Rex to your favorites on [MetaCPAN](https://metacpan.org/pod/Rex)
- listing Rex as part of your stack on [StackShare](https://stackshare.io/rex)

## Project guidelines

We took many decisions around Rex since the first commit in 2010. We found some
of the ideas coming up more often than others, and decided to share them here
(in no particular order).

### Getting help and support

If you need help with questions like “How do I…?” and “Why does it…?”, please
start a discussion via one of our
[support](https://www.rexify.org/support/index.html) channels.

We list options there for both community and commercial support.

### Discussions, issues, and pull requests

In short, we follow these steps in that order: discuss first, track next,
implement last.

1. Discuss: first we discuss the relevant details of any change proposal idea,
   and decide on next steps.
1. Track: when we decide to work on a change proposal, we open an issue to
   track progress, and design or refine potential solutions.
1. Implement: we open pull requests as a last step to propose and review a
   specific implementation of the given idea.

Please use the templates we provide to streamline our collaboration in typical
situations.

### Making exceptions

We may choose and accept skipping one or more of the steps in exceptional
cases, as long as the reasoning makes sense and gets well documented. When we
find ourselves repeating the same exception, we will document it here as a
standard case instead.

When you feel our workflow, guidelines, or templates does not fit your
situation, please consider that a strong indicator to [contact
us](https://www.rexify.org/support/index.html) early, and we’ll help figuring
out the best course of action.

### Rex core vs extending Rex

Strictly speaking, we consider the following the core competency of Rex:
execute commands and manage files, by defining tasks and orchestrating their
execution.

Rex gained lots of other capabilities over time, and historically many of them
landed in core as well. This includes the capability to extend Rex without
changing the core (or only minimally), for example when adding support to:

- new operating systems
- new shell types
- new virtualization methods
- new cloud providers

We strongly encourage to add such new capabilities via their own extension
modules outside the core. In case of questions or concerns, see also the
“Common scenarios” section, or [contact
us](https://www.rexify.org/support/index.html).

### Supported operating systems

We expect Rex to _run_ on operating systems wherever Perl can run. This
includes Linux, BSDs, Mac OS X, Windows, Solaris, and possibly others.

We also expect Rex to _manage_ endpoints running different operating systems.
This primarily means Unix-like systems for now.

We welcome patches and guides about how to support Rex both to run on and
manage even more operating systems.

In general, we aim to support Rex to run on and manage actively maintained
platforms only. See also the “Deprecation policy” section for more details.

### Supported Perl versions

Rex aims to run even on older Perl versions up to 10 years old. Currently this
means 5.14.4.

On top of the supported minimum version of Perl, we aim to support the latest
versions of all minor stable Perl 5 releases since then. That makes the full
list the following:

- 5.14.4
- 5.16.3
- 5.18.4
- 5.20.3
- 5.22.4
- 5.24.4
- 5.26.3
- 5.28.3
- 5.30.3
- 5.32.1
- 5.34.1
- 5.36.1
- 5.38.2
- 5.40.1

### Backwards compatibility

We aim to remain backwards compatible within major versions of Rex, as implied
by following [Dotted Semantic
Versioning](https://metacpan.org/pod/Version::Dotted::Semantic#Dotted-Semantic-Versioning-Specification).

To introduce new features while staying backwards compatible, Rex also uses
[feature flags](https://metacpan.org/pod/Rex#FEATURE-FLAGS). This makes it
possible to selectively opt-in to or opt-out from new features, depending on
the needs of the given use case.

Feature flags named after the minor releases of Rex (for example `1.4`) enable
the collection of preferred settings for the given Rex version.

In general, we strive to add new feature flags in pairs for opting in and out.

### Deprecation policy

We may drop features and code paths by following a planned deprecation
procedure. Adequate warnings and an ample transition period should precede any
such change.

If a supported operating system gets deprecated, we may try to keep it
supported while it doesn't cause any problems. As soon as a retired operating
system starts causing bugs, or gets in the way of progress, we consider it a
candidate to drop from support.

In other words, while we may choose to stay lazy to keep the support around, we
also don’t plan to put active effort into maintaining compatibility with
something which got abandoned by its own creators.

In case you depend on a deprecated feature, or must use or manage a retired
operating system, please consider contributing your solutions, or asking for
community or commercial [support](https://www.rexify.org/support/index.html)
for your use case.

### Code layout

We use the latest version of [Perl::Tidy](https://metacpan.org/pod/Perl::Tidy)
to format the Rex codebase according to the rules described in `.perltidyrc`.
We expect all contributions to follow the same formatting rules, and we also
actively test for it.

To avoid unnecessary “tidy only” commits in contributions, we recommend to
integrate a formatting step directly into your workflow. For example via a git
pre-commit hook, a shortcut in the editor, or as an automatic action upon
saving.

Importantly, we emphasize the importance of a consistent layout throughout the
codebase over any specific formatting rule. Since we include `.perltidyrc` in
the repo, consider it as subject of contributions too.

### Code quality

We use
[Test::Perl::Critic::Progressive](https://metacpan.org/pod/Test::Perl::Critic::Progressive)
to make sure every change follows the code quality rules in `.perlcriticrc`,
and no contribution introduces any violations accidentally.

The `dist.ini` file contains the list of perlcritic policy modules we use.

Since we include both `.perlcriticrc` and `dist.ini` in the repo, consider it
as subject of contributions too. In fact, we welcome improving both our
policies and the codebase in this regard.

### Tests should pass

Rex has two major test suites:

- the tests included with the code, exercising different modules and
  features
- the historical tests in the
  [RexOps/rex-build](https://github.com/RexOps/rex-build) repo, making sure Rex
  can manage actual VMs running different operating systems

In general, we expect contributions to include their own tests for the proposed
changes, while ensuring that previous tests still pass.

To make it easier to follow the guidelines of this document, we strive to have
corresponding tests for them as well.

### Have fun

We find it highly important to have fun while using Rex and contributing to it.
If you have a different experience, then please let us know, as that probably
indicates a bug somewhere.

## Development tools

We use [Git](https://www.git-scm.com) for version control of the source code,
and host Rex code in a [GitHub repository](https://github.com/RexOps/Rex).

We recommend to use a separate Perl environment for development, like the ones
you managed by [Perlbrew](https://perlbrew.pl/) or similar tools.

The code and examples use [cpanm](https://metacpan.org/pod/App::cpanminus) to
install modules from CPAN.

We also use [Dist::Zilla](https://metacpan.org/pod/Dist::Zilla) as an authoring
tool.

[Perltidy](https://metacpan.org/pod/distribution/Perl-Tidy/bin/perltidy) takes
care of maintaining a consistent source code formatting.

[Perlcritic](https://metacpan.org/pod/distribution/Perl-Critic/bin/perlcritic)
makes sure the codebase follows best practices and adheres to our minimum
quality requirements.

## Dependencies

After cloning the source code, run the following commands to install dependencies:

    dzil authordeps | cpanm
    dzil listdeps | cpanm

While some optional dependencies may not support your platform, use this
command to install these as well:

    dzil listdeps --suggests | cpanm

Install the remaining dependencies specific to the operating system, and Rex
itself with:

    dzil install

To only install the dependencies specific to the operating system, run one of
these commands:

- Windows: `cpanm Net::SSH2`
- non-Windows: `cpanm Net::OpenSSH Net::SFTP::Foreign IO::Pty`

When considering new dependencies, we prefer:

- Perl core modules
- CPAN modules already packaged by the operating systems distributing Rex
- CPAN modules supporting the same platforms Rex itself supports

We welcome and encourage contributions aimed at reducing the amount of Rex
dependencies, for example by:

- removing unused dependencies
- consolidating similar dependencies into a single one
- replacing external dependencies with Perl code modules

## Testing

Run the test suite included with the source code of Rex with `prove`:

    prove --lib --recurse t/

Extended, author, and release tests may need further dependencies. Install
these with:

    dzil listdeps --author --missing | cpanm

Then run those tests with:

    dzil test --all

As an important step before modifying the codebase, please run the progressive
perlcritic tests on the default branch:

    rm -f xt/author/.perlcritic-history
    AUTHOR_TESTING=1 prove --lib xt/author/critic-progressive.t

The first run should succeed, and records the current state. This serves as
baseline to compare later runs against. Please see the
[Test::Perl::Critic::Progressive
NOTES](https://metacpan.org/pod/Test::Perl::Critic::Progressive#NOTES) for more
details.

## Git workflow

We prefer receiving contributions by
[forking](https://docs.github.com/en/github/collaborating-with-issues-and-pull-requests/about-forks)
the repository on GitHub, and then sending [pull
requests](https://docs.github.com/en/github/collaborating-with-issues-and-pull-requests/about-pull-requests)
against the default branch of the repository. If you have to use a different
way, please [contact us](https://www.rexify.org/support/index.html) first to
discuss alternative options.

Please read and follow the “Discussions, issues, and pull requests” section
before investing effort in a pull request.

We recommend to use feature
[branches](https://docs.github.com/en/github/collaborating-with-issues-and-pull-requests/about-branches)
when working on contributions. This helps keeping the commits related to the
change together, while separating them from the main line of development.

We consider a single commit ideal when it:

- represents a single logical change ([atomic](https://en.wikipedia.org/wiki/Atomic_commit#Atomic_commit_convention))
- has a useful commit message
- has the expected test suite result

We expect commit messages to follow the guidelines collected in the [How to
Write a Git Commit Message](https://chris.beams.io/posts/git-commit/) article,
and we also test for most of those expectations.

We generally recommend to:

- follow a test-driven approach: add new breaking tests on a first commit, then
  change the code to fix them on a follow up commit, then refactoring on
  follow-up commits as needed
- simplify making larger changes: refactor on a separate commit first to make
  later changes simpler on smaller commits
- use atomic commits: use separate commits in a single pull request to separate
  the logical steps, and to help understanding the series of changes during
  review
- share your ideas and for feedback early: open [draft pull
  requests](https://docs.github.com/en/github/collaborating-with-issues-and-pull-requests/about-pull-requests#draft-pull-requests)
- keep your branch up-to-date:
  [rebase](https://docs.github.com/en/github/using-git/about-git-rebase) your
  feature branch on top of our default branch whenever we made new commits
  while you work
- keep a tidy history: use follow-up/cleanup commits on the same PR, and
  [squash or fixup related
  commits](https://docs.github.com/en/github/using-git/about-git-rebase)
  together in the feature branch, while keeping commits atomic (in other words,
  no need for “tidy only”, “fix typo”, and merge commits, while avoiding to
  squash everything into a single commit)
- use force push on pull request branches: work on your contributions until
  they pass automated tests and review, and keep the history tidy there to
  prepare for merging

## Common scenarios

### Add support to manage new operating systems

Allowing Rex to manage a new operating system requires the following steps:

1. Teach rex about how to detect the given operating system

    - add a way to `Rex::Hardware::Host::get_operating_system()` to detect the
      given operating system
    - add a new `is_myos()` function to `Rex::Commands::Gather`

1. Let Rex choose the proper package and service management modules for the
   given operating system

    - add support in `Rex::Service` and `Rex::Pkg`

1. Add new service and package management modules specific to the given
   operating system

    - add `Rex::Service::MyOS`
    - add `Rex::Pkg::MyOS`

While the first two steps must currently go into Rex core, please consider
publishing the `Rex::Service::MyOS` and `Rex::Pkg::MyOS` modules as a separate
distribution.

### Add support for new virtualization methods

Follow these steps to add support for a new virtualization method called `MyVirt`:

- create the top-level `Rex::Virtualization::MyVirt` module which includes the
  constructor, and the documentation
- create submodules for each virtualization command, e.g.
  `Rex::Virtualization::MyVirt::info`
- implement the logic of the given command as the `execute` method

Please consider publishing the `Rex::Virtualization::MyVirt` module as a
separate distribution.

## Contribute to this guide

If you think some of the information in this document got outdated, lacks
clarity, or has bugs, please propose changes to it too.

## Useful resources

- [Rex website](https://www.rexify.org)
- [MetaCPAN](https://metacpan.org/pod/Rex)
- [GitHub](https://github.com/RexOps/Rex)
- [Discussions](https://github.com/RexOps/Rex/discussions)
- [Issue tracker](https://github.com/RexOps/Rex/issues)
- [Google Groups](https://groups.google.com/forum/#!forum/rex-users)
- [StackShare](https://stackshare.io/rex)
- [Matrix](https://matrix.to/#/#rexops:matrix.org)
- [IRC](https://webchat.oftc.net/?channels=rexops)
