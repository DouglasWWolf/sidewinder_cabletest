# =================================================================
# This will send the specified number of gigabytes of random
# data and check to ensure the same data was read-back
# =================================================================
source cabletest_api.sh

timestamp()
{
    date +%s
}


# By default, we won't load the bitstream
need_bitstream=0

# Parse the command line
while (( "$#" )); do
    if [ $1 == "-force" ]; then
        need_bitstream=1
        shift
   else
        gigabytes=$1
        shift
   fi
done

# Ensure that the user told how how many gigabytes of data to send
if [ "$gigabytes" == "" ] || [ -z $gigabytes ]; then
    echo "Need to specify a number of gigabytes on the command line"
    exit 1
fi

# Is the bitstream not yet loaded?
test $(is_bitstream_loaded) -eq 0 && need_bitstream=1

# If we already have a the bitstream loaded...
if [ $(is_bitstream_loaded) -eq 1 ]; then

    # If there were a large number of previous errors, we're
    # going to force a reload of the bitstreams
    error_count1=$(get_errors 1)
    error_count2=$(get_errors 2)
    errors=$((error_count1 + error_count2))
    test $errors -gt 10 && need_bitstream=1

    # If there's an existing job running, halt it and wait a moment
    # for the final packets to be received
    if [ $(is_busy) -ne 0 ]; then
        echo "Halting existing job..."
        stop
        sleep 1
        echo "Halted"
    fi
fi

# If we need to load the bitstreams into the FPGA, make it so
if [ $need_bitstream -eq 1 ]; then

    # Load the cabletest bitstream first.  In the case where it was
    # busy generating packets, this will halt outgoing dataflow
    echo "Loading cabletest bitstream..."
    load_bitstream -hot_reset sidewinder_cabletest.bit 10.11.12.2:3121
    test $? -eq 0 || exit 1

    # Now that we know that there aren't packets bouncing off of it,
    # it's now safe to load the loopback bitstream
    echo "Loading loopback bitstream..."
    load_bitstream sidewinder_loopback.bit 10.11.12.3:3121
    test $? -eq 0 || exit 1
    
    # Wait a moment for PCS lock to occur
    sleep 3
    echo "Bitstreams loaded"
fi


# Display error message if we don't have PCS lock on the QSFP ports
have_pcs=1
if [ $(get_pcs_status 0) -eq 0 ]; then
    have_pcs=0;
    echo "No PCS lock detected on QSFP0" 1>&2
fi
if [ $(get_pcs_status 1) -eq 0 ]; then
    have_pcs=0;
    echo "No PCS lock detected on QSFP1" 1>&2
fi

# If we don't have QSFP lock, we can't continue
test $have_pcs -eq 0 && exit 1

# Set the packet size to 1024 bytes (i.e., 16 cycles * 64-bytes per cycle)
set_cycles_per_packet 16

# Find out how many data-cycles are in a packet
cycles_per_packet=$(get_cycles_per_packet)

# Compute the size of packet in bytes
packet_size=$((cycles_per_packet * 64))

# Convert gigabytes to bytes
xfer_size=$((gigabytes * 1024 * 1024 * 1024))

# Compute the number of packets we're going to transfer
xfer_packets=$((xfer_size / packet_size / 2))

# Start transferring packets
start $xfer_packets

# Find out when we started
ts1=$(timestamp)

percent=0
prior_rcvd=-1
rcvd_sequence=0;

printf "%15i total packets in task\n" $xfer_packets
while [ $percent -ne 100 ]; do
    
    # Keep track of the current time
    ts2=$(timestamp)

    # If this job was halted by the user, wait a half-second for the
    # final packets to be received, then call it quits
    if [ $(is_halted) -eq 3 ]; then
        echo 
        echo "Halted by user"
        sleep .5
        exit 1 
    fi

    # Find out how many packets we've received
    packets_rcvd=$(get_packets_rcvd)

    # Keep track of whether $packets_rcvd is changing
    if [ $packets_rcvd -ne $prior_rcvd ]; then
        prior_rcvd=$packets_rcvd;
        rcvd_sequence=1
    else
        rcvd_sequence=$((rcvd_sequence + 1))
    fi

    # If data isn't flowing in, stop the job
    if [ $rcvd_sequence -eq 5 ]; then
        echo -e "\n\n"
        echo "Packet flow has stopped!"
        echo $(get_packets_rcvd 1) packets received on QSFP0
        echo $(get_packets_rcvd 2) packets received on QSFP1
        exit 1        
    fi

    # Find out how many errors have occured
    errors1=$(get_errors 1)
    errors2=$(get_errors 2)
    
    # Compute the percentage complete
    percent=$((100 * packets_rcvd / xfer_packets))

    # Display our progress
    printf "\r%15i  [%3i%%]  (%i,%i errors)" $packets_rcvd $percent $errors1 $errors2

    # If we're at 100%, we're done
    test $percent -eq 100 && break;

    # Pause a moment so we don't slam the PCI bus
    sleep .5

done

# Make sure we get a linefeed at the end of our output
echo ""

# Compute the approximate number of seconds it took 
elapsed=$(( ts2 - ts1 ))

# If it took at least a second, display some basic statistics
if [ $elapsed -ne 0 ]; then 
    megabytes=$((xfer_size / 1000000))
    echo $elapsed Elapsed Seconds
    echo "Approximately $((megabytes / elapsed)) MB per second"
fi




