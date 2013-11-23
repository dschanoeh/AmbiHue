#!/usr/local/bin/ruby20

require 'multi_json'
require 'huey'
require 'logger'
require 'json'
require 'color'

:dim
:dynamic
:off
:direct
:lowpass

########### Configuration #############
$HUEIP = '192.168.0.16'
$TVIP = '192.168.0.15'

# Define from which side the colors should be read
$COLOR1_SIDE = "top"
$COLOR2_SIDE = "top"
$COLOR3_SIDE = "left"

# Each side has multiple elements that are numbered clockwise
$COLOR1_NUMBER = "6"
$COLOR2_NUMBER = "0"
$COLOR3_NUMBER = "2"

# Define which Hue lamps should be used
#   :dynamic changes the color according to the TV
#   :dim sets the lamp to a dim white
#   :off ignores this lamp
$USE_HUE1 = :dynamic
$USE_HUE2 = :dynamic
$USE_HUE3 = :dim

# Define how the Hue colors should be set
#   :direct direct mapping of the colors to the hues
#   :lowpass to reduce the light flashing the brightness changes slower
$COLOR_MODE = :lowpass

# Define the power of the lowpass filter [0...1]. 1 = immediate response
$LP_FACTOR = 0.3
#######################################

$logger = Logger.new(STDOUT)
$logger.level = Logger::DEBUG

# Set up Huey
$logger.info 'Configuring Huey...'
Huey.configure.hue_ip = $HUEIP

$b1 = Huey::Bulb.find(1)
$b2 = Huey::Bulb.find(2)
$b3 = Huey::Bulb.find(3)
$group = Huey::Group.new($b1, $b2, $b3)


def getTV()
    response = Net::HTTP.get(URI("http://#{$TVIP}:1925/1/ambilight/processed"))

    parsed = JSON.parse(response)
    r1 = parsed["layer1"][$COLOR1_SIDE][$COLOR1_NUMBER]["r"]
    g1 = parsed["layer1"][$COLOR1_SIDE][$COLOR1_NUMBER]["g"]
    b1 = parsed["layer1"][$COLOR1_SIDE][$COLOR1_NUMBER]["b"]

    r2 = parsed["layer1"][$COLOR2_SIDE][$COLOR2_NUMBER]["r"]
    g2 = parsed["layer1"][$COLOR2_SIDE][$COLOR2_NUMBER]["g"]
    b2 = parsed["layer1"][$COLOR2_SIDE][$COLOR2_NUMBER]["b"]

    r3 = parsed["layer1"][$COLOR3_SIDE][$COLOR3_NUMBER]["r"]
    g3 = parsed["layer1"][$COLOR3_SIDE][$COLOR3_NUMBER]["g"]
    b3 = parsed["layer1"][$COLOR3_SIDE][$COLOR3_NUMBER]["b"]

    return Color::RGB.new(r1,g1,b1), Color::RGB.new(r2,g2,b2), Color::RGB.new(r3,g3,b3)
end

def colorToHSL(color)

      # Manual calcuation is necessary here because of an error in the Color library
      r = color.r
      g = color.g
      b = color.b
      max = [r, g, b].max
      min = [r, g, b].min
      delta = max - min
      v = max * 100

      if (max != 0.0)
        s = delta / max * 100
      else
        s = 0.0
      end

      if (max == min)
        h = 0.0
      else
        if (r == max)
          h = (g - b) / delta
        elsif (g == max)
          h = 2 + (b - r) / delta
        elsif (b == max)
          h = 4 + (r - g) / delta
        end

        h *= 60.0

        if (h < 0)
          h += 360.0
        end
      end

      return (h * 182.04).round, (s / 100.0 * 255.0).round, (v / 100.0 * 255.0).round
end

$logger.info 'Initializing lamps...'
if $USE_HUE1==:dim || $USE_HUE1==:dynamic
    $b1.on = true
    $b1.bri = 20
    $b1.sat = 0
    $b1.save
end

if $USE_HUE2==:dim || $USE_HUE2==:dynamic
    $b2.on = true
    $b2.bri = 20
    $b2.sat = 0
    $b2.save
end

if $USE_HUE3==:dim || $USE_HUE3==:dynamic
    $b3.on = true
    $b3.bri = 20
    $b3.sat = 0
    $b3.save
end

$logger.info 'Starting main loop'

$oldBri1 = 100
$oldBri2 = 100
$oldBri3 = 100
$oldHue1 = 0
$oldHue2 = 0
$oldHue3 = 0
$oldSat1 = 0
$oldSat2 = 0
$oldSat3 = 0

while true do
    c1, c2, c3 = getTV

    hue1,sat1,bri1 = colorToHSL(c1)
    hue2,sat2,bri2 = colorToHSL(c2)
    hue3,sat3,bri3 = colorToHSL(c3)

    case $COLOR_MODE
    when :lowpass
        bri1 = ($LP_FACTOR * bri1 + (1-$LP_FACTOR) * $oldBri1).round
        bri2 = ($LP_FACTOR * bri2 + (1-$LP_FACTOR) * $oldBri2).round
        bri3 = ($LP_FACTOR * bri3 + (1-$LP_FACTOR) * $oldBri3).round
    end

    if $USE_HUE1==:dynamic
        $logger.debug "Setting Hue1: #{hue1},#{sat1},#{bri1}"
        $b1.hue = hue1
        $b1.sat = sat1
        $b1.bri = bri1
        $b1.save
    end

    if $USE_HUE2==:dynamic
        $logger.debug "Setting Hue2: #{hue2},#{sat2},#{bri2}"
        $b2.hue = hue2
        $b2.sat = sat2
        $b2.bri = bri2
        $b2.save
    end

    if $USE_HUE3==:dynamic
        $logger.debug "Setting Hue3: #{hue3},#{sat3},#{bri3}"
        $b3.hue = hue3
        $b3.sat = sat3
        $b3.bri = bri3
        $b3.save
    end

    $oldBri1 = bri1
    $oldBri2 = bri2
    $oldBri3 = bri3
    $oldHue1 = hue1
    $oldHue2 = hue2
    $oldHue3 = hue3
    $oldSat1 = sat1
    $oldSat2 = sat2
    $oldSat3 = sat3

    currentTime = Time.now
    if $lastTime == nil then
        $lastTime = currentTime
    end

    msecs = (currentTime - $lastTime) * 1000
    $logger.debug "Loop needed #{msecs.round} milliseconds"
    $lastTime = currentTime
end

