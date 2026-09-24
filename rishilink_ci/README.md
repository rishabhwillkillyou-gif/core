# RishiLink CI carrier

This branch is isolated from the repository's normal development.

It uses GitHub Actions only as a build runner. The workflow clones LocalSend
at `230fb692962668ca22ce0e61a8f53ce1cfd32102`, applies RishiLink changes,
and builds Android and Windows test artifacts. The default branch and the
existing project source are not modified by the RishiLink build.
