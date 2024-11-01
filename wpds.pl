#!/usr/bin/perl
#
# WordPress - Del.icio.us Synchronization script by http://wp.leau.co (Edward de Leau)
# see:  http://wp.leau.co/?p=7
#
# 1.0 Created by Stephen @ http://stephen.evilcoder.com/archives/2005/02/27/daily-delicious-links-perl-script
# 2.3 Update by: Edward de Leau, http://edward.de.leau.net (2007)
# 2.3.1 Update: when posting multiple postings each one can have
#       a unique title and slug (EDL) (2007)
# 2.3.2 Update by Chris Craig http://chriscraig.net to exclude private posts (2009)
# 2.3.3 Fixes some weird character output by using Unicode (EDL) (2009)
# 2.3.4 Added a filter to exclude comma's in tags (EDL) (2010)
# 2.3.4 Moved the configuration set in a seperate file (2010)
# 2.3.5 Added WordPress Multisite support (2010)
# 2.3.6 Added support for Post Formats - link: 'post-format-link' (2011)
# ------------------------------------------------------------------------
#
# This perl script allows you to daily synchronize your WordPress
# with your del.icio.us bookmarks. You can synchronize it either as
# seperate posts or as 1 daily links posting. You can style the links
# and you can add a category, synchronize the tags too and even
# put the del.icio.us tagslinks in the posting too.
#
#
# Instructions:
#
# 0. make sure you have all the required Perl packages installed incl. Net::Delicious
# 1. fill in the fields under "user-configurable variables"
# 2. replace in this script the 2 (!) references to the script location to your own physical script location
# 3. crontab/schedule the script to run at each day at Midnight GMT
#    e.g. for Dreamhost or MediaTemple at 15:50
#
# ------------------------------------------------------------------------
# For more information/questions/remarks: see my posting on this script
# http://wp.leau.co/?p=7
#
# ------------------------------------------------------------------------
# libs (make sure you set the path to your libs correctly)
use lib "/nfs/c02/h12/mnt/29931/data/scripts/delicious";
use strict;
use DateTime;
use DateTime::TimeZone;
use Net::Delicious;
use DBI;
use Encode;
use utf8;
use Config::Simple;

# ------------------------------------------------------------------------
# user-configurable variables
# ------------------------------------------------------------------------
#
# The configuration file has now been moved to a seperate file "wpds.ini"
# edit your settings there and / or adjust the location your configuration script
my $config = Config::Simple->import_from('/nfs/c02/h12/mnt/29931/data/scripts/delicious/wpds.ini', \my %config);
my $dbd = "DBI:mysql:" . $config{'wordpress.db_name'} . ":" . $config{'wordpress.db_host'};

# ------------------------------------------------------------------------
# Time Zone fiddling 
# ------------------------------------------------------------------------
my $time_local = DateTime->now;
my $time_wp = $time_local->clone()->set_time_zone($config{'timezone.wp_timezone'});
my $time_gmt = $time_local->clone()->set_time_zone('GMT');
my $time_wp_day = $time_wp->strftime("%G-%m-%d");
my $time_gmt_day = $time_gmt->strftime("%G-%m-%d");

#
# if you want to TEST the script then you can manually set a date and 
# run it (obviously you need to have bookmarks on that day)
#my $time_gmt_day = $time_gmt->strftime("%G-%m-06");
#my $time_gmt_day = $time_gmt->strftime("%G-05-24");

#
# Addition to post title : you can change it if you want a complete different post title
#
my $temp_post_title = $config{'parameters.post_title'};
$config{'parameters.post_title'} = $temp_post_title . $time_wp_day;

# ------------------------------------------------------------------------
# initialize Net::Delicious objects
# ------------------------------------------------------------------------

my $del =
 Net::Delicious->new( { user => $config{'delicious.del_username'}, 
	pswd => $config{'delicious.del_password'} } );
die "Unable to connect to del.icio.us.\n" unless $del;

# ------------------------------------------------------------------------
# Get posts from del.icio.us
# ------------------------------------------------------------------------
my @posts = $del->posts( { dt => $time_gmt_day } );

# ------------------------------------------------------------------------
# Set db table parameters / deliberately non optimized to make it clearer
# (for wordpress MU the blog id is added to the tables)
# ------------------------------------------------------------------------
my $tb_blogid = "";
if ( $config{'wordpress.wp_mu_blog_id'} > 1 )
{
	$tb_blogid = $config{'wordpress.wp_mu_blog_id'} . '_';
}
my $tb_posts                    = $config{'wordpress.prefix'} . $tb_blogid . "posts";
my $tb_wp_terms                 = $config{'wordpress.prefix'} . $tb_blogid . "terms";
my $tb_wp_term_taxonomy         = $config{'wordpress.prefix'} . $tb_blogid . "term_taxonomy";
my $tb_wp_terms_relationships   = $config{'wordpress.prefix'} . $tb_blogid . "term_relationships";

# ------------------------------------------------------------------------
# Initialize WordPress database
# ------------------------------------------------------------------------
my $dbd = "DBI:mysql:" . $config{'wordpress.db_name'} . ":" . $config{'wordpress.db_host'};
my $dbh = DBI->connect( $dbd, $config{'wordpress.db_user'}, $config{'wordpress.db_pass'} )
  or die "Couldn't connect to database: " . DBI->errstr;
my $sql = qq{SET NAMES 'utf8';};
$dbh->do($sql);

# ------------------------------------------------------------------------
# Set db table SQL procedures for the POSTS table
# ------------------------------------------------------------------------

my $sth         = $dbh->prepare(
    "INSERT INTO $tb_posts
	(post_author, post_date, post_date_gmt, post_content,
	 post_title, post_status, comment_status, ping_status,
	 post_name, post_modified, post_modified_gmt)
    VALUES (?,?,?,?,?,?,?,?,?,?,?)")
  or die "Couldn't prepare statement: " . dbh->errstr;

my $gth = $dbh->prepare("SELECT ID FROM $tb_posts ORDER BY ID DESC LIMIT 1")
  or die "Couldn't prepare statement: " . dbh->errstr;
  
# ------------------------------------------------------------------------
# Set db table SQL procedures for the WP_TERMS table
# ------------------------------------------------------------------------

my $wts    = $dbh->prepare(
    "SELECT term_id FROM $tb_wp_terms WHERE name = ?")
  or die "Couldn't prepare statement: " . dbh->errstr;

my $wti    = $dbh->prepare(
    "INSERT INTO $tb_wp_terms
    (name, slug) VALUES (?,?)")
  or die "Couldn't prepare statement: " . dbh->errstr;

# ------------------------------------------------------------------------
# Set db table SQL procedures for the WP_TERM_TAXONOMY table
# ------------------------------------------------------------------------
my $wtts    = $dbh->prepare(
    "SELECT term_taxonomy_id FROM $tb_wp_term_taxonomy WHERE term_id = ? AND taxonomy = ?")
  or die "Couldn't prepare statement: " . dbh->errstr;
  
my $wtti    = $dbh->prepare(
    "INSERT INTO $tb_wp_term_taxonomy
    (term_id, taxonomy, count) VALUES (?,?,1)")
  or die "Couldn't prepare statement: " . dbh->errstr;

my $wtts_count    = $dbh->prepare(
    "SELECT count FROM $tb_wp_term_taxonomy WHERE term_taxonomy_id = ? AND taxonomy = ?")
  or die "Couldn't prepare statement: " . dbh->errstr;  
  
my $wtti_count    = $dbh->prepare(
    "UPDATE $tb_wp_term_taxonomy
     SET count = ?
     WHERE term_taxonomy_id = ?
     ")
  or die "Couldn't prepare statement: " . dbh->errstr;

# ------------------------------------------------------------------------
# Set db table SQL procedures for the WP_RELATIONS table
# ------------------------------------------------------------------------

my $wri =
 $dbh->prepare(
    "INSERT INTO $tb_wp_terms_relationships
    (object_id,term_taxonomy_id)
    VALUES (?,?)")
  or die "Couldn't prepare statement: " . dbh->errstr;

# ------------------------------------------------------------------------
# Generate the HTML for the posting(s)
# ------------------------------------------------------------------------

my $html;
my $line;
my $termid;
my $taxcount;
my $term_taxonomy_id;
my @taglist;
my $postObject_id;
my $post_namer;
my $postcounter;
my $taxonomy_term_id;
my $dtag;
my $taglistitem;
my $category_termid;
my $term_taxonomy_id_category;
my $postformat_termid;
my $term_taxonomy_id_postformat;

$postcounter = 0;
$html = "";

# ----------------------------------------------------------------------
# CATEGORY Pre Check
# ----------------------------------------------------------------------
# check if TERM exists and return the [term id] if it does
$wts->execute($config{'wordpress.taxonomy_term_name_2'});
$category_termid = $wts->fetchrow_array();
$wts->finish;
# if category TERM does not exist ADD IT to the WordPress [wp_terms] table first
if ( !$category_termid ) 
{
	$wti->execute($config{'wordpress.taxonomy_term_name_2'},$config{'wordpress.taxonomy_term_slug_2'});
	$wti->finish;
	$wts->execute($config{'wordpress.taxonomy_term_name_2'});
	$category_termid = $wts->fetchrow_array();
	$wts->finish;
}
# Check if the category taxonomy exists else add it
$wtts->execute($category_termid,$config{'wordpress.taxonomy_type_2'});
$term_taxonomy_id_category = $wtts->fetchrow_array();
$wtts->finish;
if ( !$term_taxonomy_id_category ) 
{
	$wtti->execute($category_termid, $config{'wordpress.taxonomy_type_2'});
	$wtti->finish;		
	$wtts->execute($category_termid,$config{'wordpress.taxonomy_type_2'});
	$term_taxonomy_id_category = $wtts->fetchrow_array();
	$wtts->finish;
}

# ----------------------------------------------------------------------
# Post Format Pre Check
# ----------------------------------------------------------------------
# check if post format TERM exists and return the [term id] if it does
$wts->execute($config{'wordpress.taxonomy_term_name_3'});
$postformat_termid = $wts->fetchrow_array();
$wts->finish;
# if post format TERM does not exist ADD IT to the WordPress [wp_terms] table first
if ( !$postformat_termid  ) 
{
	$wti->execute($config{'wordpress.taxonomy_term_name_3'},$config{'wordpress.taxonomy_term_slug_3'});
	$wti->finish;
	$wts->execute($config{'wordpress.taxonomy_term_name_3'});
	$postformat_termid = $wts->fetchrow_array();
	$wts->finish;
}
# Check if the postformat taxonomy exists
$wtts->execute($postformat_termid,$config{'wordpress.taxonomy_type_3'});
$term_taxonomy_id_postformat = $wtts->fetchrow_array();
$wtts->finish;
if ( !$term_taxonomy_id_postformat ) 
{
	$wtti->execute($postformat_termid, $config{'wordpress.taxonomy_type_3'});
	$wtti->finish;		
	$wtts->execute($postformat_termid,$config{'wordpress.taxonomy_type_3'});
	$term_taxonomy_id_postformat = $wtts->fetchrow_array();
	$wtts->finish;
}

# ----------------------------------------------------------------------
# Now loop the posts
# ----------------------------------------------------------------------
foreach (@posts) 
{
	# only for shared or explicit choice to also show private bookmarks: post thebookmark
	if ($_->shared() || $config{'delicious.del_showprivate'})
	{
		$line = htmlPosting();
		if ( $config{'parameters.post'} eq "single"  )
		{
			# Save this line for later
			$html .= $line;
		} 
		else 
		{
			# Just Post the Post but with a digit behind the name (since we have multiple)
			# and we are nice: we will make it unique for your permalinks :)
			$html = $line;
			if ( $html ) 
			{
				$postcounter = $postcounter + 1;
				$post_namer = $config{'parameters.post_name'} . $postcounter;
				$postObject_id = postPost();
			}
		}
	}
		
    # BEGIN : now parse the tags
    if ($_->tags) 
	{
       foreach ( ( split /\s+/, $_->tags ) ) 
	   {
			# remove the comma (added okt 2010)
			$dtag = $_;			
			if ($config{'parameters.remove_comma'}) 
			{
				$dtag =~ s/,//;			
			}
			
			# ---------------------------------------------------------
			# TAGS / TERMS
			# ---------------------------------------------------------			
			# check if TERM exists else add it 
			$wts->execute($dtag);
			$termid = $wts->fetchrow_array();
			$wts->finish;
			if ( !$termid ) 
			{
				$wti->execute($dtag,$dtag);
				$wti->finish;
				$wts->execute($dtag);
				$termid = $wts->fetchrow_array();
				$wts->finish;
			}

			# ---------------------------------------------------------
			# TAGS / TERM-TAXONOMY
			# ---------------------------------------------------------							
			# check if TERM-TAXONOMY exists else add it
			$wtts->execute($termid,$config{'wordpress.taxonomy_type'});
			$term_taxonomy_id = $wtts->fetchrow_array();
			$wtts->finish;			
			if ( !$term_taxonomy_id ) 
			{			    
				$wtti->execute($termid, $config{'wordpress.taxonomy_type'});
				$wtti->finish;
				$wtts->execute($termid,$config{'wordpress.taxonomy_type'});
				$term_taxonomy_id = $wtts->fetchrow_array();
				$wtts->finish;
			}
						
			# ---------------------------------------------------------
			# For an aggregated post save the tags for the combined posting
			# ---------------------------------------------------------		
			if ( $config{'parameters.post'} eq "single"  ) 
			{
				push(@taglist, $term_taxonomy_id);
			} 
			
			# ---------------------------------------------------------
			# for a multi post immediately assign the tags
			# (and update the count)
			# ---------------------------------------------------------
			else 
			{
				$wtts_count->execute($term_taxonomy_id,$config{'wordpress.taxonomy_type'});
				$taxcount = $wtts_count->fetchrow_array();
				$wtts_count->finish;
				$taxcount = $taxcount + 1;
				$wtti_count->execute($taxcount,$term_taxonomy_id);
				$wtti_count->finish;
					
				$wri->execute($postObject_id,$term_taxonomy_id);
				$wri->finish;
			}
		}    
    } 
	# end: FOR ALL TAGS
	
	# if it is a multipost (setting) we can add a category and a post format now
	# meaning: every time this post loop runs it posts a post so every time we
	# add the defined category and post format
    if ( $config{'parameters.post'} ne "single"  ) 
	{
		# ---------------------------------------------------------
		# CATEGORY
		# ---------------------------------------------------------					
		# count++
		$wtts_count->execute($term_taxonomy_id_category,$config{'wordpress.taxonomy_type_2'});
		$taxcount = $wtts_count->fetchrow_array();
		$wtts_count->finish;
		$taxcount = $taxcount + 1;
		$wtti_count->execute($taxcount,$term_taxonomy_id_category);
		$wtti_count->finish;		
        # now also add the new term taxonomy id
        $wri->execute($postObject_id,$term_taxonomy_id_category);
        $wri->finish;		
		# ---------------------------------------------------------
		# POST FORMAT 
		# ---------------------------------------------------------			
		$wtts_count->execute($term_taxonomy_id_postformat,$config{'wordpress.taxonomy_type_3'});
		$taxcount = $wtts_count->fetchrow_array();
		$wtts_count->finish;
		$taxcount = $taxcount + 1;
		$wtti_count->execute($taxcount,$term_taxonomy_id_postformat);
		$wtti_count->finish;		
        # now also add the new term taxonomy id
        $wri->execute($postObject_id,$term_taxonomy_id_postformat);
        $wri->finish;		
    } # end: single post check	
} # end: for each post

# now we can add for a combined post the taxonomies:
if ( $config{'parameters.post'} eq "single" && $html ) {
    $post_namer = $config{'parameters.post_name'};
    $postObject_id = postPost();
    # add TAGS
    foreach $taglistitem(@taglist) {	
		$wtts_count->execute($taglistitem,$config{'wordpress.taxonomy_type'});
		$taxcount = $wtts_count->fetchrow_array();
		$wtts_count->finish;
		$taxcount = $taxcount + 1;
		$wtti_count->execute($taxcount,$taglistitem);
		$wtti_count->finish;
        $wri->execute($postObject_id,$taglistitem);
        $wri->finish;
    }
    # add CATEGORY
	$wtts_count->execute($term_taxonomy_id_category,$config{'wordpress.taxonomy_type_2'});
	$taxcount = $wtts_count->fetchrow_array();
	$wtts_count->finish;
	$taxcount = $taxcount + 1;
	$wtti_count->execute($taxcount,$term_taxonomy_id_category);
	$wtti_count->finish;		
    # now also add the new term taxonomy id
    $wri->execute($postObject_id,$term_taxonomy_id_category);
    $wri->finish;		
	#add POSTFORMAT
	$wtts_count->execute($term_taxonomy_id_postformat,$config{'wordpress.taxonomy_type_3'});
	$taxcount = $wtts_count->fetchrow_array();
	$wtts_count->finish;
	$taxcount = $taxcount + 1;
	$wtti_count->execute($taxcount,$term_taxonomy_id_postformat);
	$wtti_count->finish;		
    # now also add the new term taxonomy id
    $wri->execute($postObject_id,$term_taxonomy_id_postformat);
    $wri->finish;	
}

############################################################################
sub htmlPosting     #11/14/07 12:38
############################################################################
{
        my $line;
        my ( $href, $description, $tags, $extended ) =
            ( $_->href, $_->description, $_->tags, $_->extended );
		$description = decode_utf8( $description );
		$extended = decode_utf8( $extended );
        my $line =
            "<p>\n" . "<a class=\"deliciouslink\" href=\"$href\" title=\"$description\" target=\"_blank\">$description</a>";
        if ($extended) {
            $line .= "\n$extended";
        }
        # --------------------------------------------------------------------
        # If you include this then you will show the del.icio.us links under
        # the del.icio.us link, however that seems a bit pointless if
        # you are also using WordPress's Tagging system.
        # --------------------------------------------------------------------
        #
        #if ($tags) {
        #    $line .= "\n(tags:";
        #    foreach ( ( split /\s+/, $tags ) ) {
        #        $line .= " <a class=\"delicioustag\" href=\"http://del.icio.us/$del_username/$_\">$_</a>";
        #    }
        #    $line .= ")";
        #}
        # --------------------------------------------------------------------
        $line .= "</p>\n";    # close HTML tag
        return $line;

}   ##htmlPosting

############################################################################
sub postPost        #11/14/07 1:02
############################################################################
 {
    # we need the date in "YYYY-MM-DD HH:MM:SS" format
    my $now     = $time_wp->strftime("%G-%m-%d %H-%M-%S");
    my $now_gmt = $time_gmt->strftime("%G-%m-%d %H-%M-%S");

    if ( $config{'parameters.post'} ne "single"  ) {
        # $post_title = $multipleTitle . $time_wp_day . ": " .  $_->description;
		$config->param('parameters.post_title', $_->description);
		$config{'parameters.post_title'} = $_->description;
        # you can change the above to e.g. only description
        # if you do not want to indicate the links date
    }
	
    # put the post into the WP database
    $sth->execute(
        $config{'wordpress.wp_userid'},  $now,      $now_gmt,       $html,
        $config{'parameters.post_title'}, 'publish', $config{'parameters.allowcomments'}, $config{'parameters.allowpings'},
        $post_namer,  $now,      $now_gmt
);
    $sth->finish;

    # get the post ID
    $gth->execute();
    my $post_id = $gth->fetchrow_array();
    $gth->finish;

    return $post_id;
}   ##postPost

$dbh->disconnect;