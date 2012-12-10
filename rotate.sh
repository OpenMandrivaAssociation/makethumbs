#! /bin/sh

# This script rotates images.  It'll rotate the original images if it can
# do so safely, otherwise it'll record rotation details and when makethumbs.sh
# runs, it will generate rotated reduced images and thumbnail images.

GLOBAL_rcsid='$Id: rotate.sh,v 1.22 2002/09/28 04:52:16 molenda Exp $'
GLOBAL_rcsrev='$Revision: 1.22 $'

# This script is in the public domain, share and enjoy.
# The latest version is always at http://www.molenda.com/makethumbs/

# Written by Jason Molenda, 2001-11-03.


main ()
{
  enable_atexit_trap_handler
  set_environment ${1+"$@"}
  init_defaults
  find_programs
  parse_args ${1+"$@"}

  if [ $GLOBAL_rotate_original -eq 1 ]
  then
    rotate_images
  else
    record_image_rotations
  fi

  exit 0
}

init_defaults ()
{

  DEFAULT_rotation_filename="rot-state.txt"
  DEFAULT_rotation="none"
  GLOBAL_rotation_filename=$DEFAULT_rotation_filename
  GLOBAL_rotation=$DEFAULT_rotation

  TMPDIR=${TMPDIR-/tmp}

  find_in_path jpegtran
  if [ $RETURN_found -eq 1 ]
  then
    DEFAULT_rotate_original=1
    GLOBAL_have_jpegtran=1
  else
    DEFAULT_rotate_original=0
    GLOBAL_have_jpegtran=0
    check_permissions
  fi
  GLOBAL_rotate_original=$DEFAULT_rotate_original

  GLOBAL_saw_rotate_original=0
  GLOBAL_rotate_version=`echo "$GLOBAL_rcsrev" | sed 's,[^0-9.],,g'`
}

parse_args ()
{
  local optname optarg filez fn

  if [ $# -eq 0 ]
  then
    help
    exit 1
  fi

  while [ $# -gt 0 ]
  do
    optname="`echo $1 | sed 's,=.*,,'`"
    optarg="`echo $1 | sed 's,^[^=]*=,,'`"
    case "$1" in
      -o | --overwrite*)
           if [ "$GLOBAL_saw_rotate_original" -eq 1 ]
           then
             echo ERROR: More than one -o and -p option specified! >&2
             help
             exit 1
           fi
           ARGV_rotate_original=1
           GLOBAL_rotate_original=$ARGV_rotate_original
           GLOBAL_saw_rotate_original=1
         ;;
      -p | --preserve*)
           if [ "$GLOBAL_saw_rotate_original" -eq 1 ]
           then
             echo ERROR: More than one -o and -p option specified! >&2
             help
             exit 1
           fi
           ARGV_rotate_original=0
           GLOBAL_rotate_original=$ARGV_rotate_original
           GLOBAL_saw_rotate_original=1
           check_permissions
         ;;
      -r | --right | --rr | -rr | --clock* | --rotate-right | r)
           GLOBAL_rotation="clockwise"
           shift
           break
         ;;
      -l | --left | --rl | -rl | --counter* | --rotate-left | l)
           GLOBAL_rotation="counter-clockwise"
           shift
           break
         ;;
      --help | -h | --version | -v)
           help
           exit 1
         ;;
      *)
           echo ERROR: I don\'t understand option "$1" 1>&2
           help
           exit 1
         ;;
    esac
    shift
  done

  if [ -n "$GLOBAL_rotation" -a $# -eq 0 ]
  then
    echo ERROR: Rotation specified but no files listed! 1>&2
    exit 1
  fi

  make_tmpfile filez
  GLOBAL_file_list=$RETURN_tmpfile

  while [ $# -gt 0 ]
  do
    fn="$1"
    if echo "$fn" | egrep -i -- '-[trl].jpg$' >/dev/null 2>&1
    then
      shift
      continue
    fi
    divine_filename "$fn"
    if [ -n "$RETURN_filename" ]
    then
      fn="$RETURN_filename"
    else
      shift
      continue
    fi
    echo "$fn" >> $GLOBAL_file_list
    shift
  done
}

help ()
{
# The following exec goop so I don't have to manually redirect every
# message to stderr in this function.
  exec 4>&1    # save stdout fd to fd #4
  exec 1>&2    # redirect stdout to stderr

  if [ $GLOBAL_rotate_original -eq 1 ]
  then
    echo "Usage: `basename $0` [-p|-o] <-r|-l> file1.jpg file2.jpg file3.jpg ..."
    echo ' -p | --preserve     Do not touch original image, even if we can do so safely.'
  else
    echo 'Usage: `basename $0` [-r|-l] file1.jpg file2.jpg file3.jpg ...'
    echo ' -o | --overwrite    Transform original images, not just reduced ones'
  fi

  echo   ' -r | --rotate-right Rotate images to the right (90 deg clockwise)'
  echo   ' -l | --rotate-left  Rotate images to the left (90 deg counter clockwise)'
  echo   ''
  echo   "    `basename $0` tries to rotate images losslessly if possible."
  if [ $GLOBAL_rotate_original -eq 1 ]
  then
    echo   "    Lossless rotation is possible on this system, so it is the default."
  else
    echo   "    Lossless rotation is not possible on this system, so by default the"
    echo   "    original images will not be modified--only the reduced and thumbnail"
    echo   "    images will be rotated."
  fi
  echo   "    You can override this behavior with -o (overwrite) or with -p (preserve)"
  echo   ""
  echo   "    Filenames can be any unique part of the filename.  e.g. if DSCN0532.jpg"
  echo   "    exists, '`basename $0` r 32' will rotate it 90 degrees clockwise."
  echo   ""
  echo   "    You can find the latest verison of this program at http://www.molenda.com/"
  echo   -n "    This is version v$GLOBAL_rotate_version of "
  echo  "`basename $0`."
  exec 1>&4   # Copy stdout fd back from temporary save fd, #4
}


# Don't rotate the image, just record what rotation the user requested
# for when makethumbs creates thumbnails/reduced/etc images.

record_image_rotations ()
{
  local tfile filename normalized_filename

  make_tmpfile roter
  tfile=$RETURN_tmpfile

  cat $GLOBAL_file_list | while read filename
  do
    if grep -i "^[a-z-]* ${filename}$" $GLOBAL_rotation_filename >/dev/null 2>&1
    then
      grep -vi "^[a-z-]* ${filename}$" $GLOBAL_rotation_filename > $tfile
      cat $tfile > $GLOBAL_rotation_filename
    fi
    normalized_filename=`echo "$filename" |
          sed -e 's,.JPG$,.jpg,' -e 's,.jpeg$,.jpg,' -e 's,.JPEG$,.jpg,' \
              -e 's,.PNG$,.png,' -e 's,.GIF$,.gif,'`
    echo "$GLOBAL_rotation $normalized_filename" >> $GLOBAL_rotation_filename
    remove_generated_versions "$filename"
  done
  cat -n $GLOBAL_rotation_filename |  sort -k 3 -k 1n | uniq -f 2 |
      sed 's,^[ 	]*\([0-9]*\)[ 	]*,\1 ,' |
      cut -d ' ' -f 2- > $tfile
  [ -s $tfile ] && cat $tfile > $GLOBAL_rotation_filename
}


# Rotate an image, either losslessly (via jpegtran) or lossy
# (uncompress to pnm, rotate, recompress to jpeg).  This function
# should probably give the user some way of specifying the final
# compression for a lossy rotation.

rotate_images ()
{
  local tfile filename
  if [ $GLOBAL_have_jpegtran -eq 1 ]
  then
    [ $GLOBAL_rotation = "clockwise" ] && degrees=90
    [ $GLOBAL_rotation = "counter-clockwise" ] && degrees=270
  else
    [ $GLOBAL_rotation = "clockwise" ] && degrees=-90
    [ $GLOBAL_rotation = "counter-clockwise" ] && degrees=90
  fi

  make_tmpfile rot
  tfile=$RETURN_tmpfile

  cat $GLOBAL_file_list | while read filename
  do
    if [ ! -f "$filename" ]
    then
      echo WARNING: File \"$filename\" does not exist! >&2
      continue
    fi
    if [ $GLOBAL_have_jpegtran -eq 1 ]
    then
      cat "$filename" | jpegtran -trim -copy all -rotate $degrees > $tfile
    else
      [ $GLOBAL_rotation = "counter-clockwise" ] && degrees=-90
      cat "$filename" | djpeg -ppm | pnmrotate $degrees |
          cjpeg -optimize > $tfile
    fi

    if [ -s $tfile ]
    then
      cat $tfile > "$filename"
      remove_generated_versions "$filename"
    else
      echo ERROR: Rotation of \"$filename\" failed for some reason. 1>&2
    fi

  done
}

# The user may give us a filename fragment, e.g. DSCN0392 instead of
# DSCN0392.jpg, so try to guess what they might mean.  Caller may get
# an empty RETURN_filename, in which case a warning/error should be
# issued to the user.
divine_filename ()
{
  local name i tmp

  name="$*"
  RETURN_filename=""

# Exact match?
  if [ -f "$name" ]
  then
    RETURN_filename="$name"
    return
  fi

# Missing its suffix?

  for i in jpg jpeg gif png tif tiff
  do
    if [ -f "${name}.$i" ]
    then
      RETURN_filename="${name}.$i"
      return
    fi
  done

# Grab any possible matches from the dir listing, see if we luck out.
  make_tmpfile filevars
  tmp=$RETURN_tmpfile

  ls -1 | grep -i "$name" |
          egrep -v '.html$|-[trl].(jpg|gif|png)$' > $tmp
  [ ! -s "$tmp" ] && return

  if [ `cat "$tmp" | wc -l` -eq 1 ]
  then
    RETURN_filename=`cat "$tmp"`
    return
  fi

# If multiple possible matches, report it
  echo WARNING: Unable to guess which file you want to rotate given \"$name\" 1>&2

# FIXME: Maybe some more heuristics could be done.  Like if we have
# multiple filename matches, but only one jpg, use that.  Or use the
# first jpg we find in preference to any others.

  return
}

remove_generated_versions ()
{
  local fn

  fn="$*"
  source_name_to_thumb_name "$fn"
  rm -f "$RETURN_thumb_name"
  source_name_to_reduced_name "$fn"
  rm -f "$RETURN_reduced_name"
  source_name_to_large_name "$fn"
  rm -f "$RETURN_large_name"
}

source_name_to_thumb_name ()
{
  RETURN_thumb_name=`echo "$*" | sed 's,\.[^.]*$,-t.jpg,'`
  if [ "$*" = "$RETURN_thumb_name" ]
  then
    echo ERROR: I couldn\'t create a thumb name for "\"$*\""! >&2
    exit 1
  fi
  if echo "$RETURN_thumb_name" | egrep -- '-t-t\.' >/dev/null 2>&1
  then
    echo ERROR: I couldn\'t create a reduced name for "\"$*\""! >&2
    exit 1
  fi
}

source_name_to_reduced_name ()
{
  RETURN_reduced_name=`echo "$*" | sed 's,\.[^.]*$,-r.jpg,'`
  if [ "$*" = "$RETURN_reduced_name" ]
  then
    echo ERROR: I couldn\'t create a reduced name for "\"$*\""! >&2
    exit 1
  fi
  if echo "$RETURN_reduced_name" | egrep -- '-r-r\.' >/dev/null 2>&1
  then
    echo ERROR: I couldn\'t create a reduced name for "\"$*\""! >&2
    exit 1
  fi
}

source_name_to_large_name ()
{
  RETURN_large_name=`echo "$*" | sed 's,\.[^.]*$,-l.jpg,'`
  if [ "$*" = "$RETURN_large_name" ]
  then
    echo ERROR: I couldn\'t create a large name for "\"$*\""! >&2
    exit 1
  fi
  if echo "$RETURN_large_name" | egrep -- '-l-l\.' >/dev/null 2>&1
  then
    echo ERROR: I couldn\'t create a large name for "\"$*\""! >&2
    exit 1
  fi
}

#########################################################
#### Miscellaneous helper functions (mostly from makethumbs)
#########################################################


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

check_permissions ()
{
  local have_file_write_perms have_dir_write_perms file_exists

  have_file_write_perms=0
  have_dir_write_perms=0
  file_exists=0

  if [ -w . ]
  then
    have_dir_write_perms=1
  fi

  if [ -e $DEFAULT_rotation_filename ]
  then
    file_exists=1
  fi

  if [ $file_exists -eq 1 -a -w $DEFAULT_rotation_filename ]
  then
    have_file_write_perms=1
  fi

  if [ $file_exists -eq 0 -a $have_dir_write_perms -eq 0 ]
  then
    echo ERROR: Cannot write to `pwd` and $DEFAULT_rotation_filename doesn\'t exist! 1>&2
    exit 1
  fi

  if [ $file_exists -eq 1 -a $have_file_write_perms -eq 0 ]
  then
    echo ERROR: Cannot write to $DEFAULT_rotation_filename ! 1>&2
    exit 1
  fi
}

# Look around and see what programs are installed in $PATH.
find_programs ()
{
  local prog varname

  for prog in mktemp
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


# Unnecessary paranoia - makethumbs can successfully operate even
# if you have a umask of 777 thanks to this function.  What the heck.

make_file_owner_read_writable ()
{
  [ -f "$*" ] && chmod u+rw "$*"
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
    RETURN_tmpfile=`mktemp -q "$dir/rotate-${name}.XXXXXXX"`
    touch "$RETURN_tmpfile"
    if [ $? -eq 0 -a ! -L "$RETURN_tmpfile" -a -O "$RETURN_tmpfile" ]
    then
      make_file_owner_read_writable "$RETURN_tmpfile"
      add_cleanup "$RETURN_tmpfile"
      return
    fi
  fi

  base_tmpfile="$dir/rotate-${name}.$$"
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

set_environment ()
{
  IFS=" 	
  "
  export IFS
  TMPDIR=${TMPDIR-/tmp}

# Some of the optional programs makethumbs runs suck and will dump
# core with the slightest provocation - suppress that if possible.

  ulimit -c 0 >/dev/null 2>&1

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

  if [ "x$ROTATE_AVOID_INF_LOOP" != "x" -a $testvar != testval ]
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
      ROTATE_AVOID_INF_LOOP=didrun
      export ROTATE_AVOID_INF_LOOP
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
  [ -n "$1" ] && exit $1
  exit 1
}

#########################################################
#### Call to main
#########################################################

main ${1+"$@"}

exit 0
