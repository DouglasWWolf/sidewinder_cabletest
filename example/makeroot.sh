#
# This short script will make the listed executables run  
# as the root user
#

setuid_root()
{
    sudo chown root $1
    sudo chgrp root $1
    sudo chmod 4777 $1
}

setuid_root pcireg
setuid_root load_bitstream


