# Draft ZMQ capabilities
# Note that usage of these APIs is not guaranteed to be compatible across ZMQ versions.
# Use at your own risk.
module Draft

export SERVER, CLIENT, RADIO, DISH, GATHER, SCATTER, DGRAM

# Draft Socket Types, as of ZMQ 4.3.2
const SERVER = 12
const CLIENT = 13
const RADIO = 14
const DISH = 15
const GATHER = 16
const SCATTER = 17
const DGRAM = 18

end # module Draft

