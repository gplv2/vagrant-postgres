#!/bin/bash
# see http://archives.postgresql.org/pgsql-admin/2010-05/msg00285.php
# Output lines suitable for sysctl configuration based
# on total amount of RAM on the system.  The output
# will allow up to 50% of physical memory to be allocated
# into shared memory.

# On Linux, you can use it as follows (as root):
#
# ./shmsetup >> /etc/sysctl.conf
# sysctl -p

page_size=`getconf PAGE_SIZE`
phys_pages=`getconf _PHYS_PAGES`

if [ -z "$page_size" ]; then
  echo Error:  cannot determine page size
  exit 1
fi

if [ -z "$phys_pages" ]; then
  echo Error:  cannot determine number of memory pages
  exit 2
fi

shmall=`expr $phys_pages / 2`
shmmax=`expr $shmall \* $page_size` 

echo \# Maximum shared segment size in bytes
echo kernel.shmmax = $shmmax
echo \# Maximum number of shared memory segments in pages
echo kernel.shmall = $shmall

# reload
sysctl -p
