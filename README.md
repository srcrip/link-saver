# LinkSaver

<a href="https://github.com/srcrip/link-saver/actions"><img src="https://github.com/srcrip/link-saver/actions/workflows/ci.yml/badge.svg" alt="tests badge"/></a>

Behold! You are looking at an example of how you may build some kind of a link saving application in Phoenix. Picture
one of those services that let you bookmark links for later, cause the bookmarks in your browser aren't that great.

## Stuff Used

- Phoenix 1.7
- LiveView 1.0
- Postgres for [full text search](lib/link_saver/links.ex#L23-L47)
- [`instructor_ex`](https://github.com/thmsmlr/instructor_ex) for [auto-categorizing links with an LLM](lib/link_saver/links/auto_tagger.ex#L32-L41)

## Try it out

This app is currently deployed at [https://linksaver.src.rip](https://linksaver.src.rip)
