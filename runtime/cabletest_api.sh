#==============================================================================
#  Date      Vers  Who  Description
# -----------------------------------------------------------------------------
# 06-Dec-23  1.00  DWW  Initial Creation
#==============================================================================
CABLETEST_API_VERSION=1.00


#==============================================================================
# This calls the local copy of pcireg
#==============================================================================
pcireg()
{
    ./pcireg $1 $2 $3 $4 $5 $6
}
#==============================================================================

#==============================================================================
# AXI register definitions
#==============================================================================
CABLETEST_BASE=0x1000


       REG_MODULE_REV=$((CABLETEST_BASE +  0*4))
           REG_STATUS=$((CABLETEST_BASE +  1*4))
REG_CYCLES_PER_PACKET=$((CABLETEST_BASE +  2*4))
    REG_PACKET_COUNTH=$((CABLETEST_BASE +  3*4))
    REG_PACKET_COUNTL=$((CABLETEST_BASE +  4*4))
   REG_PACKETS_SENT1H=$((CABLETEST_BASE +  5*4))
   REG_PACKETS_SENT1L=$((CABLETEST_BASE +  6*4))
   REG_PACKETS_SENT2H=$((CABLETEST_BASE +  7*4))
   REG_PACKETS_SENT2L=$((CABLETEST_BASE +  8*4))
   REG_PACKETS_RCVD1H=$((CABLETEST_BASE +  9*4))
   REG_PACKETS_RCVD1L=$((CABLETEST_BASE + 10*4))
   REG_PACKETS_RCVD2H=$((CABLETEST_BASE + 11*4))
   REG_PACKETS_RCVD2L=$((CABLETEST_BASE + 12*4))
          REG_ERRORS1=$((CABLETEST_BASE + 13*4))
          REG_ERRORS2=$((CABLETEST_BASE + 14*4))
          REG_CONTROL=$((CABLETEST_BASE + 15*4))
       REG_ETH_STATUS=0x500

#==============================================================================
# This strips underscores from a string and converts it to decimal
#==============================================================================
strip_underscores()
{
    local stripped=$(echo $1 | sed 's/_//g')
    echo $((stripped))
}
#==============================================================================


#==============================================================================
# This displays the upper 32 bits of an integer
#==============================================================================
upper32()
{
    local value=$(strip_underscores $1)
    echo $(((value >> 32) & 0xFFFFFFFF))
}
#==============================================================================



#==============================================================================
# This displays the lower 32 bits of an integer
#==============================================================================
lower32()
{
    local value=$(strip_underscores $1)
    echo $((value & 0xFFFFFFFF))
}
#==============================================================================


#==============================================================================
# This reads a PCI register and displays its value in decimal
#==============================================================================
read_reg()
{
    # Capture the value of the AXI register
    text=$(pcireg $1)

    # Extract just the first word of that text
    text=($text)

    # Convert the text into a number
    value=$((text))

    # Hand the value to the caller
    echo $value
}
#==============================================================================


#==============================================================================
# reads a 64-bit register
#==============================================================================
read_reg64()
{
    local hi_reg=$1
    local lo_reg=$((hi_reg + 4))

    local msw=$(read_reg $hi_reg)
    local lsw=$(read_reg $lo_reg)

    if [ $(read_reg $hi_reg) -ne $msw ]; then
        msw=$(read_reg $hi_reg)
        lsw=$(read_reg $lo_reg)
    fi

    echo $(((msw << 32) | lsw))
}
#==============================================================================


#==============================================================================
# Displays 1 if bitstream is loaded, otherwise displays "0"
#==============================================================================
is_bitstream_loaded()
{
    reg=$(read_reg $REG_MODULE_REV)
    test $reg -ne $((0xFFFFFFFF)) && echo "1" || echo "0"
}
#==============================================================================


#==============================================================================
# Loads the bitstream into the FPGA
#
# Returns 0 on success, non-zero on failure
#==============================================================================
load_bitstream()
{
    ./load_bitstream $1 $2 $3  1>&2
    local rc=$?
    rm -rf .Xil/vivado_lab*
    return $rc
}
#==============================================================================


#==============================================================================
# Displays the "busy" status.  Non-zero = Busy generating packets
#==============================================================================
is_busy()
{
    local status=$(read_reg $REG_STATUS)
    echo $((status & 3))
}
#==============================================================================


#==============================================================================
# Displays the "halted" status.  Non-zero = Packet generated was halted
#==============================================================================
is_halted()
{
    local status=$(read_reg $REG_STATUS)
    echo $(((status >> 2) & 3))
}
#==============================================================================



#==============================================================================
# Starts generating the specified number of packets
#
# Returns: 0 on success, 1 on failure
#==============================================================================
start()
{
    local packet_count=$1

    if [ $(is_busy) -ne -0 ]; then
        echo "Generator is busy." 1>&2
        return 1
    elif [ -z $packet_count ]; then
        echo "Missing parameter on start()" 1>&2
        return 1
    else
        pcireg $REG_PACKET_COUNTH $(upper32 $packet_count)
        pcireg $REG_PACKET_COUNTL $(lower32 $packet_count)        
    fi

    return 0
}
#==============================================================================


#==============================================================================
# Displays the number of packets transmitted so far
#==============================================================================
get_packets_sent()
{
   
    if [ "$1" == "1" ]; then
        read_reg64 $REG_PACKETS_SENT1H
    elif [ "$1" == "2" ]; then
        read_reg64 $REG_PACKETS_SENT2H
    else
        echo "Bad parameter [$1] on get_packet_sent()" 1>&2
        echo "0"
        return
    fi
}
#==============================================================================


#==============================================================================
# Displays the total number of packets that will be sent
#==============================================================================
get_packet_count()
{
    read_reg64 $REG_PACKET_COUNTH 
}
#==============================================================================


#==============================================================================
# Displays the number of packets received
#
# $1 should be 1, 2, or blank
#==============================================================================
get_packets_rcvd()
{
    local rcvd1=$(read_reg64 $REG_PACKETS_RCVD1H)
    local rcvd2=$(read_reg64 $REG_PACKETS_RCVD2H)

    if [ "$1" == "1" ]; then
        echo $rcvd1
    elif [ "$1" == "2" ]; then
        echo $rcvd2
    else
        test $rcvd1 -lt $rcvd2 && echo $rcvd1 || echo $rcvd2
    fi
}
#==============================================================================


#==============================================================================
# Displays the number of cycles per packet
#==============================================================================
get_cycles_per_packet()
{
    read_reg $REG_CYCLES_PER_PACKET
}
#==============================================================================


#==============================================================================
# Sets the number of cycles per packet
#
# $1 should be in the range of 1 thru 129.
#==============================================================================
set_cycles_per_packet()
{
    local cycles=$1

    # Ensure that the caller gave us a parameter
    if [ "$cycles" == "" ]; then
        echo "Missing parameter on set_cycles_per_packet()" 1>&2
        return
    fi    

    # Ensure that the user is trying to set a valid value    
    if [ $cycles -lt 1 ] || [ $cycles -gt 129 ]; then
        echo "Invalid cycle count on set_cycles_per_packet()" 1>&2
        return
    fi

    # Is the packet-generator already busy?
    if [ $(is_busy) -ne 0 ]; then
        echo "Packet generator is busy" 1>&2
        return
    fi

    # The packet generator isn't busy: store the cycle count
    pcireg $REG_CYCLES_PER_PACKET $cycles
}
#==============================================================================


#==============================================================================
# Displays the number of data-mismatches detected
#==============================================================================
get_errors()
{
    if [ "$1" == "1" ]; then
        read_reg $REG_ERRORS1
    elif [ "$1" == "2" ]; then
        read_reg $REG_ERRORS2
    else
        echo "Bad parameter [$1] on get_errors()" 1>&2
        echo "0"
        return
    fi
}
#==============================================================================


#==============================================================================
# Causes the generator to inject an error
#==============================================================================
inject()
{
    pcireg $REG_CONTROL $1    
}
#==============================================================================


#==============================================================================
# Tell the generator to stop sending packets
#==============================================================================
stop()
{
    # Tell both channels to halt
    pcireg $REG_CONTROL 4 

    # This waits for the halt command to take effect
    while [ $(is_busy) -ne 0 ]; do
        sleep .1
    done
}
#==============================================================================



#==============================================================================
# Displays the PCS-lock status of an Ethernet port
#
# $1 = 0, 1 or blank (blank = both)
#
# Displays "1" if the selected Ethernet port has PCS-lock, else displays 0
#==============================================================================
get_pcs_status()
{
    local eth0_pcs_lock=0
    local eth1_pcs_lock=0

    # Fetch the ethernet status bits
    local status=$(read_reg $REG_ETH_STATUS)

    # Fetch the PCS lock status of the two ports
    test $((status & 0x00001)) -ne 0 && eth0_pcs_lock=1
    test $((status & 0x10000)) -ne 0 && eth1_pcs_lock=1

    # Display the requested status
    if [ "$1" == "0" ]; then
        echo $eth0_pcs_lock
    elif [ "$1" == "1" ]; then
        echo $eth1_pcs_lock
    else
        echo $((eth0_pcs_lock & eth1_pcs_lock))
    fi
}
#==============================================================================





