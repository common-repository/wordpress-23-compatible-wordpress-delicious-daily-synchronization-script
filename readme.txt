=== WordPress Del.icio.us Syncer ===
Contributors: Edward de Leau
Donate link: http://wp.leau.co
Tags: del.icio.us, wordpress, synchronization, tags
Requires at least: 2.3
Tested up to: 3.2
Stable tag: 2.3.6

Synchronizes your daily del.icio.us links to WordPress including tags

== Description ==

I have been happily running this sync script for five years now without
looking back. It syncs both the bookmarks and the tags. It supports UTF 8,
it can filter private bookmarks, ETC...

1. Fully WordPress 2.x to 3.x compatible
1. Allows you to set a category (like the original)
1. Either 1 daily links posting or multiple postings per del.icio.us bookmark
1. Synchronizes your del.icio.us tags with your WordPress tags (quite handy) *)
1. Still allows you, if you want, to post the links to del.icio.us tags
1. Multiple postings can each have its own slug (added in 2.3.1)
1. Parameter to show private delicious postings (or not) (by Christopher Craig) (added in 2.3.2)
1. UTF8 (added in version 2.3.3) (12 june 2009)
1. *) and since you might forget that you enter spaces between tags in delicious and comma’s between tags in WordPress I added the option to remove comma’s on 29 oktober 2010
1. It’s a standalone Perl script so you can re-use the code to interact with more products all from the same crontabbed script.
1. Uses Net::Delicious to maintain future compatibility with any del.icio.us API changes.
1. Completely self-contained, designed to run as a cronjob.
1. Automatically filters out links not matching the current date.
1. WordPress MU compatible
1. seperate configuration file

See http://wp.leau.co/?p=7 for much more description 

This is a perl script that can run on itself. On the url above I give some
points why this is, from IT point of view, better for synchronization scripts
(that may as well have to sync with multiple other systems and / or WordPress
installations). In other words: loosely coupled.

== Installation ==

1. Download the files wpds.pl and wpds.ini
1. Change the parameters in wpds.ini such as your WP database settings
1. Copy it to your scripts directory (ask your webhost)
1. Make sure you have all the required Perl libraries installed, particularly the The Net::Delicious library (by Aaron Straup Cope)
(depending on your host it could be that some Perl modules are available and others not so it is hard to give a generic description on what modules are needed, if you are lucky it will work directly because all modules are already available, (if you have questions just use the comment section below) (if some modules are not present you will get an error that a library is missing, it is simple to install missing libraries) (if you are still unsure about what Perl modules / libraries are: there are millions of threads to be found on this basic concept) (don’t be afraid to learn something new)
1. Schedule your script via a crontab, either by the shell or via your control panel e.g. 15:50 for Dreamhost or Mediatemple. Make sure it runs once a day around midnight. (With most hosting companies you have somewhere in your control panel an icon that lets you schedule scripts, look for it!)

See http://wp.leau.co/?p=7 for much more description 

== Contact Info ==

contact info:
http://edward.de.leau.net/contact

