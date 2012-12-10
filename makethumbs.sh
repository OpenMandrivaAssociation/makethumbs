#! /bin/sh

# This script creates tumbnails, reduced versions of large images, and an
# index.html file pointing to all of it.

GLOBAL_rcsid='$Id: makethumbs.sh,v 1.272 2007/04/25 06:18:01 molenda Exp $'
GLOBAL_rcsrev='$Revision: 1.272 $'

# Design goals are
# (1) exist in a single script that can be mailed around easily, etc.
# (2) generate clean, simple, portable HTML
# (3) no databases required
# (4) portable portable portable
# There are many other programs that compromise some or all of these goals.
# They are real neat, they make great web pages, they organize your life.
# They don't fit in a single ugly Bourne shell script whose only point in
# life is to take pictures off your digital camera and make them basically
# presentable to your friends.

# This script is in the public domain, share and enjoy.
# The latest version is always at http://www.molenda.com/makethumbs/

# Written by Jason Molenda, 1998-09-13; rewritten less lamely 2001-10-26.


## Notes to people reading this script.
##
##  Start at main() and trace the function calls from there.  Most of
##  the people who modify this script could have accomplished everything
##  they want through a proper ~/.makethumbsrc.  It's up to you.

##  As much as I like Bourne shell, I should have just done this in
##  perl or python.  On the down side, whichever of those I pick, I'll
##  hear constant whining from about half of my friends.  No one likes
##  Bourne shell, so it's the safest language choice.  And to be honest,
##  I sometimes think it's too easy when you have all those fancy high
##  level data types, scoping, abstractions, and regular expression at your
##  finger tips -- it's a little more fun when you need to work hard to
##  make things work cleanly without a lot of help from the language.

##  Return values from functions are prefixed with "RETURN_".
##  Command line options are prefixed with "ARGV_".
##  Defaults are prefixed with "DEFAULT_"
##  Settings from the .makethumbsrc are prefixed with "DOTRC_"
##  Globals variables are prefixed with "GLOBAL_".

##  GLOBAL_ will hold all the settings that we should act on.  These came
##  either from a DEFAULT_, ARGV_, or DOTRC_ if the user overrode the DEFAULT_.

##  There are a few functionally seperate sections of the script, they start
##  with one of these comments:

#### Start of real makethumbs image stuff functions
#### Index pages functions
#### Image filename conversion/test functions
#### Image creation functions
#### HTML printing functions
#### slideshow functions
#### Progress printing functions
#### checksum checking functions, unmodified file removal
#### descriptions.txt support
#### dates.txt support
#### Get EXIF et al information and add it to slideshow pages
#### Try to get image time/date data via a variety of means


main ()
{
  enable_atexit_trap_handler
  find_programs
  set_environment ${1+"$@"}

  init_defaults
  read_dotrc_file

  check_for_necessary_programs

  make_dir_transversible "."

  parse_args ${1+"$@"}
  get_image_list

  create_descriptions_file
  create_dates_file
  analyze_filenames_and_dates
  reorder_image_list

  create_generated_files
  create_index_pages

  [ $GLOBAL_create_slideshow -eq 1 ] && create_slideshow

  exit 0
}



# DEFAULT_ values are treated as const and are not normally referenced
# by functions in this script.  Functions should refer to the GLOBAL_
# version -- it will either be set to the DEFAULT_ or to the ARGV_ value
# if the user overrides it on the cmd line.
init_defaults ()
{

  DEFAULT_columns=3
  DEFAULT_max_thumb_size=150
  DEFAULT_use_two_windows=0

  DEFAULT_reduce_big_pics=1
  DEFAULT_reduce_trigger_width=1024
  DEFAULT_reduce_trigger_height=768
  DEFAULT_reduce_width=640
  DEFAULT_reduce_height=480

  DEFAULT_feed_width=400
  DEFAULT_feed_height=400
  DEFAULT_create_feed_images=0
  DEFAULT_half_text="half"
  DEFAULT_create_half_images=1

  DEFAULT_large_trigger_width=1700
  DEFAULT_large_trigger_height=1300
  DEFAULT_large_width=1280
  DEFAULT_large_height=1024
  DEFAULT_create_large_images=1

  DEFAULT_remove_originals=0
  DEFAULT_rotation_filename="rot-state.txt"
  DEFAULT_dates_filename="dates.txt"
  DEFAULT_descriptions_filename="descriptions.txt"
  DEFAULT_show_progress=1
  DEFAULT_show_timings=0
  DEFAULT_preferred_image_tools="sips" # or "netpbm" or "imagemagick"

  DEFAULT_body_tag="<body>"
  DEFAULT_body_end_tag="</body>"
  DEFAULT_meta_tag="undef"
  DEFAULT_html_charset="undef"
  DEFAULT_index_base_name="index"
  DEFAULT_html_file_suffix="html"
  DEFAULT_index_filename="${DEFAULT_index_base_name}.$DEFAULT_html_file_suffix"
  DEFAULT_print_captions=1
  DEFAULT_use_timestamps_as_captions=1
  DEFAULT_print_img_size_on_index=0
  DEFAULT_print_title_on_index=1
  DEFAULT_print_title_on_slideshow=1
  DEFAULT_compact_index_page=0
  DEFAULT_index_table_spacing="loose"   # or "tight" or "none"
  DEFAULT_compression_level="75"
  DEFAULT_image_imprinting_text="undef"

  DEFAULT_boilerplate_footer="undef"
  DEFAULT_boilerplate_insert_in_head="undef"
  DEFAULT_boilerplate_end_of_page="undef"
  DEFAULT_boilerplate_before_title="undef"
  DEFAULT_boilerplate_after_title="undef"
  DEFAULT_boilerplate_index_head_stuff="obsolete"
  DEFAULT_boilerplate_index_insert_in_head="undef"
  DEFAULT_boilerplate_index_before_title="undef"
  DEFAULT_boilerplate_index_after_title="undef"
  DEFAULT_boilerplate_index_after_table_before_indexlinks="undef"
  DEFAULT_boilerplate_index_end_of_page="undef"
  DEFAULT_boilerplate_slideshow_insert_in_head="undef"
  DEFAULT_boilerplate_slideshow_before_title="undef"
  DEFAULT_boilerplate_slideshow_after_title="undef"
  DEFAULT_boilerplate_slideshow_end_of_page="undef"

  DEFAULT_index_page_title_start_html="<h1 align=\"center\">"
  DEFAULT_index_page_title_end_html="</h1>"
  DEFAULT_slideshow_page_title_start_html="<h2>"
  DEFAULT_slideshow_page_title_end_html="</h2>"

  DEFAULT_single_index_page=0
  DEFAULT_rows_per_index_page=10

  DEFAULT_usa_specific_date_format_checks=1
  DEFAULT_link_to_original_img_on_index=0
  DEFAULT_show_image_info=0
  DEFAULT_dont_change_file_permissions="obsolete"
  DEFAULT_change_file_permissions=1
  DEFAULT_file_readable_permissions="a+r,a-x"
  DEFAULT_dir_transversible_permissions="a+x"

  DEFAULT_preview_mode=0
  DEFAULT_create_slideshow=1
  DEFAULT_print_img_size_on_slideshow=1
  DEFAULT_slideshow_img_size_across_two_lines=1
  DEFAULT_slideshow_images_are_clickable=0
  DEFAULT_slideshow_print_javascript_navigation=1
  DEFAULT_print_directory_title_on_slideshow_pages=1
  DEFAULT_slideshow_print_bottom_navlinks=0
  DEFAULT_slideshow_previous_pre_link="<h2>["
  DEFAULT_slideshow_previous="previous"
  DEFAULT_slideshow_previous_post_link="]</h2>"
  DEFAULT_slideshow_next_pre_link="<h2>["
  DEFAULT_slideshow_next="next"
  DEFAULT_slideshow_next_post_link="]</h2>"
  DEFAULT_slideshow_ret_to_index_pre_link="<h2>["
  DEFAULT_slideshow_ret_to_index="index"
  DEFAULT_slideshow_ret_to_index_post_link="]</h2>"

  DEFAULT_monthname_01_text="January"
  DEFAULT_monthname_02_text="February"
  DEFAULT_monthname_03_text="March"
  DEFAULT_monthname_04_text="April"
  DEFAULT_monthname_05_text="May"
  DEFAULT_monthname_06_text="June"
  DEFAULT_monthname_07_text="July"
  DEFAULT_monthname_08_text="August"
  DEFAULT_monthname_09_text="September"
  DEFAULT_monthname_10_text="October"
  DEFAULT_monthname_11_text="November"
  DEFAULT_monthname_12_text="December"
  DEFAULT_this_page_created_text="This page @LINKSTART@created@LINKEND@ on @DATE@."
  DEFAULT_image_set_n_text="Image set @NUMBER@"
  DEFAULT_image_set_all_text="All in one"
  DEFAULT_image_xx_of_yy_text="Image @CURRENT@ of @TOTAL@"
  DEFAULT_reduced_text="reduced"
  DEFAULT_large_text="large"
  DEFAULT_original_text="original"
  DEFAULT_original_image_text="Original image"
  DEFAULT_date_formatting_text="@MONTH@ @DAY@, @YEAR@"

  GLOBAL_columns=$DEFAULT_columns
  GLOBAL_max_thumb_size=$DEFAULT_max_thumb_size
  GLOBAL_use_two_windows=$DEFAULT_use_two_windows

  GLOBAL_reduce_big_pics=$DEFAULT_reduce_big_pics
  GLOBAL_reduce_trigger_height=$DEFAULT_reduce_trigger_height
  GLOBAL_reduce_trigger_width=$DEFAULT_reduce_trigger_width
  GLOBAL_reduce_height=$DEFAULT_reduce_height
  GLOBAL_reduce_width=$DEFAULT_reduce_width

  GLOBAL_feed_height=$DEFAULT_feed_height
  GLOBAL_feed_width=$DEFAULT_feed_width
  GLOBAL_create_feed_images=$DEFAULT_create_feed_images
  GLOBAL_create_half_images=$DEFAULT_create_half_images

  GLOBAL_create_large_images=$DEFAULT_create_large_images
  GLOBAL_large_trigger_height=$DEFAULT_large_trigger_height
  GLOBAL_large_trigger_width=$DEFAULT_large_trigger_width
  GLOBAL_large_height=$DEFAULT_large_height
  GLOBAL_large_width=$DEFAULT_large_width

  GLOBAL_rotation_filename=$DEFAULT_rotation_filename
  GLOBAL_dates_filename=$DEFAULT_dates_filename
  GLOBAL_descriptions_filename=$DEFAULT_descriptions_filename
  GLOBAL_show_progress=$DEFAULT_show_progress
  GLOBAL_show_timings=$DEFAULT_show_timings
  GLOBAL_preferred_image_tools=$DEFAULT_preferred_image_tools
  GLOBAL_remove_originals=$DEFAULT_remove_originals

  GLOBAL_body_tag=$DEFAULT_body_tag
  GLOBAL_body_end_tag=$DEFAULT_body_end_tag
  GLOBAL_meta_tag=$DEFAULT_meta_tag
  GLOBAL_html_charset=$DEFAULT_html_charset
  GLOBAL_index_filename=$DEFAULT_index_filename
  GLOBAL_index_base_name=$DEFAULT_index_base_name
  GLOBAL_html_file_suffix=$DEFAULT_html_file_suffix
  GLOBAL_print_captions=$DEFAULT_print_captions
  GLOBAL_use_timestamps_as_captions=$DEFAULT_use_timestamps_as_captions
  GLOBAL_print_img_size_on_index=$DEFAULT_print_img_size_on_index
  GLOBAL_print_title_on_index=$DEFAULT_print_title_on_index
  GLOBAL_print_title_on_slideshow=$DEFAULT_print_title_on_slideshow
  GLOBAL_compact_index_page=$DEFAULT_compact_index_page
  GLOBAL_index_table_spacing=$DEFAULT_index_table_spacing
  GLOBAL_compression_level=$DEFAULT_compression_level
  GLOBAL_image_imprinting_text=$DEFAULT_image_imprinting_text

  GLOBAL_boilerplate_footer=$DEFAULT_boilerplate_footer
  GLOBAL_boilerplate_insert_in_head=$DEFAULT_boilerplate_insert_in_head
  GLOBAL_boilerplate_end_of_page=$DEFAULT_boilerplate_end_of_page
  GLOBAL_boilerplate_before_title=$DEFAULT_boilerplate_before_title
  GLOBAL_boilerplate_after_title=$DEFAULT_boilerplate_after_title
  GLOBAL_boilerplate_index_after_table_before_indexlinks=$DEFAULT_boilerplate_index_after_table_before_indexlinks
  GLOBAL_boilerplate_index_head_stuff=$DEFAULT_boilerplate_index_head_stuff
  GLOBAL_boilerplate_index_insert_in_head=$DEFAULT_boilerplate_index_insert_in_head
  GLOBAL_boilerplate_index_before_title=$DEFAULT_boilerplate_index_before_title
  GLOBAL_boilerplate_index_after_title=$DEFAULT_boilerplate_index_after_title
  GLOBAL_boilerplate_index_end_of_page=$DEFAULT_boilerplate_index_end_of_page
  GLOBAL_boilerplate_slideshow_insert_in_head=$DEFAULT_boilerplate_slideshow_insert_in_head
  GLOBAL_boilerplate_slideshow_before_title=$DEFAULT_boilerplate_slideshow_before_title
  GLOBAL_boilerplate_slideshow_after_title=$DEFAULT_boilerplate_slideshow_after_title
  GLOBAL_boilerplate_slideshow_end_of_page=$DEFAULT_boilerplate_slideshow_end_of_page

  GLOBAL_index_page_title_start_html=$DEFAULT_index_page_title_start_html
  GLOBAL_index_page_title_end_html=$DEFAULT_index_page_title_end_html
  GLOBAL_slideshow_page_title_start_html=$DEFAULT_slideshow_page_title_start_html
  GLOBAL_slideshow_page_title_end_html=$DEFAULT_slideshow_page_title_end_html

  GLOBAL_single_index_page=$DEFAULT_single_index_page
  GLOBAL_rows_per_index_page=$DEFAULT_rows_per_index_page

  GLOBAL_usa_specific_date_format_checks=$DEFAULT_usa_specific_date_format_checks
  GLOBAL_link_to_original_img_on_index=$DEFAULT_link_to_original_img_on_index
  GLOBAL_show_image_info=$DEFAULT_show_image_info
  GLOBAL_dont_change_file_permissions=$DEFAULT_dont_change_file_permissions
  GLOBAL_change_file_permissions=$DEFAULT_change_file_permissions
  GLOBAL_file_readable_permissions=$DEFAULT_file_readable_permissions
  GLOBAL_dir_transversible_permissions=$DEFAULT_dir_transversible_permissions

  GLOBAL_preview_mode=$DEFAULT_preview_mode
  GLOBAL_create_slideshow=$DEFAULT_create_slideshow
  GLOBAL_print_img_size_on_slideshow=$DEFAULT_print_img_size_on_slideshow
  GLOBAL_slideshow_img_size_across_two_lines=$DEFAULT_slideshow_img_size_across_two_lines
  GLOBAL_slideshow_images_are_clickable=$DEFAULT_slideshow_images_are_clickable
  GLOBAL_slideshow_print_javascript_navigation=$DEFAULT_slideshow_print_javascript_navigation
  GLOBAL_print_directory_title_on_slideshow_pages=$DEFAULT_print_directory_title_on_slideshow_pages
  GLOBAL_slideshow_print_bottom_navlinks=$DEFAULT_slideshow_print_bottom_navlinks
  GLOBAL_slideshow_previous_pre_link=$DEFAULT_slideshow_previous_pre_link
  GLOBAL_slideshow_previous=$DEFAULT_slideshow_previous
  GLOBAL_slideshow_previous_post_link=$DEFAULT_slideshow_previous_post_link
  GLOBAL_slideshow_next_pre_link=$DEFAULT_slideshow_next_pre_link
  GLOBAL_slideshow_next=$DEFAULT_slideshow_next
  GLOBAL_slideshow_next_post_link=$DEFAULT_slideshow_next_post_link
  GLOBAL_slideshow_ret_to_index_pre_link=$DEFAULT_slideshow_ret_to_index_pre_link
  GLOBAL_slideshow_ret_to_index=$DEFAULT_slideshow_ret_to_index
  GLOBAL_slideshow_ret_to_index_post_link=$DEFAULT_slideshow_ret_to_index_post_link
  GLOBAL_monthname_01_text=$DEFAULT_monthname_01_text
  GLOBAL_monthname_02_text=$DEFAULT_monthname_02_text
  GLOBAL_monthname_03_text=$DEFAULT_monthname_03_text
  GLOBAL_monthname_04_text=$DEFAULT_monthname_04_text
  GLOBAL_monthname_05_text=$DEFAULT_monthname_05_text
  GLOBAL_monthname_06_text=$DEFAULT_monthname_06_text
  GLOBAL_monthname_07_text=$DEFAULT_monthname_07_text
  GLOBAL_monthname_08_text=$DEFAULT_monthname_08_text
  GLOBAL_monthname_09_text=$DEFAULT_monthname_09_text
  GLOBAL_monthname_10_text=$DEFAULT_monthname_10_text
  GLOBAL_monthname_11_text=$DEFAULT_monthname_11_text
  GLOBAL_monthname_12_text=$DEFAULT_monthname_12_text

  GLOBAL_this_page_created_text=$DEFAULT_this_page_created_text
  GLOBAL_image_set_n_text=$DEFAULT_image_set_n_text
  GLOBAL_image_set_all_text=$DEFAULT_image_set_all_text
  GLOBAL_image_xx_of_yy_text=$DEFAULT_image_xx_of_yy_text
  GLOBAL_reduced_text=$DEFAULT_reduced_text
  GLOBAL_large_text=$DEFAULT_large_text
  GLOBAL_half_text=$DEFAULT_half_text
  GLOBAL_original_text=$DEFAULT_original_text
  GLOBAL_original_image_text=$DEFAULT_original_image_text
  GLOBAL_date_formatting_text=$DEFAULT_date_formatting_text

### A handful of GLOBAL_'s aren't intended to be overridden by users,
### they're things that are determined at run-time.  And here they are.
### They do not have corresponding DEFAULT_ entries.

  GLOBAL_descriptions_file_validated=0
  GLOBAL_descriptions_file_is_invalid=0
  GLOBAL_already_failed_guessing_date_from_dir=0
  GLOBAL_heuristic_filenames_are_digicam_boring=0
  GLOBAL_heuristic_days_are_identical=0
  GLOBAL_heuristic_times_are_absent=0
  GLOBAL_heuristic_filename_pattern="undef"
  GLOBAL_total_image_count=0
  GLOBAL_no_image_titles_or_descriptions=1

  GLOBAL_makethumbs_version=`echo "$GLOBAL_rcsrev" | sed 's,[^0-9.],,g'`

  GLOBAL_rcsid=`echo "$GLOBAL_rcsid" | sed -e 's,\$Id: ,,' -e 's,molenda Exp.*,,'`
}

parse_args ()
{
  local optname optarg

  while [ $# -gt 0 ]
  do
    optname="`echo $1 | sed 's,=.*,,'`"
    optarg="`echo $1 | sed 's,^[^=]*=,,'`"
    case "$1" in
      --maxthumbsize=* | --max-thumb-size=*)
             optarg=`echo $optarg | sed 's,[^0-9],,g'`
             exit_if_empty "$optname" "$optarg"
             ARGV_max_thumb_size=$optarg
             GLOBAL_max_thumb_size=$ARGV_max_thumb_size
           ;;
      --columns=* | --cols=*)
             optarg=`echo $optarg | sed 's,[^0-9],,g'`
             exit_if_empty "$optname" "$optarg"
             ARGV_columns=$optarg
             GLOBAL_columns=$optarg
           ;;
      --one-index-page* | --one-index*)
             ARGV_single_index_page=1
             GLOBAL_single_index_page=$ARGV_single_index_page
           ;;
      --use-two-windows*|--enable-two-windows|--with-two-windows)
             ARGV_use_two_windows=1
             GLOBAL_use_two_windows=$ARGV_use_two_windows
           ;;
      --remove-orig*)
             ARGV_remove_originals=1
             GLOBAL_remove_originals=$ARGV_remove_originals
           ;;
      --progress)
             ARGV_show_progress=1
             GLOBAL_show_progress=$ARGV_show_progress
           ;;
      --quiet | -q)
             ARGV_show_progress=0
             GLOBAL_show_progress=$ARGV_show_progress
           ;;
      --disable-reduce|--without-reduce)
             ARGV_reduce_big_pics=0
             GLOBAL_reduce_big_pics=$ARGV_reduce_big_pics
           ;;
      --disable-slideshow|--without-slideshow)
             ARGV_create_slideshow=0
             GLOBAL_create_slideshow=$ARGV_create_slideshow
           ;;
      --enable-reduce|--with-reduce)
             ARGV_reduce_big_pics=1
             GLOBAL_reduce_big_pics=$ARGV_reduce_big_pics
           ;;
      --compact-index|--compact)
             ARGV_compact_index_page=1
             GLOBAL_compact_index_page=$ARGV_compact_index_page
           ;;
      --reduce-height=*)
             optarg=`echo $optarg | sed 's,[^0-9],,g'`
             exit_if_empty "$optname" "$optarg"
             ARGV_reduce_height=$optarg
             GLOBAL_reduce_height=$ARGV_reduce_height
           ;;
      --reduce-width=*)
             optarg=`echo $optarg | sed 's,[^0-9],,g'`
             exit_if_empty "$optname" "$optarg"
             ARGV_reduce_width=$optarg
             GLOBAL_reduce_width=$ARGV_reduce_width
           ;;
      --reduce-trigger-height=*)
             optarg=`echo $optarg | sed 's,[^0-9],,g'`
             exit_if_empty "$optname" "$optarg"
             ARGV_reduce_trigger_height=$optarg
             GLOBAL_reduce_trigger_height=$ARGV_reduce_trigger_height
           ;;
      --reduce-trigger-width=*)
             optarg=`echo $optarg | sed 's,[^0-9],,g'`
             exit_if_empty "$optname" "$optarg"
             ARGV_reduce_trigger_width=$optarg
             GLOBAL_reduce_trigger_width=$ARGV_reduce_trigger_width
           ;;
      --compression-level=*|--compression=*)
             optarg=`echo $optarg | sed 's,[^0-9],,g'`
             exit_if_empty "$optname" "$optarg"
             ARGV_compression_level=$optarg
             GLOBAL_compression_level=$ARGV_compression_level
           ;;
      --preview_mode|--preview|--preview-mode|-p)
             ARGV_preview_mode=1
             GLOBAL_preview_mode=1
           ;;
      --clean | --cleanup)
             do_cleanup
             exit 0
           ;;
      -h | --help | -v | --version | -V)
             help
             exit 1
           ;;
      -*)
             echo "`basename $0`: ERROR: Unrecognized option \"$1\"" >&2
           ;;
      *)
             ARGV_image_list="$ARGV_image_list $1"
           ;;
    esac
    shift
  done

  handle_complex_variable_settings
}

help ()
{
# The following exec goop so I don't have to manually redirect every
# message to stderr in this function.
  exec 4>&1    # save stdout fd to fd #4
  exec 1>&2    # redirect stdout to stderr

cat <<__EOM__
Usage: `basename $0` [options]

--compact-index     Create a compact index page to pack in lots of thumbnails
--maxthumbsize=n    Maximum size of thumbnails, in pixels, default $DEFAULT_max_thumb_size
--columns=n         Number of thumbnails per line, default $DEFAULT_columns
--disable-reduce    Don't create a reduced image if the picture is large
--disable-slideshow Don't create slideshow files
--clean             Remove all makethumbs-generated files
--compression=n     Set JPEG compression percentage to n for generated images.
                    Default is 75.  Things usually look OK down to the 40-50's.

--preview-mode      (Or '-p') Preview mode - quick index page generation.
                    Useful for checking rotations, index appearance.
--one-index-page    Only create a single index page.  Default is to put 10 rows
                    on each index page, creating as many pages as necessary.
--use-two-windows   Bring up a new window to see images, default is `[ $DEFAULT_use_two_windows -eq 1 ] && echo enabled || echo disabled`
__EOM__

if [ $DEFAULT_show_progress -eq 1 ]
then
  echo '--quiet             Avoid unnecessary output while running'
else
  echo '--progress          Show progress updates as the script runs'
fi

cat <<__EOM__
--remove-originals  Remove original images if we make reduced versions.
                    Useful when disk space is limited; default is `[ $DEFAULT_remove_originals -eq 1 ] && echo enabled || echo disabled`
                    WARNING!!! This option *will* remove your original images
                               if reduced images are available!

Run this script in a directory of JPEG files to create thumbnail images and
HTML pages.  Makethumbs will not overwrite any files you've created by hand.
Makethumbs will not modify your original images.  Makethumbs will not
corrupt your precious bodily fluids.

You can permanently override options by creating a ~/.makethumbsrc file.
Many more features can be tweaked via the .makethumbsrc file.  See the
documentation on the makethumbs home page for more information.  You should
not need to modify makethumbs or the HTML it generates.

This script written by Jason Molenda, makethumbs(AT)molenda.com.
This is version ${GLOBAL_makethumbs_version}.

The latest version of this script is always available at
http://www.molenda.com/makethumbs/
__EOM__
  exec 1>&4   # Copy stdout fd back from temporary save fd, #4
}

# RETURN_found is 1 if found, 0 if not found.  If found, $RETURN_fullname
# contains the path + filename.
find_in_path ()
{
    local OFS i target dir

    target="$*"
    RETURN_fullname=""
    RETURN_found=0
    OFS="$IFS"
    IFS=:
    for i in $PATH
    do
      [ -z "$i" ] && i="."
      if [ -f "$i/$target" ]
      then
        RETURN_fullname="$i/$target"
        RETURN_found=1
        break
      fi
    done
    IFS="$OFS"
}

# With a couple of options, setting those options implies a few other
# settings.

handle_complex_variable_settings ()
{
  if [ $GLOBAL_compact_index_page -eq 1 ] && \
     [ -n "$DOTRC_compact_index_page" -o -n "$ARGV_compact_index_page" ]
  then
    if [ -z "$ARGV_max_thumb_size" -a -z "$DOTRC_max_thumb_size" ]
    then
      GLOBAL_max_thumb_size=75
    fi
    if [ -z "$ARGV_print_captions" -a -z "$DOTRC_print_captions" ]
    then
      GLOBAL_print_captions=0
    fi
    if [ -z "$ARGV_columns" -a -z "$DOTRC_columns" ]
    then
      GLOBAL_columns=6
    fi
    if [ -z "$ARGV_index_table_spacing" -a -z "$DOTRC_index_table_spacing" ]
    then
      GLOBAL_index_table_spacing="tight"
    fi
  fi

  if [ $GLOBAL_preview_mode -eq 1 ] && \
     [ -n "$DOTRC_preview_mode" -o -n "$ARGV_preview_mode" ]
  then
    if [ -z "$ARGV_create_slideshow" -a -z "$DOTRC_create_slideshow" ]
    then
      GLOBAL_create_slideshow=0
    fi
    if [ -z "$ARGV_reduce_big_pics" -a -z "$DOTRC_reduce_big_pics" ]
    then
      GLOBAL_reduce_big_pics=0
    fi
    if [ -z "$ARGV_create_large_images" -a -z "$DOTRC_create_large_images" ]
    then
      GLOBAL_create_large_images=0
    fi
  fi
}



# Parse a user's $HOME/.makethumbsrc.  The code here is kind of
# funky because I didn't want to just bourne-shell source the file
# (". $HOME/.makethumbsrc"); any syntax error in that startup file
# would have caused makethumbs to fail in weird ways and users could have
# trouble debugging it.  It's a huge amount of work to get all the parsing
# correct so spaces, quote marks, apostrophies, etc., are all carried over
# accurately.  The sed expression where $value gets set is not something
# I'm too proud of - this is always the sort of thing that is tricky in
# Bourne shell.
read_dotrc_file ()
{
  local this_dotrc tmpf varname varname_is_valid line value curval

  for this_dotrc in $HOME/.makethumbsrc $HOME/.makethumbs $HOME/makethumbsrc \
                    ../../.makethumbsrc ../../.makethumbs ../../makethumbsrc \
                    ../.makethumbsrc ../.makethumbs ../makethumbsrc \
                    .makethumbsrc .makethumbs makethumbsrc
  do
    [ ! -f "$this_dotrc" ] && continue

    make_tmpfile dotrc
    tmpf=$RETURN_tmpfile

    cat "$this_dotrc" | grep -v '^[ 	]*#' | grep = > $tmpf
    [ ! -s $tmpf ] && continue

    while read line
    do
      varname_is_valid=0

      varname=`echo "$line" | sed -e 's,=.*,,' -e 's,[^A-Za-z_0-9],,g' \
                                  -e 's,^ARGV_,,' -e 's,^GLOBAL_,,'    \
                                  -e 's,^DEFAULT_,,' -e 's,^DOTRC_,,'`

# Eliminate whitespace, quotes around the value
      value=`echo "$line" | sed -e 's,^[^=]*=,,' -e 's,^[ 	]*,,' \
                                -e 's,[ 	]*$,,'                \
                                -e s,^\[\"\'\]\[\ \	\]\*,,        \
                                -e s,\[\ \	\]\*\[\"\'\]\$,,`

      if echo "$varname" | grep -i '_FILE$' >/dev/null 2>&1
      then
        read_in_file_contents "$value"
        if [ $RETURN_file_found -eq 1 ]
        then
          value=`echo "$RETURN_file_contents" | grep -v '^[ 	]*$'`
        else
          echo WARNING: Unable to read in file "$value" for variable "$varname" 2>&1
          continue
        fi
        varname=`echo "$varname" | sed 's,_[Ff][Ii][Ll][Ee]$,,'`
      fi

      eval [ -n \"\$GLOBAL_$varname\" ] && varname_is_valid=1

      if [ $varname_is_valid -eq 0 ]
      then
        echo ERROR: "$this_dotrc" has unrecognized variable name, \"$varname\"!>&2
        continue
      fi

# Try to do a little verification if the current value is numeric.  I could
# probably add some extra checks if the current val is 0 or 1, making an
# assumption that it's a boolean value.  (someone might try to use "yes"
# instead of '1', for instance)
      curval=`eval echo \\$GLOBAL_$varname`
      if echo "$curval" | grep '^[0-9]*$' >/dev/null 2>&1
      then
        if [ -z "$value" ]
        then
          echo WARNING: Variable $varname currently has a numeric value of $curval >&2
          echo WARNING: but you\'re setting it to an empty value. >&2
        else
          if echo "$value" | grep '^[0-9]*$' >/dev/null 2>&1
          then
            :
          else
            echo WARNING: Variable $varname currently has a numeric value of $curval >&2
            echo WARNING: but you\'re setting it to \"$value\".  >&2
          fi
        fi
      fi

      eval DOTRC_$varname='$value'
      eval GLOBAL_$varname=\$DOTRC_$varname
    done < $tmpf
  done

  handle_complex_variable_settings
  check_for_obsolete_settings
  check_for_invalid_settings
}


# A variable might be a filename instead of a value.  This function
# checks to see if such a file exists and returns the fully qualified
# pathname if it does.

read_in_file_contents ()
{
  local fn i

  RETURN_file_found=0
  RETURN_file_contents=""
  fn="$*"

# Try to expand these via eval
  if echo "$fn" | egrep '^(~|[$]HOME)' >/dev/null 2>&1
  then
    fn=`eval echo "$fn"`
  fi

# Not all Bourne shells will expand tilde.
  if echo "$fn" | egrep '^~/' >/dev/null 2>&1
  then
    fn=`echo "$fn" | sed 's,~/,,'`
  fi

  if [ -f "$fn" ]
  then
    RETURN_file_found=1
    RETURN_file_contents=`cat "$fn"`
    return
  fi

  for i in . $HOME ..
  do
    if [ -f "$i/$fn" ]
    then
      RETURN_file_found=1
      RETURN_file_contents=`cat "$i/$fn"`
      return
    fi
  done
}

# I have to change variable names sometimes, and the warnings and
# remappings are all here.
check_for_obsolete_settings ()
{

  if [ -n "$DOTRC_boilerplate_index_head_stuff" ] && \
     [ "$DOTRC_boilerplate_index_head_stuff" != "undef" -a \
       "$DOTRC_boilerplate_index_head_stuff" != "obsolete" ]
  then
    echo 'WARNING: The variable boilerplate_index_head_stuff has been renamed' 1>&2
    echo '         to boilerplate_index_insert_in_head.' 1>&2
    DOTRC_boilerplate_index_insert_in_head="$DOTRC_boilerplate_index_head_stuff"
    GLOBAL_boilerplate_index_insert_in_head="$DOTRC_boilerplate_index_insert_in_head"
  fi

  if [ -n "$DOTRC_dont_change_file_permissions" ] && \
     [ "$DOTRC_dont_change_file_permissions" != "undef" -a \
       "$DOTRC_dont_change_file_permissions" != "obsolete" ]
  then
    echo 'WARNING: The variable dont_change_file_permissions has been renamed' 1>&2
    echo '         to change_file_permissions, with the opposite setting, for' 1>&2
    echo '         consistency.  It will be unrecognized in a future version.' 1>&2
    if [ $DOTRC_dont_change_file_permissions -eq 1 ]
    then
      DOTRC_change_file_permissions=0
    else
      DOTRC_change_file_permissions=1
    fi
    GLOBAL_change_file_permissions=$DOTRC_change_file_permissions
    echo "         e.g. make it \"change_file_permissions=$DOTRC_change_file_permissions\"" 1>&2
  fi
}

check_for_invalid_settings ()
{
  if [ -n "$DOTRC_columns" -a "$DOTRC_columns" = "0" ]
  then
    echo ERROR: Invalid setting of \"columns\" to zero!  Exiting. 1>&2
    exit 1
  fi
}

# Returns a temp file in $RETURN_tmpfile.
# Takes an optional description name argument.
make_tmpfile ()
{
  make_tmpfile_in_a_dir "$TMPDIR" "$1"
}

make_tmpfile_in_cwd ()
{
  make_tmpfile_in_a_dir . "$1"
}

# Returns a temp file in $RETURN_tmpfile.
make_tmpfile_in_a_dir ()
{
  local base_tmpfile n dir name

  dir="$1"
  name="$2"

  [ -z "$dir" ] && dir="$TMPDIR"
  if [ $GLOBAL_mktemp_is_present -eq 1 ]
  then
    RETURN_tmpfile=`mktemp -q "$dir/makethumbs-${name}.XXXXXXX"`
    touch "$RETURN_tmpfile"
    if [ $? -eq 0 -a ! -L "$RETURN_tmpfile" -a -O "$RETURN_tmpfile" ]
    then
      make_file_owner_read_writable "$RETURN_tmpfile"
      add_cleanup "$RETURN_tmpfile"
      return
    fi
  fi

  base_tmpfile="$dir/makethumbs-${name}.$$"
  RETURN_tmpfile="$base_tmpfile"
  n=0
  while [ -f "$RETURN_tmpfile" ]
  do
    n=`expr $n + 1`
    RETURN_tmpfile="${base_tmpfile}-$n"
  done
  touch "$RETURN_tmpfile"
  if [ -L "$RETURN_tmpfile" -o ! -O "$RETURN_tmpfile" ]
  then
    echo "ERROR: Did someone try to spoof my tmp file \"$RETURN_tmpfile\"?" 1>&2
    echo "ERROR: I don't know what's up with that.  Aborting."
    exit 1
  fi
  make_file_owner_read_writable "$RETURN_tmpfile"
  add_cleanup "$RETURN_tmpfile"
  return
}

# Ends program execution if necessary programs can't be found.
check_for_necessary_programs ()
{
  local missed_something progname t
  missed_something=0

  if [ $GLOBAL_gawk_is_present -eq 1 ]
  then
    AWK=gawk
  else
    AWK=awk
  fi

# Old fashioned awk's don't seem to have a gensub () function.  The one place
# where I use will use perl instead.  Boo!

  t=`echo "hi hi hi" | $AWK '{print gensub ("hi", "so &", "g", $0);}' 2>/dev/null`
  if [ -n "$t" -a "$t" = "so hi so hi so hi" ] || [ $GLOBAL_perl_is_present -eq 0 ]
  then
    GLOBAL_date_parser_program="awk"
  else
    GLOBAL_date_parser_program="perl"
  fi

# For now, pull these two checks because we can usually get by without them
# and older netpbm's don't have them.
#       $GLOBAL_tifftopnm_is_present -eq 1 -a \
#       $GLOBAL_pngtopnm_is_present -eq 1 -a \

  if [ $GLOBAL_pnmfile_is_present -eq 1 -a \
       $GLOBAL_giftopnm_is_present -eq 1 -a \
       $GLOBAL_pnmscale_is_present -eq 1 -a \
       $GLOBAL_pnmrotate_is_present -eq 1 ]
  then
    GLOBAL_netpbm_is_available=1
  else
    GLOBAL_netpbm_is_available=0
  fi

  if [ $GLOBAL_mogrify_is_present -eq 1 -a \
       $GLOBAL_convert_is_present -eq 1 -a \
       $GLOBAL_identify_is_present -eq 1 ]
  then
    GLOBAL_imagemagick_is_available=1
  else
    GLOBAL_imagemagick_is_available=0
  fi

  if [ $GLOBAL_cjpeg_is_present -eq 1 -a \
       $GLOBAL_djpeg_is_present -eq 1 ]
  then
    GLOBAL_jpegsrc_is_available=1
  else
    GLOBAL_jpegsrc_is_available=0
  fi

  if [ $GLOBAL_sips_is_present -eq 1 ]
  then
    GLOBAL_sips_is_available=1
  else
    GLOBAL_sips_is_available=0
  fi
  if [ -f "/System/Library/ColorSync/Profiles/sRGB Profile.icc" ]
  then
    GLOBAL_sips_profile_convert_cmd1="--setProperty"
    GLOBAL_sips_profile_convert_cmd2="profile"
    GLOBAL_sips_profile_convert_cmd3="/System/Library/ColorSync/Profiles/sRGB Profile.icc"
  else
    GLOBAL_sips_profile_convert_cmd1=""
    GLOBAL_sips_profile_convert_cmd2=""
    GLOBAL_sips_profile_convert_cmd3=""
  fi

  if [ $GLOBAL_imagemagick_is_available -eq 0 -a \
       $GLOBAL_sips_is_available -eq 0 ]
  then
    if [ $GLOBAL_jpegsrc_is_available -eq 0 ]
    then
      echo ERROR: You need to install the jpeg utilities. >&2
      echo ERROR: You may be able to find a copy of this at ftp://ftp.uu.net/graphics/jpeg >&2
      echo ERROR: Or check the IJG home page http://www.ijg.org/ >&2
      missed_something=1
    fi
    if [ $GLOBAL_netpbm_is_available -eq 0 ]
    then
      echo ERROR: You need to install the \"netpbm\" utilities. >&2
      echo ERROR: You can find this at http://netpbm.sourceforge.net/ >&2
      missed_something=1
    fi
  fi

  if [ $missed_something -eq 1 ]
  then
    echo "" >&2
    echo ERROR: You will find all the necessary utilities pre-installed >&2
    echo ERROR: on most Linux systems. >&2
    exit 1
  fi

  if [ "$GLOBAL_preferred_image_tools" = "sips" -a \
       $GLOBAL_sips_is_available -eq 1 ]
  then
    GLOBAL_tools_to_use=sips
  elif [ "$GLOBAL_preferred_image_tools" = "imagemagick" -a \
          $GLOBAL_imagemagick_is_available -eq 1 ]
  then
    GLOBAL_tools_to_use=imagemagick
  elif [ "$GLOBAL_preferred_image_tools" = "netpbm" -a \
          $GLOBAL_jpegsrc_is_available -eq 1 -a \
          $GLOBAL_netpbm_is_available -eq 1 ]
  then
    GLOBAL_tools_to_use=netpbm
  elif [ $GLOBAL_sips_is_available -eq 1 ]
  then
    GLOBAL_tools_to_use=sips
  elif [ $GLOBAL_netpbm_is_available -eq 1 -a \
         $GLOBAL_jpegsrc_is_available -eq 1 ]
  then
    GLOBAL_tools_to_use=netpbm
  elif [ $GLOBAL_imagemagick_is_available -eq 1 ]
  then
    GLOBAL_tools_to_use=imagemagick
  else
    GLOBAL_tools_to_use=undef
  fi
}

set_environment ()
{
  IFS=" 	
  "
  export IFS
  TMPDIR=${TMPDIR-/tmp}

# Some of the optional programs makethumbs runs suck and will dump
# core with the slightest provocation - suppress that if possible.

  ulimit -c 0 >/dev/null 2>&1

# Make sure dd does sensible things.  I can't imagine this doesn't
# work, but I'm being paranoid.
  GLOBAL_dd_works_well=0
  if [ $GLOBAL_dd_is_present -eq 1 ]
  then
    bytesread=`yes 2>/dev/null | dd bs=1024 count=1 2>/dev/null | wc -c | sed 's,[^0-9],,g'`
    if [ "$bytesread" -ge 1023 -a "$bytesread" -le 1025 ]
    then
      GLOBAL_dd_works_well=1
    fi
  fi
  
# POSIX 1003.2 doesn't guarantee that echo -n works -- some systems (OK, Solaris)
# require you to put "\c" at the end of the line to avoid the line wrap.
# The general idea here was lifted from autoconf.

  if [ x`(echo -n foo; echo bar) | grep foobar` = xfoobar ]
  then
    ac_n="-n"
    ac_c=""
  else
    ac_n=""
    if [ x`(echo 'foo\c'; echo bar) | grep foobar` = xfoobar ]
    then
      ac_c='\c'
    fi
  fi

# Detect if the 'local' keyword, a somewhat edgy extension to the Bourne
# shell language (har har) is supported.  If not, try to run a shell that
# does support it.  Flow of control won't make it past this part of the
# function--it usually will either return or exec another program.

  testvar=testval
  check_if_local_supported

  if [ "x$MAKETHUMBS_AVOID_INF_LOOP" != "x" -a $testvar != testval ]
  then
    echo "Hm, I re-ran myself but local still doesn't work.  Sigh.  We'll see what happens." 1>&2
    return
  fi

  if [ $testvar = testval ]
  then
    return
  fi

  for shell in bash ksh
  do
    find_in_path $shell
    if [ $RETURN_found -eq 1 ]
    then
      echo "Ignore any warnings about 'local' - will try rerunning under ${shell}." 1>&2
      echo "You can skip this rerun step by changing the first line of this script to read" 1>&2
      echo "#! $RETURN_fullname" 1>&2
      echo "Or leave it as it is -- not a big deal." 1>&2
      MAKETHUMBS_AVOID_INF_LOOP=didrun
      export MAKETHUMBS_AVOID_INF_LOOP
      exec $shell $0 ${1+"$@"}
    fi
  done

  echo "WARNING:  This shell does not seem to support the locak keyword but I" 1>&2
  echo "          could not find a better shell... things may not work well." 1>&2

}

check_if_local_supported ()
{
  local testvar
  testvar=not-testval
}

# Look around and see what programs are installed in $PATH.
find_programs ()
{
  local prog varname

  for prog in metacam jhead dphotox dump-exif gphoto-exifdump exif \
              mktemp \
              cjpeg djpeg rdjpgcom \
              pnmfile giftopnm tifftopnm pngtopnm pnmscale pnmrotate \
              jpegtopnm ppmtojpeg \
              mogrify identify convert \
              dd awk gawk perl sips
  do
    varname=`echo $prog | tr -d '-'`
    find_in_path $prog
    if [ $RETURN_found -eq 1 ]
    then
      eval GLOBAL_${varname}_is_present=1
    else
      eval GLOBAL_${varname}_is_present=0
    fi
  done
}

enable_atexit_trap_handler ()
{
  trap "atexit  0"  0
  trap "atexit  1"  1
  trap "atexit  2"  2
  trap "atexit 15" 15
}

add_cleanup ()
{
  GLOBAL_cleanuplist="$GLOBAL_cleanuplist $*"
}

remove_cleanup ()
{
  local fn
  fn="$*"

  GLOBAL_cleanuplist=`echo $GLOBAL_cleanuplist | sed "s|${fn}||"`
}

atexit ()
{
  trap "" 0 1 2 15
  [ -n "$GLOBAL_cleanuplist" ] && rm -f $GLOBAL_cleanuplist
  if [ -n "$1" -a "$1" != 0 ]
  then
    echo "" 1>&2
  fi
  [ -n "$1" ] && exit $1
  exit 1
}


# Unnecessary paranoia - makethumbs can successfully operate even
# if you have a umask of 777 thanks to this function.  What the heck.

make_file_owner_read_writable ()
{
  [ $GLOBAL_change_file_permissions -eq 0 ] && return
  [ -f "$*" ] && chmod u+rw "$*"
}

# Only accepts *one* argument, which may contain space chars.
make_file_world_readable ()
{
  make_file_owner_read_writable "$*"

  [ $GLOBAL_change_file_permissions -eq 0 ] && return
  if [ -f "$*" -a -n "$GLOBAL_file_readable_permissions" ]
  then
    chmod "$GLOBAL_file_readable_permissions" "$*"
  fi
}


# Only accepts *one* argument, which may contain space chars.
make_dir_transversible ()
{
  [ $GLOBAL_change_file_permissions -eq 0 ] && return
  if [ -d "$*" -a -n "$GLOBAL_dir_transversible_permissions" ]
  then
    chmod "$GLOBAL_dir_transversible_permissions" "$*"
  fi
}

exit_if_empty ()
{
  local desc val

  desc="$1"
  shift
  val="$*"

  if [ -z "$val" ]
  then
    echo ERROR: No argument given with \"$desc\" command line argument! >&2
    exit 1
  fi
}

do_cleanup ()
{
  local fn indexes

  get_image_list

  move_to_backup_file "$GLOBAL_descriptions_filename"
  move_to_backup_file "$GLOBAL_dates_filename"
  indexes=`ls ${GLOBAL_index_base_name}.${GLOBAL_html_file_suffix} \
        ${GLOBAL_index_base_name}-all.${GLOBAL_html_file_suffix} \
        ${GLOBAL_index_base_name}-[0-9].${GLOBAL_html_file_suffix} \
        ${GLOBAL_index_base_name}-[0-9][0-9].${GLOBAL_html_file_suffix} \
        ${GLOBAL_index_base_name}-[0-9][0-9][0-9].${GLOBAL_html_file_suffix} \
         2>/dev/null`
  if [ -n "$indexes" ]
  then
    for fn in $indexes
    do
      remove_or_move_file_aside "$fn"
    done
  fi

  remove_existing_slideshow_html_files

  while read fn
  do
    source_name_to_half_name "$fn"
    [ "$fn" != "$RETURN_half_name" ] && rm -f "$RETURN_half_name"
    source_name_to_large_name "$fn"
    [ "$fn" != "$RETURN_large_name" ] && rm -f "$RETURN_large_name"
    source_name_to_reduced_name "$fn"
    [ "$fn" != "$RETURN_reduced_name" ] && rm -f "$RETURN_reduced_name"
    source_name_to_feed_name "$fn"
    [ "$fn" != "$RETURN_feed_name" ] && rm -f "$RETURN_feed_name"
    source_name_to_thumb_name "$fn"
    [ "$fn" != "$RETURN_thumb_name" ] && rm -f "$RETURN_thumb_name"
  done < $GLOBAL_image_list_tmpfile
}

remove_or_move_file_aside ()
{
  local fn
  fn="$*"

  [ ! -f "$fn" ] && return
  remove_file_if_unmodified "$fn"
  [ ! -f "$fn" ] && return
  move_to_backup_file "$fn"
}

move_to_backup_file ()
{
  local fn i most_recent_backup
  fn="$*"

  [ ! -f "${fn}" ] && return

  if [ ! -f "${fn}~" ]
  then
    mv "$fn" "${fn}~"
    return
  fi

  most_recent_backup=`ls -1t "${fn}~" ${fn}~* 2>/dev/null | head -1`
  if cmp "${fn}" "$most_recent_backup" >/dev/null 2>&1
  then
    rm -f "${fn}"
    touch "$most_recent_backup"
    return
  fi

  i=1
  while [ -f "${fn}~${i}~" -a $i -le 50 ]
  do
    i=`expr $i + 1`
  done

  if [ ! -f "${fn}~${i}~" ]
  then
    mv "$fn" "${fn}~${i}~"
    return
  fi
}

#########################################################
#### Start of real makethumbs image stuff functions
#########################################################


# Sets file at $GLOBAL_image_list_tmpfile with images to process.
# Tries to normalize filename extensions.
get_image_list ()
{
  local prelim_image_tmpfile i normalized_filename filename
  local t

  make_tmpfile first-image-list
  prelim_image_tmpfile="$RETURN_tmpfile"
  make_tmpfile image-list
  GLOBAL_image_list_tmpfile="$RETURN_tmpfile"

  if [ -n "$ARGV_image_list" ]
  then
    for i in $ARGV_image_list
    do
      echo $i >> $prelim_image_tmpfile
    done
  else
    ls -1 | egrep -i '\.jpg$|\.jpeg$|\.png$|\.gif$' > $prelim_image_tmpfile
  fi

  cat $prelim_image_tmpfile | while read filename
  do
    [ -s "$filename" ] || continue
    if echo "$filename" | egrep -- '-[bfhtrl].(jpg|gif|png)$' >/dev/null 2>&1
    then
      continue
    fi

    normalized_filename=`echo "$filename" |
              sed -e 's,.JPG$,.jpg,' -e 's,.jpeg$,.jpg,' -e 's,.JPEG$,.jpg,' \
                  -e 's,.PNG$,.png,' -e 's,.GIF$,.gif,'`

    move_a_file_in_the_face_of_adversity "$filename" "$normalized_filename"

    if [ $RETURN_new_and_old_are_identical -eq 0 -a \
         $RETURN_did_move_file -eq 0 ]
    then
      echo "WARNING:  Unable to move \"$filename\" to \"$normalized_filename\"!" 1>&2
      if [ $RETURN_new_file_exists -eq 1 -a $RETURN_old_file_exists -eq 1 ]
      then
        echo "WARNING:  In fact, both seem to exist.  Yech!  Will try to continue." 1>&2
        continue
      fi
    fi

    if [ $RETURN_new_file_exists -eq 1 ]
    then
      filename="$normalized_filename"
    fi

    make_file_world_readable "$filename"
    echo "$filename" >> $GLOBAL_image_list_tmpfile
  done

  if [ ! -s "$GLOBAL_image_list_tmpfile" ]
  then
    echo ERROR: No images found! >&2
    exit 1
  fi
}


# The silly way I move files via a temp file is for case-preserving
# but case-insensitive filesystems like MacOS's HFS+ or Windows' NTFS.
# On those, doing "mv foo.JPG foo.jpg" is an error, and testing for either
# file will return true all the time.  Sigh.

# The hokey stuff with looking at file-basename.[jJpPgG][pPnNiI][gGgGfF]
# is because these filesystems will, when you do
# ls -1 foo.JPG | egrep foo.JPG
# return foo.JPG regardless of whether the file is called foo.jpg or foo.JPG.
# How lame.  Using a glob tricks it into returning the true extension.

move_a_file_in_the_face_of_adversity ()
{
  local src dest t tfile
  local src_egrep dest_egrep src_basename dest_basename

  RETURN_did_move_file=0
  RETURN_old_file_exists=0
  RETURN_new_file_exists=0
  RETURN_new_and_old_are_identical=0

  src="$1"
  dest="$2"

  quote_egrep_chars "$src"
  src_egrep="$RETURN_egrep"
  quote_egrep_chars "$dest"
  dest_egrep="$RETURN_egrep"

  src_basename=`echo "$src" | sed 's,\.[jpgpnggifJPGPNGGIF]*$,,'`

  if [ "$src" != "$dest" ]
  then
    dest_basename=`echo "$dest" | sed 's,\.[jpgpnggifJPGPNGGIF]*$,,'`
    t=`ls -1 "${dest_basename}."[jJpPgG][pPnNiI][gGgGfF] 2>/dev/null |
       egrep "$dest_egrep"`
    if [ -z "$t" ]
    then
      make_tmpfile_in_cwd filemover
      remove_cleanup "$RETURN_tmpfile"  # don't remove this one...
      tfile="$RETURN_tmpfile"
      mv "$src" "$tfile" && mv "$tfile" "$dest" && RETURN_did_move_file=1
    fi
    t=`ls -1 "${src_basename}."[jJpPgG][pPnNiI][gGgGfF] 2>/dev/null |
       egrep "$src_egrep"`
    [ -n "$t" ] && RETURN_old_file_exists=1
    t=`ls -1 "${dest_basename}."[jJpPgG][pPnNiI][gGgGfF] 2>/dev/null |
       egrep "$dest_egrep"`
    [ -n "$t" ] && RETURN_new_file_exists=1
  else
    RETURN_new_and_old_are_identical=1
    t=`ls -1 "${src_basename}."[jJpPgG][pPnNiI][gGgGfF] 2>/dev/null |
       egrep "$src_egrep"`
    [ -n "$t" ] && RETURN_old_file_exists=1
    [ -n "$t" ] && RETURN_new_file_exists=1
  fi
}

# Use the order of filenames in the descriptions.txt [captions] section
# to determine the order that they'll be presented on the web page.

reorder_image_list ()
{
  local newlist fn newsize oldsize
  get_caption_filenames_from_descriptions_file
  [ -z "$RETURN_captions_tmpfile" ] && return
  [ ! -s "$RETURN_captions_tmpfile" ] && return

  make_tmpfile newlist
  newlist="$RETURN_tmpfile"

  while read fn
  do
    quote_egrep_chars "$fn"
    if egrep "^${RETURN_egrep}\$" $newlist >/dev/null 2>&1
    then
      continue
    fi
    if egrep "^${RETURN_egrep}\$" $GLOBAL_image_list_tmpfile >/dev/null 2>&1
    then
      echo "$fn" >> $newlist
    fi
  done < $RETURN_captions_tmpfile

  while read fn
  do
    quote_egrep_chars "$fn"
    if egrep "^${RETURN_egrep}\$" $newlist >/dev/null 2>&1
    then
      :
    else
      echo "$fn" >> $newlist
    fi
  done < $GLOBAL_image_list_tmpfile

  newsize=`ls -l $newlist | awk '{print $5}'`
  oldsize=`ls -l $GLOBAL_image_list_tmpfile | awk '{print $5}'`

# I don't know... is there a case where the new one could be smaller?
# Maybe a duplicate could be in the original list, and that'd be eliminated
# by the reordering.  I'll skip the obvious check for now.
  if [ -n "$newsize" -a -n "$oldsize" -a $newsize -gt 0 ]
  then
    cat $newlist > $GLOBAL_image_list_tmpfile
  fi
}

iterate_over_image_list ()
{
  local col first_row fn filelist indexno

  indexno="$1"
  col=0
  first_row=1
  GLOBAL_last_row_was_closed=0

  make_tmpfile thislist-$indexno
  filelist="$RETURN_tmpfile"
  if [ "$indexno" = "allinone" ]
  then
    cat $GLOBAL_image_list_tmpfile > $filelist
  else
    grep "^$indexno " $GLOBAL_image_indexpages | sed 's,^[0-9]* ,,' > $filelist
  fi

  while read fn
  do
    if [ $col -eq 0 ]
    then
      print_html_row_start
      GLOBAL_last_row_was_closed=0
    fi
    print_html_column_start
    print_image_entry "$fn"
    print_html_column_end
    col=`expr $col + 1`
    if [ $col -eq $GLOBAL_columns ]
    then
      print_html_row_end
      col=0
      GLOBAL_last_row_was_closed=1
    fi
  done < $filelist
}

print_image_entry ()
{
  local fn thumb_width thumb_height was_reduced

  fn="$*"
  source_name_to_thumb_name "$fn"
  get_dimensions "$RETURN_thumb_name"
  thumb_width=$RETURN_width
  thumb_height=$RETURN_height

  reduced_file_exists "$fn"
  was_reduced=$RETURN_reduced_exists

  print_image_link $thumb_width $thumb_height $was_reduced "$fn"
  print_image_size "$fn"
}

# Only remove JPG images.  Removing GIF/PNG images is a little tricky -
# see the RCS comment on rev 1.60 for more details on why this is tricky.
# FIXME:  This function is incorrect given 'large' images - they should
# become the plain files if they exist, not the reduced ones.
maybe_remove_original ()
{
  local name reduced_name large_name old_name
  local quote_egrep_chars t

  name="$*"
  RETURN_original_removed=0

  [ $GLOBAL_remove_originals -eq 0 ] && return
  [ ! -f "$name" ] && return
  if echo "$name" | grep -v '\.jpg$' > /dev/null 2>&1
  then
    return
  fi

# Have we already removed this file in the past?  i.e. the "original"
# that we're currently looking at is actually a reduced/large/half image
# that was promoted to "original" in a previous --remove-originals run.

  if [ -f removed-file-list.txt ]
  then
    quote_egrep_chars "$name"
    t=`egrep "^${RETURN_egrep}\$" removed-file-list.txt`
    if [ -n "$t" ]
    then
      return
    fi
  fi

  source_name_to_reduced_name "$name"
  reduced_name="$RETURN_reduced_name"
  source_name_to_large_name "$name"
  large_name="$RETURN_large_name"
  source_name_to_half_name "$name"
  half_name="$RETURN_half_name"

  if [ -f "$half_name" -a -s "$half_name" ]
  then
    mv "$name" "${name}.bak"
    mv "$half_name" "$name"
    old_name="$half_name"
  elif [ -f "$large_name" -a -s "$large_name" ]
  then
    mv "$name" "${name}.bak"
    mv "$large_name" "$name"
    old_name="$large_name"
  elif [ -f "$reduced_name" -a -s "$reduced_name" ]
  then
    mv "$name" "${name}.bak"
    mv "$reduced_name" "$name"
    old_name="$reduced_name"
  fi

  if [ ! -f "$old_name" -a -f "$name" -a -s "$name" ]
  then
    rm -f "${name}.bak"
    RETURN_original_removed=1
    if [ ! -f  removed-file-list.txt ] 
    then
      touch removed-file-list.txt
      make_file_owner_read_writable removed-file-list.txt
      echo "# This is a list of images whose original versions have been removed." >> removed-file-list.txt
      echo "# makethumbs.sh maintains this so multiple uses of --remove-originals" >> removed-file-list.txt
      echo "# won't continue removing reduced versions of images." >> removed-file-list.txt
     
    fi
    echo "$name" >> removed-file-list.txt
  else
    echo ERROR: I got confused while trying to remove original file >&2
    echo ERROR: \"$name\"!  Aborting... >&2
    exit 1
  fi
}

# A little complicated - parameters are
# THUMBNAIL-WIDTH  THUMBNAIL-HEIGHT  REDUCED-IMG-MADE?  FILENAME
# $thumb_width $thumb_height $was_reduced "$fn"
print_image_link ()
{
  local twidth theight reduced fn caption thumb_name
  local slideshow_name reduced_slideshow_name
  local image_name reduced_name main_link_href secondary_link_href
  local href_title
  local t

  twidth=$1; shift
  theight=$1; shift
  reduced=$1; shift
  fn="$*"

  get_image_caption_for_main_index "$fn"
  caption="$RETURN_caption"
  if [ "$RETURN_caption_was_from" = "descriptions-file" ]
  then
    quote_html_chars "$caption"
    href_title="title=\"$RETURN_html\" "
  else
    href_title=""
  fi

  source_name_to_thumb_name "$fn"
  thumb_name="$RETURN_thumb_name"

  if [ $GLOBAL_create_slideshow -eq 1 ]
  then
    image_name_to_html_name "$fn"
    slideshow_name="$RETURN_html_name"

    source_name_to_reduced_html_name "$fn"
    reduced_slideshow_name="$RETURN_reduced_html_name"
  fi

  image_name="$fn"
  source_name_to_reduced_name "$image_name"
  reduced_name="$RETURN_reduced_name"


# The logic ahead is complicated.  We change our behavior depending
# on whether (a) this image has a reduced version ($reduced), whether
# (b) we are making slideshows ($GLOBAL_create_slideshow), and whether
# (c) there are any reduced images present.
# One odd case is if we are making a slideshow, and we are making reduced
# versions of images, but _this_ particular image didn't have a reduced
# version.  In this one case, the _main_ link we emit is to the reduced
# HTML slideshow page.  That way when people do Next/Previous, they'll
# proceed to the Reduced version (the one they most likely want).
  if [ $reduced -eq 1 ]
  then
    if [ $GLOBAL_create_slideshow -eq 1 ]
    then
      main_link_href="$reduced_slideshow_name"
      secondary_link_href="$slideshow_name"
    else
      main_link_href="$reduced_name"
      secondary_link_href="$image_name"
    fi
  else
    if [ $GLOBAL_create_slideshow -eq 1 ]
    then
      if [ $GLOBAL_reduce_big_pics -eq 1 -a \
           $GLOBAL_there_is_at_least_one_reduced_img -eq 1 ]
      then
        main_link_href="$reduced_slideshow_name"
      else
        main_link_href="$slideshow_name"
      fi
    else
      main_link_href="$image_name"
    fi
  fi

  echo $ac_n "    <a ${href_title}$ac_c"
  [ $GLOBAL_use_two_windows -eq 1 ] && echo $ac_n "target=\"display\" $ac_c"
  quote_url_chars "$main_link_href"; main_link_href="$RETURN_url"
  quote_url_chars "$thumb_name"; thumb_name="$RETURN_url"
  echo $ac_n "href=\"$main_link_href\"><img src=\"$thumb_name\" $ac_c"
  echo $ac_n "width=\"$twidth\" height=\"$theight\" $ac_c"
  echo $ac_n "alt=\"\" /></a>$ac_c"
  if [ $GLOBAL_print_captions -eq 1 ]
  then
    echo "<br />"
    echo $ac_n "    <a href=\"$main_link_href\">$caption</a>$ac_c"
    if [ $reduced -eq 1 -a \
         $GLOBAL_create_slideshow -eq 1 -a \
         $GLOBAL_link_to_original_img_on_index -eq 1 ]
    then
      quote_url_chars "$secondary_link_href"
      t=`echo "$GLOBAL_original_image_text" | sed 's, ,\&nbsp;,g'`
      echo $ac_n "<br /><a href=\"$RETURN_url\">[${t}]</a>$ac_c"
    fi
  fi
  echo ""
}

print_image_size ()
{
  if [ $GLOBAL_print_captions -eq 1 -a \
       $GLOBAL_print_img_size_on_index -eq 1 ]
  then
    return_image_size "$*"
    echo "&nbsp;(${RETURN_image_size_str})"
  fi
}

return_image_size ()
{
  local bytes kbytes fn

  RETURN_image_size_str=""

  fn="$*"
  bytes=`ls -l "$fn" | awk '{print $5}'`
  kbytes=`expr $bytes / 1000`
  RETURN_image_size_str="${kbytes}k"
}

foo_to_pnm ()
{
  case "$*" in
   *.jpg)
        RETURN_foo_to_pnm="djpeg -ppm";;
   *.gif)
        RETURN_foo_to_pnm="giftopnm";;
   *.tif)
        RETURN_foo_to_pnm="tifftopnm";;
   *.png)
        RETURN_foo_to_pnm="pngtopnm";;
   *)
      echo ERROR: Unable to proceed with file "$*"! >&2
      exit 1;;
  esac
}

#########################################################
#### Index pages functions
#########################################################

create_index_pages ()
{
  local t index_pages thumbnails_per_page

  if [ $GLOBAL_single_index_page -eq 1 ]
  then
    thumbnails_per_page="$GLOBAL_total_image_count"
  else
    thumbnails_per_page=`expr $GLOBAL_rows_per_index_page \* $GLOBAL_columns`
  fi
  compute_number_of_indexes
  index_pages="$RETURN_number_of_index_pages"

  make_tmpfile indexpages
  GLOBAL_image_indexpages="$RETURN_tmpfile"
  set_up_indexpages_tmpfile $index_pages $thumbnails_per_page

  t=1
  while [ $t -le $index_pages ]
  do
    create_an_index_page $t $index_pages
    t=`expr $t + 1`
  done

  if [ $GLOBAL_single_index_page -eq 0 -a $index_pages -gt 1 ]
  then
    create_an_index_page "allinone" $index_pages
  fi
}

compute_number_of_indexes ()
{
  local thumbnails_per_page index_pages

  RETURN_number_of_index_pages=""
  if [ $GLOBAL_single_index_page -eq 1 ]
  then
    RETURN_number_of_index_pages=1
    return
  fi

  thumbnails_per_page=`expr $GLOBAL_rows_per_index_page \* $GLOBAL_columns`
  index_pages=`expr $GLOBAL_total_image_count / $thumbnails_per_page + 1`
  if [ `expr $GLOBAL_total_image_count % $thumbnails_per_page` -le \
       `expr $GLOBAL_columns \* 1` -a $index_pages -gt 1 ]
  then
    RETURN_number_of_index_pages=`expr $index_pages - 1`
  else
    RETURN_number_of_index_pages="$index_pages"
  fi
}

set_up_indexpages_tmpfile ()
{
  local index_pages thumbnails_per_page
  local i cur_page fn

  index_pages="$1"
  thumbnails_per_page="$2"

  cur_page=1
  i=1
  while read fn
  do
    [ $cur_page -gt $index_pages ] && cur_page=$index_pages

    echo "$cur_page" "$fn" >> $GLOBAL_image_indexpages
    if [ `expr $i % $thumbnails_per_page` -eq 0 ]
    then
      i=1
      cur_page=`expr $cur_page + 1`
    else
      i=`expr $i + 1`
    fi
  done < $GLOBAL_image_list_tmpfile
}

create_an_index_page ()
{
  local indexno page_name index_pages
  indexno="$1"
  index_pages="$2"

  if [ -z "$indexno" -o -z "$index_pages" ]
  then
    echo ERROR: Unable to understand index page number because it\'s empty 1>&2
    exit 1
  fi

  if [ "$indexno" = 1 -o $GLOBAL_single_index_page -eq 1 ]
  then
    page_name="${GLOBAL_index_base_name}.${GLOBAL_html_file_suffix}"
  elif [ "$indexno" = "allinone" ]
  then
    page_name="${GLOBAL_index_base_name}-all.${GLOBAL_html_file_suffix}"
  else
    page_name="${GLOBAL_index_base_name}-${indexno}.${GLOBAL_html_file_suffix}"
  fi

  remove_or_move_file_aside "$page_name"

  progress_update_start_creating_index_html "$page_name"
  point_stdout_to_an_index_file "$page_name"
  print_html_header

  print_index_list "$indexno" $index_pages
  print_html_table_start
  iterate_over_image_list "$indexno"
  print_html_table_end
  print_index_list "$indexno" $index_pages
  print_html_footer "$page_name"
  progress_update_done_creating_index_html
}

print_index_list ()
{
  local indexno index_pages i page t
  local pad_for_one_digit pad_for_two_digits padding

  indexno="$1"
  index_pages="$2"

  [ "$indexno" = 1 -a $index_pages -eq 1 ] && return
  [ $GLOBAL_single_index_page -eq 1 ] && return

  case $index_pages in
    [0-9][0-9][0-9])
         pad_for_one_digit="\\&nbsp;\\&nbsp;"
         pad_for_two_digits="\\&nbsp;"
       ;;
    [0-9][0-9])
         pad_for_one_digit="\\&nbsp;"
         pad_for_two_digits=""
       ;;
    [0-9])
         pad_for_one_digit=""
         pad_for_two_digits=""
       ;;
    *)
         pad_for_one_digit=""
         pad_for_two_digits=""
       ;;
  esac

  echo '<blockquote><b>'
  echo $ac_n "  $ac_c"
  i=1
  while [ $i -le $index_pages ]
  do
    case $i in
      [0-9])           padding="$pad_for_one_digit" ;;
      [0-9][0-9])      padding="$pad_for_two_digits";;
      [0-9][0-9][0-9]) padding="";;
      *)               padding="";;
    esac

    if [ $i -eq 1 ]
    then
      page="${GLOBAL_index_base_name}.${GLOBAL_html_file_suffix}"
    else
      page="${GLOBAL_index_base_name}-${i}.${GLOBAL_html_file_suffix}"
    fi
    [ $i != "$indexno" ] && echo $ac_n "<a href=\"$page\">$ac_c"
    t=`echo "$GLOBAL_image_set_n_text" | 
       sed -e 's, ,\&nbsp;,g' -e "s,@NUMBER@,<tt>${padding}${i}</tt>,"`
    echo $ac_n "[${t}]$ac_c"
    [ $i != "$indexno" ] && echo $ac_n "</a>$ac_c"
    echo $ac_n " $ac_c"
    i=`expr $i + 1`
  done

  if [ $indexno != "allinone" ]
  then
    echo $ac_n "<a href=\"${GLOBAL_index_base_name}-all.${GLOBAL_html_file_suffix}\">$ac_c"
  fi
  if [ -n "$GLOBAL_image_set_all_text" ]
  then
    t=`echo "$GLOBAL_image_set_all_text" | sed 's, ,\&nbsp;,g'`
    echo $ac_n "[${t}]$ac_c"
  fi
  if [ $indexno != "allinone" ]
  then
    echo '</a>'
  else
    echo ""
  fi
  echo '</b></blockquote>'

  echo "<p />"
}

point_stdout_to_an_index_file ()
{
  local fn
  fn="$*"

  if [ -f "$fn" ]
  then
    echo ERROR: I was unable to remove an index page somehow!  Exiting. 1>&2
    exit 1
  fi

  GLOBAL_print_html_header_footer=1

  exec > "$fn"
  add_cleanup "$fn"
  make_file_world_readable "$fn"
}


# Given an image name, return the name of the index.html page with that
# image on it.

map_image_to_index ()
{
  local fn i page_name
  fn="$*"
  RETURN_index_name=""

  generated_name_to_source_name "$fn"
  quote_egrep_chars "$RETURN_source_name"
  indexno=`egrep "^[0-9]* ${RETURN_egrep}\$" $GLOBAL_image_indexpages |
           head -1 | sed 's, .*,,' | sed 's,[^0-9],,g'`

  if [ -z "$indexno" ]
  then
    echo ERROR: Unable to figure index page for image \"$fn\"! 1>&2
    exit 1
  fi

  if [ $indexno -eq 1 ]
  then
    page_name="${GLOBAL_index_base_name}.${GLOBAL_html_file_suffix}"
  else
    page_name="${GLOBAL_index_base_name}-${indexno}.${GLOBAL_html_file_suffix}"
  fi

  RETURN_index_name="$page_name"
}

#########################################################
#### Image filename conversion/test functions
#########################################################

source_name_to_thumb_name ()
{
  source_name_to_generated_file_name thumb t "$*"
  RETURN_thumb_name="$RETURN_generated_name"
}

source_name_to_feed_name ()
{
  source_name_to_generated_file_name feed f "$*"
  RETURN_feed_name="$RETURN_generated_name"
}

source_name_to_reduced_name ()
{
  source_name_to_generated_file_name reduced r "$*"
  RETURN_reduced_name="$RETURN_generated_name"
}

source_name_to_large_name ()
{
  source_name_to_generated_file_name large l "$*"
  RETURN_large_name="$RETURN_generated_name"
}

source_name_to_half_name ()
{
  source_name_to_generated_file_name half h "$*"
  RETURN_half_name="$RETURN_generated_name"
}

# Call it like
#   source_name_to_generated_name large l foo.jpg
# to get back "foo-l.jpg"

source_name_to_generated_file_name ()
{
  local type ext fn
  RETURN_generated_name=""

  type="$1"; shift
  ext="$1"; shift
  fn="$*"

  RETURN_generated_name=`echo "$*" | sed "s,\.[^.]*\$,-${ext}.jpg,"`
  if [ "$fn" = "$RETURN_generated_name" ]
  then
    echo ERROR: I couldn\'t create a $type name for "\"${fn}\""! >&2
    exit 1
  fi
  if echo "$RETURN_generated_name" | egrep -- "-${ext}-${ext}\." >/dev/null 2>&1
  then
    echo ERROR: I couldn\'t create a $type name for "\"${fn}\""! >&2
    exit 1
  fi
}

is_feed_name ()
{
  RETURN_is_feed_name=0
  if echo "$*" | egrep -- '-f\.(jpg|gif|png)$' >/dev/null 2>&1
  then
    RETURN_is_feed_name=1
  fi
}

is_reduced_name ()
{
  RETURN_is_reduced_name=0
  if echo "$*" | egrep -- '-r\.(jpg|gif|png)$' >/dev/null 2>&1
  then
    RETURN_is_reduced_name=1
  fi
}

is_large_name ()
{
  RETURN_is_large_name=0
  if echo "$*" | egrep -- '-l\.(jpg|gif|png)$' >/dev/null 2>&1
  then
    RETURN_is_large_name=1
  fi
}

is_half_name ()
{
  RETURN_is_half_name=0
  if echo "$*" | egrep -- '-h\.(jpg|gif|png)$' >/dev/null 2>&1
  then
    RETURN_is_half_name=1
  fi
}

is_generated_name ()
{
  RETURN_is_generated_name=0
  if echo "$*" | egrep -- '-[bfhtrl]\.(jpg|gif|png)$' >/dev/null 2>&1
  then
    RETURN_is_generated_name=1
  fi
}

source_name_to_source_html_name ()
{
  RETURN_source_html_name=`echo "$*" |
                           sed "s,\.[^.]*\$,.${GLOBAL_html_file_suffix},"`
  if [ "$*" = "$RETURN_source_html_name" ]
  then
    echo ERROR: I couldn\'t create an HTML name for "\"$*\""! >&2
    exit 1
  fi
}

image_name_to_html_name ()
{
  RETURN_html_name=`echo "$*" | sed "s,\.[^.]*\$,.${GLOBAL_html_file_suffix},"`
  if [ "$*" = "$RETURN_html_name" ]
  then
    echo ERROR: I couldn\'t create an HTML name for "\"$*\""! >&2
    exit 1
  fi
}

html_name_to_image_name ()
{
  local fn basename imgname

  fn="$*"
  basename=`echo "$fn" | sed -e "s,-[bfhtrl].${GLOBAL_html_file_suffix}\$,," -e "s,.${GLOBAL_html_file_suffix}\$,,"`
  quote_egrep_chars "$basename"
  imgname=`egrep "^${RETURN_egrep}.(jpg|gif|png)\$" $GLOBAL_image_list_tmpfile | head -1`
  RETURN_image_name="$imgname"
  if [ ! -f "$RETURN_image_name" ]
  then
    echo ERROR: I couldn\'t guess the image name for HTML file "\"$*\""! >&2
    exit 1
  fi
}

# We may have a reduced image, or we may not.  If the reduced image
# is present, we return the source image HTML name (so
# source_name_to_source_html_name is equivalent to this function),
# otherwise we return the reduced image HTML name.
source_name_to_reduced_html_name ()
{
  local reduced_name

  source_name_to_reduced_name "$*"
  reduced_name="$RETURN_reduced_name"

  RETURN_reduced_html_name=`echo "$reduced_name" | sed "s,\.[jpgpnggif]*\$,.${GLOBAL_html_file_suffix},"`

  if [ "$reduced_name" = "$RETURN_reduced_html_name" ]
  then
    echo ERROR: I couldn\'t create an HTML name for "\"$reduced_name\""! >&2
    exit 1
  fi
}

source_name_to_large_html_name ()
{
  local large_name

  source_name_to_large_name "$*"
  large_name="$RETURN_large_name"

  RETURN_large_html_name=`echo "$large_name" | sed "s,\.[jpgpnggif]*\$,.${GLOBAL_html_file_suffix},"`

  if [ "$large_name" = "$RETURN_large_html_name" ]
  then
    echo ERROR: I couldn\'t create an HTML name for "\"$large_name\""! >&2
    exit 1
  fi
}

source_name_to_half_html_name ()
{
  local half_name

  source_name_to_half_name "$*"
  half_name="$RETURN_half_name"

  RETURN_half_html_name=`echo "$half_name" | sed "s,\.[jpgpnggif]*\$,.${GLOBAL_html_file_suffix},"`

  if [ "$half_name" = "$RETURN_half_html_name" ]
  then
    echo ERROR: I couldn\'t create an HTML name for "\"$half_name\""! >&2
    exit 1
  fi
}

generated_name_to_source_name ()
{
  local is_generated_file nameroot source

  is_generated_name "$*"
  if [ $RETURN_is_generated_name -eq 1 ]
  then
    is_generated_file=1
    nameroot=`echo "$*" | sed 's,-[bfhtrl]\.[jpgpnggif]*$,,'`
  else
    is_generated_file=0
    nameroot=`echo "$*" | sed 's,\.[jpgpnggif]*$,,'`
  fi

  quote_egrep_chars "$nameroot"
  source=`egrep "^${RETURN_egrep}\.(jpg|gif|png)\$" $GLOBAL_image_list_tmpfile`
  if [ -z "$source" -o ! -f "$source" -o ! -s "$source" ]
  then
    echo ERROR: I couldn\'t find the source name from \"$*\"! >&2
    exit 1
  fi

  if [ "$*" = "$source" -a $is_generated_file -eq 1 ]
  then
    echo ERROR: I couldn\'t find convert source name with \"$*\"! >&2
    exit 1
  fi

  RETURN_source_name="$source"
}

quote_egrep_chars ()
{
  RETURN_egrep=`echo "$*" | sed -e 's,(,\\\\(,g' -e 's,),\\\\),g' -e 's,\+,\\\\+,g'`
}

quote_url_chars ()
{
  RETURN_url=`echo "$*" | sed -e 's, ,%20,g' -e 's,",%22,g'`
}

quote_html_chars ()
{
  RETURN_html=`echo "$*" | sed -e 's,&,\&amp;,g' \
                               -e 's,<,\&lt;,g' \
                               -e 's,>,\&gt;,g' \
                               -e 's,",\&quot;,g'`
}

#########################################################
#### Image creation functions
#########################################################

create_generated_files ()
{
  local fn
  local height width

  GLOBAL_there_is_at_least_one_reduced_img=0
  GLOBAL_there_is_at_least_one_large_img=0
  GLOBAL_there_is_at_least_one_half_img=0
  progress_update_start_creating_reduced_images

  while read fn
  do

    get_dimensions "$fn"
    width="$RETURN_width";
    height="$RETURN_height"

    create_thumbnail "$height" "$width" "$fn"

    create_feed "$height" "$width" "$fn"

    create_reduced "$height" "$width" "$fn"
    [ $RETURN_was_reduced -eq 1 ] && GLOBAL_there_is_at_least_one_reduced_img=1

    create_large "$height" "$width" "$fn"
    [ $RETURN_was_larged -eq 1 ] && GLOBAL_there_is_at_least_one_large_img=1

    create_half "$height" "$width" "$fn"
    [ $RETURN_was_halfed -eq 1 ] && GLOBAL_there_is_at_least_one_half_img=1

    maybe_remove_original "$fn"
  done <  $GLOBAL_image_list_tmpfile

  progress_update_done_creating_reduced_images
}

create_thumbnail ()
{
  local source_fn thumb_fn
  local source_height source_width

  source_height="$1"
  source_width="$2"
  source_fn="$3"

  source_name_to_thumb_name "$source_fn"
  thumb_fn="$RETURN_thumb_name"

  general_image_reducer \
                $source_height $source_width \
                0 0 \
                $GLOBAL_max_thumb_size $GLOBAL_max_thumb_size \
                1 \
                "$source_fn" "$thumb_fn"
  if [ $RETURN_reduced_exists -eq 1 -a $RETURN_reduced_already_existed -eq 0 ]
  then
    progress_update_created_thumbnail_image
  fi
}

create_feed ()
{
  local source_fn thumb_fn
  local source_height source_width

  source_height="$1"
  source_width="$2"
  source_fn="$3"

  [ $GLOBAL_create_feed_images -eq 0 ] && return

  source_name_to_feed_name "$source_fn"
  feed_fn="$RETURN_feed_name"

  general_image_reducer \
                $source_height $source_width \
                0 0 \
                $GLOBAL_feed_height $GLOBAL_feed_width \
                1 \
                "$source_fn" "$feed_fn"
  if [ $RETURN_reduced_exists -eq 1 -a $RETURN_reduced_already_existed -eq 0 ]
  then
    progress_update_created_feed_image
  fi
}


create_reduced ()
{
  local source_fn reduced_fn start_conv
  local source_height source_width

  source_height="$1"
  source_width="$2"
  shift; shift
  source_fn="$*"
  RETURN_was_reduced=0

  [ $GLOBAL_reduce_big_pics -eq 0 ] && return

  source_name_to_reduced_name "$source_fn"
  reduced_fn="$RETURN_reduced_name"

  general_image_reducer \
                $source_height $source_width \
                $GLOBAL_reduce_trigger_height $GLOBAL_reduce_trigger_width \
                $GLOBAL_reduce_height $GLOBAL_reduce_width \
                0 \
                "$source_fn" "$reduced_fn"
  if [ $RETURN_reduced_exists -eq 1 ]
  then
    RETURN_was_reduced=1
    if [ $RETURN_reduced_already_existed -eq 0 ]
    then
      progress_update_created_reduced_image
    fi
  fi
}

create_large ()
{
  local source_fn large_fn
  local source_height source_width

  source_height="$1"
  source_width="$2"
  shift; shift
  source_fn="$*"
  RETURN_was_larged=0

  [ $GLOBAL_create_large_images -eq 0 ] && return

  source_name_to_large_name "$source_fn"
  large_fn="$RETURN_large_name"

  general_image_reducer \
                $source_height $source_width \
                $GLOBAL_large_trigger_height $GLOBAL_large_trigger_width \
                $GLOBAL_large_height $GLOBAL_large_width \
                0 \
                "$source_fn" "$large_fn"
  if [ $RETURN_reduced_exists -eq 1 ]
  then
    RETURN_was_larged=1
    if [ $RETURN_reduced_already_existed -eq 0 ]
    then
      progress_update_created_large_image
    fi
  fi
}

create_half ()
{
  local source_fn large_fn
  local source_height source_width
  local dest_height dest_width

  source_height="$1"
  source_width="$2"
  shift; shift
  source_fn="$*"
  RETURN_was_halfed=0

  [ $GLOBAL_create_half_images -eq 0 ] && return

# Only create half-res versions for very large images -- larger than
# 6 mpixels.  Otherwise the "large" version is already good enough.

  [ `expr $source_height \* $source_width` -lt 6000000 ] && return

  source_name_to_half_name "$source_fn"
  half_fn="$RETURN_half_name"

  dest_height=`expr $source_height \* 7`
  dest_height=`expr $dest_height / 10`
  dest_width=`expr $source_width \* 7`
  dest_width=`expr $dest_width / 10`
  
  general_image_reducer \
                $source_height $source_width \
                0 0 \
                $dest_height $dest_width \
                0 \
                "$source_fn" "$half_fn"
  if [ $RETURN_reduced_exists -eq 1 ]
  then
    RETURN_was_halfed=1
    if [ $RETURN_reduced_already_existed -eq 0 ]
    then
      progress_update_created_half_image
    fi
  fi
}



general_image_reducer ()
{
  local source_height source_width
  local trigger_height trigger_width
  local dest_height dest_width
  local creating_a_thumbnail
  local source_name
  local target_name

  local start_conv
  local t
  local converted_with
  local width_delta height_delta
  local biggerdimen resizename

  source_height="$1"
  source_width="$2"
  trigger_height="$3"
  trigger_width="$4"
  dest_height="$5"
  dest_width="$6"
  creating_a_thumbnail="$7"
  source_name="$8"
  target_name="$9"

  RETURN_reduced_exists=0
  RETURN_reduced_already_existed=0

  if [ -f "$target_name" -a -s "$target_name" ]
  then
    [ $creating_a_thumbnail -eq 1 ] && get_dimensions "$target_name"
    width_delta=`expr $RETURN_width - $dest_width | tr -d '-'`
    height_delta=`expr $RETURN_height - $dest_height | tr -d '-'`
    if [ $creating_a_thumbnail -eq 1 -a \
         $width_delta -ne 0 -a $width_delta -ne 1 -a \
         $height_delta -ne 0 -a $height_delta -ne 1 ]
    then
      rm -f "$target_name"
    else
      make_file_world_readable "$target_name"
      RETURN_reduced_exists=1
      RETURN_reduced_already_existed=1
      return
    fi
  fi

# If this is a portrait image, we need to swap the trigger/reduction dimensions.

# FIXME This is controversial in my mind.  The question is what a height/width
# constraint means.  Does it mean that's how much screen real estate you want
# to use, or does it mean how many pixels you want in an image?  If it's
# referring to the screen real estate, then we want to reduce to height/width
# regardless of whether the image is in portait or landscape orientation.
# If it's referring to the # of pixels, then we want to swap height/width
# when we're looking at a portrait photo vs a landscape photo.
# The vast majority of programs on the net do the screen real estate path
# because it's the obvious one.  The following code errs on the side of pixel
# count.  I haven't made up my mind yet.

# NB: A whole better way of doing this would be to specify scaling in terms
# of the original size (e.g. "50%"), or specify the target size in terms of
# megapixels.  Maybe some day.

  if [ $source_height -gt $source_width ]
  then
    t=$trigger_height
    trigger_height=$trigger_width
    trigger_width=$t
#    t=$dest_height
#    dest_height=$dest_width
#    dest_width=$t
  fi

  if [ $creating_a_thumbnail -eq 1 -o \
       $source_width -ge $trigger_width -o \
       $source_height -ge $trigger_height ]
  then
    add_cleanup "$target_name"
    check_for_rotation "$source_name"

    if [ $GLOBAL_tools_to_use = sips ]
    then
      [ -z "$RETURN_rotation_angle" ] && RETURN_rotation_angle="0"

# We scale to only a single side with sips (if we want to maintain the
# correct aspect ratio), so select the larger of the two to make it
# conform to the target dimension.

      if [ $source_height -gt $source_width ]
      then
        biggerdimen=$dest_height
        resizename=Height
      else
        biggerdimen=$dest_width
        resizename=Width
      fi

      sips --resample$resizename $biggerdimen \
              --rotate $RETURN_rotation_angle \
              --setProperty format jpeg \
              --setProperty formatOptions $GLOBAL_compression_level \
              $GLOBAL_sips_profile_convert_cmd1 \
              $GLOBAL_sips_profile_convert_cmd2 \
              "$GLOBAL_sips_profile_convert_cmd3" \
              --addIcon \
              "$source_name" --out "$target_name" 1>/dev/null 2>&1 |
              grep -v ^rejected 
      converted_with="sips"
    elif [ $GLOBAL_tools_to_use = imagemagick ]
    then
      [ -z "$RETURN_rotation_angle" ] && RETURN_rotation_angle="0"
      convert -quality $GLOBAL_compression_level \
              -rotate $RETURN_rotation_angle \
              -geometry ${dest_width}x${dest_height} \
              "$source_name" JPEG:- > "$target_name"
      converted_with="imagemagick"
    elif [ $GLOBAL_tools_to_use = netpbm ]
    then
      foo_to_pnm "$source_name"
      start_conv="$RETURN_foo_to_pnm"
      [ "$RETURN_rotation_angle" = "0" ] && RETURN_rotation_angle=""
      $start_conv "$source_name" |
          pnmscale -xysize $dest_width \
                           $dest_height 2>/dev/null |
          $RETURN_rotation_cmd $RETURN_rotation_angle |
          cjpeg -optimize -quality $GLOBAL_compression_level > "$target_name"
      converted_with="netpbm"
    fi

    if [ $GLOBAL_jhead_is_present -eq 1 -a $creating_a_thumbnail -eq 0 -a \
         "x$converted_with" != xnetpbm ]
    then
      jhead -te "$source_name" "$target_name" >/dev/null 2>&1
    fi
    make_file_world_readable "$target_name"

    remove_cleanup "$target_name"
    tag_image_with_text "$target_name"

    RETURN_reduced_exists=1
  fi

  if [ $RETURN_reduced_exists -eq 1 -a ! -s "$target_name" ]
  then
    echo "ERROR: Unable to reduce \"$source_name\"!  Exiting." >&2
    exit 1
  fi
}

reduced_file_exists ()
{
  local fn
  fn="$*"

  RETURN_reduced_exists=0
  [ $GLOBAL_reduce_big_pics -eq 0 ] && return
  source_name_to_reduced_name="$fn"
  if [ -f "$RETURN_reduced_name" ]
  then
    RETURN_reduced_exists=1
  fi
}

get_dimensions ()
{
  local fn conv dimens

  fn="$*"

# Note that I redirect the output of djpeg to /dev/null.  There
# is something stupid about RH 8 where programs that get cut off
# get a different signal than they did previously--both the yes(1)
# invocation and djpeg emit errors on the RH8 system when they
# never did in the past.  I bet RH did something stupid.
# I really don't want to send the output of djpeg or whatever to
# /dev/null because its errors can often be useful to the user, but
# I don't have much choice here (short of saving the error output to
# a file and trying to grep out the bogus errors)

  if [ $GLOBAL_tools_to_use = sips ]
  then
    dimens="`sips -g pixelWidth "$fn" | tail -1 | sed 's,[^0-9]* *,,' | grep -v nil` `sips -g pixelHeight "$fn" | tail -1 | sed 's,[^0-9]* *,,' | grep -v nil`"
  elif [ $GLOBAL_tools_to_use = imagemagick ]
  then
    dimens=`identify -ping "$fn" 2>&1 | grep ' [0-9]*x[0-9]*[=+ ]' | 
            sed 's,.* \([0-9]*\)x\([0-9]*\)[= +].*,\1 \2,' | head -1`
  elif [ $GLOBAL_tools_to_use = netpbm ]
  then
    foo_to_pnm "$fn"
    conv="$RETURN_foo_to_pnm"
    dimens=`$conv "$fn" 2>/dev/null | pnmfile | awk '{print $4 " " $6}'`
  fi

  RETURN_width=`echo $dimens | cut -d ' ' -f1`
  RETURN_height=`echo $dimens | cut -d ' ' -f2`

  if [ -z "$RETURN_width" -o -z "$RETURN_height" ]
  then
    echo ERROR: Internal error in get_dimensions, for some reason I couldn\'t get >&2
    echo ERROR: the dimensions of \"$fn\".  Exiting. >&2
    exit 1
  fi
}

check_for_rotation ()
{
  local fn rot_cmd

  fn="$*"
  RETURN_do_rotation=0
  RETURN_rotation_cmd=cat
  RETURN_rotation_angle="0"

  [ ! -f $GLOBAL_rotation_filename ] && return
  if grep -i "^[a-z-]* ${fn}" $GLOBAL_rotation_filename >/dev/null 2>&1
  then
    :
  else
    return
  fi

  rot_cmd=`grep -i "^[a-z-]* ${fn}" $GLOBAL_rotation_filename | sed "s/ ${fn}//"`
  if [ -z "$rot_cmd" ]
  then
    echo WARNING: Unrecognized rotation for "$fn"!  Ignoring rotate. >&2
    return
  fi

  if [ "$rot_cmd" != "clockwise" -a "$rot_cmd" != "counter-clockwise" ]
  then
    echo WARNING: Unrecognized rotation for "$fn"!  Ignoring rotate. >&2
    return
  fi

  RETURN_do_rotation=1
  RETURN_rotation_cmd=pnmrotate
  if [ "$rot_cmd" = "clockwise" ]
  then
    RETURN_rotation_angle=-90
  else
    RETURN_rotation_angle=90
  fi
}

get_image_number ()
{
  local fn num total

  generated_name_to_source_name "$*"
  fn="$RETURN_source_name"

  num=`cat -n $GLOBAL_image_list_tmpfile |
       grep "^[ 	]*[0-9]*[ 	]*${fn}\$" |
       cut -f1 | sed 's,[^0-9],,g'`

  if [ -z "$num" ]
  then
    echo WARNING: Could not get image number for file \"$fn\"! 1>&2
  fi
  RETURN_image_number="$num"
  total="$GLOBAL_total_image_count"
  if [ -z "$total" ]
  then
    echo WARNING: Could not determine number of image files! 1>&2
  fi
  RETURN_number_of_images="$total"
}

tag_image_with_text ()
{
  local fn font_size font xoffset yoffset text

  fn="$*"
  [ -n "$GLOBAL_image_imprinting_text" ] || return
  [ "$GLOBAL_image_imprinting_text" = "undef" ] && return
  [ $GLOBAL_mogrify_is_present -eq 0 ] && return

  font_size=12
  font="-*-helvetica-bold-r-*-*-${font_size}-*-*-*-*-*-iso8859-*"

  compute_subtitle_pixelwidth "$font_size"

  get_dimensions "$fn"
  xoffset=`expr $RETURN_width - $GLOBAL_image_subtitle_pixelwidth`
  [ $xoffset -le 0 ] && xoffset=0
  yoffset=`expr $RETURN_height - $font_size`
  add_cleanup "$fn"
  text=`echo "$GLOBAL_image_imprinting_text" | sed "s,\",',g"`
  mogrify -fill yellow -font "$font" \
      -draw "text ${xoffset},${yoffset} \"$text\"" "$fn"
  remove_cleanup "$fn"
}

# This function tries to determine the pixel width of a text string given
# the string and given the font size that it'll be rendered in.  I wish we
# could just get the number directly from the imaging program that does it,
# but I don't think I can.  I need this information so I can justify the
# text right-flush at the bottom of the image.
#
# The font is proportional, so these are just estimations.  In short,
#
# upper-case char pixel width = font-size / 1.45  (8.27 pixels/char @ 12pts)
# lower-case char pixel width = font-size / 2.20  (5.45 pixels/char @ 12pts)
# space char pixel width      = font-size / 2.22  (5.45 pixels/char @ 12pts)
# all other chars pixel width = font-size / 1.60  (7.50 pixels/char @ 12pts)

compute_subtitle_pixelwidth ()
{
  local font_size len len_padded lowcase upcase space otherchars pixellen

  font_size="$*"
  [ -n "$GLOBAL_image_subtitle_pixelwidth" ] && return

  len=`echo "$GLOBAL_image_imprinting_text" | wc -c |
       sed -e 's,^[ 	]*,,' -e 's,[ 	]*$,,'`
  len_padded=`expr $len \* $font_size \* 10`

  lowcase=`echo "$GLOBAL_image_imprinting_text" | tr -cd '[a-z]' |
           wc -c | sed -e 's,^[ 	]*,,' -e 's,[ 	]*$,,'`
  upcase=`echo "$GLOBAL_image_imprinting_text" | tr -cd '[A-Z0-9]' |
           wc -c | sed -e 's,^[ 	]*,,' -e 's,[ 	]*$,,'`
  space=`echo "$GLOBAL_image_imprinting_text" | tr -cd '[ 	]' |
           wc -c | sed -e 's,^[ 	]*,,' -e 's,[ 	]*$,,'`
  otherchars=`expr $len - $upcase - $lowcase - $space`

  pixellen=`expr $lowcase \* $font_size \* 100 / 220`
  pixellen=`expr $pixellen + $upcase \* $font_size \* 100 / 145`
  pixellen=`expr $pixellen + $space \* $font_size \* 100 / 220`
  pixellen=`expr $pixellen + $otherchars \* $font_size \* 100 / 160`
  pixellen=`expr $pixellen + 2`
  GLOBAL_image_subtitle_pixelwidth="$pixellen"
}

#########################################################
#### HTML printing functions
#########################################################

print_html_header ()
{
  get_directory_title
  echo '<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN"'
  echo '     "http://www.w3.org/TR/html4/loose.dtd">'
  echo '<html>'
  echo '<head>'
  echo "  <title>$RETURN_directory_title_inline</title>"
  [ -n "$GLOBAL_meta_tag" -a "$GLOBAL_meta_tag" != undef ] && echo "  $GLOBAL_meta_tag"
  if [ "$GLOBAL_html_charset" != "undef" ]
  then
    echo "  <meta http-equiv=\"Content-Type\" content=\"text/html; charset=${GLOBAL_html_charset}\">"
  fi
  echo "  <meta name=\"generator\" content=\"makethumbs v$GLOBAL_makethumbs_version\">"
  if [ -n "$GLOBAL_boilerplate_index_insert_in_head" -a \
          "$GLOBAL_boilerplate_index_insert_in_head" != undef ]
  then
    echo "$GLOBAL_boilerplate_index_insert_in_head"
  elif [ -n "$GLOBAL_boilerplate_insert_in_head" -a \
          "$GLOBAL_boilerplate_insert_in_head" != undef ]
  then
    echo "$GLOBAL_boilerplate_insert_in_head"
  fi
  echo '</head>'
  echo "$GLOBAL_body_tag"
  echo ""
  if [ -n "$GLOBAL_boilerplate_index_before_title" -a \
          "$GLOBAL_boilerplate_index_before_title" != undef ]
  then
    echo "$GLOBAL_boilerplate_index_before_title"
    echo ""
  elif [ -n "$GLOBAL_boilerplate_before_title" -a \
          "$GLOBAL_boilerplate_before_title" != undef ]
  then
    echo "$GLOBAL_boilerplate_before_title"
    echo ""
  fi
  if [ $GLOBAL_print_title_on_index -eq 1 ]
  then
    echo $ac_n "$GLOBAL_index_page_title_start_html$ac_c"
    echo $ac_n "$RETURN_directory_title$ac_c"
    echo    "$GLOBAL_index_page_title_end_html"
  fi
  echo ""
  if [ -n "$GLOBAL_boilerplate_index_after_title" -a \
          "$GLOBAL_boilerplate_index_after_title" != undef ]
  then
    echo "$GLOBAL_boilerplate_index_after_title"
    echo ""
  elif [ -n "$GLOBAL_boilerplate_after_title" -a \
          "$GLOBAL_boilerplate_after_title" != undef ]
  then
    echo "$GLOBAL_boilerplate_after_title"
    echo ""
  fi
  get_directory_description
  if [ -n "$RETURN_directory_description" ]
  then
    echo "<p />$RETURN_directory_description"
    echo "<p />"
    echo ""
  fi
}

print_html_table_start ()
{
  case "$GLOBAL_index_table_spacing" in
    loose)
       echo '<table width="100%" cellspacing="10" cellpadding="0">'
       ;;
    tight)
       echo '<table width="100%" cellspacing="2" cellpadding="0">'
       ;;
    none | *)
       echo '<table width="100%" cellspacing="0" cellpadding="0">'
       ;;
  esac
}

print_html_table_end ()
{
  if [ $GLOBAL_last_row_was_closed -eq 0 ]
  then
    echo "</tr>"
  fi
  echo ""
  echo '</table>'
  if [ -n "$GLOBAL_boilerplate_index_after_table_before_indexlinks" -a \
       "$GLOBAL_boilerplate_index_after_table_before_indexlinks" != "undef" ]
  then
    echo "$GLOBAL_boilerplate_index_after_table_before_indexlinks"
  fi
}


print_html_row_start ()
{
  echo ""
  echo '<tr>'
}

print_html_row_end ()
{
  echo '</tr>'
  echo ""
  if [ $GLOBAL_index_table_spacing = "loose" ]
  then
  # <!-- lame way to pad rows a bit but looks nice-->
    echo "<tr><td>&nbsp;</td></tr>"
  fi
}

print_html_column_start ()
{
  echo '  <td align="center">'
}

print_html_column_end ()
{
  echo '  </td>'
}


# FIXME: I can't decide if the user's footer text should come
# before the "This page created" text or after that text.  If they're
# putting a <hr/> tag, it would probably look better to put the
# This Page text after the user's footer text.

print_html_footer ()
{
  local fn t date
  fn="$*"

  echo ""
  if [ -n "$GLOBAL_this_page_created_text" -a \
       "$GLOBAL_this_page_created_text" != "undef" ]
  then
    date=`date '+%Y-%m-%d'`
    t=`echo "$GLOBAL_this_page_created_text" |
       sed -e 's,@LINKSTART@,<a href="http://www.molenda.com/makethumbs/">,' |
       sed -e 's,@LINKEND@,</a>,' -e "s,@DATE@,${date},"`
    [ -n "$t" ] && echo "<p>$t</p>"
  fi

  if [ -n "$GLOBAL_boilerplate_footer" -a "$GLOBAL_boilerplate_footer" != undef ]
  then
    echo ""
    echo "$GLOBAL_boilerplate_footer"
    echo ""
  fi

  cat << __EOM__

<!-- This file generated automatically by makethumbs.sh, written by
      Jason Molenda, makethumbs(AT)molenda.com.
      $GLOBAL_rcsid
      The latest version of this script is always available at
               http://www.molenda.com/makethumbs/  -->

__EOM__

  if [ -n "$GLOBAL_boilerplate_index_end_of_page" -a \
          "$GLOBAL_boilerplate_index_end_of_page" != undef ]
  then
    echo "$GLOBAL_boilerplate_index_end_of_page"
  elif [ -n "$GLOBAL_boilerplate_end_of_page" -a \
          "$GLOBAL_boilerplate_end_of_page" != undef ]
  then
    echo "$GLOBAL_boilerplate_end_of_page"
  else
    echo "$GLOBAL_body_end_tag"
    echo '</html>'
  fi
  add_checksum_to_file "$fn"

  remove_cleanup "$fn"
}

#########################################################
#### slideshow functions
#########################################################

create_slideshow ()
{
  local fileset prev cur next

  [ $GLOBAL_create_slideshow -eq 0 ] && return

  progress_update_start_creating_slideshow_pages

  remove_existing_slideshow_html_files

  create_slideshow_image_list

  while read fileset
  do
    prev=`echo "$fileset" | cut -d\| -f1`
    cur=`echo "$fileset" | cut -d\| -f2`
    next=`echo "$fileset" | cut -d\| -f3`

    create_slideshow_source_file "$prev" "$cur" "$next"
    if [ $GLOBAL_reduce_big_pics -eq 1 -a \
         $GLOBAL_there_is_at_least_one_reduced_img -eq 1 ]
    then
      create_slideshow_reduced_file "$prev" "$cur" "$next"
    fi
    if [ $GLOBAL_create_large_images -eq 1 -a \
         $GLOBAL_there_is_at_least_one_large_img -eq 1 ]
    then
      create_slideshow_large_file "$prev" "$cur" "$next"
    fi
    if [ $GLOBAL_create_half_images -eq 1 -a \
         $GLOBAL_there_is_at_least_one_half_img -eq 1 ]
    then
      create_slideshow_half_file "$prev" "$cur" "$next"
    fi
    progress_update_created_slideshow_page
  done < $GLOBAL_slideshow_image_list
  progress_update_done_creating_slideshow_pages
}

create_slideshow_source_file ()
{
  local prev_image cur_image next_image html_file

  prev_image="$1"
  cur_image="$2"
  next_image="$3"

  image_name_to_html_name "$cur_image"
  html_file="$RETURN_html_name"
  add_cleanup "$html_file"
  touch "$html_file"
  make_file_world_readable "$html_file"

# The following exec goop so I don't have to manually redirect every
# message to stderr in this function.
  exec 5>&1                   # save stdout fd to fd #5
  exec > "$html_file"         # redirect stdout to the file

  print_slideshow_file_header       "$prev_image" "$cur_image" "$next_image"
  print_slideshow_top_navlinks      "$prev_image" "$cur_image" "$next_image"
  print_slideshow_image             "$cur_image" "source"
  print_slideshow_size_links        "source" "$cur_image"
  print_slideshow_image_description "$cur_image"
  print_slideshow_bottom_navlinks   "$prev_image" "$cur_image" "$next_image"
  print_image_exif_info             "$cur_image"
  print_slideshow_file_footer

  remove_cleanup                    "$html_file"

  exec 1>&5   # Copy stdout fd back from temporary save fd, #5
}

create_slideshow_reduced_file ()
{
  local prev_image cur_image next_image
  local cur_source_image cur_reduced_image html_file

  prev_image="$1"
  cur_image="$2"
  next_image="$3"
  cur_source_image="$cur_image"
  cur_reduced_image="$cur_image"

  if [ "$prev_image" != NULL ]
  then
    source_name_to_reduced_name "$prev_image"
    prev_image="$RETURN_reduced_name"
  fi

  source_name_to_reduced_name "$cur_image"
  cur_reduced_image="$RETURN_reduced_name"
  if [ -f "$RETURN_reduced_name" ]
  then
    cur_image="$RETURN_reduced_name"
  else
    source_name_to_large_name "$cur_image"
    if [ -f "$RETURN_large_name" ]
    then
      cur_image="$RETURN_large_name"
    fi
  fi

  if [ "$next_image" != NULL ]
  then
    source_name_to_reduced_name "$next_image"
    next_image="$RETURN_reduced_name"
  fi

  image_name_to_html_name "$cur_reduced_image"
  html_file="$RETURN_html_name"
  add_cleanup "$html_file"
  touch "$html_file"
  make_file_world_readable "$html_file"

# The following exec goop so I don't have to manually redirect every
# message to stderr in this function.
  exec 5>&1                   # save stdout fd to fd #5
  exec > "$html_file"         # redirect stdout to the file

  print_slideshow_file_header       "$prev_image" "$cur_image" "$next_image"
  print_slideshow_top_navlinks      "$prev_image" "$cur_image" "$next_image"
  print_slideshow_image             "$cur_image" "reduced"
  print_slideshow_size_links        "reduced" "$cur_image"
  print_slideshow_image_description "$cur_image"
  print_slideshow_bottom_navlinks   "$prev_image" "$cur_image" "$next_image"
  print_image_exif_info             "$cur_reduced_image"
  print_slideshow_file_footer
  remove_cleanup                    "$html_file"

  exec 1>&5   # Copy stdout fd back from temporary save fd, #5
}


create_slideshow_large_file ()
{
  local prev_image cur_image next_image
  local cur_source_image cur_large_image html_file

  prev_image="$1"
  cur_image="$2"
  next_image="$3"
  cur_source_image="$cur_image"
  cur_large_image="$cur_image"

  if [ "$prev_image" != NULL ]
  then
    source_name_to_large_name "$prev_image"
    prev_image="$RETURN_large_name"
  fi

  source_name_to_large_name "$cur_image"
  cur_large_image="$RETURN_large_name"
  if [ -f "$RETURN_large_name" ]
  then
    cur_image="$RETURN_large_name"
  else
    source_name_to_reduced_name "$cur_image"
    if [ -f "$RETURN_reduced_name" ]
    then
      cur_image="$RETURN_reduced_name"
    fi
  fi

  if [ "$next_image" != NULL ]
  then
    source_name_to_large_name "$next_image"
    next_image="$RETURN_large_name"
  fi

  image_name_to_html_name "$cur_large_image"
  html_file="$RETURN_html_name"
  add_cleanup "$html_file"
  touch "$html_file"
  make_file_world_readable "$html_file"

# The following exec goop so I don't have to manually redirect every
# message to stderr in this function.
  exec 5>&1                   # save stdout fd to fd #5
  exec > "$html_file"         # redirect stdout to the file

  print_slideshow_file_header       "$prev_image" "$cur_image" "$next_image"
  print_slideshow_top_navlinks      "$prev_image" "$cur_image" "$next_image"
  print_slideshow_image             "$cur_image" "large"
  print_slideshow_size_links        "large" "$cur_image"
  print_slideshow_image_description "$cur_image"
  print_slideshow_bottom_navlinks   "$prev_image" "$cur_image" "$next_image"
  print_image_exif_info             "$cur_large_image"
  print_slideshow_file_footer
  remove_cleanup                    "$html_file"

  exec 1>&5   # Copy stdout fd back from temporary save fd, #5
}

create_slideshow_half_file ()
{
  local prev_image cur_image next_image
  local cur_source_image cur_half_image html_file

  prev_image="$1"
  cur_image="$2"
  next_image="$3"
  cur_source_image="$cur_image"
  cur_large_image="$cur_image"

  if [ "$prev_image" != NULL ]
  then
    source_name_to_half_name "$prev_image"
    prev_image="$RETURN_half_name"
  fi

  source_name_to_half_name "$cur_image"
  cur_half_image="$RETURN_half_name"
  if [ -f "$RETURN_half_name" ]
  then
    cur_image="$RETURN_half_name"
  else
    source_name_to_large_name "$cur_image"
    if [ -f "$RETURN_large_name" ]
    then
      cur_image="$RETURN_large_name"
    else
      source_name_to_reduced_name "$cur_image"
      if [ -f "$RETURN_reduce_name" ]
      then
        cur_image="$RETURN_reduce_name"
      fi
    fi
  fi

  if [ "$next_image" != NULL ]
  then
    source_name_to_half_name "$next_image"
    next_image="$RETURN_half_name"
  fi

  image_name_to_html_name "$cur_half_image"
  html_file="$RETURN_html_name"
  add_cleanup "$html_file"
  touch "$html_file"
  make_file_world_readable "$html_file"

# The following exec goop so I don't have to manually redirect every
# message to stderr in this function.
  exec 5>&1                   # save stdout fd to fd #5
  exec > "$html_file"         # redirect stdout to the file

  print_slideshow_file_header       "$prev_image" "$cur_image" "$next_image"
  print_slideshow_top_navlinks      "$prev_image" "$cur_image" "$next_image"
  print_slideshow_image             "$cur_image" "half"
  print_slideshow_size_links        "half" "$cur_image"
  print_slideshow_image_description "$cur_image"
  print_slideshow_bottom_navlinks   "$prev_image" "$cur_image" "$next_image"
  print_image_exif_info             "$cur_large_image"
  print_slideshow_file_footer
  remove_cleanup                    "$html_file"

  exec 1>&5   # Copy stdout fd back from temporary save fd, #5
}


javascript_navigate='<!-- The following Javascript lets people navigate with keyboard shortcuts -->
<script type="text/javascript"><!--
document.onkeypress = handler;
function handler (e) {
   key_n = 110;   key_k = 107;  // "n", "k" for next
   key_p = 112;   key_j = 106;  // "p", "j" for previous
   if (navigator.appName == "Netscape") { keyval = e.which; }
   else                                 { keyval = window.event.keyCode; }
   @JAVASCRIPT_PREVIOUS@
   @JAVASCRIPT_NEXT@
   return; }
//--></script>'

javascript_next_img='if (keyval == key_n || keyval == key_k) { location = "@NEXT@"; return true; }'

javascript_previous_img='if (keyval == key_p || keyval == key_j) { location = "@PREVIOUS@"; return true; }'


print_slideshow_file_header ()
{
  local source_image prev_image next_image
  local t t_prev t_next

  prev_image="$1"
  source_image="$2"
  next_image="$3"

  get_image_caption "$source_image"
  is_this_a_boring_filename "$source_image"

  if [ $GLOBAL_slideshow_print_javascript_navigation -eq 1 ]
  then
    if [ "$prev_image" != NULL -a "$prev_image" ]
    then
      image_name_to_html_name "$prev_image"
      quote_url_chars "$RETURN_html_name"
      t_prev=`echo "$javascript_previous_img" |
              sed "s/@PREVIOUS@/${RETURN_url}/g"`
    fi
    if [ "$next_image" != NULL -a "$next_image" ]
    then
      image_name_to_html_name "$next_image"
      quote_url_chars "$RETURN_html_name"
      t_next=`echo "$javascript_next_img" |
              sed "s/@NEXT@/${RETURN_url}/g"`
    fi
    t=`echo "$javascript_navigate" |
       sed -e "s/@JAVASCRIPT_PREVIOUS@/${t_prev}/g" |
       sed -e "s/@JAVASCRIPT_NEXT@/${t_next}/g"`
  fi

#

  echo '<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN"'
  echo '     "http://www.w3.org/TR/html4/loose.dtd">'
  echo '<html>'
  echo '<head>'
  echo "  <title>$RETURN_caption_inline</title>"
  [ -n "$GLOBAL_meta_tag" -a "$GLOBAL_meta_tag" != undef ] && echo "  $GLOBAL_meta_tag"
  if [ "$GLOBAL_html_charset" != "undef" ]
  then
    echo "  <meta http-equiv=\"Content-Type\" content=\"text/html; charset=${GLOBAL_html_charset}\">"
  fi
  echo "  <meta name=\"generator\" content=\"makethumbs v$GLOBAL_makethumbs_version\">"
  echo '  <!-- makethumbs generated HTML file which may be removed without warning -->'

  [ $GLOBAL_slideshow_print_javascript_navigation -eq 1 ] && echo "$t"
  if [ -n "$GLOBAL_boilerplate_slideshow_insert_in_head" -a \
          "$GLOBAL_boilerplate_slideshow_insert_in_head" != undef ]
  then
    echo "$GLOBAL_boilerplate_slideshow_insert_in_head"
  elif [ -n "$GLOBAL_boilerplate_insert_in_head" -a \
          "$GLOBAL_boilerplate_insert_in_head" != undef ]
  then
    echo "$GLOBAL_boilerplate_insert_in_head"
  fi
  echo '</head>'
  echo "$GLOBAL_body_tag"
  echo ""

  if [ -n "$GLOBAL_boilerplate_slideshow_before_title" -a \
          "$GLOBAL_boilerplate_slideshow_before_title" != undef ]
  then
    echo "$GLOBAL_boilerplate_slideshow_before_title"
    echo ""
  elif [ -n "$GLOBAL_boilerplate_before_title" -a \
          "$GLOBAL_boilerplate_before_title" != undef ]
  then
    echo "$GLOBAL_boilerplate_before_title"
    echo ""
  fi

  if [ $GLOBAL_print_title_on_slideshow -eq 1 ]
  then
    get_directory_title
    if [ -n "$RETURN_directory_title_inline" ]
    then
      if [ $RETURN_directory_title_is_from_user -eq 1 ]
      then
        echo $ac_n "$GLOBAL_slideshow_page_title_start_html$ac_c"
        if [ $GLOBAL_print_directory_title_on_slideshow_pages -eq 1 ]
        then
          echo $ac_n "$RETURN_directory_title_inline$ac_c"
        fi
        if [ $GLOBAL_heuristic_filenames_are_digicam_boring -eq 0 -o \
             $RETURN_caption_was_from = "descriptions-file" -o \
             $RETURN_is_boring -eq 0 ]
        then
          if [ $GLOBAL_print_directory_title_on_slideshow_pages -eq 1 ]
          then
            echo $ac_n " / $ac_c"
          fi
          echo $ac_n "$RETURN_caption_inline$ac_c"
        fi
        echo "$GLOBAL_slideshow_page_title_end_html"
      elif [ $RETURN_caption_was_from = "descriptions-file" -o \
             $RETURN_is_boring -eq 0 ]
      then
        echo $ac_n "$GLOBAL_slideshow_page_title_start_html$ac_c"
        echo $ac_n "$RETURN_caption_inline$ac_c"
        echo    "$GLOBAL_slideshow_page_title_end_html"
      fi
    fi
  fi
  if [ -n "$GLOBAL_boilerplate_slideshow_after_title" -a \
          "$GLOBAL_boilerplate_slideshow_after_title" != undef ]
  then
    echo "$GLOBAL_boilerplate_slideshow_after_title"
    echo ""
  elif [ -n "$GLOBAL_boilerplate_after_title" -a \
          "$GLOBAL_boilerplate_after_title" != undef ]
  then
    echo "$GLOBAL_boilerplate_after_title"
    echo ""
  fi
}

print_slideshow_size_links ()
{
  local current_image current_image_type
  local reduced_image large_image orig_image

  local reduced_link_text large_link_text orig_link_text half_link_text
  local size
  local spacer t

  current_image_type="$1"
  current_image="$2"

  if [ $GLOBAL_slideshow_img_size_across_two_lines -eq 1 ]
  then
    spacer="<br />"
  else
    spacer="&nbsp;"
  fi

  generated_name_to_source_name "$current_image"
  orig_image="$RETURN_source_name"
  source_name_to_reduced_name "$orig_image"
  reduced_image="$RETURN_reduced_name"
  source_name_to_large_name "$orig_image"
  large_image="$RETURN_large_name"
  source_name_to_half_name "$orig_image"
  half_image="$RETURN_half_name"

  if [ -f "$reduced_image" ]
  then
    if [ $GLOBAL_print_img_size_on_slideshow -eq 1 ]
    then
      return_image_size "$reduced_image"
      size="${spacer}(${RETURN_image_size_str})"
    fi
    t=`echo "$GLOBAL_reduced_text" | sed -e 's, ,\&nbsp;,g'`
    if [ "$current_image_type" != "reduced" ]
    then
      image_name_to_html_name "$reduced_image"
      quote_url_chars "$RETURN_html_name"
      reduced_link_text="[<a href=\"$RETURN_url\">${t}</a>]$size"
    else
      reduced_link_text="[${t}]$size"
    fi
  fi

  if [ -f "$large_image" ]
  then
    if [ $GLOBAL_print_img_size_on_slideshow -eq 1 ]
    then
      return_image_size "$large_image"
      size="${spacer}(${RETURN_image_size_str})"
    fi
    t=`echo "$GLOBAL_large_text" | sed -e 's, ,\&nbsp;,g'`
    if [ "$current_image_type" != "large" ]
    then
      image_name_to_html_name "$large_image"
      quote_url_chars "$RETURN_html_name"
      large_link_text="[<a href=\"$RETURN_url\">${t}</a>]$size"
    else
      large_link_text="[${t}]$size"
    fi
  fi

  if [ -f "$half_image" ]
  then
    if [ $GLOBAL_print_img_size_on_slideshow -eq 1 ]
    then
      return_image_size "$half_image"
      size="${spacer}(${RETURN_image_size_str})"
    fi
    t=`echo "$GLOBAL_half_text" | sed -e 's, ,\&nbsp;,g'`
    if [ "$current_image_type" != "half" ]
    then
      image_name_to_html_name "$half_image"
      quote_url_chars "$RETURN_html_name"
      half_link_text="[<a href=\"$RETURN_url\">${t}</a>]$size"
    else
      half_link_text="[${t}]$size"
    fi
  fi

  if [ -f "$orig_image" ]
  then
    if [ $GLOBAL_print_img_size_on_slideshow -eq 1 ]
    then
      return_image_size "$orig_image"
      size="${spacer}(${RETURN_image_size_str})"
    fi
    t=`echo "$GLOBAL_original_text" | sed -e 's, ,\&nbsp;,g'`
    if [ "$current_image_type" != "source" ]
    then
      image_name_to_html_name "$orig_image"
      quote_url_chars "$RETURN_html_name"
      orig_link_text="[<a href=\"$RETURN_url\">${t}</a>]$size"
    else
      orig_link_text="[${t}]$size"
    fi
  fi

  [ -z "$reduced_link_text" -a -z "$large_link_text" -a -z "$half_link_text" ] && return

  echo '<div align="center">'
  echo '  <table cellspacing="0" cellpadding="0"><tr>'
  echo "    <td align=\"center\">$reduced_link_text</td>"
  echo "    <td>&nbsp;</td>"
  echo "    <td align=\"center\">$large_link_text</td>"
  echo "    <td>&nbsp;</td>"
  if [ -n "$half_link_text" ]
  then
    echo "    <td align=\"center\">$half_link_text</td>"
    echo "    <td>&nbsp;</td>"
  fi
  echo "    <td align=\"center\">$orig_link_text</td>"
  echo '  </tr></table></div>'
}

print_slideshow_image_description ()
{
  local image_name

  image_name="$*"
  get_image_description "$image_name"

  if [ -n "$RETURN_image_description" ]
  then
    echo "<p /><div align=\"center\">$RETURN_image_description</div>"
  fi
}

print_slideshow_file_footer ()
{
  if [ -n "$GLOBAL_boilerplate_footer" -a \
       "$GLOBAL_boilerplate_footer" != undef ]
  then
    echo ""
    echo "$GLOBAL_boilerplate_footer"
    echo ""
  fi

  if [ -n "$GLOBAL_boilerplate_slideshow_end_of_page" -a \
       "$GLOBAL_boilerplate_slideshow_end_of_page" != undef ]
  then
    echo "$GLOBAL_boilerplate_slideshow_end_of_page"
  elif [ -n "$GLOBAL_boilerplate_end_of_page" -a \
          "$GLOBAL_boilerplate_end_of_page" != undef ]
  then
    echo "$GLOBAL_boilerplate_end_of_page"
  else
    echo "$GLOBAL_body_end_tag"
    echo "</html>"
  fi
}

print_slideshow_image ()
{
  local cur_image type target_pre target_post
  local source_image click_target_image
  local caption_quoted

  cur_image="$1"
  type="$2"
  target_pre=""
  target_post=""

  get_image_caption "$cur_image"
  is_this_a_boring_filename "$cur_image"
  if [ $RETURN_is_boring -eq 1 -a $RETURN_caption_was_from = filename ]
  then
    caption_quoted=""
  else
    quote_html_chars "$RETURN_caption_inline"
    caption_quoted="$RETURN_html"
  fi

# If we're going to make the image clickable, then clicking proceeds
# in this order if all the image types exist:
#  reduced -> large -> source -> reduced -> large -> ...

  if [ $GLOBAL_slideshow_images_are_clickable -eq 1 ]
  then
    generated_name_to_source_name "$cur_image"
    source_image="$RETURN_source_name"
    source_name_to_large_name "$source_image"
    source_name_to_half_name "$source_image"
    source_name_to_reduced_name "$source_image"

    if [ "$type" = "reduced" ]
    then
      if [ -f "$RETURN_large_name" ]
      then
        click_target_image="$RETURN_large_name"
      else
        click_target_image="$source_image"
      fi
    fi
    if [ "$type" = "large" ]
    then
      if [ -f "$RETURN_half_name" ]
      then
        click_target_image="$RETURN_half_name"
      else
        click_target_image="$source_image"
      fi
    fi
    if [ "$type" = "half" ]
    then
      click_target_image="$source_image"
    fi

    if [ "$type" = "source" ]
    then
      if [ -f "$RETURN_reduced_name" ]
      then
        click_target_image="$RETURN_reduced_name"
      elif [ -f "$RETURN_large_name" ]
      then
        click_target_image="$RETURN_large_name" ]
      fi
    fi

    if [ -n "$click_target_image" -a "$click_target_image" != "$cur_image" ]
    then
      image_name_to_html_name "$click_target_image"
      quote_url_chars "$RETURN_html_name"
      target_pre="<a href=\"$RETURN_url\">"
      target_post="</a>"
    fi
  fi
  get_dimensions "$cur_image"

  echo ""
  quote_url_chars "$cur_image"
  echo "<div align=\"center\">$target_pre<img src=\"$RETURN_url\" height=\"$RETURN_height\" width=\"$RETURN_width\" alt=\"$caption_quoted\" />$target_post</div>"
  echo ""
}

print_slideshow_top_navlinks ()
{
  local prev_image cur_image next_image
  local prev_html cur_html next_html
  local prev_markup middle_markup next_markup index_href
  local imgno imgtotal right_text left_text
  local t

  prev_image="$1"
  cur_image="$2"
  next_image="$3"

  prev_html="$prev_image"
  cur_html="$cur_image"
  next_html="$next_image"

  middle_markup=""

  if [ "$prev_image" != NULL ]
  then
    image_name_to_html_name "$prev_image"
    prev_html="$RETURN_html_name"
  fi
  image_name_to_html_name "$cur_image"
  cur_html="$RETURN_html_name"
  if [ "$next_image" != NULL ]
  then
    image_name_to_html_name "$next_image"
    next_html="$RETURN_html_name"
  fi

## Emit link to previous image
  if [ "$prev_image" = NULL ]
  then
    prev_markup="$GLOBAL_slideshow_previous_pre_link$GLOBAL_slideshow_previous$GLOBAL_slideshow_previous_post_link"
  else
    quote_url_chars "$prev_html"
    prev_markup="$GLOBAL_slideshow_previous_pre_link<a href=\"$RETURN_url\">$GLOBAL_slideshow_previous</a>$GLOBAL_slideshow_previous_post_link"
  fi

## Emit link to next image
  if [ "$next_image" = NULL ]
  then
    next_markup="$GLOBAL_slideshow_next_pre_link$GLOBAL_slideshow_next$GLOBAL_slideshow_next_post_link"
  else
    quote_url_chars "$next_html"
    next_markup="$GLOBAL_slideshow_next_pre_link<a href=\"$RETURN_url\">$GLOBAL_slideshow_next</a>$GLOBAL_slideshow_next_post_link"
  fi

## Emit link to index
  map_image_to_index "$cur_image"
  middle_markup="$GLOBAL_slideshow_ret_to_index_pre_link<a href=\"${RETURN_index_name}\">$GLOBAL_slideshow_ret_to_index</a>$GLOBAL_slideshow_ret_to_index_post_link"

## Get "Image xx of yy" info
  get_image_number "$cur_image"
  imgno="$RETURN_image_number"
  imgtotal="$RETURN_number_of_images"
  if [ -n "$imgno" -a -n "$imgtotal" ]
  then
    t=`echo "$GLOBAL_image_xx_of_yy_text" | 
       sed -e "s,@CURRENT@,${imgno}," -e "s,@TOTAL@,${imgtotal},"`
    right_txt="$t"
    left_txt=""
  else
    right_txt="&nbsp;"
    left_txt="&nbsp;"
  fi

  get_image_timestamp_from_dates_file "$cur_image"
  if [ -n "$RETURN_timestamp" ]
  then
    left_txt="$RETURN_timestamp"
  fi

  echo ''

  echo '<table width="100%">'
  echo "<tr>"
  echo "  <td align=\"left\" width=\"25%\">$left_txt</td>"
  echo '  <td align="center" width="50%">'
  echo '    <table><tr>'
  echo "      <td>$prev_markup</td>"
  echo "      <td>&nbsp;</td>"
  echo "      <td>$middle_markup</td>"
  echo "      <td>&nbsp;</td>"
  echo "      <td>$next_markup</td>"
  echo '    </tr></table>'
  echo '  </td>'
  echo "  <td align=\"right\" width=\"25%\">$right_txt</td>"
  echo '</tr>'
  echo '</table>'

  echo ''
}

print_slideshow_bottom_navlinks ()
{
  local prev_image cur_image next_image
  local prev_html cur_html next_html
  local prev_markup middle_markup next_markup index_href
  local imgno imgtotal right_text left_text
  local t

  [ $GLOBAL_slideshow_print_bottom_navlinks -eq 0 ] && return

  prev_image="$1"
  cur_image="$2"
  next_image="$3"

  prev_html="$prev_image"
  cur_html="$cur_image"
  next_html="$next_image"

  middle_markup=""

  if [ "$prev_image" != NULL ]
  then
    image_name_to_html_name "$prev_image"
    prev_html="$RETURN_html_name"
  fi
  image_name_to_html_name "$cur_image"
  cur_html="$RETURN_html_name"
  if [ "$next_image" != NULL ]
  then
    image_name_to_html_name "$next_image"
    next_html="$RETURN_html_name"
  fi

## Emit link to previous image
  if [ "$prev_image" = NULL ]
  then
    prev_markup="$GLOBAL_slideshow_previous_pre_link$GLOBAL_slideshow_previous$GLOBAL_slideshow_previous_post_link"
  else
    quote_url_chars "$prev_html"
    prev_markup="$GLOBAL_slideshow_previous_pre_link<a href=\"$RETURN_url\">$GLOBAL_slideshow_previous</a>$GLOBAL_slideshow_previous_post_link"
  fi

## Emit link to next image
  if [ "$next_image" = NULL ]
  then
    next_markup="$GLOBAL_slideshow_next_pre_link$GLOBAL_slideshow_next$GLOBAL_slideshow_next_post_link"
  else
    quote_url_chars "$next_html"
    next_markup="$GLOBAL_slideshow_next_pre_link<a href=\"$RETURN_url\">$GLOBAL_slideshow_next</a>$GLOBAL_slideshow_next_post_link"
  fi

## Emit link to index
  map_image_to_index "$cur_image"
  middle_markup="$GLOBAL_slideshow_ret_to_index_pre_link<a href=\"${RETURN_index_name}\">$GLOBAL_slideshow_ret_to_index</a>$GLOBAL_slideshow_ret_to_index_post_link"

## Get "Image xx of yy" info
  right_txt="&nbsp;"
  left_txt="&nbsp;"

  echo ''

  echo '<table width="100%">'
  echo "<tr>"
  echo "  <td align=\"left\" width=\"25%\">$left_txt</td>"
  echo '  <td align="center" width="50%">'
  echo '    <table><tr>'
  echo "      <td>$prev_markup</td>"
  echo "      <td>&nbsp;</td>"
  echo "      <td>$middle_markup</td>"
  echo "      <td>&nbsp;</td>"
  echo "      <td>$next_markup</td>"
  echo '    </tr></table>'
  echo '  </td>'
  echo "  <td align=\"right\" width=\"25%\">$right_txt</td>"
  echo '</tr>'
  echo '</table>'

  echo ''
}


create_slideshow_image_list ()
{
  local number_of_files
  local prev_num   cur_num   next_num
  local prev_image cur_image next_image

  number_of_files=`cat $GLOBAL_image_list_tmpfile | wc -l | sed 's, ,,g'`
  cur_num=1

  make_tmpfile ss-source
  GLOBAL_slideshow_image_list=$RETURN_tmpfile

  while [ $cur_num -le $number_of_files ]
  do
    prev_num=`expr $cur_num - 1`
    next_num=`expr $cur_num + 1`

    if [ $cur_num -eq 1 ]
    then
      prev_image=NULL
    else
      prev_image=`cat $GLOBAL_image_list_tmpfile | sed -n "${prev_num}p"`
    fi
    cur_image=`cat $GLOBAL_image_list_tmpfile | sed -n "${cur_num}p"`
    if [ $cur_num -eq $number_of_files ]
    then
      next_image=NULL
    else
      next_image=`cat $GLOBAL_image_list_tmpfile | sed -n "${next_num}p"`
    fi

    echo "${prev_image}|${cur_image}|${next_image}" >> $GLOBAL_slideshow_image_list
    cur_num=`expr $cur_num + 1`
  done
}

remove_existing_slideshow_html_files ()
{
  local file_list fn

  make_tmpfile file_list
  file_list=$RETURN_tmpfile

  ls -1 | grep "\.$GLOBAL_html_file_suffix" > $file_list
  while read fn
  do
    if grep "makethumbs generated HTML file which may be removed without warning" "$fn" >/dev/null 2>&1
    then
      rm -f "$fn"
    fi
  done < $file_list
}



#########################################################
#### Progress printing functions
#########################################################

# Descriptions.txt

progress_update_start_descriptions ()
{
  [ $GLOBAL_show_progress -eq 0 ] && return
  if [ $GLOBAL_show_timings -eq 1 ]
  then
    GLOBAL_progress_timestamp_start=`date '+%s' 2>/dev/null`
  fi
}

progress_update_created_descriptions ()
{
  [ $GLOBAL_show_progress -eq 0 ] && return
  echo $ac_n "Created $GLOBAL_descriptions_filename$ac_c" >&2
  if [ $GLOBAL_show_timings -eq 1 ]
  then
    print_timestamp_diff $GLOBAL_progress_timestamp_start `date '+%s'`
  fi
  echo "" >&2
}

progress_update_updated_descriptions ()
{
  [ $GLOBAL_show_progress -eq 0 ] && return
  echo $ac_n "Updated $GLOBAL_descriptions_filename$ac_c" >&2
  if [ $GLOBAL_show_timings -eq 1 ]
  then
    print_timestamp_diff $GLOBAL_progress_timestamp_start `date '+%s'`
  fi
  echo "" >&2
}

# Dates.txt

progress_update_start_updating_dates ()
{
  [ $GLOBAL_show_progress -eq 0 ] && return
  if [ $GLOBAL_show_timings -eq 1 ]
  then
    GLOBAL_progress_timestamp_start=`date '+%s' 2>/dev/null`
  fi
}

progress_update_done_updating_dates ()
{
  [ $GLOBAL_show_progress -eq 0 ] && return
  echo $ac_n "Updated $GLOBAL_dates_filename$ac_c" >&2
  if [ $GLOBAL_show_timings -eq 1 ]
  then
    print_timestamp_diff $GLOBAL_progress_timestamp_start `date '+%s'`
  fi
  echo "" >&2
}

progress_update_start_creating_dates ()
{
  [ $GLOBAL_show_progress -eq 0 ] && return
  echo $ac_n "Creating $GLOBAL_dates_filename $ac_c" >&2
  if [ $GLOBAL_show_timings -eq 1 ]
  then
    GLOBAL_progress_timestamp_start=`date '+%s' 2>/dev/null`
  fi
}

progress_update_created_date ()
{
  [ $GLOBAL_show_progress -eq 0 ] && return
  echo $ac_n ".$ac_c" >&2
}

progress_update_done_creating_dates ()
{
  local time
  [ $GLOBAL_show_progress -eq 0 ] && return
  echo $ac_n " done.$ac_c" >&2

  if [ $GLOBAL_show_timings -eq 1 ]
  then
    print_timestamp_diff $GLOBAL_progress_timestamp_start `date '+%s'`
  fi
  echo "" >&2
}

# index.html

progress_update_start_creating_index_html ()
{
  local fn
  fn="$*"
  [ -z "$fn" ] && fn="$GLOBAL_index_filename"
  if [ $GLOBAL_show_timings -eq 1 ]
  then
    GLOBAL_progress_timestamp_start=`date '+%s' 2>/dev/null`
  fi

  [ $GLOBAL_show_progress -eq 0 ] && return
  echo $ac_n "Creating $fn$ac_c" >&2
}

progress_update_done_creating_index_html ()
{
  local time
  [ $GLOBAL_show_progress -eq 0 ] && return

  if [ $GLOBAL_show_timings -eq 1 ]
  then
    print_timestamp_diff $GLOBAL_progress_timestamp_start `date '+%s'`
  fi
  echo "" >&2
}

# reduced/thumbnail images

progress_update_start_creating_reduced_images ()
{
  [ $GLOBAL_show_progress -eq 0 ] && return
  echo $ac_n "Making reduced/thumbnail images $ac_c" >&2
  GLOBAL_did_we_reduce_anything=0
  if [ $GLOBAL_show_timings -eq 1 ]
  then
    GLOBAL_progress_timestamp_start=`date '+%s' 2>/dev/null`
  fi
}

progress_update_created_feed_image ()
{
  [ $GLOBAL_show_progress -eq 0 ] && return
  echo $ac_n ",$ac_c" >&2
  GLOBAL_did_we_reduce_anything=1
}

progress_update_created_reduced_image ()
{
  [ $GLOBAL_show_progress -eq 0 ] && return
  echo $ac_n "o$ac_c" >&2
  GLOBAL_did_we_reduce_anything=1
}

progress_update_created_large_image ()
{
  [ $GLOBAL_show_progress -eq 0 ] && return
  echo $ac_n "O$ac_c" >&2
  GLOBAL_did_we_reduce_anything=1
}

progress_update_created_half_image ()
{
  [ $GLOBAL_show_progress -eq 0 ] && return
  echo $ac_n "0$ac_c" >&2
  GLOBAL_did_we_reduce_anything=1
}

progress_update_created_thumbnail_image ()
{
  [ $GLOBAL_show_progress -eq 0 ] && return
  echo $ac_n ".$ac_c" >&2
  GLOBAL_did_we_reduce_anything=1
}

progress_update_done_creating_reduced_images ()
{
  [ $GLOBAL_show_progress -eq 0 ] && return
  if [ $GLOBAL_did_we_reduce_anything -eq 0 ]
  then
    echo $ac_n "(none regenerated)$ac_c" >&2
  else
    echo $ac_n " done.$ac_c" >&2
  fi

  if [ $GLOBAL_show_timings -eq 1 ]
  then
    print_timestamp_diff $GLOBAL_progress_timestamp_start `date '+%s'`
  fi
  echo "" >&2
}

# slideshow pages

progress_update_start_creating_slideshow_pages ()
{
  [ $GLOBAL_show_progress -eq 0 ] && return
  echo $ac_n "Making slideshow pages $ac_c" >&2
  if [ $GLOBAL_show_timings -eq 1 ]
  then
    GLOBAL_progress_timestamp_start=`date '+%s' 2>/dev/null`
  fi
}

progress_update_created_slideshow_page ()
{
  [ $GLOBAL_show_progress -eq 0 ] && return
  echo $ac_n ".$ac_c" >&2
}

progress_update_done_creating_slideshow_pages ()
{
  [ $GLOBAL_show_progress -eq 0 ] && return
  echo $ac_n " done.$ac_c" >&2

  if [ $GLOBAL_show_timings -eq 1 ]
  then
    print_timestamp_diff $GLOBAL_progress_timestamp_start `date '+%s'`
  fi
  echo "" >&2
}

print_timestamp_diff ()
{
  local start end
  local secs
  local mins

  start=$1
  end=$2
  secs=""
  mins=""

  [ -z "$start" -o -z "$end" ] && return

  secs=`expr $end - $start 2>/dev/null`
  [ -z "$secs" ] && return

  if [ $secs -ge 100 ]
  then
    mins=`expr $secs / 60`
    secs=`expr $secs % 60`
    echo $ac_n " ($mins minutes $secs seconds)$ac_c" >&2
  else
    echo $ac_n " ($secs seconds)$ac_c" >&2
  fi
}

#########################################################
#### checksum checking functions, unmodified file removal
#########################################################

remove_file_if_unmodified ()
{
  local filename

  filename="$*"
  verify_file_checksum "$filename"
  if [ $RETURN_cksum_ok -eq 1 ]
  then
    rm -f "$filename"
    return
  fi
}

# $RETURN_cksum_ok is '1' if a valid checksum is found.  If no checksum
# is found, or the checksum doesn't match, a '0' is returned (i.e. the
# user may have modified this file for all we know).

verify_file_checksum ()
{
  local filename sum_program recorded_sum sum_output

  filename="$*"
  RETURN_cksum_ok=0
  if grep '<!-- makethumbs checksum ' "$filename" >/dev/null 2>&1
  then
    :
  else
    return
  fi

  sum_program=`grep '<!-- makethumbs checksum' "$filename"  | tail -1 |
                sed -e 's,.*makethumbs checksum \([^ ]*\) \(.*\) -->,\1,'`
  recorded_sum=`grep '<!-- makethumbs checksum' "$filename" | tail -1 |
                sed -e 's,.*makethumbs checksum \([^ ]*\) \(.*\) -->,\2,'`

  find_in_path "$sum_program"
  [ $RETURN_found -eq 0 ] && return

  sum_output=`grep -v '<!-- makethumbs checksum' "$filename" | "$sum_program"`
  if [ "$sum_program" = md5sum -o "$sum_program" = sha1sum ]
  then
    sum_output=`echo "$sum_output" | awk '{print $1}'`
  fi

  normalize_checksum_string "$sum_output"
  sum_output="$RETURN_str_norm"

  normalize_checksum_string "$recorded_sum"
  recorded_sum="$RETURN_str_norm"

  if [ -n "$sum_output" -a -n "$recorded_sum" -a \
       "$sum_output" = "$recorded_sum" ]
  then
    RETURN_cksum_ok=1
  fi

}

find_checksum_program ()
{
  local i

  for i in md5sum md5 sha1sum cksum sum
  do
    find_in_path $i
    if [ $RETURN_found -eq 1 ]
    then
      RETURN_cksum_prog=$i
      return
    fi
  done

  RETURN_cksum_prog=""
}

add_checksum_to_file ()
{
  local filename sum

  filename="$*"
  find_checksum_program
  [ -z "$RETURN_cksum_prog" ] && return
  [ -z "$filename" ] && return

  if grep '<!-- makethumbs checksum ' "$filename" >/dev/null 2>&1
  then
    return
  fi

  sum=`cat $filename | $RETURN_cksum_prog`
  if [ $RETURN_cksum_prog = md5sum -o $RETURN_cksum_prog = sha1sum ]
  then
    sum=`echo "$sum" | awk '{print $1}'`
  fi

  normalize_checksum_string "$sum"
  sum="$RETURN_str_norm"

  echo "<!-- makethumbs checksum $RETURN_cksum_prog $sum -->" >> "$filename"
}

normalize_checksum_string ()
{
  local istr

  istr="$*"
  istr=`echo "$istr" | sed -e 's,^[ 	]*,,' -e 's,[ 	]*$,,' \
                           -e 's,[ 	][ 	]*, ,'`
  RETURN_str_norm="$istr"
}


#########################################################
#### descriptions.txt support
#########################################################

create_descriptions_file ()
{
  local max i l

  progress_update_start_descriptions
  if [ -f $GLOBAL_descriptions_filename ]
  then
    update_descriptions_file
    return
  fi

  add_cleanup $GLOBAL_descriptions_filename
  touch $GLOBAL_descriptions_filename
  make_file_world_readable $GLOBAL_descriptions_filename

  echo '[short title]  (best to avoid HTML markup here, keep it short, <br>s are OK)' > $GLOBAL_descriptions_filename
  echo ''                          >> $GLOBAL_descriptions_filename
  echo ''                          >> $GLOBAL_descriptions_filename
  echo '[longer page description]  (all the HTML you want, as many lines as you want)' >> $GLOBAL_descriptions_filename
  echo ''                          >> $GLOBAL_descriptions_filename
  echo ''                          >> $GLOBAL_descriptions_filename
  echo '[captions]  (best to avoid HTML markup here, keep it short, <br>s are OK)' >> $GLOBAL_descriptions_filename
  echo ''                          >> $GLOBAL_descriptions_filename

# find max length of image names
  max=0
  while read i
  do
    l=`echo "$i" | awk '{print length}'`
    [ $l -gt $max ] && max=$l
  done < $GLOBAL_image_list_tmpfile

  while read i
  do
    echo "$i" |
       awk "{printf (\"%-${max}s \\n\""', $0);}' >> $GLOBAL_descriptions_filename
  done < $GLOBAL_image_list_tmpfile

  echo ''                          >> $GLOBAL_descriptions_filename
  echo '[descriptions]  (all the HTML you want, but each file on just one line)' >> $GLOBAL_descriptions_filename
  echo ''                          >> $GLOBAL_descriptions_filename

  while read i
  do
    echo "$i" |
       awk "{printf (\"%-${max}s \\n\""', $0);}' >> $GLOBAL_descriptions_filename
  done < $GLOBAL_image_list_tmpfile

  remove_cleanup $GLOBAL_descriptions_filename
  make_file_world_readable $GLOBAL_descriptions_filename
  progress_update_created_descriptions
}

update_descriptions_file ()
{
  local filenames_to_add fn new_desc oldsz newsz

  make_tmpfile newfiles
  filenames_to_add="$RETURN_tmpfile"

  while read fn
  do
    check_if_file_in_descriptions_file "$fn"
    if [ $RETURN_file_is_present -eq 0 ]
    then
      echo "$fn  " >> $filenames_to_add
    fi
  done < $GLOBAL_image_list_tmpfile

  [ ! -s $filenames_to_add ] && return

  make_tmpfile new-desc
  new_desc="$RETURN_tmpfile"

  cat $GLOBAL_descriptions_filename | sed '/^\[captions\]/,$d' > $new_desc
  grep '^\[captions\]' $GLOBAL_descriptions_filename >> $new_desc
  echo "" >> $new_desc
  cat $GLOBAL_descriptions_filename |
       sed '1,/^\[captions\]/d' |
       sed '/^\[descriptions\]/,$d' | grep -v '^[ 	]*$' >> $new_desc
  cat $filenames_to_add >> $new_desc

  echo "" >> $new_desc
  grep '^\[descriptions\]' $GLOBAL_descriptions_filename >> $new_desc
  echo "" >> $new_desc
  cat $GLOBAL_descriptions_filename |
       sed '1,/^\[descriptions\]/d' | grep -v '^[ 	]*$' >> $new_desc
  cat $filenames_to_add >> $new_desc

  [ ! -s "$new_desc" ] && return

  oldsz=`ls -l $GLOBAL_descriptions_filename | awk '{print $5}' | sed 's,[^0-9],,g'`
  newsz=`ls -l $new_desc | awk '{print $5}' | sed 's,[^0-9],,g'`

# If the new one isn't larger than the old one, something is wrong.
  if [ $newsz -gt $oldsz ]
  then
    cat $new_desc > $GLOBAL_descriptions_filename
  else
    echo WARNING:  Some problem updating the $GLOBAL_descriptions_filename 1>&2
  fi
  progress_update_updated_descriptions
}


#
validate_descriptions_file ()
{
  local is_valid

  [ ! -f $GLOBAL_descriptions_filename ] && return
  [ $GLOBAL_descriptions_file_validated -eq 1 ] && return
  [ $GLOBAL_descriptions_file_is_invalid -eq 1 ] && return

  is_valid=`cat $GLOBAL_descriptions_filename |
     egrep '^\[short title\]|^\[longer page description\]|^\[captions\]|^\[descriptions\]' |
     awk 'BEGIN { state = 0 } { \
       if ($1 == "[short" && $2 == "title]" && state == 0 )
          { state = 1 ; next }
       if ($1 == "[longer" && $2 == "page" && state == 1)
          { state = 2 ; next}
       if ($1 == "[captions]" && state == 2)
          { state = 3; next}
       if ($1 == "[descriptions]" && state == 3)
          { print "ok"; next}
       print "error"
     }'`

  if [ -n "$is_valid" ]
  then
    if [ "$is_valid" = "ok" ]
    then
      GLOBAL_descriptions_file_validated=1
    else
      echo WARNING: Invalid $GLOBAL_descriptions_filename !  Ignoring. 1>&2
      GLOBAL_descriptions_file_is_invalid=1
    fi
  fi
}

check_if_file_in_descriptions_file ()
{
  local title_count no_title_count tot
  RETURN_file_is_present=0

  quote_egrep_chars "$*"
  title_count=`egrep "^$RETURN_egrep[ 	]*[^ 	].*\$" $GLOBAL_descriptions_filename | wc -l | sed 's,[^0-9],,g'`
  no_title_count=`egrep "^$RETURN_egrep[ 	]*\$"  $GLOBAL_descriptions_filename | wc -l | sed 's,[^0-9],,g'`

  tot=`expr "$title_count" + "$no_title_count"`
  if [ -n "$tot" -a "$tot" -ge 2 ]
  then
    RETURN_file_is_present=1
  fi
  if [ $GLOBAL_no_image_titles_or_descriptions -eq 1 -a "$title_count" -gt 0 ]
  then
    GLOBAL_no_image_titles_or_descriptions=0
  fi
}

get_short_page_title_from_descriptions_file ()
{
  RETURN_short_page_title=""

  [ ! -f $GLOBAL_descriptions_filename ] && return
  validate_descriptions_file
  [ $GLOBAL_descriptions_file_validated -eq 0 ] && return

  RETURN_short_page_title=`cat $GLOBAL_descriptions_filename | grep -v '^#' |
    awk 'BEGIN { seen_title = 0; seen_longerdesc = 0; } \
    { \
      if ($1 == "[short" && $2 == "title]") { seen_title = 1; next; }
      if (seen_title != 1) { next; }
      if ($1 == "[longer" && $2 == "page") { seen_longerdesc = 1; next; }
      if (seen_longerdesc == 1) { next; }
      print;
    }' | grep -v '^[ 	]*$'`
  RETURN_short_page_title=`echo "$RETURN_short_page_title" |
         sed -e 's,^[ 	]*,,' -e 's,[ 	]*$,,'`
}

get_page_description_from_descriptions_file ()
{
  RETURN_page_description=""

  [ ! -f $GLOBAL_descriptions_filename ] && return
  validate_descriptions_file
  [ $GLOBAL_descriptions_file_validated -eq 0 ] && return

  RETURN_page_description=`cat $GLOBAL_descriptions_filename | grep -v '^#' |
    awk 'BEGIN { seen_longerdesc = 0; seen_captions = 0; } \
    { \
      if ($1 == "[longer" && $2 == "page") { seen_longdesc = 1; next; }
      if (seen_longdesc != 1) { next; }
      if ($1 == "[captions]") { seen_captions = 1; next; }
      if (seen_captions == 1) { next; }
      print;
    }' | grep -v '^[ 	]*$'`
  RETURN_page_description=`echo "$RETURN_page_description" |
         sed -e 's,^[ 	]*,,' -e 's,[ 	]*$,,'`
}

get_image_caption_from_descriptions_file ()
{
  local fn

  fn="$*"
  RETURN_image_caption=""
  [ ! -f $GLOBAL_descriptions_filename ] && return
  [ $GLOBAL_no_image_titles_or_descriptions -eq 1 ] && return
  [ -z "$fn" ] && return
  validate_descriptions_file
  [ $GLOBAL_descriptions_file_validated -eq 0 ] && return

  generated_name_to_source_name "$fn"
  fn="$RETURN_source_name"
  RETURN_image_caption=`\
     egrep "^${fn}"'[ 	]|^\[captions\]|^\[descriptions\]' \
           $GLOBAL_descriptions_filename |
    awk 'BEGIN { seen_captions = 0; seen_desc = 0; } \
    { \
      if ($1 == "[captions]") { seen_captions = 1; next; }
      if (seen_captions != 1) { next; }
      if ($1 == "[descriptions]") { seen_desc = 1; next; }
      if (seen_desc == 1) { next; }
      print
    }' | grep -v '^[ 	]*$' | head -1`

  RETURN_image_caption=`echo "$RETURN_image_caption" | sed "s/${fn}//" |
            sed -e 's,^[ 	]*,,' -e 's,[ 	]*$,,'`
}

get_image_description_from_descriptions_file ()
{
  local fn

  fn="$*"
  RETURN_image_description=""
  [ ! -f $GLOBAL_descriptions_filename ] && return
  [ $GLOBAL_no_image_titles_or_descriptions -eq 1 ] && return
  [ -z "$fn" ] && return
  validate_descriptions_file
  [ $GLOBAL_descriptions_file_validated -eq 0 ] && return

  generated_name_to_source_name "$fn"
  fn="$RETURN_source_name"
  RETURN_image_description=`\
     egrep "^${fn}"'[ 	]|^\[captions\]|^\[descriptions\]' \
           $GLOBAL_descriptions_filename |
    awk 'BEGIN { seen_desc = 0; } \
    { \
      if ($1 == "[descriptions]") { seen_desc = 1; next; }
      if (seen_desc != 1) { next; }
      print
    }' | grep -v '^[ 	]*$' | head -1`

  RETURN_image_description=`echo "$RETURN_image_description" |
            sed "s/${fn}//" |
            sed -e 's,^[ 	]*,,' -e 's,[ 	]*$,,'`
}


# Return the filenames in the [captions] section, in the order they
# appear in the file.

get_caption_filenames_from_descriptions_file ()
{
  RETURN_captions_tmpfile=""

  [ ! -f $GLOBAL_descriptions_filename ] && return
  validate_descriptions_file
  [ $GLOBAL_descriptions_file_validated -eq 0 ] && return

  make_tmpfile captions
  RETURN_captions_tmpfile="$RETURN_tmpfile"

  cat $GLOBAL_descriptions_filename |
       sed '1,/^\[captions\]/d' |
       sed '/^\[descriptions\]/,$d' |
       grep -v '^[ 	]*$' |
       sed 's,^\(.*\)\.\([jgp][pin][gfg]\)[ 	].*,\1.\2,' \
          >> $RETURN_captions_tmpfile
}

## The functions that the rest of the script will use:

get_image_caption ()
{
  local fn

  fn="$*"
  get_image_caption_from_descriptions_file "$fn"
  if [ -n "$RETURN_image_caption" ]
  then
    RETURN_caption="$RETURN_image_caption"
    RETURN_caption_was_from="descriptions-file"
    RETURN_caption_inline=`echo "$RETURN_caption" |
                 sed -e 's, *<[Bb][Rr]> *, ,g' -e 's, *<[Bb][Rr] */> *, ,g'`
  else
    RETURN_caption=`echo "$fn" |
      sed -e 's,-[bfhtrl]\.[jpgpnggif]*$,,' \
          -e 's,\.[jpgpnggif]*$,,' \
          -e 's,-, ,g' -e 's,_, ,g'`
    RETURN_caption_inline="$RETURN_caption"
    RETURN_caption_was_from="filename"
  fi
}

get_image_caption_for_main_index ()
{
  local fn
  fn="$*"

  get_image_caption "$fn"
  [ "$RETURN_caption_was_from" = "descriptions-file" ] && return
  [ $GLOBAL_use_timestamps_as_captions -eq 0 ] && return

  if [ $GLOBAL_heuristic_filenames_are_digicam_boring -eq 1 ]
  then
    get_image_timestamp_from_dates_file "$fn"
    if [ $GLOBAL_heuristic_days_are_identical -eq 0 -a -n "$RETURN_date" ]
    then
      iso8601_format_datestr_to_human "$RETURN_date"
      if [ -n "$RETURN_human_date" ]
      then
        RETURN_caption="$RETURN_human_date"
        return
      fi
    fi

    if [ -n "$RETURN_time" ]
    then
      RETURN_caption="$RETURN_time"
      return
    fi
  fi
}

is_this_a_boring_filename ()
{
  local fn t

  generated_name_to_source_name "$*"
  fn="$RETURN_source_name"
  RETURN_is_boring=0

  [ $GLOBAL_heuristic_filenames_are_digicam_boring -eq 0 ] && return

  t=`echo "$fn" | sed 's,[ 	]*[0-9]*[ 	]*,,g'`
  if [ -n "$t" -a -n "$GLOBAL_heuristic_filename_pattern" -a \
       "$t" = "$GLOBAL_heuristic_filename_pattern" ]
  then
    RETURN_is_boring=1
  fi
}

get_image_description ()
{
  get_image_description_from_descriptions_file "$*"
}

get_directory_title ()
{
  local t

  get_short_page_title_from_descriptions_file
  if [ -n "$RETURN_short_page_title" ]
  then
    RETURN_directory_title="$RETURN_short_page_title"
    RETURN_directory_title_inline=`echo "$RETURN_short_page_title" |
                 sed -e 's, *<[Bb][Rr]> *, ,g' -e 's, *<[Bb][Rr] */> *, ,g'`
    RETURN_directory_title_is_from_user=1
  else
    t=`pwd`
    RETURN_directory_title=`basename "$t"`
    RETURN_directory_title_inline="$RETURN_directory_title"
    RETURN_directory_title_is_from_user=0
  fi
}

get_directory_description ()
{
  get_page_description_from_descriptions_file
  RETURN_directory_description="$RETURN_page_description"
}

#########################################################
#### dates.txt support
#########################################################

create_dates_file ()
{
  local fn

  if [ -f $GLOBAL_dates_filename ]
  then
    update_dates_file
    return
  fi

  touch $GLOBAL_dates_filename
  make_file_world_readable $GLOBAL_dates_filename

  cat > $GLOBAL_dates_filename << __EOF__
# This is a one-time generated file (but updated whenever new images are added)
# which records the timestamps of images for various purposes.  You can modify
# any entry if you wish--makethumbs will not regenerate a timestamp unless
# this file is completely removed or an image's entry in this file is removed.

# Each line has three fields -- FILENAME | DATE | TIME .
# DATE should be YYYY-MM-DD, but need not be.
# TIME should be HH:MM, but need not be.

__EOF__

  add_cleanup $GLOBAL_dates_filename
  progress_update_start_creating_dates
  while read fn
  do
    get_image_time_date "$fn"
    echo "${fn}|${RETURN_date}|${RETURN_time}" >> $GLOBAL_dates_filename
    progress_update_created_date
  done < $GLOBAL_image_list_tmpfile

  remove_cleanup "$GLOBAL_dates_filename"
  make_file_world_readable "$GLOBAL_dates_filename"
  progress_update_done_creating_dates
}

update_dates_file ()
{
  local fn updated

  [ ! -f $GLOBAL_dates_filename ] && return
  updated=0
  progress_update_start_updating_dates

  while read fn
  do
    if grep "^${fn}|.*|.*" $GLOBAL_dates_filename >/dev/null 2>&1
    then
      continue
    fi
    get_image_time_date "$fn"
    echo "${fn}|${RETURN_date}|${RETURN_time}" >> $GLOBAL_dates_filename
    updated=1
  done < $GLOBAL_image_list_tmpfile
  [ $updated -eq 1 ] && progress_update_done_updating_dates
}

get_image_timestamp_from_dates_file ()
{
  local fn l

  RETURN_timestamp=""
  RETURN_date=""
  RETURN_time=""
  generated_name_to_source_name "$*"
  fn="$RETURN_source_name"

  [ ! -f $GLOBAL_dates_filename ] && return

  l=`grep "^${fn}|.*|.*$" $GLOBAL_dates_filename 2>/dev/null | head -1`
  if [ -n "$l" ]
  then
    if [ `echo "$l" | awk -F\| '{print NF}'` -eq 3 ]
    then
      RETURN_date=`echo "$l" | awk -F\| '{print $2}' |
                   sed -e 's,^[ 	]*,,' -e 's,[ 	]*$,,'`
      RETURN_time=`echo "$l" | awk -F\| '{print $3}'|
                   sed -e 's,^[ 	]*,,' -e 's,[ 	]*$,,'`
      if [ -n "$RETURN_time" -a -n "$RETURN_date" ]
      then
        RETURN_timestamp="$RETURN_date $RETURN_time"
      else
        RETURN_timestamp="$RETURN_date$RETURN_time"
      fi
    fi
  fi
}


# Set up some global variables for the index.html image captioning.
# If the user hasn't set a caption by hand, and the filename looks
# uninteresting (e.g. it's a digicam name like P8382010.jpg), then
#
# if we have multiple days in this directory, let's use the day name
# for the caption.
#
# if all images are from the same day, then let's use the time.
#
# This function sets up the necessary state to do something intelligent
# at caption emitting time.

analyze_filenames_and_dates ()
{
  local t empty_count same_day_count count boring_pattern

  GLOBAL_total_image_count=`cat "$GLOBAL_image_list_tmpfile" | wc -l |
                            sed -e 's,^[ 	]*,,' -e 's,[ 	]*$,,'`

  [ $GLOBAL_total_image_count -eq 0 ] && return

  t=`cat "$GLOBAL_image_list_tmpfile" | grep '[0-9][0-9][0-9]' |
     sed -e 's,^P[0-9A-Ca-c],P,' -e 's,[0-9],,g' |
     sort | uniq -c | sort -rn | head -1 |
     sed -e 's,^[ 	]*,,' -e 's,[ 	]*$,,'`

# No boring digicam-style filenames in this dir?
  if [ -z "$t" ]
  then
    return
  fi

# More than 70% of the filenames are identical sans numbers?  Probably
# from a digicam or some other uninteresting filename.

  count=`echo "$t" | cut -d ' ' -f1 | sed 's,[^0-9],,g'`
  boring_pattern=`echo "$t" | sed -e 's,^[ 	]*[0-9]*[ 	]*,,g'`

  count=`expr "$count" \* 100`
  if [ `expr "$count" / $GLOBAL_total_image_count` -ge 70 ]
  then
    GLOBAL_heuristic_filenames_are_digicam_boring=1
    GLOBAL_heuristic_filename_pattern="$boring_pattern"
  fi

  empty_count=`cat "$GLOBAL_dates_filename" | egrep -v '^#|^$' |
               awk -F\| '{if (NF == 3) {print $2}}' |
               grep '^[ 	]*$' | wc -l |
               sed -e 's,^[ 	]*,,' -e 's,[ 	]*$,,'`
  same_day_count=`cat "$GLOBAL_dates_filename" | egrep -v '^#|^$' |
               awk -F\| '{if (NF == 3) {print $2}}' |
               grep -v '^[ 	]*$' | sort | uniq -c | sort -rn | head -1 |
               sed -e 's,^[ 	]*\([0-9]*\).*,\1,'`

# More than 80% of the image's days are identical?
# Less than 20% of the image's times are missing?   Note it.

  if [ -n "$empty_count" -a -n "$same_day_count" ]
  then
    empty_count=`expr "$empty_count" \* 100`
    same_day_count=`expr "$same_day_count" \* 100`

    if [ `expr "$empty_count" / $GLOBAL_total_image_count` -le 20 -a \
         `expr "$same_day_count" / $GLOBAL_total_image_count` -ge 80 ]
    then
      GLOBAL_heuristic_days_are_identical=1
    fi
  fi

  empty_count=`cat "$GLOBAL_dates_filename" | egrep -v '^#|^$' |
               awk -F\| '{if (NF == 3) {print $3}}' |
               grep '^[ 	]*$' | wc -l |
               sed -e 's,^[ 	]*,,' -e 's,[ 	]*$,,'`
  empty_count=`expr "$empty_count" \* 100`

  if [ `expr "$empty_count" / $GLOBAL_total_image_count` -gt 80 ]
  then
    GLOBAL_heuristic_times_are_absent=0
  fi
}


iso8601_format_datestr_to_human ()
{
  local date year month day t
  date="$*"
  RETURN_human_date="$date"

  if echo "$date" | egrep '^(19|20)[0-9][0-9]-[01][0-9]-[0-3][0-9]$' >/dev/null 2>&1
  then
    :
  else
    return
  fi

  year=`echo "$date" | sed 's,.*\([12][09][0-9][0-9]\)-\([01][0-9]\)-\([0-3][0-9]\).*,\1,'`
  month=`echo "$date" | sed 's,.*\([12][09][0-9][0-9]\)-\([01][0-9]\)-\([0-3][0-9]\).*,\2,'`
  day=`echo "$date" | sed 's,.*\([12][09][0-9][0-9]\)-\([01][0-9]\)-\([0-3][0-9]\).*,\3,'`

  month=`echo "$month" | sed \
     -e "s,^01\$,$GLOBAL_monthname_01_text," -e "s,^02\$,$GLOBAL_monthname_02_text," \
     -e "s,^03\$,$GLOBAL_monthname_03_text," -e "s,^04\$,$GLOBAL_monthname_04_text," \
     -e "s,^05\$,$GLOBAL_monthname_05_text," -e "s,^06\$,$GLOBAL_monthname_06_text," \
     -e "s,^07\$,$GLOBAL_monthname_07_text," -e "s,^08\$,$GLOBAL_monthname_08_text," \
     -e "s,^09\$,$GLOBAL_monthname_09_text," -e "s,^10\$,$GLOBAL_monthname_10_text," \
     -e "s,^11\$,$GLOBAL_monthname_11_text," -e "s,^12\$,$GLOBAL_monthname_12_text,"`
  month=`echo "$month" | sed -e 's, ,\&nbsp;,g'`
  day=`echo "$day" | sed 's,^0,,'`

  if [ -n "$year" -a -n "$month" -a -n "$day" ]
  then
    t=`echo "$GLOBAL_date_formatting_text" | 
       sed -e "s,@MONTH@,${month}," -e "s,@DAY@,${day}," -e "s,@YEAR@,${year},"`
    RETURN_human_date=`echo "$t" | sed 's, ,\&nbsp;,g'`
  fi
}


#########################################################
#### Get EXIF et al information and add it to slideshow pages
#########################################################


# This function should add the photo information using a variety
# of programs to recover the EXIF data embedded in the JPEG.
#
# The order of precedence is currently
#  INFO.TXT -> jhead -> metacam -> dump-exif
#
# But I think metacam is seing the most active development and it will
# probably come before jhead in the future.

print_image_exif_info ()
{
  local fn html
  fn="$*"

  image_name_to_html_name "$fn"
  html="$RETURN_html_name"
  generated_name_to_source_name "$fn"
  fn="$RETURN_source_name"

  print_libexif_info "$fn"
  [ $RETURN_printed_something -eq 1 ] && return

  print_coolpix_info_txt "$fn"
  [ $RETURN_printed_something -eq 1 ] && return

  print_jhead_info "$fn"
  [ $RETURN_printed_something -eq 1 ] && return

  print_metacam_info "$fn"
  [ $RETURN_printed_something -eq 1 ] && return

  print_gphoto_exifdump_info "$fn"
  [ $RETURN_printed_something -eq 1 ] && return

  print_dumpexif_info "$fn"
  [ $RETURN_printed_something -eq 1 ] && return
}

print_coolpix_info_txt ()
{
  local fn
  RETURN_printed_something=0

  fn="$*"

  get_coolpix_info_txt "$fn"
  if [ -n "$RETURN_info_txt" ]
  then
      echo ""
      echo "<!-- Information about this photo from the Nikon Coolpix INFO.TXT record -->"
    if [ $GLOBAL_show_image_info -eq 1 ]
    then
      echo "<pre>"
    else
      echo "<!--"
    fi

    echo "$RETURN_info_txt"

    if [ $GLOBAL_show_image_info -eq 1 ]
    then
      echo "</pre>"
    else
      echo "-->"
    fi
    echo ""
    RETURN_printed_something=1
  fi
}

print_jhead_info ()
{
  local fn
  RETURN_printed_something=0

  fn="$*"
  [ $GLOBAL_jhead_is_present -eq 0 ] && return

  if jhead "$fn" 2>&1 | grep -i 'Exposure time *:' >/dev/null
  then
    echo ""
    echo "<!-- Information about this photo from jhead -->"
    if [ $GLOBAL_show_image_info -eq 1 ]
    then
      echo "<pre>"
    else
      echo "<!--"
    fi

    jhead "$fn" 2>/dev/null | grep -v 'File date.*:' | grep -v '^$' | sed 's,^,     ,'

    if [ $GLOBAL_show_image_info -eq 1 ]
    then
      echo "</pre>"
    else
      echo "-->"
    fi
    echo ""
    RETURN_printed_something=1
  fi
}

# "exif" is from the libexif project:
# 	http://www.sourceforge.net/projects/libexif
# It's comprehensive but not so pretty without a little reformatting
# Output looks like this in rev 0.4:
#--------------------+-----------------------------------------------------------
#Tag                 |Value
#--------------------+-----------------------------------------------------------
#Image Description   |
#Manufacturer        |NIKON CORPORATION
#Model               |NIKON D100
#x-Resolution        |300/1
#y-Resolution        |300/1
#Resolution Unit     |Inch
#Software            |Ver.0.32
#Date and Time       |2002:05:16 00:19:17
#YCbCr Positioning   |co-sited                                          
# [...]
# etc

print_libexif_info ()
{
  local fn
  RETURN_printed_something=0

  fn="$*"
  [ $GLOBAL_exif_is_present -eq 0 ] && return

  if exif "$fn" 2>&1 | grep -i 'Image Description' > /dev/null
  then
    echo ""
    echo "<!-- Information about this photo from exif -->"
    if [ $GLOBAL_show_image_info -eq 1 ]
    then
      echo "<pre>"
    else
      echo "<!--"
    fi

    exif "$fn" 2>/dev/null | 
      egrep 'Manufacturer|Model|Software|Date and time|Exposure Time|FNumber|ExposureProgram|ISO Speed Ratings|Exif Version|Exposure Bias|MaxApertureValue|Metering Mode|Light Source|Flash|Focal Length|Color Space|Scene Type|Subject Distance|Digital Zoom Ratio|Scene Capture Type|Gain Control|Contrast|Saturation|Sharpness|White Balance|Exposure Mode' |
      grep -v '[|][ 	]*$' | grep -v '^[	 ]*$' |
      sed -e 's,[ 	]*$,,' -e 's,|, : ,' -e 's,^,    ,' |
      grep -v 'Unknown[ 	]*$' |
      grep -iv 'Digital Zoom Ratio.* 1/1$' | grep -vi 'Exposure Bias.* 0\.0$' |
      egrep -vi FlashPixVersion |
      egrep -iv '(Gain Control|Saturdation|Contrast|Sharpness).* Normal$' |
      egrep -iv 'Scene Capture Type.* Standard$' |
      egrep -iv 'MaxApertureValue.* [0-9]+/[0-9]+$' 

    if [ $GLOBAL_show_image_info -eq 1 ]
    then
      echo "</pre>"
    else
      echo "-->"
    fi
    echo ""
    RETURN_printed_something=1
  fi
}

print_metacam_info ()
{
  local fn
  RETURN_printed_something=0

  fn="$*"
  [ $GLOBAL_metacam_is_present -eq 0 ] && return

  if metacam "$fn" 2>&1 | grep -i 'Focal Length: ' >/dev/null
  then
    echo ""
    echo "<!-- Information about this photo from metacam -->"
    if [ $GLOBAL_show_image_info -eq 1 ]
    then
      echo "<pre>"
    else
      echo "<!--"
    fi

    metacam "$fn" 2>/dev/null | grep -v '^$' | 
        sed -e 's,.*Standard Fields -.*,::: Standard Fields :::,' \
             -e 's,.*EXIF Fields -.*,::: EXIF Fields :::,' \
             -e 's,.*Manufacturer Fields -.*,::: Manufacturer Fields :::,' |
         egrep -vi '^File:' |
         egrep -vi 'image capture date|image digitized date|component configuration|(x|y) resolution|ycbcr positioning|exif image (height|width)|flashpix ver|software version|compressed bits per pixel|firmware version|manufacturer fields|standard fields|exif fields|image description|sub-second .* time|nikon version number|sensing method|owner name|image type|image number|contrast.*normal|sharpness.*normal|saturation.*normal|drive mode.*normal|exif version|shutter speed value|colorspace.*sRGB|exposure bias:[^0-9]*0[^0-9]*$|image size|scene capture type: standard|^[ 	]aperture value|macro mode.*no macro|focus mode.*single focus|exposure mode.*auto exposure'
    if [ $GLOBAL_show_image_info -eq 1 ]
    then
      echo "<pre>"
    else
      echo "-->"
    fi
    echo ""
    RETURN_printed_something=1
  fi
}

print_gphoto_exifdump_info ()
{
  local fn
  fn="$*"
  RETURN_printed_something=0

  [ $GLOBAL_gphotoexifdump_is_present -eq 0 ] && return

  get_gphoto_exifdump_info "$fn"

  if [ -n "$RETURN_gphoto_info" ]
  then
    echo ""
    echo "<!-- Information about this photo from gphoto-exifdump -->"
    if [ $GLOBAL_show_image_info -eq 1 ]
    then
      echo "<pre>"
    else
      echo "<!--"
    fi

    echo "$RETURN_gphoto_info" |  grep -v '^$' | sed 's,^,     ,'

    if [ $GLOBAL_show_image_info -eq 1 ]
    then
      echo "<pre>"
    else
      echo "-->"
    fi
    echo ""
    RETURN_printed_something=1
  fi
}


# Convert this:
#   Tag 0x10F Make = 'SONY'
#   Tag 0x132 DateTime = '2001:10:31 13:45:19'
#   Tag 0x9205 MaxApertureValue = 28/10=2.8 
# Into this:
#   Camera make  : SONY
#   Date/Time    : 2001:10:31 13:45:19
#   Max Aperture : f/2.8

# gphoto 0.4.3's gphoto-exifdump outputs like this, but it's such a useless
# format that I'd suspect they'll change it eventually... I'll need to keep
# an eye on that or makethumbs could start inserting garbage into peoples
# image galleries.

get_gphoto_exifdump_info ()
{
  local fn t
  RETURN_gphoto_info=""

  fn="$*"
  [ $GLOBAL_gphotoexifdump_is_present -eq 0 ] && return
  t=`gphoto-exifdump "$fn"  2>/dev/null | 
      egrep 'Make|Model|DateTime|ExposureTime|FNumber|ISOSpeedRatings|MaxApertureValue|Flash|FocalLength' |
      egrep -v 'MakerNote|FlashPixVersion' | sed 's,^Tag 0x[0-9a-fA-F]* *,,' |
      sed -e 's,DateTimeOriginal,DateTime,' -e 's,DateTimeDigitized,DateTime,' |
      sort | uniq | sed -e 's,^[ 	]*,,' -e 's,[ 	]*$,,' |
      sed -e "s,.*Make.*'\(.*\)'\$,a Camera make  : \1," \
          -e "s,.*Model.*'\(.*\)'\$,b Camera model : \1," \
          -e "s,.*DateTime.*'\(.*\)'\$,c Date/Time    : \1," \
          -e 's,.*Flash = 0.*,d Flash        : No,' \
          -e 's,.*Flash = 1.*,d Flash        : Yes,' \
          -e 's,.*ExposureTime.*= *\([0-9.]*\)$,f Exposure time: \1s,' \
          -e 's,.*FNumber.*= *\([0-9.]*\)$,g Aperture     : f/\1,' \
          -e 's,.*ISOSpeedRatings = *\([0-9.]*\)$,h ISO equiv.   : \1,' \
          -e 's,.*MaxApertureValue.*= *\([0-9.]*\)$,i Max Aperture : f/\1,' \
          -e 's,.*FocalLength.*= *\([0-9.]*\)$,e Focal Length : \1mm,' |
      grep -v '^Tag' | sort | cut -d ' ' -f 2-`

  if [ -n "$t" ]
  then
    RETURN_gphoto_info="$t"
  fi
}

print_dumpexif_info ()
{
  local fn
  RETURN_printed_something=0

  fn="$*"
  [ $GLOBAL_dumpexif_is_present -eq 0 ] && return

  if dump-exif "$fn" 2>&1 | grep -i 'ExposureTime:' >/dev/null
  then
    if [ $GLOBAL_show_image_info -eq 1 ]
    then
      echo "<pre>"
    else
      echo "<!-- Information about this photo from dump-exif:"
    fi

    dump-exif "$fn" 2>/dev/null | grep -v '^$' | sed 's,^,     ,'

    if [ $GLOBAL_show_image_info -eq 1 ]
    then
      echo "<pre>"
    else
      echo "-->"
    fi
    echo ""
    RETURN_printed_something=1
  fi
}

get_coolpix_info_txt ()
{
  local filename lineno

  filename="$*"
  RETURN_info_txt=""
  [ ! -f INFO.TXT ] && return
  generated_name_to_source_name "$filename"
  filename="$RETURN_source_name"

  if cat INFO.TXT | tr -d '\r' | grep -i "^$filename\$" >/dev/null 2>&1
  then
    :
  else
    return
  fi

  lineno=`cat -n INFO.TXT | tr -d '\r' |
          grep -i "^[ 	]*[0-9]*[ 	]*$filename\$" | cut -f1 |
          sed 's,[^0-9],,g'`

  RETURN_info_txt=`cat INFO.TXT |
      tr -d '\r' | sed "1,${lineno}d" |
      awk '{if (NF == 0) { exit } print "     " $0;}' |
      grep -v '^[ 	]*$'`
}

#########################################################
#### Try to get image time/date data via a variety of means
#########################################################

get_image_time_date ()
{
  local fn

  generated_name_to_source_name "$*"
  fn="$RETURN_source_name"
  RETURN_time_date=""
  RETURN_date=""
  RETURN_time=""

  get_time_date_via_jhead "$fn"
  if [ -n "$RETURN_jhead_time_date" ]
  then
    RETURN_time_date="$RETURN_jhead_time_date"
    RETURN_date="$RETURN_jhead_date"
    RETURN_time="$RETURN_jhead_time"
    return
  fi

  get_time_date_via_strings "$fn"
  if [ -n "$RETURN_strings_time_date" ]
  then
    RETURN_time_date="$RETURN_strings_time_date"
    RETURN_date="$RETURN_strings_date"
    RETURN_time="$RETURN_strings_time"
    return
  fi

  get_time_date_via_metacam "$fn"
  if [ -n "$RETURN_metacam_time_date" ]
  then
    RETURN_time_date="$RETURN_metacam_time_date"
    RETURN_date="$RETURN_metacam_date"
    RETURN_time="$RETURN_metacam_time"
    return
  fi

  get_time_date_via_exiftools "$fn"
  if [ -n "$RETURN_exiftools_time_date" ]
  then
    RETURN_time_date="$RETURN_exiftools_time_date"
    RETURN_date="$RETURN_exiftools_date"
    RETURN_time="$RETURN_exiftools_time"
    return
  fi

  get_coolpix_time_date "$fn"
  if [ -n "$RETURN_coolpix_time_date" ]
  then
    RETURN_time_date="$RETURN_coolpix_time_date"
    RETURN_date="$RETURN_coolpix_date"
    RETURN_time="$RETURN_coolpix_time"
    return
  fi

  get_chillcam_time_date "$fn"
  if [ -n "$RETURN_chillcam_time_date" ]
  then
    RETURN_time_date="$RETURN_chillcam_time_date"
    RETURN_date="$RETURN_chillcam_date"
    RETURN_time="$RETURN_chillcam_time"
    return
  fi

  get_webcam32_time_date "$fn"
  if [ -n "$RETURN_webcam32_time_date" ]
  then
    RETURN_time_date="$RETURN_webcam32_time_date"
    RETURN_date="$RETURN_webcam32_date"
    RETURN_time="$RETURN_webcam32_time"
    return
  fi

  get_date_via_preferred_filename "$fn"
  if [ -n "$RETURN_preferred_filename_time_date" ]
  then
    RETURN_time_date="$RETURN_preferred_filename_time_date"
    RETURN_date="$RETURN_preferred_filename_date"
    RETURN_time="$RETURN_preferred_filename_time"
    return
  fi

  get_date_via_filename_usa_specific "$fn"
  if [ -n "$RETURN_usa_time_date" ]
  then
    RETURN_time_date="$RETURN_usa_time_date"
    RETURN_date="$RETURN_usa_date"
    RETURN_time="$RETURN_usa_time"
    return
  fi

  guess_date_via_directory_name
  if [ -n "$RETURN_guessed_date" ]
  then
    RETURN_time_date="$RETURN_guessed_time_date"
    RETURN_date="$RETURN_guessed_date"
    RETURN_time="$RETURN_guessed_time"
    return
  fi

  get_date_via_filename_reluctantly "$fn"
  if [ -n "$RETURN_reluctant_time_date" ]
  then
    RETURN_time_date="$RETURN_reluctant_time_date"
    RETURN_date="$RETURN_reluctant_date"
    RETURN_time="$RETURN_reluctant_time"
    return
  fi

}

# Get one of these lines from metacam output :
#
#         Image Creation Date: 2001:12:23 13:39:48
#          Image Capture Date: 2001:12:23 13:39:48
#        Image Digitized Date: 2001:12:23 13:39:48
#
# All three may be present, or only one may be present.

get_time_date_via_metacam ()
{
  local fn td

  [ $GLOBAL_metacam_is_present -eq 0 ] && return
  fn="$*"
  RETURN_metacam_time_date=""
  RETURN_metacam_date=""
  RETURN_metacam_time=""

  td=`metacam "$fn" 2>/dev/null |
      egrep -i 'Image (Creation|Capture|Digitized) Date' |
      grep -v '0000:00:00 00:00' |
      head -1 | awk '{print $(NF-1) " " $NF}' | sed -e 's,[^0-9: ],,g' \
        -e 's,\([12][0-9][0-9][0-9]\):\([01][0-9]\):\([0-3][0-9]\) \([012][0-9]\):\([0-6][0-9]\).*,\1-\2-\3 \4:\5,'`

  if [ -n "$td" ]
  then
    RETURN_metacam_time_date="$td"
    RETURN_metacam_date=`echo "$td" | awk '{print $1}'`
    RETURN_metacam_time=`echo "$td" | awk '{print $2}'`
  fi
}

# Get this line from dump-exif (a part of exif-tools) output :
#
#    DateTimeOriginal: 2000:04:19 15:01:56

get_time_date_via_exiftools ()
{
  local fn td

  [ $GLOBAL_dumpexif_is_present -eq 0 ] && return
  fn="$*"
  RETURN_exiftools_time_date=""
  RETURN_exiftools_date=""
  RETURN_exiftools_time=""

  td=`dump-exif "$fn" 2>/dev/null |
      egrep -i 'DateTimeOriginal' |
      grep -v '0000:00:00 00:00' |
      head -1 | awk '{print $(NF-1) " " $NF}' | sed -e 's,[^0-9: ],,g' \
        -e 's,\([12][0-9][0-9][0-9]\):\([01][0-9]\):\([0-3][0-9]\) \([012][0-9]\):\([0-6][0-9]\).*,\1-\2-\3 \4:\5,'`

  if [ -n "$td" ]
  then
    RETURN_exiftools_time_date="$td"
    RETURN_exiftools_date=`echo "$td" | awk '{print $1}'`
    RETURN_exiftools_time=`echo "$td" | awk '{print $2}'`
  fi
}

# Get this line from jhead output :
#
#     Date/Time    : 2000:04:30 16:26:56

get_time_date_via_jhead ()
{
  local fn td

  [ $GLOBAL_jhead_is_present -eq 0 ] && return
  fn="$*"
  RETURN_jhead_time_date=""
  RETURN_jhead_date=""
  RETURN_jhead_time=""

  td=`jhead "$fn" 2>/dev/null |
      egrep -i 'Date/Time *:' |
      grep -v '0000:00:00 00:00' |
      head -1 | awk '{print $(NF-1) " " $NF}' | sed -e 's,[^0-9: ],,g' \
        -e 's,\([12][0-9][0-9][0-9]\):\([01][0-9]\):\([0-3][0-9]\) \([012][0-9]\):\([0-6][0-9]\).*,\1-\2-\3 \4:\5,'`

  if [ -n "$td" ]
  then
    RETURN_jhead_time_date="$td"
    RETURN_jhead_date=`echo "$td" | awk '{print $1}'`
    RETURN_jhead_time=`echo "$td" | awk '{print $2}'`
  fi
}



get_coolpix_time_date ()
{
  local fn timestamp

  fn="$*"
  RETURN_coolpix_time_date=""
  RETURN_coolpix_date=""
  RETURN_coolpix_time=""

  get_coolpix_info_txt "$fn"
  if [ -n "$RETURN_info_txt" ]
  then
    timestamp=`echo "$RETURN_info_txt" | grep '^[ 	]*DATE' |
               awk '{print $3 " " $4}' | sed 's,\.,-,g' | sed 's,[^0-9 :-],,g'`
    if [ -n "$timestamp" ]
    then
      RETURN_coolpix_time_date="$timestamp"
      RETURN_coolpix_date=`echo "$timestamp" | awk '{print $1}'`
      RETURN_coolpix_time=`echo "$timestamp" | awk '{print $2}'`
      return
    fi
  fi
}

# See if we can find the date string with good old strings(1).
# The date is in there in the form of 2001:11:19 19:25:09

get_time_date_via_strings ()
{
  local fn="$*"
  local td

  RETURN_strings_time_date=""
  RETURN_strings_date=""
  RETURN_strings_time=""

# Use dd if it is available to just read the first 2kbytes of the file - 
# if there's a date string in the EXIF header, it'll be there.  I used
# to just run 'strings' on the file, but that would take over twice as
# long as just reading the first block.
  
  td=`(if [ $GLOBAL_dd_works_well -eq 1 ]; then dd bs=2048 count=1 <"$fn" 2>/dev/null; else cat < "$fn"; fi )| strings 2>/dev/null |
      grep -v '0000:00:00 00:00' |
      egrep '(19|20)[0-9][0-9]:(0[1-9]|1[0-2]):[0-3][0-9] [0-2][0-9]:[0-6][0-9]:[0-6][0-9]' |
      sort | uniq -c | sort -rn | sed 's,^[ 	]+[0-9]+[ 	]+,,' |
      head -1 | awk '{print $(NF-1) " " $NF}' |
      sed -e 's,[^0-9: ],,g' \
          -e 's,\([12][0-9][0-9][0-9]\):\([01][0-9]\):\([0-3][0-9]\) \([012][0-9]\):\([0-6][0-9]\).*,\1-\2-\3 \4:\5,'`

  if [ -n "$td" ]
  then
    RETURN_strings_time_date="$td"
    RETURN_strings_date=`echo "$td" | awk '{print $1}'`
    RETURN_strings_time=`echo "$td" | awk '{print $2}'`
  fi
}

# Olympus cameras (C2000Z, C2020Z, C3030Z) have photo filenames in the form of
# P<MONTH-DIGIT><DAY><4-DIGIT-SEQ-NO>.jpg
# If a person hasn't set the time/date in the camera, MONTH-DIGIT (a hex
# dgit) and DAY are 1, giving you a name of the form P101xxxx.jpg, which
# should be ignored.  Yes, this means that photos taken on New Year's Day
# will not be recognized.

get_olympus_filename_date ()
{
  local fn="$*"
  local month day

  RETURN_olympus_time_date=""
  RETURN_olympus_date=""
  RETURN_olympus_time=""

  if echo "$fn" | egrep '^P[1-9A-Ca-c][0-3][0-9][0-9][0-9][0-9][0-9].jpg$' >/dev/null 2>&1
  then
    month=`echo "$fn" | sed    -e 's,^P\(.\).*,\1,' \
     -e "s,^1\$,$GLOBAL_monthname_01_text," -e "s,^2\$,$GLOBAL_monthname_02_text," \
     -e "s,^3\$,$GLOBAL_monthname_03_text," -e "s,^4\$,$GLOBAL_monthname_04_text," \
     -e "s,^5\$,$GLOBAL_monthname_05_text," -e "s,^6\$,$GLOBAL_monthname_06_text," \
     -e "s,^7\$,$GLOBAL_monthname_07_text," -e "s,^8\$,$GLOBAL_monthname_08_text," \
     -e "s,^9\$,$GLOBAL_monthname_09_text," -e "s,^[Aa]\$,$GLOBAL_monthname_10_text," \
     -e "s,^[Bb]\$,$GLOBAL_monthname_11_text," -e "s,^[Cc]\$,$GLOBAL_monthname_12_text,"`
    day=`echo "$fn" | sed -e 's,^P.\([0-3][0-9]\).*,\1,' -e 's,^0,,'`

    if [ -n "$month" -a -n "$day" ]
    then
      [ "$month" = January -a "$day" = "1" ] && return
      [ "$month" = 0 -a "$day" = "0" ] && return
      RETURN_olympus_time_date="$month $day"
      RETURN_olympus_date="$month $day"
      RETURN_olympus_time=""
    fi
  fi
}

# This only tries to recognize dates in some form of YYYY-MM-DD.
# Americans might expect MM-DD-YYYY to work, or MM-DD-YY, but
# it's not globally unambiguous, so those Americans may now learn
# the joys of ISO 8601.  Unless I feel like adding support for
# the US formats some day.  Don't hold your breath.

guess_date_via_directory_name ()
{
  local t

  [ $GLOBAL_already_failed_guessing_date_from_dir -eq 1 ] && return

  t=`pwd`
  t=`basename "$t"`
  RETURN_guessed_time_date=""
  RETURN_guessed_date=""
  RETURN_guessed_time=""

# Don't re-do work we've aready done during this makethumbs run.

  if [ -n "$GLOBAL_static_var_guessed_date_from_dirname" ]
  then
    RETURN_guessed_time_date="$GLOBAL_static_var_guessed_date_from_dirname"
    RETURN_guessed_date="$GLOBAL_static_var_guessed_date_from_dirname"
    RETURN_guessed_time=""
    return
  fi

  iso8601_date_decoder "$t"

  if [ -n "$RETURN_iso8601_time_date" ]
  then
    RETURN_guessed_time_date="$RETURN_iso8601_time_date"
    RETURN_guessed_date="$RETURN_iso8601_date"
    RETURN_guessed_time="$RETURN_iso8601_time"
    GLOBAL_static_var_guessed_date_from_dirname="$RETURN_iso8601_time_date"
  else
    GLOBAL_already_failed_guessing_date_from_dir=1
  fi
}

get_date_via_preferred_filename ()
{
  local fn

  fn="$*"
  RETURN_preferred_filename_time_date=""
  RETURN_preferred_filename_date=""
  RETURN_preferred_filename_time=""

  iso8601_date_decoder "$fn"
  if [ -n "$RETURN_iso8601_time_date" ]
  then
    RETURN_preferred_filename_time_date="$RETURN_iso8601_time_date"
    RETURN_preferred_filename_date="$RETURN_iso8601_date"
    RETURN_preferred_filename_time="$RETURN_iso8601_time"
    return
  fi

}

get_date_via_filename_usa_specific ()
{
  local fn

  fn="$*"
  RETURN_usa_time_date=""
  RETURN_usa_date=""
  RETURN_usa_time=""
  [ $GLOBAL_usa_specific_date_format_checks -eq 0 ] && return

  try_ians_filename_format "$fn"
  if [ -n "$RETURN_ians_date" ]
  then
    RETURN_usa_time_date="$RETURN_ians_time_date"
    RETURN_usa_date="$RETURN_ians_date"
    RETURN_usa_time="$RETURN_ians_time"
    return
  fi

  try_kristens_filename_format "$fn"
  if [ -n "$RETURN_kristens_date" ]
  then
    RETURN_usa_time_date="$RETURN_kristens_time_date"
    RETURN_usa_date="$RETURN_kristens_date"
    RETURN_usa_time="$RETURN_kristens_time"
    return
  fi

  try_erics_filename_format "$fn"
  if [ -n "$RETURN_erics_date" ]
  then
    RETURN_usa_time_date="$RETURN_erics_time_date"
    RETURN_usa_date="$RETURN_erics_date"
    RETURN_usa_time="$RETURN_erics_time"
    return
  fi
}

get_date_via_filename_reluctantly ()
{
  local fn

  fn="$*"
  RETURN_reluctant_time_date=""
  RETURN_reluctant_date=""
  RETURN_reluctant_time=""

  get_olympus_filename_date "$fn"
  if [ -n "$RETURN_olympus_date" ]
  then
    RETURN_reluctant_time_date="$RETURN_olympus_time_date"
    RETURN_reluctant_date="$RETURN_olympus_date"
    RETURN_reluctant_time="$RETURN_olympus_time"
    return
  fi

}

iso8601_date_decoder ()
{
  local name canonical_fmt t
  local fmt1 fmt2 fmt3 fmt4 fmt5 fmt6 fmt7 fmt8

  name="$*"
  RETURN_iso8601_time_date=""
  RETURN_iso8601_time=""
  RETURN_iso8601_date=""

  canonical_fmt="[12][09][0-9][0-9]-[012][0-9]-[0-3][0-9]"
  fmt1="$canonical_fmt"
  fmt2="[12][09][0-9][0-9]-[012]?[0-9]-[0-3]?[0-9]"
  fmt3="[12][09][0-9][0-9]_[012][0-9]_[0-3][0-9]"
  fmt4="[12][09][0-9][0-9]_[012]?[0-9]_[0-3]?[0-9]"
  fmt5="[12][09][0-9][0-9]\.[012][0-9]\.[0-3][0-9]"
  fmt6="[12][09][0-9][0-9]\.[012]?[0-9]\.[0-3]?[0-9]"
  fmt7="[12][09][0-9][0-9] [012]?[0-9] [0-3]?[0-9]"
  fmt8="[12][09][0-9][0-9][012][0-9][0-3][0-9]"

  for exp in "$fmt1" "$fmt2" "$fmt3" "$fmt4" "$fmt5" "$fmt6" "$fmt7" "$fmt8"
  do
    if echo "$name" | egrep "$exp" >/dev/null 2>&1
    then

# Old fashioned awk's won't support gensub(), so use perl
# as a backup.  I hate to do it, but gsub won't do what
# I need as near as I can tell...
      if [ $GLOBAL_date_parser_program = "awk" ]
      then
        t=`echo "$name" | sed "s/.*\(${exp}\).*/\1/" |
              $AWK '{\
                 datepat="^.*\([12][09][0-9][0-9]\)[^0-9]*\([01]?[0-9]\)[^0-9]*\([0-3]?[0-9]\)[^0-9]?.*$"
                 year = gensub (datepat, "\\\\1", "g", $0);
                 month = gensub (datepat, "\\\\2", "g", $0);
                 day = gensub (datepat, "\\\\3", "g", $0);
                 printf ("%s-%02d-%02d", year, month, day);
                }'`
      else
        t=`echo "$name" | sed "s/.*\(${exp}\).*/\1/" |
            perl -ne \
               'if (/^.*([12][09]\d\d)[^\d]*([01]?\d)[^\d]*([0-3]?[\d])[^\d]?.*$/) 
                  {printf ("%s-%02d-%02d\n", $1, $2, $3); }'`
      fi

      if echo "$t" | egrep "$canonical_fmt" >/dev/null 2>&1
      then
        RETURN_iso8601_time_date="$t"
        RETURN_iso8601_date="$t"
        RETURN_iso8601_time=""
        return
      fi
    fi
  done
}

# ChillCAM is a web cam program that embeds the time/date in the comment field.
# www.chillcam.com
# format is "MM/DD/YYYY HH:MM:SS"

get_chillcam_time_date ()
{
  local fn t

  fn="$*"
  t=""
  RETURN_chillcam_time_date=""
  RETURN_chillcam_date=""
  RETURN_chillcam_time=""

  if [ $GLOBAL_rdjpgcom_is_present -eq 0 -a \
       $GLOBAL_jhead_is_present -eq 0 -a \
       $GLOBAL_jpegtopnm_is_present -eq 0 ]
  then
    return
  fi

  if [ $GLOBAL_rdjpgcom_is_present -eq 1 ]
  then
    t=`rdjpgcom "$fn" 2>/dev/null | grep -i chillcam | head -1`
  fi

  if [ -z "$t" -a $GLOBAL_jhead_is_present -eq 1 ]
  then
    t=`jhead "$fn" 2>/dev/null | grep -i chillcam | head -1`
  fi

  if [ -z "$t" -a $GLOBAL_jpegtopnm_is_present -eq 1 ]
  then
    t=`jpegtopnm -comment "$fn" 2>&1 >/dev/null | grep -i chillcam | head -1`
  fi

  [ -z "$t" ] && return
  t=`echo "$t" | awk '{print $(NF-1) " " $NF}' |
        sed -e 's,[^0-9/: ],,g' |
        grep '[01][0-9]/[0-3][0-9]/[12][0-9][0-9][0-9] [0-2][0-9]:[0-6][0-9]:[0-6][0-9]' |
        sed -e 's,\([01][0-9]\)/\([0-3][0-9]\)/\([12][0-9][0-9][0-9]\) \([012][0-9]\):\([0-6][0-9]\).*,\3-\1-\2 \4:\5,'`
  [ -z "$t" ] && return

  RETURN_chillcam_time_date="$t"
  RETURN_chillcam_date=`echo "$t" | awk '{print $1}'`
  RETURN_chillcam_time=`echo "$t" | awk '{print $2}'`
}

# Webcam32 is some webcam snapshot program that puts the time/date in a
# jpeg comment.  www.webcam32.com.
# format is "MM/DD/YY HH:MM:SS" in typical USA fashion.

get_webcam32_time_date ()
{
  local fn t

  fn="$*"
  t=""
  RETURN_chillcam_time_date=""
  RETURN_chillcam_date=""
  RETURN_chillcam_time=""

  if [ $GLOBAL_rdjpgcom_is_present -eq 0 -a \
       $GLOBAL_jhead_is_present -eq 0 -a \
       $GLOBAL_jpegtopnm_is_present -eq 0 ]
  then
    return
  fi

  if [ $GLOBAL_rdjpgcom_is_present -eq 1 ]
  then
    t=`rdjpgcom "$fn" 2>/dev/null | grep -i webcam32 | head -1`
  fi

  if [ -z "$t" -a $GLOBAL_jhead_is_present -eq 1 ]
  then
    t=`jhead "$fn" 2>/dev/null | grep -i webcam32 | head -1`
  fi

  if [ -z "$t" -a $GLOBAL_jpegtopnm_is_present -eq 1 ]
  then
    t=`jpegtopnm -comment "$fn" 2>&1 >/dev/null | grep -i webcam32 | head -1`
  fi

  [ -z "$t" ] && return
  t=`echo "$t" | awk '{print $(NF-1) " " $NF}' |
        sed -e 's,[^0-9/: ],,g' |
        grep '[01][0-9]/[0-3][0-9]/[0-9][0-9] [0-2][0-9]:[0-6][0-9]:[0-6][0-9]' |
        sed -e 's,\([01][0-9]\)/\([0-3][0-9]\)/\([0-8][0-9]\) \([012][0-9]\):\([0-6][0-9]\).*,20\3-\1-\2 \4:\5,' \
            -e 's,\([01][0-9]\)/\([0-3][0-9]\)/\([9][0-9]\) \([012][0-9]\):\([0-6][0-9]\).*,19\3-\1-\2 \4:\5,'`
  [ -z "$t" ] && return

  RETURN_webcam32_time_date="$t"
  RETURN_webcam32_date=`echo "$t" | awk '{print $1}'`
  RETURN_webcam32_time=`echo "$t" | awk '{print $2}'`
}



#### USA SPECIFIC DATE FORMAT CHECKS

## Dates can be ordered by month/day/year or they can be ordered by
## day/month/year, depending on which part of the world you live in.
## I'd rather everyone use an ISO8601 unambiguous date, but they don't.
## The following timestamp checks all assume a US (MM/DD/year) format
## date string, and they can all be disabled by setting
## usa_specific_date_format_checks to zero in your .makethumbsrc file.

# Ian Lance Taylor has his images named MMDDYY-n+.jpg.
# (where 'n' is the sequence number on that day).
# I cheat and assume that years "00" - "29" are 2000-2029 and years
# "70-99" are 1970-1999.

try_ians_filename_format ()
{
  local fn t

  fn="$*"
  RETURN_ians_time_date=""
  RETURN_ians_date=""
  RETURN_ians_time=""
  [ $GLOBAL_usa_specific_date_format_checks -eq 0 ] && return

  if echo "$fn" | egrep '^(0[1-9]|1[0-2])(0[1-9]|[12][0-9]|3[01])[0-27-9][0-9]-[1-9][0-9]*\.(jpg|gif|png)$' >/dev/null 2>&1
  then
    t=`echo "$fn" |
       sed -e 's|^\([01][0-9]\)\([0-3][0-9]\)\([0-2][0-9]\).*|20\3-\1-\2|' \
           -e 's|^\([01][0-9]\)\([0-3][0-9]\)\([7-9][0-9]\).*|19\3-\1-\2|'`
    if [ -n "$t" ]
    then
      if echo "$t" | egrep '^(19|20)[0-9][0-9]-[01][0-9]-[0-3][0-9]$' >/dev/null 2>&1
      then
        RETURN_ians_time_date="$t"
        RETURN_ians_date="$t"
        RETURN_ians_time=""
        return
      fi
    fi
  fi
}


# Eric Perlman names his files with the date encoded in the filename
# in a format like "foo_(3-2-2002).jpg". (i.e. *MM-DD-YYYY* s.t. MM and DD
# can be single digit.)

try_erics_filename_format ()
{
  local fn t month day year

  fn="$*"
  RETURN_erics_time_date=""
  RETURN_erics_date=""
  RETURN_erics_time=""
  [ $GLOBAL_usa_specific_date_format_checks -eq 0 ] && return

  if echo "$fn" | egrep '[(](0?[1-9]|1[0-2])-(0?[1-9]|[12][0-9]|3[01])-(19|20)[0-9][0-9][)]' >/dev/null 2>&1
  then
    year=`echo "$fn" |
          sed -e 's|.*[(]\([0-9]*\)-\([0-9]*\)-\([12][09][0-9][0-9]\)[)].*|\3|'`
    month=`echo "$fn" |
          sed -e 's|.*[(]\([0-9]*\)-\([0-9]*\)-\([12][09][0-9][0-9]\)[)].*|\1|'`
    day=`echo "$fn" |
          sed -e 's|.*[(]\([0-9]*\)-\([0-9]*\)-\([12][09][0-9][0-9]\)[)].*|\2|'`
    t=`printf "%s-%02d-%02d" "$year" "$month" "$day" 2>/dev/null`
    if [ -n "$t" ]
    then
      if echo "$t" | egrep '^(19|20)[0-9][0-9]-[01][0-9]-[0-3][0-9]$' >/dev/null 2>&1
      then
        RETURN_erics_time_date="$t"
        RETURN_erics_date="$t"
        RETURN_erics_time=""
        return
      fi
    fi
  fi
}

# Kristen Kakos has her images named MMDDYY_<name>.jpg.
# I cheat and assume that years "00" - "29" are 2000-2029 and years
# "70-99" are 1970-1999.

try_kristens_filename_format ()
{
  local fn t

  fn="$*"
  RETURN_kristens_time_date=""
  RETURN_kristens_date=""
  RETURN_kristens_time=""
  [ $GLOBAL_usa_specific_date_format_checks -eq 0 ] && return

  if echo "$fn" | egrep '^(0[1-9]|1[0-2])(0[1-9]|[12][0-9]|3[01])[0-27-9][0-9]_[a-zA-Z1-9].*\.(jpg|gif|png)$' >/dev/null 2>&1
  then
    t=`echo "$fn" |
       sed -e 's|^\([01][0-9]\)\([0-3][0-9]\)\([0-2][0-9]\).*|20\3-\1-\2|' \
           -e 's|^\([01][0-9]\)\([0-3][0-9]\)\([7-9][0-9]\).*|19\3-\1-\2|'`
    if [ -n "$t" ]
    then
      if echo "$t" | egrep '^(19|20)[0-9][0-9]-[01][0-9]-[0-3][0-9]$' >/dev/null 2>&1
      then
        RETURN_kristens_time_date="$t"
        RETURN_kristens_date="$t"
        RETURN_kristens_time=""
        return
      fi
    fi
  fi
}


#########################################################
#### call to main
#########################################################

main ${1+"$@"}
